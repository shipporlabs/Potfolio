import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a normal browser download of the PNG.
Future<String> saveImage(Uint8List bytes, String name) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = '$name.png';
  a.style.display = 'none';
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  Future.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return 'Image downloaded';
}
