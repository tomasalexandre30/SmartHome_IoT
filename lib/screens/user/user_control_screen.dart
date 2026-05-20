import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class UserControlScreen extends StatefulWidget {
  const UserControlScreen({super.key});
  @override
  State<UserControlScreen> createState() => _UserControlScreenState();
}

class _UserControlScreenState extends State<UserControlScreen> {
  String? _lastShownPollZone;
  String? _lastShownPollId;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final currentZoneId = ss.currentZoneId ?? ble.currentZoneId;
        final currentZone = ss.zones.where((z) => z.id == currentZoneId).firstOrNull;

        // Mostrar poll dialog quando chegar uma poll nova
        if (currentZone?.activePoll != null) {
          final poll = currentZone!.activePoll!;
          final pollId = '${poll.requestedBy}_${poll.expiresAt.millisecondsSinceEpoch}';
          final alreadyVoted = poll.votes.containsKey(ss.uid);
          final isRequester = poll.requestedBy == ss.uid;

          if (!alreadyVoted && !isRequester &&
              (_lastShownPollZone != currentZoneId || _lastShownPollId != pollId)) {
            _lastShownPollZone = currentZoneId;
            _lastShownPollId = pollId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showPollDialog(context, ss, currentZone, poll);
            });
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Controlo')),
          body: currentZone == null
              ? _NoZoneState(scanning: ble.scanning)
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _CurrentZoneBanner(zone: currentZone),
              _PollStatusBanner(zoneId: currentZone.id),
              const SizedBox(height: 24),
              // Modo absoluto ativo — user vê banner e controlos desaparecem
              if (currentZone.isAbsoluteLocked) ...[
                _AbsoluteLockedBanner(zone: currentZone),
              ] else ...[
                const SectionHeader(title: 'Modo de controlo'),
                const SizedBox(height: 10),
                _LightModeSelector(zone: currentZone, ss: ss),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Controlos'),
                const SizedBox(height: 10),
                _ControlsGrid(zone: currentZone),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Sensores da zona'),
              const SizedBox(height: 10),
              _SensorsCard(zone: currentZone),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Estado das outras zonas'),
              const SizedBox(height: 10),
              ...ss.zones
                  .where((z) => z.id != currentZoneId)
                  .map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OtherZoneRow(zone: z),
              )),
            ],
          ),
        );
      },
    );
  }

  void _showPollDialog(BuildContext context, SmartSpaceProvider ss, Zone zone, ZonePoll poll) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PollDialog(zone: zone, poll: poll, ss: ss),
    );
  }
}

// ── Poll Dialog ───────────────────────────────────────────────────────────────

class _PollDialog extends StatefulWidget {
  final Zone zone;
  final ZonePoll poll;
  final SmartSpaceProvider ss;
  const _PollDialog({required this.zone, required this.poll, required this.ss});

