import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/smartspace_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen>
    with SingleTickerProviderStateMixin {
  LogCategory? _categoryFilter;
  String? _zoneFilter;
  String _search = '';
  bool _showSearch = false;
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _categoryFilter = switch (_tabController.index) {
          1 => LogCategory.auth,
          2 => LogCategory.zones,
          3 => LogCategory.commands,
          4 => LogCategory.system,
          _ => null,
        };
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final ss = context.read<SmartSpaceProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Pesquisar eventos ou utilizadores...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _search = v),
        )
            : const Text('Histórico Global'),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: _showSearch ? AppTheme.accent : AppTheme.textMuted,
            ),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _search = '';
                _searchCtrl.clear();
              }
            }),
          ),
          IconButton(
            icon: Icon(
              _zoneFilter != null
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color:
              _zoneFilter != null ? AppTheme.accent : AppTheme.textMuted,
            ),
            onPressed: () => _showFilterSheet(context, ss.zones),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Autenticação'),
            Tab(text: 'Zonas'),
            Tab(text: 'Comandos'),
            Tab(text: 'Sistema'),
          ],
        ),
      ),
      body: StreamBuilder<List<LogEvent>>(
        stream: db.allLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }

          final firestoreLogs = snapshot.data ?? [];
          final allLogs = _mergeLogs(firestoreLogs, ss.logs);

          var filtered = allLogs.toList();
          if (_categoryFilter != null) {
            filtered = filtered
                .where((e) => e.category == _categoryFilter)
                .toList();
          }
          if (_zoneFilter != null) {
            filtered =
                filtered.where((e) => e.zoneId == _zoneFilter).toList();
          }
          if (_search.isNotEmpty) {
            filtered = filtered
                .where((e) =>
            e.message
                .toLowerCase()
                .contains(_search.toLowerCase()) ||
                e.userName
                    .toLowerCase()
                    .contains(_search.toLowerCase()))
                .toList();
          }

          return Column(
            children: [
              // ── Stats ──────────────────────────────────────────────
              _AdminStatsBar(logs: allLogs),

              // ── Filtros ativos ─────────────────────────────────────
              if (_zoneFilter != null || _search.isNotEmpty)
                _ActiveFilters(
                  zoneFilter: _zoneFilter,
                  search: _search,
                  zones: ss.zones,
                  count: filtered.length,
                  onRemoveZone: () => setState(() => _zoneFilter = null),
                  onRemoveSearch: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),

              // ── Lista ──────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyHistory(
                    hasFilters: _categoryFilter != null ||
                        _zoneFilter != null ||
                        _search.isNotEmpty)
                    : ListView.builder(
                  padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final showHeader = i == 0 ||
                        !_sameDay(filtered[i].timestamp,
                            filtered[i - 1].timestamp);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          _DateHeader(date: filtered[i].timestamp),
                        _AdminLogTile(
                          event: filtered[i],
                          zoneName: ss.zones
                              .where((z) =>
                          z.id == filtered[i].zoneId)
                              .firstOrNull
                              ?.name,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<LogEvent> _mergeLogs(
      List<LogEvent> firestore, List<LogEvent> local) {
    final ids = firestore.map((e) => e.id).toSet();
    final localOnly =
    local.where((e) => !ids.contains(e.id)).toList();
    final merged = [...firestore, ...localOnly];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showFilterSheet(BuildContext context, List<Zone> zones) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Filtrar por zona',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: zones.map((z) {
                final active = _zoneFilter == z.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _zoneFilter =
                    z.id == _zoneFilter ? null : z.id);
                    Navigator.pop(context);
                  },
                  child: _FilterPill(
                    label: z.name,
                    icon: z.icon,
                    active: active,
                    color: z.color,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (_zoneFilter != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _zoneFilter = null);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_all_rounded,
                      color: AppTheme.error),
                  label: const Text('Limpar filtro',
                      style: TextStyle(color: AppTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppTheme.errorBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Stats Bar ────────────────────────────────────────────────────────────

class _AdminStatsBar extends StatelessWidget {
  final List<LogEvent> logs;
  const _AdminStatsBar({required this.logs});

  @override
  Widget build(BuildContext context) {
    final total = logs.length;
    final auth =
        logs.where((e) => e.category == LogCategory.auth).length;
    final zones =
        logs.where((e) => e.category == LogCategory.zones).length;
    final commands =
        logs.where((e) => e.category == LogCategory.commands).length;
    final system =
        logs.where((e) => e.category == LogCategory.system).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(glowColor: AppTheme.accent),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              Text('$total eventos registados no total',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(
                  value: '$auth',
                  label: 'Auth',
                  color: const Color(0xFF8B5CF6)),
              _divider(),
              _StatItem(
                  value: '$zones',
                  label: 'Zonas',
                  color: AppTheme.success),
              _divider(),
              _StatItem(
                  value: '$commands',
                  label: 'Comandos',
                  color: AppTheme.accent),
              _divider(),
              _StatItem(
                  value: '$system',
                  label: 'Sistema',
                  color: AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 30,
      color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 10),
            textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── Active Filters ─────────────────────────────────────────────────────────────

class _ActiveFilters extends StatelessWidget {
  final String? zoneFilter;
  final String search;
  final List<Zone> zones;
  final int count;
  final VoidCallback onRemoveZone;
  final VoidCallback onRemoveSearch;

  const _ActiveFilters({
    required this.zoneFilter,
    required this.search,
    required this.zones,
    required this.count,
    required this.onRemoveZone,
    required this.onRemoveSearch,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        if (zoneFilter != null)
          _Chip(
            label: zones
                .where((z) => z.id == zoneFilter)
                .firstOrNull
                ?.name ??
                zoneFilter!,
            onRemove: onRemoveZone,
          ),
        if (search.isNotEmpty) ...[
          const SizedBox(width: 6),
          _Chip(label: '"$search"', onRemove: onRemoveSearch),
        ],
        const SizedBox(width: 8),
        Text('$count eventos',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 12)),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: SS.pill(color: AppTheme.accent),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.accent, fontSize: 12)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded,
              color: AppTheme.accent, size: 14),
        ),
      ],
    ),
  );
}

// ── Admin Log Tile ─────────────────────────────────────────────────────────────

class _AdminLogTile extends StatelessWidget {
  final LogEvent event;
  final String? zoneName;
  const _AdminLogTile({required this.event, this.zoneName});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showDetails(context),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: event.color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: event.color.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícone + categoria ──────────────────────────────────
          Column(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: event.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: event.color.withOpacity(0.25)),
                ),
                child:
                Icon(event.icon, color: event.color, size: 18),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: event.type.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _shortCategory(event.category),
                  style: TextStyle(
                    color: event.type.categoryColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Conteúdo ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.message,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    if (event.userName.isNotEmpty)
                      _MetaChip(
                        icon: Icons.person_rounded,
                        label: event.userName,
                        color: const Color(0xFF8B5CF6),
                      ),
                    if (zoneName != null)
                      _MetaChip(
                        icon: Icons.room_rounded,
                        label: zoneName!,
                        color: AppTheme.accent,
                      ),
                    _MetaChip(
                      icon: Icons.access_time_rounded,
                      label: _formatTime(event.timestamp),
                      color: AppTheme.textMuted,
                    ),
                    _MetaChip(
                      icon: event.isAdmin
                          ? Icons.shield_rounded
                          : Icons.person_outline_rounded,
                      label: event.isAdmin ? 'Admin' : 'User',
                      color: event.isAdmin
                          ? AppTheme.accent
                          : AppTheme.success,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Chevron ────────────────────────────────────────────
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textMuted, size: 16),
        ],
      ),
    ),
  );

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LogDetailSheet(event: event, zoneName: zoneName),
    );
  }

  String _shortCategory(LogCategory c) {
    switch (c) {
      case LogCategory.auth:     return 'AUTH';
      case LogCategory.zones:    return 'ZONA';
      case LogCategory.commands: return 'CMD';
      case LogCategory.system:   return 'SYS';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Log Detail Sheet ───────────────────────────────────────────────────────────

class _LogDetailSheet extends StatelessWidget {
  final LogEvent event;
  final String? zoneName;
  const _LogDetailSheet({required this.event, this.zoneName});

  @override
  Widget build(BuildContext context) {
    final dt = event.timestamp;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // ── Header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border:
                Border.all(color: event.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: event.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(event.icon,
                        color: event.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.message,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: event.type.categoryColor
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.type.categoryLabel,
                            style: TextStyle(
                              color: event.type.categoryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── Detalhes ───────────────────────────────────────────
            _DetailRow(
              icon: Icons.person_rounded,
              label: 'Utilizador',
              value: event.userName.isNotEmpty ? event.userName : '—',
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: event.isAdmin
                  ? Icons.shield_rounded
                  : Icons.person_outline_rounded,
              label: 'Papel no sistema',
              value: event.isAdmin
                  ? '⚡ Administrador'
                  : '👤 Utilizador',
              color: event.isAdmin ? AppTheme.accent : AppTheme.success,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.fingerprint_rounded,
              label: 'ID do utilizador',
              value: event.uid.isNotEmpty
                  ? '${event.uid.substring(0, 8)}...'
                  : '—',
              color: AppTheme.textMuted,
              monospace: true,
            ),
            const SizedBox(height: 12),
            if (zoneName != null) ...[
              _DetailRow(
                icon: Icons.room_rounded,
                label: 'Zona',
                value: zoneName!,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 12),
            ],
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Data',
              value: dateStr,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Hora exata',
              value: timeStr,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.label_rounded,
              label: 'Tipo de evento',
              value: _typeLabel(event.type),
              color: event.color,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'ID do evento',
              value: event.id.length > 20
                  ? '${event.id.substring(0, 20)}...'
                  : event.id,
              color: AppTheme.textMuted,
              monospace: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _typeLabel(LogEventType t) {
    switch (t) {
      case LogEventType.userRegister:       return 'Registo de utilizador';
      case LogEventType.userLogin:          return 'Início de sessão';
      case LogEventType.userLogout:         return 'Fim de sessão';
      case LogEventType.zoneEntry:          return 'Entrada em zona';
      case LogEventType.zoneExit:           return 'Saída de zona';
      case LogEventType.beaconDetected:     return 'Beacon detetado';
      case LogEventType.manualCommand:      return 'Comando manual';
      case LogEventType.automationTrigger:  return 'Automação acionada';
      case LogEventType.connectionLost:     return 'Falha de ligação';
      case LogEventType.connectionRestored: return 'Ligação restabelecida';
      case LogEventType.alert:              return 'Alerta do sistema';
    }
  }
}

// ── Detail Row ─────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool monospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Empty History ──────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  final bool hasFilters;
  const _EmptyHistory({required this.hasFilters});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasFilters
              ? Icons.filter_alt_off_rounded
              : Icons.history_rounded,
          color: AppTheme.textMuted, size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          hasFilters
              ? 'Sem eventos com estes filtros'
              : 'Nenhum evento registado',
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          hasFilters
              ? 'Tenta remover alguns filtros'
              : 'Os eventos aparecem aqui quando\nos utilizadores interagem com o sistema.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 13),
        ),
      ],
    ),
  );
}

// ── Filter Pill ────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final IconData? icon;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: active ? color.withOpacity(0.12) : AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: active ? color : AppTheme.border,
        width: active ? 1.5 : 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon,
              color: active ? color : AppTheme.textMuted,
              size: 13),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
                color: active ? color : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: active
                    ? FontWeight.w700
                    : FontWeight.w500)),
        if (active) ...[
          const SizedBox(width: 6),
          Icon(Icons.check_rounded, color: color, size: 12),
        ],
      ],
    ),
  );
}

// ── Meta Chip ──────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ── Date Header ────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Hoje';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Ontem';
    } else {
      label =
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

extension _FirstOrNullAdminHistory<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}