import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

/// A form field that previews and picks a photo (stored as a base64 data URI).
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
    const primary = Color(0xFFFF7A45);
    const light = Color(0xFFA8A8B3);
    final hasPhoto = isPhotoUrl(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: light)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final uri = await pickPhotoDataUri();
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
                              _miniBtn(Icons.edit, () async {
                                final uri = await pickPhotoDataUri();
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
                        Text("Fotoğraf Seç", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
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