  @override
  State<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends State<_PollDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.poll.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining = (_remaining - 1).clamp(0, 30));
      if (_remaining <= 0) { t.cancel(); if (mounted) Navigator.of(context).pop(); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String get _actionDescription {
    switch (widget.poll.action) {
      case 'lightOff':      return 'desligar a luz';
      case 'lightOn':       return 'ligar a luz';
      case 'setIntensity':
        final pct = widget.poll.intensity != null
            ? ' para ${(widget.poll.intensity! * 100).toInt()}%' : '';
        return 'mudar a intensidade$pct';
      case 'setColor':
        return 'mudar a cor do LED';
      case 'setModeAuto':   return 'mudar para modo AUTO';
      case 'setModeManual': return 'mudar para modo MANUAL';
      default:              return widget.poll.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / 30.0;
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.how_to_vote_rounded, color: AppTheme.warning, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Votação',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${_remaining}s',
              style: const TextStyle(color: AppTheme.accent, fontSize: 12,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        ),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress, backgroundColor: AppTheme.border,
            color: progress > 0.3 ? AppTheme.accent : AppTheme.error, minHeight: 3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.poll.requestedByName} quer $_actionDescription na ${widget.zone.name}.',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Aceitas?', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.ss.votePoll(widget.zone.id, false);
            if (!mounted) return;
            Navigator.of(context).pop();
            // Se é intensidade ou cor → pedir contra-proposta
            if (widget.poll.action == 'setIntensity') {
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) {
                _showCounterProposalDialog(context, widget.ss, widget.zone, widget.poll);
              }
            } else if (widget.poll.action == 'setColor') {
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) {
                _showColorCounterProposalDialog(context, widget.ss, widget.zone, widget.poll);
              }
            }
          },
          child: const Text('Não', style: TextStyle(color: AppTheme.error)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          onPressed: () {
            widget.ss.votePoll(widget.zone.id, true);
            Navigator.of(context).pop();
          },
          child: const Text('Sim', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Poll Status Banner ────────────────────────────────────────────────────────

// ── Poll Status Banner — usa Consumer para reagir ao estado atual ────────────
// Desaparece imediatamente quando activePoll fica null

class _PollStatusBanner extends StatefulWidget {
  final String zoneId;
  const _PollStatusBanner({required this.zoneId});

  @override
  State<_PollStatusBanner> createState() => _PollStatusBannerState();
}

class _PollStatusBannerState extends State<_PollStatusBanner> {
  int _remaining = 30;
  Timer? _timer;
  String? _lastPollId;

  void _startTimer(ZonePoll poll) {
    _timer?.cancel();
    _remaining = poll.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining = (_remaining - 1).clamp(0, 30));
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(
      builder: (context, ss, _) {
        final zone = ss.zoneById(widget.zoneId);
        final poll = zone?.activePoll;

        // Poll desapareceu → oculta imediatamente
        if (poll == null) {
          _timer?.cancel();
          _lastPollId = null;
          return const SizedBox.shrink();
        }

        // Poll nova → reinicia timer
        final pollId = '${poll.requestedBy}_${poll.expiresAt.millisecondsSinceEpoch}';
        if (pollId != _lastPollId) {
          _lastPollId = pollId;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer(poll));
        }

        final alreadyVoted = poll.votes.containsKey(ss.uid);
        final yes = poll.yesVotes;
        final no  = poll.noVotes;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.how_to_vote_rounded, color: AppTheme.warning, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Votação em curso — ${_remaining}s',
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Text('$yes sim · $no não',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
            if (!alreadyVoted) ...[
              const SizedBox(height: 8),
              Text('${poll.requestedByName} pediu para mudar a zona.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ] else
              const Text('Votaste — a aguardar os restantes...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        );
      },
    );
  }
}

// ── Absolute Locked Banner ────────────────────────────────────────────────────

class _AbsoluteLockedBanner extends StatelessWidget {
  final Zone zone;
  const _AbsoluteLockedBanner({required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.lock_rounded, color: AppTheme.error, size: 16),
      const SizedBox(width: 10),
      const Expanded(
        child: Text('Zona controlada pelo administrador.\nControlos temporariamente bloqueados.',
            style: TextStyle(color: AppTheme.error, fontSize: 12)),
      ),
    ]),
  );
}

// ── Light Mode Selector ───────────────────────────────────────────────────────

class _LightModeSelector extends StatelessWidget {
  final Zone zone;
  final SmartSpaceProvider ss;
  const _LightModeSelector({required this.zone, required this.ss});

  @override
  Widget build(BuildContext context) {
    final isAuto = zone.lightMode == LightMode.auto;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _ModeButton(
          label: 'AUTO',
          icon: Icons.auto_awesome_rounded,
          sublabel: 'LDR ajusta intensidade',
          active: isAuto,
          color: AppTheme.accent,
          onTap: () => ss.setZoneLightMode(zone.id, LightMode.auto),
        ),
        const SizedBox(width: 4),
        _ModeButton(
          label: 'MANUAL',
          icon: Icons.tune_rounded,
          sublabel: 'Controlo total',
          active: !isAuto,
          color: AppTheme.warning,
          onTap: () => ss.setZoneLightMode(zone.id, LightMode.manual),
        ),
      ]),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.icon, required this.sublabel,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color.withOpacity(0.4), width: 1.5) : null,
        ),
        child: Column(children: [
          Icon(icon, color: active ? color : AppTheme.textMuted, size: 20),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
              color: active ? color : AppTheme.textMuted,
              fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sublabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

// ── No Zone State ─────────────────────────────────────────────────────────────

class _NoZoneState extends StatelessWidget {
  final bool scanning;
  const _NoZoneState({required this.scanning});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              scanning ? Icons.bluetooth_searching_rounded : Icons.location_off_rounded,
              color: AppTheme.accent, size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(scanning ? 'À procura da tua zona...' : 'Nenhuma zona detetada',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            scanning
                ? 'Os controlos ficam disponíveis quando a tua zona for detetada.'
                : 'Ativa o scan BLE no Dashboard para detetar a tua zona.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

// ── Current Zone Banner ───────────────────────────────────────────────────────

class _CurrentZoneBanner extends StatelessWidget {
  final Zone zone;
  const _CurrentZoneBanner({required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: SS.glowCard(glowColor: zone.color),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
            color: zone.color.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
        child: Icon(zone.icon, color: zone.color, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Zona atual',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(zone.name,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.people_rounded, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text('${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),
      ])),
      ZoneStatusBadge(zone: zone),
    ]),
  );
}

// ── Controls Grid ─────────────────────────────────────────────────────────────

class _ControlsGrid extends StatelessWidget {
  final Zone zone;
  const _ControlsGrid({required this.zone});

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    // _ControlsGrid só é mostrado quando não há ABSOLUTE — isBlocked é sempre false aqui
    const isBlocked = false;
    final isAuto = zone.lightMode == LightMode.auto;

    return Column(children: [
      Row(children: [
        Expanded(
          child: _BigToggleBtn(
            icon: zone.lightOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
            label: 'LED RGB',
            sublabel: isAuto ? 'AUTO' : (zone.lightOn ? 'Ligado' : 'Desligado'),
            active: zone.lightOn, color: AppTheme.warning, enabled: !isBlocked,
            onTap: () => ss.toggleLight(zone.id),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigToggleBtn(
            icon: zone.buzzerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: 'Buzzer', sublabel: zone.buzzerOn ? 'Ativo' : 'Inativo',
            active: zone.buzzerOn, color: AppTheme.error, enabled: !isBlocked,
            onTap: () => ss.toggleBuzzer(zone.id),
          ),
        ),
      ]),

      if (zone.lightOn) ...[
        const SizedBox(height: 12),
        if (isAuto)
          _AutoLdrIndicator(zone: zone)
        else ...[
          // Intensidade — em MANUAL (usa widget com estado local para o slider)
          _IntensitySlider(zone: zone, enabled: !isBlocked),
          const SizedBox(height: 12),
          _ColorPickerCard(zone: zone),
          const SizedBox(height: 12),
          _TimerCard(zone: zone),
        ],
      ],
    ]);
  }
}

// ── Auto LDR Indicator ────────────────────────────────────────────────────────

class _AutoLdrIndicator extends StatelessWidget {
  final Zone zone;
  const _AutoLdrIndicator({required this.zone});

  @override
  Widget build(BuildContext context) {
    final ldr = zone.luminosity ?? 0.0;
    final threshold = zone.automations.ldrThreshold;
    final autoIntensity = (zone.lightIntensity * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: SS.iconBox(color: AppTheme.accent),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 16)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Intensidade automática',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('$autoIntensity%',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: zone.lightIntensity.clamp(0.0, 1.0),
            backgroundColor: AppTheme.border, color: AppTheme.accent, minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.wb_sunny_rounded, color: AppTheme.warning, size: 14),
          const SizedBox(width: 6),
          Text('Luminosidade: ${ldr.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('Limiar: ${threshold.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(
          ldr >= threshold
              ? 'Luz ambiente suficiente — LED desligado automaticamente'
              : 'A compensar luz ambiente com intensidade adaptativa',
          style: TextStyle(color: ldr >= threshold ? AppTheme.success : AppTheme.accent, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ── Intensity Slider — estado local para evitar polls a cada pixel ───────────

class _IntensitySlider extends StatefulWidget {
  final Zone zone;
  final bool enabled;
  const _IntensitySlider({required this.zone, required this.enabled});

  @override
  State<_IntensitySlider> createState() => _IntensitySliderState();
}

class _IntensitySliderState extends State<_IntensitySlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.zone.lightIntensity;
  }

  @override
  void didUpdateWidget(_IntensitySlider old) {
    super.didUpdateWidget(old);
    // Só atualiza o valor local se não está a arrastar
    // (para não interromper o gesto do utilizador)
    if (!_dragging) _localValue = widget.zone.lightIntensity;
  }

  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: SS.card(),
      child: Column(children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: SS.iconBox(color: AppTheme.warning),
              child: const Icon(Icons.brightness_6_rounded, color: AppTheme.warning, size: 16)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Intensidade',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('${(_localValue * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: _localValue,
            onChanged: widget.enabled ? (v) {
              setState(() { _localValue = v; _dragging = true; });
            } : null,
            onChangeEnd: widget.enabled ? (v) {
              _dragging = false;
              // Só envia quando o utilizador larga o slider
              ss.setLightIntensity(widget.zone.id, v);
            } : null,
            activeColor: AppTheme.warning, inactiveColor: AppTheme.border,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            Text('100%', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ]),
    );
  }
}

// ── Color Picker Card ─────────────────────────────────────────────────────────

class _PresetColor { final String name; final Color color; const _PresetColor(this.name, this.color); }

class _ColorPickerCard extends StatelessWidget {
  final Zone zone;
  const _ColorPickerCard({required this.zone});

  static const List<_PresetColor> _presets = [
    _PresetColor('Branco', Color(0xFFFFFFFF)), _PresetColor('Vermelho', Color(0xFFFF0000)),
    _PresetColor('Verde', Color(0xFF00FF00)),  _PresetColor('Azul', Color(0xFF0000FF)),
    _PresetColor('Amarelo', Color(0xFFFFFF00)),_PresetColor('Ciano', Color(0xFF00FFFF)),
    _PresetColor('Magenta', Color(0xFFFF00FF)),_PresetColor('Laranja', Color(0xFFFF6600)),
    _PresetColor('Roxo', Color(0xFF8800FF)),   _PresetColor('Rosa', Color(0xFFFF0088)),
  ];

  @override
  Widget build(BuildContext context) {
    final ss = context.read<SmartSpaceProvider>();
    final currentColor = zone.lightColor;
    final isWhite = zone.lightR > 200 && zone.lightG > 200 && zone.lightB > 200;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SS.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isWhite ? const Color(0xFF2C2C2C) : currentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isWhite ? const Color(0xFF555555) : currentColor.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(Icons.palette_rounded, color: isWhite ? Colors.white : currentColor, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Cor do LED',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: currentColor, borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isWhite ? const Color(0xFF999999) : currentColor.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(
                  color: isWhite ? Colors.grey.withOpacity(0.3) : currentColor.withOpacity(0.5),
                  blurRadius: 10, spreadRadius: 1)],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _presets.map((preset) {
            final isSelected = zone.lightR == preset.color.red &&
                zone.lightG == preset.color.green && zone.lightB == preset.color.blue;
            final isPresetWhite = preset.color == Colors.white;
            return GestureDetector(
              onTap: () => ss.setLightColor(zone.id, preset.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isPresetWhite
                      ? (isSelected ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8))
                      : preset.color.withOpacity(isSelected ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPresetWhite
                        ? (isSelected ? const Color(0xFF888888) : const Color(0xFFCCCCCC))
                        : (isSelected ? preset.color.withOpacity(0.8) : preset.color.withOpacity(0.3)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: preset.color, shape: BoxShape.circle,
                          border: isPresetWhite ? Border.all(color: const Color(0xFFAAAAAA), width: 1) : null)),
                  const SizedBox(width: 6),
                  Text(preset.name, style: TextStyle(
                      color: isPresetWhite ? (isSelected ? Colors.white : AppTheme.textPrimary) : preset.color,
                      fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _RgbSliderRow(label: 'R', value: zone.lightR, color: const Color(0xFFFF3333),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(v, zone.lightG, zone.lightB, 1.0))),
        const SizedBox(height: 8),
        _RgbSliderRow(label: 'G', value: zone.lightG, color: const Color(0xFF22CC22),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(zone.lightR, v, zone.lightB, 1.0))),
        const SizedBox(height: 8),
        _RgbSliderRow(label: 'B', value: zone.lightB, color: const Color(0xFF3366FF),
            onChanged: (v) => ss.setLightColor(zone.id, Color.fromRGBO(zone.lightR, zone.lightG, v, 1.0))),
        const SizedBox(height: 12),
        Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border)),
          child: Text('RGB(${zone.lightR}, ${zone.lightG}, ${zone.lightB})',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11,
                  fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        )),
      ]),
    );
  }
}

