import 'package:flutter/services.dart';

import '../../domain/medicine_catalog.dart';

/// Reads the bundled medicine catalogue once per run.
///
/// The domain side ([MedicineCatalog]) is plain Dart and never touches the
/// asset bundle; this is the one place that does. A missing or broken asset
/// is not fatal: the merge then simply runs without a catalogue, as it did
/// before there was one.
abstract final class CatalogLoader {
  static const medicinesAsset = 'assets/catalog/medicines.json';
  static const lookAlikesAsset = 'assets/catalog/lookalikes.json';

  static Future<MedicineCatalog?>? _loading;

  static Future<MedicineCatalog?> load({AssetBundle? bundle}) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<MedicineCatalog?> _load(AssetBundle bundle) async {
    try {
      return MedicineCatalog.fromJson(
        await bundle.loadString(medicinesAsset),
        lookAlikes: await bundle.loadString(lookAlikesAsset),
      );
    } catch (_) {
      _loading = null;
      return null;
    }
  }
}
