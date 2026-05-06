import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/beacon_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmartSpaceProvider, BeaconService>(
      builder: (context, ss, ble, _) {
        final auth = context.watch<AuthService>();
        final user = auth.appUser;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Definições')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [

              // ── Conta ──────────────────────────────────────────────
              _GroupHeader(title: 'Conta'),
              _AccountCard(user: user, auth: auth),
              const SizedBox(height: 8),

              // ── BLE ────────────────────────────────────────────────
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
                  label: const Text('Adicionar Beacon',
                      style: TextStyle(color: AppTheme.accent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // ── About ──────────────────────────────────────────────
              const SizedBox(height: 8),
              _AboutCard(),
            ],
          ),
        );
      },
    );
  }

  void _showAddBeaconDialog(BuildContext context, BeaconService ble) {
    showDialog(context: context, builder: (_) => _AddBeaconDialog(ble: ble));
  }
}

// ── Account Card ───────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final AppUser? user;
  final AuthService auth;
  const _AccountCard({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    final roleColor = AppTheme.success;
    final initial = (user?.displayName ?? 'U')[0].toUpperCase();

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProfileSheet(user: user, auth: auth),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SS.card(accentColor: roleColor),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: roleColor.withOpacity(0.25), width: 1.5),
              ),
              child: Center(
                child: Text(initial,
                    style: TextStyle(
                        color: roleColor, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName ?? 'Utilizador',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                    ),
                    child: const Text('👤 Utilizador',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Profile Sheet ──────────────────────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  final AppUser? user;
  final AuthService auth;
  const _ProfileSheet({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    final initial = (user?.displayName ?? 'U')[0].toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.success.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: AppTheme.success, fontSize: 34, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),
          Text(user?.displayName ?? 'Utilizador',
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(user?.email ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.success.withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, color: AppTheme.success, size: 14),
                SizedBox(width: 6),
                Text('Utilizador',
                    style: TextStyle(
                        color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? '—'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.badge_outlined, label: 'Nome', value: user?.displayName ?? '—'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.person_rounded, label: 'Papel no sistema',
              value: 'Utilizador', valueColor: AppTheme.success),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.fingerprint_rounded,
              label: 'ID de utilizador',
              value: user?.uid != null ? '${user!.uid.substring(0, 8)}...' : '—'),
          const SizedBox(height: 28),
          _LogoutButton(auth: auth),
          const SizedBox(height: 12),
          _DeleteAccountButton(auth: auth),
        ],
      ),
    );
  }
}

// ── About Card ─────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SS.glowCard(),
    child: Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 12),
        const Text('SmartSpace',
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const Text('v1.0.0 • Firebase Auth',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        const Text(
          'Sistemas de IoT e Móveis 2025/26\nNOVA School of Science & Technology',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

// ── Logout + Delete (reutilizados dos dois ecrãs) ─────────────────────────────

class _LogoutButton extends StatelessWidget {
  final AuthService auth;
  const _LogoutButton({required this.auth});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 50,
    child: OutlinedButton.icon(
      onPressed: () => _confirm(context),
      icon: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 18),
      label: const Text('Terminar sessão',
          style: TextStyle(
              color: AppTheme.error, fontSize: 15, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppTheme.errorBorder),
        backgroundColor: AppTheme.errorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
          SizedBox(width: 10),
          Text('Terminar sessão?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ]),
        content: const Text('Tens a certeza que queres sair da tua conta?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
              final ss = context.read<SmartSpaceProvider>();
              await ss.clearZoneOnLogout();
              await auth.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  final AuthService auth;
  const _DeleteAccountButton({required this.auth});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 50,
    child: OutlinedButton.icon(
      onPressed: () => _confirm(context),
      icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.textMuted, size: 18),
      label: const Text('Apagar conta',
          style: TextStyle(
              color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  void _confirm(BuildContext context) {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 20),
            SizedBox(width: 10),
            Text('Apagar conta?',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta ação é irreversível. Todos os teus dados serão apagados permanentemente.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Confirma a tua password:',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordCtrl,
                obscureText: obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppTheme.textMuted, size: 18,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (passwordCtrl.text.isEmpty) return;
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                final ss = context.read<SmartSpaceProvider>();
                await ss.clearZoneOnLogout();
                final error = await auth.deleteAccount(password: passwordCtrl.text);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Apagar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36, height: 36,
        decoration: SS.iconBox(color: AppTheme.accent),
        child: Icon(icon, color: AppTheme.accent, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}

// ── Beacon Config Row ──────────────────────────────────────────────────────────

class _BeaconConfigRow extends StatelessWidget {
  final Beacon beacon;
  const _BeaconConfigRow({required this.beacon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: beacon.isNearby ? AppTheme.accentBorder : AppTheme.border),
    ),
    child: Row(
      children: [
        Icon(Icons.bluetooth_rounded,
            color: beacon.isNearby ? AppTheme.accent : AppTheme.textMuted, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beacon.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('UUID: ${beacon.uuid}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('MAC: ${beacon.mac}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ),
        if (beacon.isNearby)
          Text(beacon.signalBar,
              style: TextStyle(color: beacon.signalColor, fontSize: 12)),
      ],
    ),
  );
}

// ── Add Beacon Dialog ──────────────────────────────────────────────────────────

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
    _nameCtrl.dispose(); _uuidCtrl.dispose(); _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppTheme.surfaceCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('Adicionar Beacon', style: TextStyle(color: AppTheme.textPrimary)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'ex: Beacon Sala')),
        const SizedBox(height: 12),
        TextField(controller: _uuidCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                labelText: 'Nome do dispositivo', hintText: 'ex: R24120458')),
        const SizedBox(height: 12),
        TextField(controller: _macCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                labelText: 'MAC Address', hintText: 'ex: 51:00:24:12:01:CA')),
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
            widget.ble.registerBeacons([Beacon(
              uuid: _uuidCtrl.text.trim(),
              mac: _macCtrl.text.trim(),
              name: _nameCtrl.text.trim(),
              zoneId: _selectedZone,
            )]);
            Navigator.pop(context);
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(title.toUpperCase(),
        style: const TextStyle(
            color: AppTheme.textMuted, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
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
  const _ToggleRow({required this.icon, required this.label,
    this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: value ? AppTheme.accent : AppTheme.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        )),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}