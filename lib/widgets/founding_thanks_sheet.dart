import 'package:flutter/material.dart';

import '../config/founding_member.dart';
import '../services/founding_member.dart';

/// Kurucu üyelere bir kez gösterilen teşekkür ekranı.
///
/// Kapat'a basılınca bir daha çıkmaz (FoundingMember.markThanksShown).
/// Kapatmadan kaçılamasın diye dışarı dokunarak veya geri tuşuyla
/// kapatılamıyor — hediyenin görülmesi bu ekranın tek amacı.
Future<void> showFoundingThanks(BuildContext context) async {
  await FoundingMember.grantAdFreeGift();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dctx) => PopScope(
      canPop: false,
      child: _FoundingThanksDialog(onClose: () => Navigator.pop(dctx)),
    ),
  );
  await FoundingMember.markThanksShown();
}

class _FoundingThanksDialog extends StatelessWidget {
  final VoidCallback onClose;
  const _FoundingThanksDialog({required this.onClose});

  static const _primary = Color(0xFFFF7A45);
  static const _text = Color(0xFF2D2D3A);
  static const _body = Color(0xFF5A5A6A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(child: Text("🤍", style: TextStyle(fontSize: 38))),
              const SizedBox(height: 14),
              const Text(
                "Küçük bir teşekkür mektubu",
                style: TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.bold, color: _text, height: 1.25),
              ),
              const SizedBox(height: 18),
              Text(
                FoundingMember.salutation(),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text),
              ),
              const SizedBox(height: 12),
              const Text(
                "Bu uygulamayı yaparken en çok merak ettiğimiz şey şuydu: acaba birileri "
                "gerçekten kullanır mı?\n\n"
                "Sen kullandın. Hem de daha ortada eksikler varken, sabırla. O yüzden bu "
                "mesajı yazarken kalbimiz biraz kıpır kıpır.\n\n"
                "BabyBites artık büyüyor ve bazı özellikleri ücretli hâle getiriyoruz. Ama "
                "seni bunun dışında tuttuk — çünkü sen \"sonradan gelen\" değilsin, sen "
                "başlangıçtansın.",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _body, height: 1.6),
              ),
              const SizedBox(height: 18),
              _gift("Bugün kullandığın her özellik, ömür boyu ücretsiz senin"),
              const SizedBox(height: 10),
              _gift("Üstüne $kFoundingAdFreeDays gün boyunca reklamsız kullanım"),
              const SizedBox(height: 18),
              const Text(
                "Küçük bir jest, biliyoruz. Ama içten.\n\n"
                "Sana ve bebeğine sağlıklı, keyifli öğünler. 🤍",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _body, height: 1.6),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Anladım, teşekkürler",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gift(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🤍", style: TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text, height: 1.45),
            ),
          ),
        ],
      );
}