class _RgbSliderRow extends StatelessWidget {
  final String label; final int value; final Color color; final ValueChanged<int> onChanged;
  const _RgbSliderRow({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 16, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
    const SizedBox(width: 8),
    Expanded(child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(value: value.toDouble(), min: 0, max: 255,
          onChanged: (v) => onChanged(v.toInt()), activeColor: color, inactiveColor: AppTheme.border),
    )),
    const SizedBox(width: 8),
    SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.right,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
  ]);
}

// ── Timer Card ────────────────────────────────────────────────────────────────

class _TimerCard extends StatefulWidget {
  final Zone zone;
  const _TimerCard({required this.zone});
  @override State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  int _selectedMinutes = 15;
  Timer? _countdown;
  int _remainingSeconds = 0;
  bool _active = false;
  static const List<int> _options = [5, 10, 15, 30, 60];

  @override
  void dispose() { _countdown?.cancel(); super.dispose(); }

  void _start() {
    setState(() { _active = true; _remainingSeconds = _selectedMinutes * 60; });
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        t.cancel(); setState(() => _active = false);
        final ss = context.read<SmartSpaceProvider>();
        if (widget.zone.lightOn) ss.toggleLight(widget.zone.id);
      }
    });
  }

  void _cancel() { _countdown?.cancel(); setState(() { _active = false; _remainingSeconds = 0; }); }

  String get _formattedTime {
    final m = _remainingSeconds ~/ 60; final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _active ? _remainingSeconds / (_selectedMinutes * 60) : 1.0;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16), decoration: SS.card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32, decoration: SS.iconBox(color: AppTheme.accent),
            child: const Icon(Icons.timer_rounded, color: AppTheme.accent, size: 16)),
        const SizedBox(width: 10),
        const Expanded(child: Text('Temporizador',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
        if (_active) Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(_formattedTime, style: const TextStyle(color: AppTheme.accent, fontSize: 13,
              fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        ),
      ]),
      const SizedBox(height: 14),
      if (!_active) ...[
        Row(children: _options.map((min) {
          final selected = _selectedMinutes == min;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _selectedMinutes = min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: min == _options.last ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected ? AppTheme.accent.withOpacity(0.5) : AppTheme.border,
                    width: selected ? 1.5 : 1),
              ),
              child: Column(children: [
                Text('$min', style: TextStyle(color: selected ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w800)),
                Text('min', style: TextStyle(color: selected ? AppTheme.accent : AppTheme.textMuted, fontSize: 9)),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: widget.zone.lightOn ? _start : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.zone.lightOn ? AppTheme.accent.withOpacity(0.12) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: widget.zone.lightOn ? AppTheme.accent.withOpacity(0.4) : AppTheme.border),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined,
                  color: widget.zone.lightOn ? AppTheme.accent : AppTheme.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(widget.zone.lightOn ? 'Desligar em $_selectedMinutes min' : 'Luz já está desligada',
                  style: TextStyle(color: widget.zone.lightOn ? AppTheme.accent : AppTheme.textMuted,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ] else ...[
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _progress, backgroundColor: AppTheme.border,
                color: AppTheme.accent, minHeight: 4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.lightbulb_rounded, color: AppTheme.accent, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text('A luz desliga em $_formattedTime',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13))),
            GestureDetector(onTap: _cancel, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3))),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.error,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ],
    ]),
  );
}

