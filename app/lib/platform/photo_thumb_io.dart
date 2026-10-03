import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

Widget photoThumb(String path, double size) {
  final file = File(path);
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: file.existsSync()
        ? Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
            errorBuilder: (_, _, _) => _blank(size),
          )
        : _blank(size),
  );
}

Widget _blank(double size) => Container(
  width: size,
  height: size,
  color: AppColors.hairline,
  child: const Icon(Icons.image_outlined, color: AppColors.muted),
);
