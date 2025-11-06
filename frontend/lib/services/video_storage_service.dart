import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class VideoStorageService {
  static const String _storageKey = 'uploadedVideos';

  // Load videos from storage
  Future<List<VideoModel>> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? videosJson = prefs.getString(_storageKey);

    if (videosJson == null || videosJson.isEmpty) {
      // Return sample data if no data exists
      return _getSampleData();
    }

    final List<dynamic> decoded = json.decode(videosJson);
    return decoded.map((json) => VideoModel.fromJson(json)).toList();
  }

  // Save videos to storage
  Future<void> saveVideos(List<VideoModel> videos) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        videos.map((v) => v.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  // Update single video status
  Future<List<VideoModel>> updateVideoStatus(
    List<VideoModel> videos,
    String id,
    VideoStatus newStatus,
  ) async {
    final updatedVideos = videos.map((video) {
      if (video.id == id) {
        return video.copyWith(status: newStatus);
      }
      return video;
    }).toList();

    await saveVideos(updatedVideos);
    return updatedVideos;
  }

  // Get sample data
  List<VideoModel> _getSampleData() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return [
      VideoModel(
        id: '1',
        filename: 'Laporan_Pelecehan_Verbal_Kampus.webm',
        uploadDate: _formatDate(now),
        uploadTime: '09:15:30',
        size: '12.5 MB',
        status: VideoStatus.newReport,
        blurType: 'gaussian',
        location: 'Gedung Teknik Elektro, Lantai 2',
        description:
            'Terjadi pelecehan verbal oleh mahasiswa senior kepada mahasiswa junior di area koridor. Pelaku menggunakan kata-kata kasar dan merendahkan.',
        email: 'mahasiswa@gmail.com',
        phone: '081234567890',
      ),
      VideoModel(
        id: '2',
        filename: 'Laporan_Intimidasi_Ruang_Kelas.webm',
        uploadDate: _formatDate(now),
        uploadTime: '10:45:12',
        size: '8.3 MB',
        status: VideoStatus.processing,
        blurType: 'pixelation',
        location: 'Ruang Kelas A-301',
        description:
            'Mahasiswa mengalami intimidasi dan ancaman dari sekelompok mahasiswa lain di dalam kelas.',
        email: 'reporter@student.pnl.ac.id',
      ),
      VideoModel(
        id: '3',
        filename: 'Laporan_Kekerasan_Area_Parkir.webm',
        uploadDate: _formatDate(yesterday),
        uploadTime: '14:20:45',
        size: '15.7 MB',
        status: VideoStatus.completed,
        blurType: 'gaussian',
        location: 'Area Parkir Motor Gedung Utama',
        description:
            'Terjadi perkelahian dan kekerasan fisik antara dua kelompok mahasiswa. Beberapa orang mengalami luka ringan.',
        phone: '082233445566',
      ),
    ];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
