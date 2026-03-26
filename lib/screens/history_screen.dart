import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<HistoryPoint> _data = HistoryPoint.sampleData;

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Histórico'),
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tab,
              indicatorColor: AppColors.indigo,
              indicatorWeight: 2.5,
              labelColor: AppColors.indigo,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Temperatura'), Tab(text: 'Humidade'), Tab(text: 'Luz')],
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _SummaryRow(data: _data),
        ),
        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            _ChartPanel(data: _data, getValue: (p) => p.temperature,
                color: AppColors.green, unit: '°C', label: 'Temperatura'),
            _ChartPanel(data: _data, getValue: (p) => p.humidity,
                color: AppColors.teal, unit: '%', label: 'Humidade'),
            _ChartPanel(data: _data, getValue: (p) => p.luminosityPercent,
                color: AppColors.amber, unit: '%', label: 'Luminosidade'),
          ],
        )),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<HistoryPoint> data;
  const _SummaryRow({required this.data});
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final temps = data.map((d) => d.temperature).toList();
    final hums  = data.map((d) => d.humidity).toList();
    return Row(children: [
      Expanded(child: _StatChip(label: 'Temp. média',
          value: '${(temps.reduce((a,b) => a+b) / temps.length).toStringAsFixed(1)}°C',
          color: AppColors.green)),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(label: 'Hum. média',
          value: '${(hums.reduce((a,b) => a+b) / hums.length).toStringAsFixed(0)}%',
          color: AppColors.teal)),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(label: 'Registos',
          value: '${data.length}', color: AppColors.indigo)),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppText.label),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(
          color: color, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
    ]),
  );
}

class _ChartPanel extends StatelessWidget {
  final List<HistoryPoint> data;
  final double Function(HistoryPoint) getValue;
  final Color color;
  final String unit, label;
  const _ChartPanel({required this.data, required this.getValue,
    required this.color, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Center(child: Text('Sem dados', style: AppText.body));
    final values = data.map(getValue).toList();
    final minVal = values.reduce((a,b) => a < b ? a : b) - 2;
    final maxVal = values.reduce((a,b) => a > b ? a : b) + 2;
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), getValue(e.value))).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(getValue(data.last).toStringAsFixed(1),
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 40,
                  fontWeight: FontWeight.w700, letterSpacing: -1.5)),
          Padding(padding: const EdgeInsets.only(bottom: 6),
              child: Text(unit, style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w400))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Agora', style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        Text('Últimas ${data.length} leituras · $label', style: AppText.body),
        const SizedBox(height: 24),
        Expanded(child: LineChart(LineChartData(
          minY: minVal, maxY: maxVal,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: (maxVal - minVal) / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 36,
              interval: (maxVal - minVal) / 4,
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 28, interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('${data[i].time.hour}h',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)));
              },
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, curveSmoothness: 0.35,
            color: color, barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (_, __, ___, i) =>
                FlDotCirclePainter(
                    radius: i == data.length - 1 ? 5 : 0,
                    color: color, strokeWidth: 0, strokeColor: Colors.transparent)),
            belowBarData: BarAreaData(show: true,
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.12), color.withOpacity(0.0)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          )],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            tooltipBorder: const BorderSide(color: AppColors.border),
            tooltipRoundedRadius: 10,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.y.toStringAsFixed(1)}$unit',
              GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            )).toList(),
          )),
        ))),
      ]),
    );
  }
}