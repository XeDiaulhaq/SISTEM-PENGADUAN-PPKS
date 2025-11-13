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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perekaman Laporan',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rekam kejadian dengan anonimisasi otomatis',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.face_retouching_natural,
                            size: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AUTO BLUR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Camera Preview Card
              Card(
                color: isDark ? const Color(0xFF171717) : Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 360, // Lebih compact
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child:
                                _cameraController?.value.isInitialized ?? false
                                    ? CameraPreview(_cameraController!)
                                    : const Center(
                                        child: Text(
                                          'Klik "Mulai Rekam" untuk merekam video\natau "Upload Berkas" untuk mengunggah file',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text(
                              'Upload Berkas',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor:
                                  isDark ? Colors.white70 : Colors.black87,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                            icon: Icon(
                                _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                                size: 18),
                            label: Text(
                                _isRecording ? 'Stop Rekam' : 'Mulai Rekam',
                                style: const TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording
                                  ? Colors.red
                                  : (isDark ? Colors.white : Colors.black),
                              foregroundColor: _isRecording
                                  ? Colors.white
                                  : (isDark ? Colors.black : Colors.white),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
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
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detail Laporan',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lengkapi informasi untuk proses investigasi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.note_alt_outlined,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      TextField(
                        controller: _locationController,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          labelText: 'Lokasi Kejadian *',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on,
                            size: 20,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          hintText: 'Contoh: Gedung A Lantai 2, Ruang Kelas 201',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(12),
                          labelText: 'Deskripsi Kejadian *',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Icon(
                              Icons.description,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          alignLabelWithHint: true,
                          hintText: 'Jelaskan kronologi kejadian secara detail...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contact Information
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Informasi Kontak',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Untuk pembaruan status penanganan laporan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.contact_mail_outlined,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Email & Phone
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                labelText: 'Email *',
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                prefixIcon: Icon(
                                  Icons.email,
                                  size: 20,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                labelText: 'No. Telepon *',
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                prefixIcon: Icon(
                                  Icons.phone,
                                  size: 20,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: (_locationController.text.isEmpty ||
                                          _descriptionController.text.isEmpty ||
                                          _emailController.text.isEmpty ||
                                          _phoneController.text.isEmpty)
                                    ? null  // Disable button if fields are empty
                                    : _submitReport,
                                icon: const Icon(Icons.upload_rounded, size: 18),
                                label: Text(
                                  'Kirim Laporan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: (_locationController.text.isEmpty ||
                                           _descriptionController.text.isEmpty ||
                                           _emailController.text.isEmpty ||
                                           _phoneController.text.isEmpty)
                                        ? (isDark ? Colors.white38 : Colors.black38)
                                        : (isDark ? Colors.black : Colors.white),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  disabledBackgroundColor: isDark 
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.06),
                                  disabledForegroundColor: isDark
                                      ? Colors.white.withOpacity(0.38)
                                      : Colors.black.withOpacity(0.38),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            if (_locationController.text.isEmpty ||
                                _descriptionController.text.isEmpty ||
                                _emailController.text.isEmpty ||
                                _phoneController.text.isEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Semua field wajib diisi (lokasi, deskripsi, email, dan no. telepon)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.red[400] : Colors.red[600],
                                ),
                              ),
                            ],
                          ],
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