import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:tapa_hike/services/socket.dart';

/// Uploads an image file to the server and returns the parsed JSON response.
/// Throws on network errors or non-2xx status codes.
Future<Map<String, dynamic>> uploadMessageImage(
  File imageFile, {
  String text = '',
}) async {
  final uri = Uri.parse('$httpScheme://$domain/api/messages/upload-image/');

  // Read file as bytes and determine a safe filename with correct extension.
  // This ensures the multipart content-type is set correctly even when
  // image_picker gives a temp path without a recognisable extension.
  final bytes = await imageFile.readAsBytes();
  final originalName = imageFile.path.split(Platform.pathSeparator).last;
  final filename = _ensureImageExtension(originalName, bytes);

  final request = http.MultipartRequest('POST', uri)
    ..headers['X-Team-Code'] = socketConnection.authStr
    ..fields['text'] = text
    ..files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
    ));

  final streamed = await request.send();
  final body = await streamed.stream.bytesToString();
  final data = json.decode(body) as Map<String, dynamic>;

  if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
    throw Exception(data['error'] ?? 'Upload failed (${streamed.statusCode})');
  }

  return data;
}

/// Ensure the filename ends with .jpg or .png so the http package
/// sets the correct content-type. Falls back to checking magic bytes.
String _ensureImageExtension(String name, List<int> bytes) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    return name;
  }
  // Check PNG magic bytes: 89 50 4E 47
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return '$name.png';
  }
  // Default to JPEG (most camera output)
  return '$name.jpg';
}
