import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

Widget photoThumb(String path, double size) => ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Image.network(
    path,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _blank(size),
  ),
);

Widget _blank(double size) => Container(
  width: size,
  height: size,
  color: AppColors.hairline,
  child: const Icon(Icons.image_outlined, color: AppColors.muted),
);
