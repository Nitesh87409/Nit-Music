import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger;

Future<String?> pickImage() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.single.bytes != null) {
      final file = result.files.single;
      String? mimeType;

      if (file.extension != null) {
        switch (file.extension!.toLowerCase()) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          case 'bmp':
            mimeType = 'image/bmp';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          default:
            mimeType = 'application/octet-stream';
        }
      } else {
        mimeType = 'application/octet-stream';
      }

      return 'data:$mimeType;base64,${base64Encode(file.bytes!)}';
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error picking playlist image',
      error: e,
      stackTrace: stackTrace,
    );
  }

  return null;
}

Widget buildImagePreview({
  String? imageBase64,
  String? imageUrl,
  double width = 80,
  double height = 80,
}) {
  Widget? imageWidget;

  Widget brokenImageFallback() => SizedBox(
    width: width,
    height: height,
    child: Builder(
      builder: (context) => Icon(
        FluentIcons.image_off_20_regular,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  if (imageBase64 != null) {
    try {
      final base64Data = imageBase64.contains(',')
          ? imageBase64.split(',').last
          : imageBase64;
      final bytes = base64Decode(base64Data);

      imageWidget = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => Icon(
          FluentIcons.image_off_20_regular,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error decoding playlist image preview',
        error: e,
        stackTrace: stackTrace,
      );
      imageWidget = brokenImageFallback();
    }
  } else if (imageUrl != null && imageUrl.isNotEmpty) {
    imageWidget = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) => Icon(
        FluentIcons.image_off_20_regular,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  if (imageWidget == null) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    ),
  );
}

Widget buildImagePickerRow(
  BuildContext context,
  Function() onPickImage,
  bool isImagePicked,
) {
  final colorScheme = Theme.of(context).colorScheme;

  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPickImage,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: colorScheme.primary,
        side: BorderSide(
          color: isImagePicked ? colorScheme.primary : colorScheme.outline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      icon: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          isImagePicked
              ? FluentIcons.checkmark_circle_20_filled
              : FluentIcons.image_add_20_regular,
          size: 20,
        ),
      ),
      label: Text(
        isImagePicked
            ? context.l10n!.imagePicked
            : context.l10n!.pickImageFromDevice,
      ),
    ),
  );
}
