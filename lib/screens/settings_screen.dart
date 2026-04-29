import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../services/beacon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Definições')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [

            // ── BLE ─────────────────────────────────────────────────────
            _GroupHeader(title: 'Bluetooth BLE'),
            _SettingCard(children: [
              _ToggleRow(
                icon: Icons.bluetooth_rounded,
                label: 'Scan automático',
                subtitle: 'Deteta a tua zona continuamente',
                value: ble.scanning,
                onChanged: (v) => v ? ble.startScanning() : ble.stopScanning(),
              ),
            ]),
            const SizedBox(height: 8),

            _GroupHeader(title: 'Beacons Configurados'),
            ...ble.beacons.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BeaconConfigRow(beacon: b),
            )),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () => _showAddBeaconDialog(context, ble),
                icon: const Icon(Icons.add_rounded, color: AppTheme.accent),
                label: const Text('Adicionar Beacon', style: TextStyle(color: AppTheme.accent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // ── Preferências por zona ────────────────────────────────────
            _GroupHeader(title: 'Preferências por Zona'),
            ...ss.zones.map((z) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ZonePreferencesCard(zone: z),
            )),

            // ── Sistema ──────────────────────────────────────────────────
            _GroupHeader(title: 'Sistema'),
            _SettingCard(children: [
              _ToggleRow(
                icon: Icons.cloud_rounded,
                label: 'Ligação ao servidor',
                subtitle: 'Firebase (disponível em breve)',
                value: ss.isConnected,
                onChanged: (v) => ss.setConnected(v),
              ),
              const Divider(height: 1),
              _ActionRow(
                icon: Icons.delete_sweep_rounded,
                label: 'Limpar histórico',
                subtitle: 'Remove todos os logs locais',
                color: AppTheme.error,
                onTap: () => _confirmClear(context),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Debug BLE ─────────────────────────────────────────────────
            _GroupHeader(title: 'Debug BLE'),
            _DebugBleCard(ble: ble),
            const SizedBox(height: 24),

            // ── About ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: SS.glowCard(),
              child: Column(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text('SmartSpace', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Text('v1.0.0 • Fase 1 (BLE)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('Sistemas de IoT e Móveis 2025/26\nNOVA School of Science & Technology',
                      textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBeaconDialog(BuildContext context, BeaconService ble) {
    showDialog(context: context, builder: (_) => _AddBeaconDialog(ble: ble));
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Limpar histórico?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Esta ação não pode ser desfeita.', style: TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Limpar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Debug BLE Card ────────────────────────────────────────────────────────────

class _DebugBleCard extends StatelessWidget {
  final BeaconService ble;
  const _DebugBleCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SS.glowCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dispositivos BLE detetados', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Filtra por [BLE SCAN] no Logcat para ver todos', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          if (ble.debugLog.isEmpty)
            const Text('Nenhum dispositivo detetado ainda.\nInicia o scan no Dashboard.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
          else
            ...ble.debugLog.take(10).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(entry, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'monospace')),
            )),
        ],
      ),
    );
  }
}

// ── Zone Preferences Card ─────────────────────────────────────────────────────

class _ZonePreferencesCard extends StatefulWidget {
  final Zone zone;
  const _ZonePreferencesCard({required this.zone});

  @override
  State<_ZonePreferencesCard> createState() => _ZonePreferencesCardState();
}

class _ZonePreferencesCardState extends State<_ZonePreferencesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ss = context.watch<SmartSpaceProvider>();
    final prefs = ss.preferencesFor(widget.zone.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: widget.zone.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(widget.zone.icon, color: widget.zone.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(widget.zone.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: AppTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Intensidade de luz', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                      Text('${(prefs.lightIntensity * 100).toInt()}%',
                          style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Slider(
                    value: prefs.lightIntensity,
                    onChanged: (v) => ss.updatePreferences(prefs.copyWith(lightIntensity: v)),
                    activeColor: AppTheme.warning,
                    inactiveColor: AppTheme.border,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.thermostat_rounded, color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Temperatura preferida', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                      Text('${prefs.temperatureTarget.toStringAsFixed(0)}°C',
                          style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Slider(
                    value: prefs.temperatureTarget,
                    min: 16, max: 30,
                    onChanged: (v) => ss.updatePreferences(prefs.copyWith(temperatureTarget: v)),
                    activeColor: AppTheme.error,
                    inactiveColor: AppTheme.border,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.do_not_disturb_on_rounded, color: AppTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Não incomodar', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                      Switch(
                        value: prefs.doNotDisturb,
                        onChanged: (v) => ss.updatePreferences(prefs.copyWith(doNotDisturb: v)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Beacon Config Row ─────────────────────────────────────────────────────────

class _BeaconConfigRow extends StatelessWidget {
  final Beacon beacon;
  const _BeaconConfigRow({required this.beacon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: beacon.isNearby ? AppTheme.accentBorder : AppTheme.border),
    ),
    child: Row(
      children: [
        Icon(Icons.bluetooth_rounded, color: beacon.isNearby ? AppTheme.accent : AppTheme.textMuted, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beacon.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('UUID: ${beacon.uuid}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('MAC: ${beacon.mac}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ),
        if (beacon.isNearby)
          Text(beacon.signalBar, style: TextStyle(color: beacon.signalColor, fontSize: 12)),
      ],
    ),
  );
}

// ── Add Beacon Dialog ─────────────────────────────────────────────────────────

class _AddBeaconDialog extends StatefulWidget {
  final BeaconService ble;
  const _AddBeaconDialog({required this.ble});

  @override
  State<_AddBeaconDialog> createState() => _AddBeaconDialogState();
}

class _AddBeaconDialogState extends State<_AddBeaconDialog> {
  final _nameCtrl = TextEditingController();
  final _uuidCtrl = TextEditingController();
  final _macCtrl  = TextEditingController();
  String _selectedZone = 'zone_a';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _uuidCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: const Text('Adicionar Beacon', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'ex: Beacon Sala'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _uuidCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Nome do dispositivo', hintText: 'ex: R24120458'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _macCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'ex: 51:00:24:12:01:CA'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedZone,
            dropdownColor: AppTheme.surfaceCard,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Zona associada'),
            items: const [
              DropdownMenuItem(value: 'zone_a', child: Text('Sala')),
              DropdownMenuItem(value: 'zone_b', child: Text('Quarto')),
              DropdownMenuItem(value: 'zone_c', child: Text('Escritório')),
            ],
            onChanged: (v) => setState(() => _selectedZone = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.isNotEmpty && _uuidCtrl.text.isNotEmpty && _macCtrl.text.isNotEmpty) {
              widget.ble.registerBeacons([
                Beacon(
                  uuid: _uuidCtrl.text.trim(),
                  mac: _macCtrl.text.trim(),
                  name: _nameCtrl.text.trim(),
                  zoneId: _selectedZone,
                ),
              ]);
              Navigator.pop(context);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(title.toUpperCase(),
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
  );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: children),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.icon, required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: value ? AppTheme.accent : AppTheme.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 14)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 18),
        ],
      ),
    ),
  );
}