import 'dart:async';
import 'package:flutter/material.dart';

/// Rewarded ad service.
///
/// The user OPTS IN to watch a short ad in exchange for a reward (e.g. a
/// temporary ad-free window, unlocking a premium action). [show] returns true
/// only if the ad was watched to the end (reward earned).
///
/// Today this is a PLACEHOLDER (a non-skippable countdown dialog) so the full
/// flow works on web, where Google AdMob is unavailable. On the Android/iOS
/// build, replace the body with a real `google_mobile_ads` RewardedAd:
///
///   RewardedAd.load(
///     adUnitId: '<rewarded-ad-unit-id>',
///     request: const AdRequest(),
///     rewardedAdLoadCallback: RewardedAdLoadCallback(
///       onAdLoaded: (ad) => ad.show(
///         onUserEarnedReward: (ad, reward) => completer.complete(true)),
///       onAdFailedToLoad: (_) => completer.complete(false),
///     ),
///   );
class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  /// Shows a rewarded ad and resolves true if the reward was earned.
  Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RewardedPlaceholderDialog(),
    );
    return result ?? false;
  }
}

class _RewardedPlaceholderDialog extends StatefulWidget {
  const _RewardedPlaceholderDialog();

  @override
  State<_RewardedPlaceholderDialog> createState() => _RewardedPlaceholderDialogState();
}

class _RewardedPlaceholderDialogState extends State<_RewardedPlaceholderDialog> {
  static const int _seconds = 5;
  int _remaining = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Navigator.of(context).pop(true); // reward earned
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF7A45);
    const text = Color(0xFF2D2D3A);
    const light = Color(0xFFA8A8B3);
    final progress = (_seconds - _remaining) / _seconds;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(6)),
              child: const Text("Reklam", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: light)),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.play_circle_fill, size: 56, color: primary),
            const SizedBox(height: 14),
            const Text("Ödülün hazırlanıyor…", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: text)),
            const SizedBox(height: 6),
            Text("Reklam bitince ödülünü kazanacaksın ($_remaining sn)", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: light)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0xFFECECF0), valueColor: const AlwaysStoppedAnimation(primary)),
            ),
          ],
        ),
      ),
    );
  }
}
