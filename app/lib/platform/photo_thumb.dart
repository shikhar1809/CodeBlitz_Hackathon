import 'package:flutter/widgets.dart';

import 'photo_thumb_stub.dart'
    if (dart.library.io) 'photo_thumb_io.dart'
    as platform;

/// A photo from a path: a file on the phone, a blob URL in the browser.
Widget photoThumb(String path, {double size = 72}) =>
    platform.photoThumb(path, size);
