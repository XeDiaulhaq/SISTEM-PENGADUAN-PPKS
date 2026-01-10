import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'api_exceptions.dart';
import 'backend_config.dart';

class ReportSubmissionService {
  ReportSubmissionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> submitReport({
    required XFile video,
    required String title,
    required String location,
    required String description,
    required String email,
    required String phone,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$fastApiBaseUrl/reports/upload'),
    )
      ..headers['X-Report-Api-Key'] = reportApiKey
      ..fields['title'] = title
      ..fields['location'] = location
      ..fields['description'] = description
      ..fields['email'] = email
      ..fields['reporter_phone'] = phone;

    final bytes = await video.readAsBytes();
    final fileName = _resolveFileName(video);

    request.files.add(
      http.MultipartFile.fromBytes(
        'recording',
        bytes,
        filename: fileName,
        contentType: _detectContentType(video.path),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 201) {
      String message = 'Gagal mengirim laporan. (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {
        // ignore json parse errors
      }
      throw ApiException(message, response.statusCode);
    }
  }

  void dispose() {
    _client.close();
  }

  String _resolveFileName(XFile file) {
    final basename = p.basename(file.path);
    if (basename.isNotEmpty && basename != '.') {
      return basename;
    }
    return file.name;
  }

  MediaType _detectContentType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.mov':
        return MediaType('video', 'quicktime');
      case '.mkv':
        return MediaType('video', 'x-matroska');
      case '.avi':
        return MediaType('video', 'x-msvideo');
      case '.webm':
        return MediaType('video', 'webm');
      default:
        return MediaType('video', 'mp4');
    }
  }
}
