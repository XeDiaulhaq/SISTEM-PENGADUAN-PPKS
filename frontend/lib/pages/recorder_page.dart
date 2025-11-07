import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/terms_dialog.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  bool _isRecording = false;
  bool _blurEnabled = false;
  String _blurMethod = 'gaussian'; // 'gaussian' or 'pixelation'
  CameraController? _cameraController;
  String? _uploadedVideoPath;
  bool _showTermsDialog = true;
  List<String> _recordedChunks = [];

  // Form fields
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _showTermsDialogIfNeeded();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _showErrorSnackBar('Tidak dapat mengakses kamera: $e');
    }
  }

  void _showTermsDialogIfNeeded() {
    if (_showTermsDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => TermsDialog(
            onAccept: () {
              setState(() => _showTermsDialog = false);
              Navigator.of(context).pop();
            },
          ),
        );
      });
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorSnackBar('Kamera belum siap');
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
      _showSuccessSnackBar(
        'Kamera aktif',
        'Perekaman video dimulai. Tekan "Hentikan Rekam" untuk mengakhiri.',
      );
    } catch (e) {
      _showErrorSnackBar('Error saat memulai rekaman: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _uploadedVideoPath = file.path;
      });
      _showSuccessSnackBar(
        'Rekaman selesai',
        'Video berhasil direkam dan siap untuk dikirim',
      );
    } catch (e) {
      _showErrorSnackBar('Error saat menghentikan rekaman: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _uploadedVideoPath = video.path;
        });
        _showSuccessSnackBar(
          'Video dipilih',
          'Video berhasil dipilih dan siap untuk dikirim',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error saat memilih video: $e');
    }
  }

  Future<void> _submitReport() async {
    if (_locationController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showErrorSnackBar(
        'Data tidak lengkap. Semua field wajib diisi (lokasi, deskripsi, email, dan no. telepon)',
      );
      return;
    }

    if (_uploadedVideoPath == null) {
      _showErrorSnackBar(
        'Video belum tersedia. Silakan rekam video atau upload berkas terlebih dahulu',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingVideos = prefs.getString('uploadedVideos') ?? '[]';
      final videos = List<Map<String, dynamic>>.from(
        json.decode(existingVideos) as List,
      );

      videos.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'filename':
            'Laporan_${DateTime.now().toLocal().toString().replaceAll(RegExp(r'[^0-9]'), '_')}.mp4',
        'uploadDate': DateTime.now().toLocal().toString(),
        'status': 'new',
        'blurType': _blurEnabled ? _blurMethod : null,
        'location': _locationController.text,
        'description': _descriptionController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'videoPath': _uploadedVideoPath,
      });

      await prefs.setString('uploadedVideos', json.encode(videos));

      _showSuccessSnackBar(
        'Laporan berhasil dikirim!',
        'Laporan Anda telah masuk ke dashboard admin dan akan segera diproses. Terima kasih atas laporan Anda.',
      );

      // Reset form
      setState(() {
        _locationController.clear();
        _descriptionController.clear();
        _emailController.clear();
        _phoneController.clear();
        _uploadedVideoPath = null;
        _recordedChunks.clear();
      });

      // Navigate back after delay
      Future.delayed(
        const Duration(milliseconds: 1500),
        () => Navigator.of(context).pop(),
      );
    } catch (e) {
      _showErrorSnackBar('Error saat mengirim laporan: $e');
    }
  }

  void _showSuccessSnackBar(String title, [String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message),
            ],
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistem Perekaman Laporan',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rekam kronologi kejadian dengan jaminan anonimitas visual sejak proses perekaman dimulai',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),

              // Camera Preview Card
              Card(
                color: isDark ? const Color(0xFF171717) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: isDark
                                ? Colors.grey[900]
                                : Colors.grey[200],
                            child: _cameraController?.value.isInitialized ?? false
                                ? CameraPreview(_cameraController!)
                                : const Center(
                                    child: Text(
                                      'Klik "Mulai Rekam" untuk merekam video\natau "Upload Berkas" untuk mengunggah file Silakan pilih file video (MP4, MOV, WebM, MKV) atau gambar (PNG, JPG)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Berkas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor:
                                  isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                            icon: Icon(_isRecording
                                ? Icons.stop
                                : Icons.videocam),
                            label: Text(
                                _isRecording ? 'Stop Rekam' : 'Mulai Rekam'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording
                                  ? Colors.red
                                  : (isDark ? Colors.white : Colors.black),
                              foregroundColor: _isRecording
                                  ? Colors.white
                                  : (isDark ? Colors.black : Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Form Card
              Card(
                color: isDark ? const Color(0xFF171717) : Colors.white,
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Laporan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lengkapi informasi berikut untuk membantu proses investigasi',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Location
                      TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Lokasi Kejadian *',
                          prefixIcon: const Icon(Icons.location_on),
                          hintText: 'Contoh: Gedung A Lantai 2, Ruang Kelas 201',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi Kejadian *',
                          prefixIcon: const Icon(Icons.description),
                          hintText: 'Jelaskan kronologi kejadian secara detail...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Information
                      Text(
                        'Informasi Kontak',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Informasi kontak diperlukan untuk mendapatkan pembaruan terkait penanganan laporan Anda',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email & Phone
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email *',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'No. Telepon *',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitReport,
                          icon: const Icon(Icons.send),
                          label: const Text('Kirim Laporan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.white : Colors.black,
                            foregroundColor:
                                isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}