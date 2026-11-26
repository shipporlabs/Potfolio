import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveImage(Uint8List bytes, String name) async {
  if (Platform.isAndroid || Platform.isIOS) {
    if (!await Gal.hasAccess()) {
      final ok = await Gal.requestAccess();
      if (!ok) throw Exception('Allow Potfolio to add photos in your phone settings, then try again.');
    }
    try {
      await Gal.putImageBytes(bytes, name: name);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw Exception('Allow Potfolio to add photos in your phone settings, then try again.');
      }
      if (e.type == GalExceptionType.notEnoughSpace) throw Exception('Your phone is out of space.');
      throw Exception('Couldn’t save the image to your gallery.');
    }
    return Platform.isIOS ? 'Saved to Photos' : 'Saved to your gallery';
  }
  // Desktop: hand the file to the system share / save dialog.
  await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: '$name.png')]);
  return 'Image ready';
}