// ── Big Toggle Button ─────────────────────────────────────────────────────────

class _BigToggleBtn extends StatelessWidget {
  final IconData icon; final String label, sublabel;
  final bool active, enabled; final Color color; final VoidCallback onTap;
  const _BigToggleBtn({required this.icon, required this.label, required this.sublabel,
    required this.active, required this.enabled, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.10) : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: !enabled ? AppTheme.border.withOpacity(0.5)
                : active ? color.withOpacity(0.35) : AppTheme.border,
            width: active ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: active ? color.withOpacity(0.15) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: enabled ? (active ? color : AppTheme.textMuted) : AppTheme.border, size: 22)),
          Switch(value: active, onChanged: enabled ? (_) => onTap() : null,
              activeColor: color, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(
            color: enabled ? (active ? AppTheme.textPrimary : AppTheme.textSecondary) : AppTheme.textMuted,
            fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
              color: enabled ? (active ? color : AppTheme.textMuted) : AppTheme.border,
              shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(sublabel, style: TextStyle(
              color: enabled ? (active ? color : AppTheme.textMuted) : AppTheme.border, fontSize: 12)),
        ]),
      ]),
    ),
  );
}

// ── Sensors Card ──────────────────────────────────────────────────────────────

class _SensorsCard extends StatelessWidget {
  final Zone zone;
  const _SensorsCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final hasData = zone.temperature != null || zone.humidity != null ||
        zone.luminosity != null || zone.motionDetected != null;

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(20), decoration: SS.card(),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: SS.iconBox(color: AppTheme.textMuted),
              child: const Icon(Icons.sensors_off_rounded, color: AppTheme.textMuted, size: 20)),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sem dados de sensores', style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('Aguarda a ligação ao ESP32.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ])),
        ]),
      );
    }

    return Container(decoration: SS.card(), child: Column(children: [
      if (zone.temperature != null)
        _SensorRow(icon: Icons.thermostat_rounded, label: 'Temperatura',
            value: '${zone.temperature!.toStringAsFixed(1)}°C', color: AppTheme.warning),
      if (zone.humidity != null) ...[
        const Divider(height: 1, indent: 16, endIndent: 16),
        _SensorRow(icon: Icons.water_drop_rounded, label: 'Humidade',
            value: '${zone.humidity!.toStringAsFixed(0)}%', color: AppTheme.accent),
      ],
      if (zone.luminosity != null) ...[
        const Divider(height: 1, indent: 16, endIndent: 16),
        _SensorRow(icon: Icons.wb_sunny_rounded, label: 'Luminosidade',
            value: '${zone.luminosity!.toStringAsFixed(0)}%', color: const Color(0xFFFFB830)),
      ],
      if (zone.motionDetected != null) ...[
        const Divider(height: 1, indent: 16, endIndent: 16),
        _SensorRow(icon: Icons.motion_photos_on_rounded, label: 'Movimento',
            value: zone.motionDetected! ? 'Detetado' : 'Sem movimento',
            color: zone.motionDetected! ? AppTheme.success : AppTheme.textMuted),
      ],
    ]));
  }
}

