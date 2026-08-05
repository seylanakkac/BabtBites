import 'package:flutter/material.dart';

import '../data/tracking_store.dart';

/// "Bebeğin bunu sevdi mi?" seçici — gıda ve tarif detaylarında aynı görünür.
///
/// FAVORİ İLE KARIŞTIRMA: kalp simgesi ebeveynin yer imi (sonra kolay bulmak
/// için). Bu satır bebeğin TEPKİSİ; listelerde "sevdikleri" filtresini besler.
///
/// Seçili çipe yeniden dokunmak işareti kaldırır — yanlış dokunuş geri
/// alınabilsin diye.
class TastePicker extends StatelessWidget {
  /// Kayıtlı beğeni: "sevdi" | "sevmedi" | null.
  final String? value;

  /// Yeni değer (aynı çipe basılırsa null gelir).
  final ValueChanged<String?> onChanged;

  /// Başlık satırında görünecek ad (ör. gıdanın/tarifin adı). Boşsa genel metin.
  final String subject;

  const TastePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.subject = "",
  });

  static const Color _text = Color(0xFF2D2D3A);
  static const Color _light = Color(0xFFA8A8B3);
  static const Color _liked = Color(0xFF10B981);
  static const Color _disliked = Color(0xFFFF7A45);

  @override
  Widget build(BuildContext context) {
    final title = value == null
        ? (subject.isEmpty ? "Bebeğiniz sevdi mi?" : "$subject'i sevdi mi?")
        : "Bebeğiniz: ${tasteLabel(value)}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: _light),
        ),
        const SizedBox(height: 8),
        Row(
          children: kTasteOptions.map((o) {
            final sel = value == o.$1;
            final color = o.$1 == "sevdi" ? _liked : _disliked;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: o.$1 == "sevdi" ? 8 : 0),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onChanged(sel ? null : o.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? color.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? color : const Color(0xFFE2E2E6),
                          width: sel ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(o.$2, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            o.$3,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: sel ? color : _text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
