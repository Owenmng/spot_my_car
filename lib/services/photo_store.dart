import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Photos des spots stockées dans Firestore (compressées), pour rester dans l'offre gratuite.
class PhotoStore {
  PhotoStore._();

  static final _cache = <String, Future<Uint8List?>>{};
  static CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('spot_photos');

  /// Réduit la photo (900 px de large, JPEG) pour tenir largement sous la limite d'un document.
  static Future<Uint8List> compress(Uint8List bytes) => compute(_compress, bytes);

  static Uint8List _compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final resized = oriented.width > 900 ? img.copyResize(oriented, width: 900, interpolation: img.Interpolation.average) : oriented;
    var quality = 74;
    var out = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    while (out.lengthInBytes > 600 * 1024 && quality > 40) {
      quality -= 10;
      out = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    return out;
  }

  /// Version 1024 px envoyée à l'IA : plus légère, donc plus rapide à analyser.
  static Future<Uint8List> forAnalysis(Uint8List bytes) => compute(_analysis, bytes);

  static Uint8List _analysis(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final o = img.bakeOrientation(decoded);
    final r = (o.width > 1024 || o.height > 1024)
        ? img.copyResize(o, width: o.width >= o.height ? 1024 : null, height: o.height > o.width ? 1024 : null, interpolation: img.Interpolation.average)
        : o;
    return Uint8List.fromList(img.encodeJpg(r, quality: 80));
  }

  static DocumentReference<Map<String, dynamic>> ref(String carId) => _col.doc(carId);

  static Future<Uint8List?> load(String carId) {
    return _cache.putIfAbsent(carId, () async {
      try {
        final snap = await _col.doc(carId).get();
        final data = snap.data()?['data'];
        if (data is Blob) return data.bytes;
        return null;
      } catch (_) {
        _cache.remove(carId);
        return null;
      }
    });
  }

  static Future<void> delete(String carId) async {
    _cache.remove(carId);
    try {
      await _col.doc(carId).delete();
    } catch (_) {}
  }
}
