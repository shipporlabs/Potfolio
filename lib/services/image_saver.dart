import 'dart:typed_data';

import 'image_saver_io.dart' if (dart.library.js_interop) 'image_saver_web.dart' as impl;

/// Saves PNG bytes: to Photos / the gallery on phones, as a file download on
/// the web. Returns a short confirmation to show the user. Throws with a
/// readable message if it can't.
Future<String> saveImage(Uint8List bytes, String name) => impl.saveImage(bytes, name);
