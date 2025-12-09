import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_exceptions.dart';
import '../services/local_face_blur_service.dart';
import '../services/report_submission_service.dart';
import '../services/streaming_service.dart';
import '../widgets/footer.dart';
import '../widgets/terms_dialog.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  static const _frameInterval = Duration(milliseconds: 3000); // 3 detik per frame untuk performa optimal
  bool _isRecording = false;
  CameraController? _cameraController;
  String? _uploadedVideoPath;
  bool _showTermsDialog = true;
  final _reportSubmissionService = ReportSubmissionService();
  final _streamingService = StreamingService();
  final _faceBlurService = LocalFaceBlurService();
  bool _isSubmitting = false;
  StreamSubscription<Uint8List>? _processedFrameSubscription;
  Uint8List? _latestBlurredFrame;
  Timer? _streamingTimer;
  bool _isSendingFrame = false;
  bool _isStreaming = false;

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
    _registerFormListeners();
    // DISABLED: Streaming subscription - will use local blur preview instead
    // _startLocalBlurPreview();
  }

  @override
  void dispose() {
    _reportSubmissionService.dispose();
    _faceBlurService.dispose();
    unawaited(_stopStreaming());
    _streamingService.dispose();
    _cameraController?.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _registerFormListeners() {
    for (final controller in [
      _locationController,
      _descriptionController,
      _emailController,
      _phoneController,
    ]) {
      controller.addListener(_onFormChanged);
    }
  }

  void _onFormChanged() => setState(() {});

  Future<void> _initializeCamera() async {
    try {
      print('[Camera] Getting available cameras...');
      final cameras = await availableCameras();
      print('[Camera] Found ${cameras.length} camera(s)');

      if (cameras.isEmpty) {
        _showErrorSnackBar(
          'Tidak ada kamera yang tersedia. '
          'Pastikan browser memiliki izin untuk mengakses kamera.',
        );
        return;
      }

      // Coba setiap kamera yang tersedia
      CameraDescription? workingCamera;
      Exception? lastError;

      for (var i = 0; i < cameras.length; i++) {
        final camera = cameras[i];
        print('[Camera] Trying camera $i: ${camera.name}');

        try {
          final controller = CameraController(
            camera,
            ResolutionPreset.low,
            enableAudio: true, // Enable audio untuk recording dengan suara
          );

          print('[Camera] Initializing camera $i...');
          await controller.initialize();
          print('[Camera] Camera $i initialized successfully!');

          // Jika berhasil, gunakan kamera ini
          _cameraController = controller;
          workingCamera = camera;
          break;
        } catch (e) {
          print('[Camera] Failed to initialize camera $i: $e');
          lastError = e as Exception;
          // Lanjut coba kamera berikutnya
        }
      }

      if (workingCamera == null) {
        print('[Camera] All cameras failed to initialize');
        throw lastError ?? Exception('Tidak dapat menginisialisasi kamera');
      }

      print('[Camera] Successfully using camera: ${workingCamera.name}');

      if (mounted) {
        setState(() {});
        // DISABLED: Streaming preview blur disabled untuk performa lebih baik
        // Server akan proses blur saat submit
        // _startStreaming();
        _showSuccessSnackBar(
          'Kamera siap',
          'Tekan "Mulai Rekam" untuk memulai perekaman video.',
        );
      }
    } catch (e) {
      print('[Camera] Error in _initializeCamera: $e');
      String errorMessage = 'Tidak dapat mengakses kamera: $e';

      // Berikan pesan error yang lebih spesifik
      if (e.toString().contains('Permission') ||
          e.toString().contains('NotAllowedError')) {
        errorMessage =
          'Akses kamera ditolak!\n\n'
          'Pastikan:\n'
          '1. Browser memiliki izin untuk mengakses kamera\n'
          '2. Tidak ada aplikasi lain yang menggunakan kamera\n'
          '3. Refresh halaman dan izinkan akses kamera saat diminta';
      } else if (e.toString().contains('NotFoundError')) {
        errorMessage =
          'Kamera tidak ditemukan!\n\n'
          'Pastikan:\n'
          '1. Kamera terpasang dengan benar\n'
          '2. Driver kamera sudah terinstall\n'
          '3. Kamera tidak digunakan aplikasi lain';
      } else if (e.toString().contains('NotReadable') ||
                 e.toString().contains('cameraNotReadable')) {
        errorMessage =
          'Kamera sedang digunakan aplikasi lain!\n\n'
          'Solusi:\n'
          '1. Tutup aplikasi lain yang menggunakan kamera (Teams, Zoom, dll)\n'
          '2. Tutup tab browser lain yang menggunakan kamera\n'
          '3. Restart browser Chrome\n'
          '4. Jika masih gagal, restart komputer\n\n'
          'Atau gunakan tombol "Upload Berkas" untuk mengunggah video.';
      }

      _showErrorSnackBar(errorMessage);

      if (mounted) {
        setState(() {});
      }
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
      _showErrorSnackBar(
        'Kamera tidak tersedia.\n\n'
        'Silakan gunakan tombol "Upload Berkas" untuk mengunggah video yang sudah ada.',
      );
      return;
    }

    try {
      // PENTING: Stop streaming saat recording untuk performa lebih baik
      // Client tidak perlu streaming - server akan process blur nanti
      await _stopStreaming();

      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
      _latestBlurredFrame = null;
      _showSuccessSnackBar(
        'Recording dimulai',
        'Video sedang direkam. Tekan "Hentikan Rekam" untuk mengakhiri.',
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
      // DISABLED: No streaming needed anymore
      // _startStreaming();
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

  Future<void> _startStreaming() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isStreaming) return;

    try {
      await _streamingService.connect();
      await _processedFrameSubscription?.cancel();
      _processedFrameSubscription = _streamingService.frames.listen((frame) {
        if (!mounted) return;
        setState(() => _latestBlurredFrame = frame);
      });

      _streamingTimer ??=
          Timer.periodic(_frameInterval, (_) {
        unawaited(_captureAndSendFrame());
      });

      if (mounted) {
        setState(() => _isStreaming = true);
      } else {
        _isStreaming = true;
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memulai streaming: $e');
    }
  }

  Future<void> _stopStreaming() async {
    _streamingTimer?.cancel();
    _streamingTimer = null;
    await _processedFrameSubscription?.cancel();
    _processedFrameSubscription = null;
    await _streamingService.disconnect();

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _latestBlurredFrame = null;
      });
    } else {
      _isStreaming = false;
      _latestBlurredFrame = null;
    }
  }

  Future<void> _captureAndSendFrame() async {
    // Skip jika sedang mengirim atau tidak streaming
    if (_isSendingFrame || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    // IMPORTANT: Jangan capture saat recording untuk menghindari freeze
    if (_cameraController!.value.isRecordingVideo) {
      print('[Frame] Skipping capture - recording in progress');
      return;
    }

    _isSendingFrame = true;
    try {
      final still = await _cameraController!.takePicture();
      final bytes = await still.readAsBytes();

      // Kirim frame ke server untuk di-blur (non-blocking)
      _streamingService.sendFrame(bytes).then((_) {
        print('[Frame] Frame sent successfully');
      }).catchError((e) {
        print('[Frame] Failed to send: $e');
      });
    } catch (e) {
      print('[Frame] Failed to capture: $e');
    } finally {
      _isSendingFrame = false;
    }
  }

  Future<void> _captureAndBlurLocal() async {
    // Untuk local face blur preview - not blocking, fire and forget
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (!mounted) return;

    try {
      final still = await _cameraController!.takePicture();
      final bytes = await still.readAsBytes();

      // Blur local (non-blocking)
      _faceBlurService.detectAndBlurFaces(bytes).then((blurredBytes) {
        if (blurredBytes != null && mounted) {
          setState(() => _latestBlurredFrame = blurredBytes);
        }
      }).catchError((e) {
        print('[LocalBlur] Error in processing: $e');
      });
    } catch (e) {
      print('[LocalBlur] Failed to capture: $e');
    }
  }

  void _startLocalBlurPreview() {
    // Timer untuk capture dan blur local setiap N ms
    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      // Update local blur every 500ms saat tidak recording
      if (!_isRecording && mounted) {
        unawaited(_captureAndBlurLocal());
      }
    });
  }

  Future<void> _submitReport() async {
    if (!_isFormValid) {
      _showErrorSnackBar('Data tidak lengkap. Isi seluruh field wajib.');
      return;
    }

    if (_uploadedVideoPath == null) {
      _showErrorSnackBar('Video belum tersedia. Silakan rekam atau upload berkas.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final file = XFile(_uploadedVideoPath!);
      final location = _locationController.text.trim();
      final description = _descriptionController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final title = 'Laporan $location';

        await _reportSubmissionService.submitReport(
        video: file,
        title: title,
        location: location,
        description: description,
        email: email,
          phone: phone,
      );

      _showSuccessSnackBar(
        'Laporan berhasil dikirim!',
        'Video berhasil diunggah ke server dan siap ditinjau tim admin.',
      );

      setState(() {
        _locationController.clear();
        _descriptionController.clear();
        _emailController.clear();
        _phoneController.clear();
        _uploadedVideoPath = null;
      });
    } on ApiException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Error saat mengirim laporan: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _isFormValid =>
      _locationController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

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
    final canSubmit =
        _isFormValid && _uploadedVideoPath != null && !_isSubmitting;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[200],
                            ),
                            child: _buildPreviewPlaceholder(),
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
                      const SizedBox(height: 16),
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
                                color: isDark
                                  ? Colors.white12
                                  : Colors.black.withValues(alpha: 0.05),
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
                            fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
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
                            fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
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
                                color: isDark
                                  ? Colors.white12
                                  : Colors.black.withValues(alpha: 0.05),
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
                                fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.02),
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
                                fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.02),
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
                                color: isDark
                                  ? Colors.white12
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: canSubmit ? _submitReport : null,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.upload_rounded, size: 18),
                                label: Text(
                                  'Kirim Laporan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: canSubmit
                                        ? (isDark ? Colors.black : Colors.white)
                                        : (isDark ? Colors.white38 : Colors.black38),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  disabledBackgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.06),
                                  disabledForegroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.38)
                                      : Colors.black.withValues(alpha: 0.38),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            if (!_isFormValid) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Semua field wajib diisi (lokasi, deskripsi, email, dan no. telepon)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.red[400] : Colors.red[600],
                                ),
                              ),
                            ] else if (_uploadedVideoPath == null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Rekam atau unggah video sebelum mengirim laporan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.orange[300] : Colors.orange[700],
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
                      const SizedBox(height: 12),
                      const Footer(),
                    ],
                  ), // Column
                ), // Padding
              ), // ConstrainedBox
            ), // Center
          ), // SingleChildScrollView
        ), // SafeArea
      ); // Scaffold
  }

  Widget _buildPreviewPlaceholder() {
    // Jika kamera sudah initialize dan siap
    if (_cameraController?.value.isInitialized ?? false) {
      final preview = CameraPreview(_cameraController!);
      return Stack(
        fit: StackFit.expand,
        children: [
          preview,
          // Privacy disclaimer overlay
          if (!_isRecording)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip,
                      color: Colors.green[300],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privasi Terjaga: Wajah akan otomatis di-blur saat video diproses di server',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Show recording indicator
          if (_isRecording)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Jika kamera belum tersedia
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _cameraController == null
                ? 'Menginisialisasi kamera...'
                : 'Kamera Tidak Aktif',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _cameraController == null
                  ? 'Mohon tunggu...'
                  : 'Pastikan kamera sudah diizinkan di sistem Windows.\n\n'
                    'Atau gunakan "Upload Berkas" untuk mengunggah video yang sudah ada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_cameraController != null && !(_cameraController?.value.isInitialized ?? false))
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _cameraController = null;
                });
                _initializeCamera();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
