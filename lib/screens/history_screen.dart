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

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Dados estáticos — serão substituídos por lista acumulada do MQTT
  final List<HistoryPoint> _data = HistoryPoint.sampleData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.green,
              indicatorWeight: 2,
              labelColor: AppColors.green,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Temperatura'),
                Tab(text: 'Humidade'),
                Tab(text: 'Luminosidade'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Cards de resumo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SummaryCards(data: _data),
          ),

          // Gráficos
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChartView(
                  data: _data,
                  getValue: (p) => p.temperature,
                  color: AppColors.green,
                  unit: '°C',
                  label: 'Temperatura',
                ),
                _ChartView(
                  data: _data,
                  getValue: (p) => p.humidity,
                  color: AppColors.green,
                  unit: '%',
                  label: 'Humidade',
                ),
                _ChartView(
                  data: _data,
                  getValue: (p) => p.luminosityPercent,
                  color: AppColors.orange,
                  unit: '%',
                  label: 'Luminosidade',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CARDS DE RESUMO ──────────────────────────
class _SummaryCards extends StatelessWidget {
  final List<HistoryPoint> data;

  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final temps  = data.map((d) => d.temperature).toList();
    final hums   = data.map((d) => d.humidity).toList();

    return Row(
      children: [
        Expanded(child: _MiniCard(
          label: 'Temp. média',
          value: '${(temps.reduce((a, b) => a + b) / temps.length).toStringAsFixed(1)}°C',
          color: AppColors.green,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard(
          label: 'Hum. média',
          value: '${(hums.reduce((a, b) => a + b) / hums.length).toStringAsFixed(0)}%',
          color: AppColors.green,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard(
          label: 'Registos',
          value: '${data.length}',
          color: AppColors.textSecondary,
        )),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GRÁFICO ──────────────────────────────────
class _ChartView extends StatelessWidget {
  final List<HistoryPoint> data;
  final double Function(HistoryPoint) getValue;
  final Color color;
  final String unit;
  final String label;

  const _ChartView({
    required this.data,
    required this.getValue,
    required this.color,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('Sem dados', style: AppText.body));
    }

    final values = data.map(getValue).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxVal = values.reduce((a, b) => a > b ? a : b) + 2;

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), getValue(e.value));
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Valor mais recente
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: getValue(data.last).toStringAsFixed(1),
                style: AppText.valueLarge(color),
              ),
              TextSpan(
                text: unit,
                style: GoogleFonts.jetBrainsMono(
                  color: color.withOpacity(0.5),
                  fontSize: 18,
                ),
              ),
            ]),
          ),
          Text('Último valor — $label', style: AppText.body),
          const SizedBox(height: 24),

          // Gráfico
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minVal,
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal - minVal) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: (maxVal - minVal) / 4,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        final h = data[i].time.hour;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${h}h',
                            style: GoogleFonts.jetBrainsMono(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, i) => FlDotCirclePainter(
                        radius: i == data.length - 1 ? 5 : 3,
                        color: i == data.length - 1 ? color : color.withOpacity(0.4),
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.card,
                    tooltipBorder: const BorderSide(color: AppColors.border, width: 0.5),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}$unit',
                        GoogleFonts.jetBrainsMono(color: color, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}