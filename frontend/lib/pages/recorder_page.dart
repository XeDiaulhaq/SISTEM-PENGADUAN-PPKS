import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_exceptions.dart';
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
  static const _frameInterval = Duration(milliseconds: 250);
  bool _isRecording = false;
  CameraController? _cameraController;
  String? _uploadedVideoPath;
  bool _showTermsDialog = true;
  final _reportSubmissionService = ReportSubmissionService();
  final _streamingService = StreamingService();
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
  }

  @override
  void dispose() {
    _reportSubmissionService.dispose();
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
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
        _startStreaming();
      }
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
      _latestBlurredFrame = null;
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
      _startStreaming();
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
    if (_isSendingFrame || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isRecordingVideo) return;

    _isSendingFrame = true;
    try {
      final still = await _cameraController!.takePicture();
      final bytes = await still.readAsBytes();
      await _streamingService.sendFrame(bytes);
    } catch (_) {
      // swallow errors, preview will retry on next tick
    } finally {
      _isSendingFrame = false;
    }
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 0.05),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 16,
                            color: isDark ? Colors.tealAccent : Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Blur otomatis aktif dan terekam',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
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
    if (_cameraController?.value.isInitialized ?? false) {
      final preview = CameraPreview(_cameraController!);
      return Stack(
        fit: StackFit.expand,
        children: [
          preview,
          if (_latestBlurredFrame != null)
            Positioned.fill(
              child: Image.memory(
                _latestBlurredFrame!,
                fit: BoxFit.cover,
              ),
            )
          else ...[
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: preview,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return const Center(
      child: Text(
        'Klik "Mulai Rekam" untuk merekam video\natau "Upload Berkas" untuk mengunggah file',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
