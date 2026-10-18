import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/admin_store.dart';
import 'image_helpers.dart';

const _primary = Color(0xFFFF7A45);
const _light = Color(0xFFA8A8B3);

Future<void> _openBannerLink(String? raw) async {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return;
  final uri = Uri.tryParse(t.contains('://') ? t : 'https://$t');
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Admin'in eklediği "kendi reklamımız" banner'ı. Aktif banner yoksa hiç yer
/// kaplamaz (SizedBox.shrink). Birden çok banner varsa dönüşümlü gösterilir.
///
/// AdMob/AdSense kapalı olduğundan uygulamadaki reklam alanları bununla dolar.
class HouseAdBanner extends StatefulWidget {
  final double height;
  final EdgeInsets margin;
  const HouseAdBanner({
    super.key,
    this.height = 90,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  State<HouseAdBanner> createState() => _HouseAdBannerState();
}

class _HouseAdBannerState extends State<HouseAdBanner> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final n = houseBanners.length;
    if (n > 1) {
      _idx = Random().nextInt(n);
      // Birden çok banner varsa her 8 saniyede bir dönsün.
      _timer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (!mounted) return;
        final count = houseBanners.length;
        if (count <= 1) return;
        setState(() => _idx = (_idx + 1) % count);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = houseBanners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final b = banners[_idx % banners.length];
    final title = (b["title"] ?? "").toString().trim();
    final subtitle = (b["subtitle"] ?? "").toString().trim();
    final img = (b["imageUrl"] ?? "").toString();

    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFF7A45), Color(0xFFFF9E6B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title.isNotEmpty ? title : "Reklam",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );

    return GestureDetector(
      onTap: () => _openBannerLink(b["link"]?.toString()),
      child: Container(
        margin: widget.margin,
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E2E6)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isPhotoUrl(img) ? photoOrFallback(img, fallback: fallback, fit: BoxFit.cover) : fallback,
            // Alt degrade + başlık (görselin üstünde okunur kalsın).
            if (isPhotoUrl(img) && (title.isNotEmpty || subtitle.isNotEmpty))
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.black.withOpacity(0.55), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            // "Sponsorlu" etiketi (şeffaflık — reklam olduğu belli olsun).
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(6)),
                child: const Text("Sponsorlu", style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Araya giren (interstitial) tam ekran house reklamı. 5 saniye sonra otomatik
/// kapanır; kullanıcı "Kapat" ile erken kapatabilir, görsele dokununca link
/// açılır. Aktif banner yoksa hiçbir şey göstermez.
Future<void> showHouseInterstitial(BuildContext context) async {
  final banners = houseBanners;
  if (banners.isEmpty) return;
  final b = banners[Random().nextInt(banners.length)];
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) => _HouseInterstitial(banner: b),
  );
}

class _HouseInterstitial extends StatefulWidget {
  final Map<String, dynamic> banner;
  const _HouseInterstitial({required this.banner});

  @override
  State<_HouseInterstitial> createState() => _HouseInterstitialState();
}

class _HouseInterstitialState extends State<_HouseInterstitial> {
  int _left = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banner;
    final img = (b["imageUrl"] ?? "").toString();
    final title = (b["title"] ?? "").toString().trim();
    final subtitle = (b["subtitle"] ?? "").toString().trim();

    final fallback = Container(
      color: _primary,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(title.isNotEmpty ? title : "Reklam", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst çubuk: "Sponsorlu" + geri sayım + kapat.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                const Text("Sponsorlu", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
                const Spacer(),
                Text(_left > 0 ? "$_left sn" : "", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _light)),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _close,
                  icon: const Icon(Icons.close, size: 22, color: _light),
                  tooltip: "Kapat",
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Görsel (dokununca link açılır).
          Flexible(
            child: GestureDetector(
              onTap: () {
                _openBannerLink(b["link"]?.toString());
                _close();
              },
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: isPhotoUrl(img) ? photoOrFallback(img, fallback: fallback, fit: BoxFit.cover) : fallback,
              ),
            ),
          ),
          if (title.isNotEmpty || subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: [
                  if (title.isNotEmpty)
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D2D3A))),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                  ],
                ],
              ),
            ),
          // "İncele" düğmesi.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _openBannerLink(b["link"]?.toString());
                  _close();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("İncele", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
