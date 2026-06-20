import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

const _kPrimary = Color(0xFFFF7A45);

/// True when [url] holds an actual image (base64 data URI or network URL),
/// as opposed to an emoji / asset name.
bool isPhotoUrl(String? url) =>
    url != null && (url.startsWith('data:') || url.startsWith('http'));

/// Renders the photo at [url] (data URI or network), or [fallback] otherwise.
Widget photoOrFallback(
  String? url, {
  required Widget fallback,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (url == null || url.isEmpty) return fallback;
  try {
    if (url.startsWith('data:')) {
      final bytes = base64Decode(url.split(',').last);
      return Image.memory(bytes, fit: fit, width: width, height: height,
          errorBuilder: (_, __, ___) => fallback);
    }
    if (url.startsWith('http')) {
      return Image.network(url, fit: fit, width: width, height: height,
          errorBuilder: (_, __, ___) => fallback);
    }
  } catch (_) {}
  return fallback;
}

/// Opens the gallery and returns a downscaled base64 data URI, or null if the
/// user cancelled / it failed. Downscaling keeps local storage small.
///
/// This is the raw pick (no crop). Prefer [pickCropPhotoDataUri] in forms so the
/// user can frame the photo.
Future<String?> pickPhotoDataUri() async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      maxHeight: 700,
      imageQuality: 60,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  } catch (_) {
    return null;
  }
}

/// Picks a photo from the gallery, lets the user crop/zoom/choose an aspect
/// ratio, then returns a JPEG base64 data URI (downscaled to keep payload
/// small), or null if cancelled / failed.
Future<String?> pickCropPhotoDataUri(BuildContext context) async {
  try {
    final picker = ImagePicker();
    // Pick at a generous size so cropping has decent source resolution.
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (file == null) return null;
    final src = await file.readAsBytes();
    if (!context.mounted) return null;
    final cropped = await showCropDialog(context, src);
    if (cropped == null) return null;
    final jpeg = _toJpegDataUri(cropped, maxSide: 1100, quality: 78);
    return jpeg;
  } catch (_) {
    return null;
  }
}

/// Re-crops an existing base64 data URI (or returns null if it isn't a data
/// URI / the user cancelled).
Future<String?> recropPhotoDataUri(BuildContext context, String? current) async {
  if (current == null || !current.startsWith('data:')) {
    // Nothing local to re-crop (e.g. a network URL): fall back to a fresh pick.
    return pickCropPhotoDataUri(context);
  }
  try {
    final src = base64Decode(current.split(',').last);
    final cropped = await showCropDialog(context, src);
    if (cropped == null) return null;
    return _toJpegDataUri(cropped, maxSide: 1100, quality: 78);
  } catch (_) {
    return null;
  }
}

/// Decodes [bytes], downscales so the longest side is at most [maxSide], and
/// re-encodes as JPEG. Falls back to the raw bytes if decoding fails.
String _toJpegDataUri(Uint8List bytes, {required int maxSide, required int quality}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
    img.Image out = decoded;
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > maxSide) {
      if (decoded.width >= decoded.height) {
        out = img.copyResize(decoded, width: maxSide);
      } else {
        out = img.copyResize(decoded, height: maxSide);
      }
    }
    final jpg = img.encodeJpg(out, quality: quality);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  } catch (_) {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}

/// Shows the crop editor for [imageBytes] and returns the cropped bytes, or null.
Future<Uint8List?> showCropDialog(BuildContext context, Uint8List imageBytes) {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CropDialog(imageBytes: imageBytes),
  );
}

class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropDialog({required this.imageBytes});

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final _controller = CropController();
  bool _busy = false;
  double? _ratio; // null = serbest (free)

  static const List<({String label, double? value})> _ratios = [
    (label: "Serbest", value: null),
    (label: "1:1", value: 1.0),
    (label: "4:3", value: 4 / 3),
    (label: "16:9", value: 16 / 9),
    (label: "3:4", value: 3 / 4),
  ];

  void _setRatio(double? r) {
    setState(() => _ratio = r);
    _controller.aspectRatio = r;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogW = media.size.width.clamp(0, 720).toDouble();
    final dialogH = (media.size.height * 0.9).clamp(0, 760).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
              child: Row(
                children: [
                  const Text("Fotoğrafı Kırp",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2D2D3A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF7A7A87)),
                    onPressed: _busy ? null : () => Navigator.pop(context, null),
                  ),
                ],
              ),
            ),
            // Crop area
            Expanded(
              child: Container(
                color: const Color(0xFF1C1C22),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,
                  aspectRatio: _ratio,
                  interactive: true,
                  baseColor: const Color(0xFF1C1C22),
                  maskColor: Colors.black.withOpacity(0.55),
                  radius: 8,
                  cornerDotBuilder: (size, edge) =>
                      const DotControl(color: _kPrimary),
                  onCropped: (result) {
                    switch (result) {
                      case CropSuccess(:final croppedImage):
                        Navigator.pop(context, croppedImage);
                      case CropFailure():
                        if (mounted) {
                          setState(() => _busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Kırpma başarısız, tekrar deneyin.")),
                          );
                        }
                    }
                  },
                ),
              ),
            ),
            // Aspect ratio presets
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _ratios.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final r = _ratios[i];
                    final selected = _ratio == r.value;
                    return ChoiceChip(
                      label: Text(r.label),
                      selected: selected,
                      onSelected: _busy ? null : (_) => _setRatio(r.value),
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF2D2D3A),
                      ),
                      selectedColor: _kPrimary,
                      backgroundColor: const Color(0xFFF1F1F4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: selected ? _kPrimary : const Color(0xFFE2E2E6)),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("İpucu: Sürükleyerek taşı, tekerlek/iki parmakla yakınlaştır.",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFFA8A8B3))),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E2E6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("İptal",
                          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _busy = true);
                              _controller.crop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Kırp ve Kaydet",
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A form field that previews and picks a photo (stored as a base64 data URI),
/// with a crop/zoom/aspect-ratio step after picking.
class PhotoPickerField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final double height;

  const PhotoPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = "Fotoğraf",
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    const primary = _kPrimary;
    const light = Color(0xFFA8A8B3);
    final hasPhoto = isPhotoUrl(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: light)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final uri = await pickCropPhotoDataUri(context);
            if (uri != null) onChanged(uri);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasPhoto ? primary.withOpacity(0.4) : const Color(0xFFE2E2E6),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        photoOrFallback(value, fallback: const SizedBox()),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              // Re-crop the current photo.
                              _miniBtn(Icons.crop, () async {
                                final uri = await recropPhotoDataUri(context, value);
                                if (uri != null) onChanged(uri);
                              }),
                              const SizedBox(width: 6),
                              // Pick a different photo (then crop).
                              _miniBtn(Icons.edit, () async {
                                final uri = await pickCropPhotoDataUri(context);
                                if (uri != null) onChanged(uri);
                              }),
                              const SizedBox(width: 6),
                              _miniBtn(Icons.delete, () => onChanged(null)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 32, color: primary),
                        SizedBox(height: 8),
                        Text("Fotoğraf Seç ve Kırp", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );
}
