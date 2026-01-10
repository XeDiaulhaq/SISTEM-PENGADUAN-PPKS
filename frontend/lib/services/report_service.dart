import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/video_model.dart';
import 'api_exceptions.dart';
import 'backend_config.dart';

class ReportService {
  ReportService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<VideoModel>> fetchReports(String token) async {
    final response = await _client.get(
      Uri.parse('$fastApiBaseUrl/reports?limit=100&offset=0'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => _mapReport(e as Map<String, dynamic>)).toList();
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException('Sesi login berakhir. Silakan login ulang.');
    }

    throw ApiException(_readError(response.body), response.statusCode);
  }

  Future<void> updateReportStatus(
    String token,
    String reportId,
    VideoStatus status,
  ) async {
    final response = await _client.patch(
      Uri.parse('$fastApiBaseUrl/reports/$reportId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: json.encode({'status': _statusToApiValue(status)}),
    );

    if (response.statusCode == 200) {
      return;
    }
    if (response.statusCode == 401) {
      throw UnauthorizedException('Sesi login berakhir. Silakan login ulang.');
    }
    throw ApiException(_readError(response.body), response.statusCode);
  }

  VideoModel _mapReport(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse((json['created_at'] ?? '') as String) ?? DateTime.now();
    final recordingPath = json['recording_path'] as String?;
    final filename = recordingPath != null ? recordingPath.split('/').last : 'recording_${json['id']}';
    final downloadUrl = '$fastApiBaseUrl/reports/${json['id']}/file';
    final duration = json['duration_seconds'];

    return VideoModel(
      id: json['id'].toString(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String)
          : 'Tanpa Judul',
      filename: filename,
      uploadDate: _formatDate(createdAt),
      uploadTime: _formatTime(createdAt),
      size: duration is num ? '${duration}s' : '-',
      status: _statusFromApi(json['status'] as String?),
      blurType: null,
      location: _nullableString(json['location']),
      description: (json['notes'] as String?) ?? (json['title'] as String?),
      email: _nullableString(json['submitted_by']),
      phone: _nullableString(json['reporter_phone']),
      videoUrl: recordingPath != null ? downloadUrl : null,
    );
  }

  String? _nullableString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  VideoStatus _statusFromApi(String? status) {
    switch (status) {
      case 'processing':
        return VideoStatus.processing;
      case 'completed':
        return VideoStatus.completed;
      case 'new':
      default:
        return VideoStatus.newReport;
    }
  }

  String _statusToApiValue(VideoStatus status) {
    switch (status) {
      case VideoStatus.processing:
        return 'processing';
      case VideoStatus.completed:
        return 'completed';
      case VideoStatus.newReport:
      default:
        return 'new';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _readError(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map<String, dynamic> && detail['message'] is String) {
        return detail['message'] as String;
      }
    } catch (_) {
      // ignore
    }
    return 'Terjadi kesalahan pada server.';
  }
}
