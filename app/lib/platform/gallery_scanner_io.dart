import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import 'gallery_scanner.dart';

GalleryScanner createGalleryScanner() =>
    Platform.isAndroid || Platform.isIOS ? _PhotoManagerScanner() : _Desktop();

class _PhotoManagerScanner implements GalleryScanner {
  @override
  Future<ScanOutcome> recent({
    Duration within = const Duration(days: 7),
    int limit = 12,
  }) async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) return const ScanOutcome(ScanStatus.denied);

      final since = DateTime.now().subtract(within);
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          createTimeCond: DateTimeCond(min: since, max: DateTime.now()),
          orders: [const OrderOption(type: OrderOptionType.createDate)],
        ),
      );
      if (albums.isEmpty) return const ScanOutcome(ScanStatus.nothing);
      final assets = await albums.first.getAssetListRange(start: 0, end: limit);

      final paths = <String>[];
      for (final a in assets) {
        final file = await a.file;
        if (file != null) paths.add(file.path);
      }
      return paths.isEmpty
          ? const ScanOutcome(ScanStatus.nothing)
          : ScanOutcome(ScanStatus.found, paths);
    } catch (_) {
      return const ScanOutcome(ScanStatus.unsupported);
    }
  }
}

class _Desktop implements GalleryScanner {
  @override
  Future<ScanOutcome> recent({
    Duration within = const Duration(days: 7),
    int limit = 12,
  }) async => const ScanOutcome.unsupported();
}
