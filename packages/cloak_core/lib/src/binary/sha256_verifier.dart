import 'dart:io';
import 'package:crypto/crypto.dart';

/// Streams a file through SHA-256 and compares against an expected digest.
class Sha256Verifier {
  const Sha256Verifier._();

  static Future<String> hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<bool> verify(File file, String expectedHex) async {
    final actual = await hashFile(file);
    return actual.toLowerCase() == expectedHex.toLowerCase();
  }
}