class _SensorRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _SensorRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: SS.iconBox(color: color),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ]),
  );
}

// ── Other Zone Row ────────────────────────────────────────────────────────────

class _OtherZoneRow extends StatelessWidget {
  final Zone zone;
  const _OtherZoneRow({required this.zone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14), decoration: SS.card(),
    child: Row(children: [
      Container(width: 42, height: 42,
          decoration: BoxDecoration(color: zone.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(zone.icon, color: zone.color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(zone.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.people_rounded, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text('${zone.occupantCount} ocupante${zone.occupantCount != 1 ? "s" : ""}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      ])),
      ZoneStatusBadge(zone: zone),
    ]),
  );
}

// ── Counter-Proposal Dialogs ──────────────────────────────────────────────────

void _showCounterProposalDialog(
    BuildContext context, SmartSpaceProvider ss, Zone zone, ZonePoll poll) {
  double sliderValue = zone.lightIntensity;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: AppTheme.warning, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Qual a tua preferência?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${poll.requestedByName} pediu ${(poll.intensity! * 100).toInt()}% de intensidade.\n'
                'Indica a tua preferência — será calculada a média.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('${(sliderValue * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 28, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Slider(
            value: sliderValue, min: 0, max: 1,
            activeColor: AppTheme.warning, inactiveColor: AppTheme.border,
            onChanged: (v) => setStateDialog(() => sliderValue = v),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              ss.submitCounterProposal(zone.id, intensity: sliderValue);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

void _showColorCounterProposalDialog(
    BuildContext context, SmartSpaceProvider ss, Zone zone, ZonePoll poll) {
  int r = zone.lightR, g = zone.lightG, b = zone.lightB;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.palette_rounded, color: AppTheme.warning, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Qual a tua cor preferida?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${poll.requestedByName} pediu uma mudança de cor.\n'
                'Indica a tua preferência — será calculada a média RGB.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Color.fromRGBO(r, g, b, 1.0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
          )),
          const SizedBox(height: 12),
          _SimpleRgbRow(label: 'R', value: r, color: const Color(0xFFFF3333),
              onChanged: (v) => setStateDialog(() => r = v)),
          _SimpleRgbRow(label: 'G', value: g, color: const Color(0xFF22CC22),
              onChanged: (v) => setStateDialog(() => g = v)),
          _SimpleRgbRow(label: 'B', value: b, color: const Color(0xFF3366FF),
              onChanged: (v) => setStateDialog(() => b = v)),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              ss.submitCounterProposal(zone.id, r: r, g: g, b: b);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

class _SimpleRgbRow extends StatelessWidget {
  final String label; final int value; final Color color; final ValueChanged<int> onChanged;
  const _SimpleRgbRow({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 16, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
    const SizedBox(width: 8),
    Expanded(child: Slider(
      value: value.toDouble(), min: 0, max: 255,
      onChanged: (v) => onChanged(v.toInt()),
      activeColor: color, inactiveColor: AppTheme.border,
    )),
    SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.right,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
  ]);
}