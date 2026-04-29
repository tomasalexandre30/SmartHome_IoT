import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smartspace_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  LogEventType? _filter;

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartSpaceProvider>(builder: (context, ss, _) {
      final logs = _filter == null
          ? ss.logs
          : ss.logs.where((e) => e.type == _filter).toList();

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Histórico'),
          actions: [
            IconButton(
              icon: Icon(_filter != null ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                  color: _filter != null ? AppTheme.accent : AppTheme.textMuted),
              onPressed: _showFilterSheet,
              tooltip: 'Filtrar',
            ),
          ],
        ),
        body: Column(
          children: [
            // Stats bar
            _StatsBar(logs: ss.logs),

            // Filter chip
            if (_filter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: SS.pill(color: AppTheme.accent),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_filterLabel(_filter!), style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _filter = null),
                            child: const Icon(Icons.close_rounded, color: AppTheme.accent, size: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${logs.length} eventos', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),

            // Log list
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, color: AppTheme.textMuted, size: 48),
                          SizedBox(height: 12),
                          Text('Nenhum evento registado', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final showDateHeader = i == 0 ||
                            !_sameDay(logs[i].timestamp, logs[i - 1].timestamp);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader) _DateHeader(date: logs[i].timestamp),
                            LogTile(event: logs[i]),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por tipo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LogEventType.values.map((t) => GestureDetector(
                onTap: () {
                  setState(() => _filter = t == _filter ? null : t);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: SS.pill(color: _filter == t ? AppTheme.accent : AppTheme.textMuted),
                  child: Text(_filterLabel(t),
                      style: TextStyle(color: _filter == t ? AppTheme.accent : AppTheme.textMuted, fontSize: 13)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _filterLabel(LogEventType t) {
    switch (t) {
      case LogEventType.zoneEntry:          return 'Entradas';
      case LogEventType.zoneExit:           return 'Saídas';
      case LogEventType.manualCommand:      return 'Comandos manuais';
      case LogEventType.automationTrigger:  return 'Automações';
      case LogEventType.connectionLost:     return 'Falhas de ligação';
      case LogEventType.connectionRestored: return 'Ligações restabelecidas';
      case LogEventType.alert:              return 'Alertas';
    }
  }
}

// ── Stats Bar ──────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final List<LogEvent> logs;
  const _StatsBar({required this.logs});

  @override
  Widget build(BuildContext context) {
    final entries = logs.where((e) => e.type == LogEventType.zoneEntry).length;
    final automations = logs.where((e) => e.type == LogEventType.automationTrigger).length;
    final commands = logs.where((e) => e.type == LogEventType.manualCommand).length;
    final alerts = logs.where((e) => e.type == LogEventType.alert).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: SS.glowCard(),
      child: Row(
        children: [
          _Stat(value: '$entries', label: 'Entradas', color: AppTheme.success),
          _divider(),
          _Stat(value: '$automations', label: 'Automações', color: const Color(0xFF8B5CF6)),
          _divider(),
          _Stat(value: '$commands', label: 'Comandos', color: AppTheme.accent),
          _divider(),
          _Stat(value: '$alerts', label: 'Alertas', color: AppTheme.warning),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── Date header ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Hoje';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      label = 'Ontem';
    } else {
      label = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}
