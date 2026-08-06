import 'package:flutter/material.dart';

import 'local_profile_avatar_io.dart'
    if (dart.library.html) 'local_profile_avatar_stub.dart';

/// Shows a local file image when available (mobile/desktop); network URL fallback.
Widget buildLocalProfileAvatar({
  required String? path,
  required double radius,
  String? networkUrl,
  Color? placeholderColor,
}) {
  return buildLocalProfileAvatarImpl(
    path: path,
    radius: radius,
    networkUrl: networkUrl,
    placeholderColor: placeholderColor,
  );
}
