import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/founding_member.dart';
import '../data/extras_store.dart';
import 'storage_service.dart';

/// Kurucu üye statüsü, hediyesi ve teşekkür ekranının bir kez gösterilmesi.
class FoundingMember {
  FoundingMember._();

  /// Teşekkürün gösterildiği bilgisi CİHAZDA ve KULLANICI BAZINDA tutulur.
  /// Hesap bazında olması şart (aynı cihazda başka hesapla girilebilir);
  /// buluta taşımaya gerek yok, ikinci bir cihazda bir kez daha görmek
  /// zararsız.
  static String _shownKey(String uid) => 'founding_thanks_shown_$uid';

  /// Hesap kesim tarihinden önce mi açılmış?
  static bool isFounding() {
    final created = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    return created != null && created.isBefore(kFoundingCutoff);
  }

  /// Teşekkür ekranı bu kullanıcıya gösterilmeli mi?
  static Future<bool> shouldShowThanks() async {
    if (!kFoundingThanksEnabled) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !isFounding()) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_shownKey(uid)) ?? false);
    } catch (e) {
      debugPrint('FoundingMember.shouldShowThanks failed: $e');
      return false; // Emin olamıyorsak gösterme — tekrar tekrar çıkmasın.
    }
  }

  /// Kapat'a basıldığında çağrılır; ekran bir daha çıkmaz.
  static Future<void> markThanksShown() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shownKey(uid), true);
    } catch (e) {
      debugPrint('FoundingMember.markThanksShown failed: $e');
    }
  }

  /// Ödüllü reklamın verebileceği EN UZUN reklamsız süre (bkz. premium_screen:
  /// 1 gün). Geri alma bu eşiği kullanıyor — bundan uzun bir pencere ancak
  /// kurucu üye hediyesinden gelmiş olabilir.
  static const Duration _maxRewardedAdFree = Duration(days: 2); // 1 gün + pay

  /// Kurucu üye hediyesiyle verilmiş reklamsız hakkı GERİ ALIR.
  ///
  /// Hediye ekranı 04.08.2026'da kapatıldı, ama o güne kadar ekranı görenlerin
  /// hesabına 90 günlük reklamsız hak yazılmıştı ve bu buluttan bütün
  /// cihazlarına taşınıyordu — reklamlar sessizce hiç görünmüyordu.
  ///
  /// ÖDÜLLÜ REKLAM HAKKINA DOKUNMAZ: kullanıcı reklam izleyerek kazandığı
  /// 1 günlük hakkı kaybetmemeli. Hakkın kaynağı kaydedilmediği için ayrım
  /// SÜREYE göre yapılıyor: [_maxRewardedAdFree]'den uzak bir bitiş tarihi
  /// ödüllü reklamdan gelmiş olamaz.
  ///
  /// ⚠️ Hediye ileride tekrar açılırsa (abonelik yayına girince) bu temizlik
  /// yeni verilenleri de siler; o gün [kFoundingThanksEnabled] ile birlikte
  /// buradaki çağrı da kaldırılmalı.
  ///
  /// Bir şey geri alındıysa true döner.
  static Future<bool> revokeGiftedAdFree() async {
    final raw = globalAdFreeUntil;
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    // Çözülemeyen değer de temizlenir: adFreeActive() onu zaten yok sayıyor.
    if (until == null || until.isAfter(DateTime.now().add(_maxRewardedAdFree))) {
      clearAdFreeUntil();
      await StorageService.instance.saveExtras();
      return true;
    }
    return false;
  }

  /// 3 aylık reklamsız kullanımı tanımlar.
  ///
  /// Mevcut reklamsız pencere (ödüllü reklamdan gelen) daha ileri bir tarihse
  /// ona dokunulmaz — kullanıcının hakkı kısaltılmamalı.
  static Future<void> grantAdFreeGift() async {
    final now = DateTime.now();
    final gift = now.add(const Duration(days: kFoundingAdFreeDays));
    final current = globalAdFreeUntil != null ? DateTime.tryParse(globalAdFreeUntil!) : null;
    if (current != null && current.isAfter(gift)) return;
    globalAdFreeUntil = gift.toIso8601String();
    await StorageService.instance.saveExtras();
  }

  /// Kayıttaki yakınlığa göre hitap. Babaya "Güzel Anne" demek, sıcak olsun
  /// diye yazılmış metni tersine çevirir.
  static String salutation() {
    final rel = (StorageService.instance.loadParent()?["relationship"] ?? "").trim().toLowerCase();
    if (rel.startsWith("anne")) return "Güzel Anne,";
    if (rel.startsWith("baba")) return "Değerli Baba,";
    if (rel.isNotEmpty) return "Değerli Ebeveyn,";
    return "Merhaba,";
  }
}
