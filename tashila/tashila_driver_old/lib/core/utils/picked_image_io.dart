import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Copies a picked image to a stable temp file so uploads/previews work on
/// Android after the camera content URI or cache file is removed.
Future<String> persistPickedImage(XFile file, String prefix) async {
  final bytes = await file.readAsBytes();
  final trimmedName = file.name.trim();
  final ext = trimmedName.contains('.')
      ? trimmedName.substring(trimmedName.lastIndexOf('.'))
      : '.jpg';
  final dest = File(
    '${Directory.systemTemp.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  await dest.writeAsBytes(bytes, flush: true);
  return dest.path;
}

Future<List<int>> readUploadBytes(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    return file.readAsBytes();
  }
  return XFile(filePath).readAsBytes();
}
