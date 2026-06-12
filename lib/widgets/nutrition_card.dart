import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One row in the detailed nutrition table.
class NutrientRow {
  final String label;
  final double value;
  final String unit;
  const NutrientRow(this.label, this.value, this.unit);
}

/// A detailed nutrition card: a calorie donut (segments coloured by the
/// calorie share of carbohydrate / protein / fat), the three macros with
/// grams and percentage, and a full nutrient table underneath.
class NutritionDetailCard extends StatelessWidget {
  final double energyKcal;
  final double carb;
  final double protein;
  final double fat;
  final List<NutrientRow> tableRows;
  final String portionLabel;

  const NutritionDetailCard({
    super.key,
    required this.energyKcal,
    required this.carb,
    required this.protein,
    required this.fat,
    required this.tableRows,
    this.portionLabel = "",
  });

  static const _text = Color(0xFF2D2D3A);
  static const _light = Color(0xFFA8A8B3);
  static const _carbColor = Color(0xFF3B9EDB);
  static const _proteinColor = Color(0xFFFF4D6A);
  static const _fatColor = Color(0xFFF2B705);

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final carbCal = carb * 4;
    final proteinCal = protein * 4;
    final fatCal = fat * 9;
    final total = carbCal + proteinCal + fatCal;
    double pct(double v) => total <= 0 ? 0 : (v / total * 100);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _MacroDonutPainter(
                    carbCal: carbCal,
                    proteinCal: proteinCal,
                    fatCal: fatCal,
                    carbColor: _carbColor,
                    proteinColor: _proteinColor,
                    fatColor: _fatColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(energyKcal.round().toString(),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: _text)),
                        const Text("kcal", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _macroRow("Karbonhidrat", carb, "g", pct(carbCal), _carbColor),
                    const SizedBox(height: 12),
                    _macroRow("Protein", protein, "g", pct(proteinCal), _proteinColor),
                    const SizedBox(height: 12),
                    _macroRow("Yağ", fat, "g", pct(fatCal), _fatColor),
                  ],
                ),
              ),
            ],
          ),
          if (portionLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text("Porsiyon: $portionLabel", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
          ],
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE2E2E6))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("detaylı bilgi", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
              Expanded(child: Divider(color: Color(0xFFE2E2E6))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: tableRows.asMap().entries.map((e) {
                final r = e.value;
                final even = e.key.isEven;
                return Container(
                  color: even ? const Color(0xFFFAFAFB) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5A5A6A))),
                      Text("${_fmt(r.value)} ${r.unit}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Bu değerler kullanılan malzeme ve porsiyon miktarına göre değişiklik gösterebilir.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, double grams, String unit, double pct, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
        Text("${_fmt(grams)}$unit", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(width: 8),
        Text("%${pct.round()}", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  final double carbCal, proteinCal, fatCal;
  final Color carbColor, proteinColor, fatColor;

  _MacroDonutPainter({
    required this.carbCal,
    required this.proteinCal,
    required this.fatCal,
    required this.carbColor,
    required this.proteinColor,
    required this.fatColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2 - stroke / 2 - 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFECECF0);
    canvas.drawCircle(rect.center, rect.width / 2, bg);

    final total = carbCal + proteinCal + fatCal;
    if (total <= 0) return;

    double start = -math.pi / 2;
    void arc(double cal, Color color) {
      if (cal <= 0) return;
      final sweep = cal / total * 2 * math.pi;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }

    arc(carbCal, carbColor);
    arc(proteinCal, proteinColor);
    arc(fatCal, fatColor);
  }

  @override
  bool shouldRepaint(_MacroDonutPainter o) =>
      o.carbCal != carbCal || o.proteinCal != proteinCal || o.fatCal != fatCal;
}
