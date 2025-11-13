import 'package:flutter/material.dart';
import 'dart:async';
import '../models/video_model.dart';
import '../services/video_storage_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final VideoStorageService _storageService = VideoStorageService();
  List<VideoModel> _videos = [];
  VideoFilter _filter = VideoFilter.all;
  Timer? _refreshTimer;
  bool _isLoading = true;

  // Getter untuk dark mode detection
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    // Auto-refresh every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadVideos();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    final videos = await _storageService.loadVideos();
    if (mounted) {
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVideoStatus(String id, VideoStatus newStatus) async {
    final updatedVideos =
        await _storageService.updateVideoStatus(_videos, id, newStatus);
    setState(() {
      _videos = updatedVideos;
    });

    if (mounted) {
      final statusText =
          newStatus == VideoStatus.processing ? 'Sedang Diproses' : 'Selesai';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status laporan diubah menjadi "$statusText"'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<VideoModel> get _filteredVideos {
    final today = DateTime.now();
    final todayStr = '${today.day}/${today.month}/${today.year}';

    switch (_filter) {
      case VideoFilter.today:
        return _videos.where((v) => v.uploadDate == todayStr).toList();
      case VideoFilter.processing:
        return _videos
            .where((v) => v.status == VideoStatus.processing)
            .toList();
      case VideoFilter.completed:
        return _videos.where((v) => v.status == VideoStatus.completed).toList();
      case VideoFilter.all:
      default:
        return _videos;
    }
  }

  void _showVideoDetail(VideoModel video) {
    showDialog(
      context: context,
      builder: (context) => VideoDetailDialog(
        video: video,
        onStatusUpdate: _updateVideoStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = '${today.day}/${today.month}/${today.year}';

    final stats = [
      StatCard(
        title: 'Total Laporan',
        value: _videos.length.toString(),
        icon: Icons.video_library,
        color: Colors.blue,
        filter: VideoFilter.all,
      ),
      StatCard(
        title: 'Laporan Hari Ini',
        value: _videos.where((v) => v.uploadDate == todayStr).length.toString(),
        icon: Icons.trending_up,
        color: Colors.green,
        filter: VideoFilter.today,
      ),
      StatCard(
        title: 'Sedang Diproses',
        value: _videos
            .where((v) => v.status == VideoStatus.processing)
            .length
            .toString(),
        icon: Icons.access_time,
        color: Colors.orange,
        filter: VideoFilter.processing,
      ),
      StatCard(
        title: 'Selesai Diproses',
        value: _videos
            .where((v) => v.status == VideoStatus.completed)
            .length
            .toString(),
        icon: Icons.check_circle,
        color: Colors.purple,
        filter: VideoFilter.completed,
      ),
    ];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: 1280), // max-w-7xl = 80rem = 1280px
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // px-4 = 1rem = 16px
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                      height: 60), // pt-20 = 5rem = 80px (lebih kecil)
                  // Header
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 32, // Sedikit lebih kecil
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6), // mb-1.5 = 0.375rem = 6px
                  Text(
                    'Monitor dan kelola laporan yang masuk dari mahasiswa',
                    style: TextStyle(
                      fontSize: 16, // Lebih kecil
                      color: isDark
                          ? const Color(0xFFA3A3A3)
                          : const Color(0xFF737373),
                    ),
                  ),
                  const SizedBox(
                      height: 24), // mb-6 = 1.5rem = 24px (lebih kecil)

                  // Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          constraints.maxWidth > 1024 // lg breakpoint
                              ? 4
                              : constraints.maxWidth > 768 // md breakpoint
                                  ? 2
                                  : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing:
                              12, // gap-3 = 0.75rem = 12px (lebih compact)
                          mainAxisSpacing: 12, // gap-3 = 0.75rem = 12px
                          childAspectRatio: 2.0, // Lebih landscape lagi
                        ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final stat = stats[index];
                          final isSelected = _filter == stat.filter;
                          final isFirst = index == 0; // Total Laporan card
                          return InkWell(
                            onTap: () => setState(() => _filter = stat.filter),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF171717)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isFirst
                                    ? Border.all(
                                        color: const Color(
                                            0xFF3B82F6), // Blue border for first card
                                        width: 2,
                                      )
                                    : isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : const Color(0xFF3B82F6),
                                            width: 2,
                                          )
                                        : Border.all(
                                            color: isDark
                                                ? const Color(0xFF262626)
                                                : const Color(0xFFE5E5E5),
                                          ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    16.0), // Padding lebih compact
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            stat.title,
                                            style: TextStyle(
                                              fontSize: 13, // Lebih kecil
                                              color: isDark
                                                  ? const Color(0xFFA3A3A3)
                                                  : const Color(0xFF737373),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8), // mb-2
                                          Text(
                                            stat.value,
                                            style: TextStyle(
                                              fontSize: 32, // Angka besar
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12), // p-3
                                      decoration: BoxDecoration(
                                        color: stat.color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        stat.icon,
                                        color: Colors.white,
                                        size: 24, // w-6 h-6
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(
                      height: 20), // mb-5 = 1.25rem = 20px (lebih kecil)

                  // Video List Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171717) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF262626)
                            : const Color(0xFFE5E5E5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                          20.0), // p-5 = 1.25rem = 20px (lebih compact)
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12, // ml-3 = 0.75rem = 12px
                                  children: [
                                    Text(
                                      'Daftar Laporan Video',
                                      style: TextStyle(
                                        fontSize: 20, // Lebih kecil
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    if (_filter != VideoFilter.all)
                                      Text(
                                        '(${_filter.displayName})',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF60A5FA)
                                              : const Color(0xFF3B82F6),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_filter != VideoFilter.all)
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => _filter = VideoFilter.all),
                                  icon: Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFFD4D4D4)
                                        : const Color(0xFF525252),
                                  ),
                                  label: Text(
                                    'Reset Filter',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFD4D4D4)
                                          : const Color(0xFF525252),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF404040)
                                          : const Color(0xFFD4D4D4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(
                              height: 16), // mb-4 = 1rem = 16px (lebih kecil)

                          // Video List
                          if (_filteredVideos.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredVideos.length,
                              separatorBuilder: (context, index) => const SizedBox(
                                  height:
                                      12), // space-y-3 = 0.75rem = 12px (lebih kecil)
                              itemBuilder: (context, index) {
                                final video = _filteredVideos[index];
                                return VideoCard(
                                  video: video,
                                  onView: () => _showVideoDetail(video),
                                  onDownload: () => _downloadVideo(video),
                                  onStatusUpdate: _updateVideoStatus,
                                  isDark: isDark,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 40), // pb-10 = 2.5rem = 40px (lebih kecil)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0), // py-12 = 3rem = 48px
        child: Column(
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64, // w-16 h-16 = 4rem = 64px
              color: isDark ? const Color(0xFF737373) : const Color(0xFFA3A3A3),
            ),
            const SizedBox(height: 16), // mb-4 = 1rem = 16px
            Text(
              _filter == VideoFilter.all
                  ? 'Belum ada laporan video yang diunggah'
                  : 'Tidak ada laporan dengan filter ini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8), // mt-2 = 0.5rem = 8px
            Text(
              _filter == VideoFilter.all
                  ? 'Video yang diunggah melalui halaman Recorder akan muncul di sini'
                  : 'Coba pilih filter lain atau reset filter',
              style: TextStyle(
                fontSize: 14, // text-sm
                color:
                    isDark ? const Color(0xFF737373) : const Color(0xFFA3A3A3),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _downloadVideo(VideoModel video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download video: ${video.filename}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Stat Card Model
class StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VideoFilter filter;

  StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.filter,
  });
}

// Video Filter Enum
enum VideoFilter {
  all,
  today,
  processing,
  completed;

  String get displayName {
    switch (this) {
      case VideoFilter.all:
        return 'Semua';
      case VideoFilter.today:
        return 'Hari Ini';
      case VideoFilter.processing:
        return 'Sedang Diproses';
      case VideoFilter.completed:
        return 'Selesai Diproses';
    }
  }
}

// Video Card Widget
class VideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final Function(String, VideoStatus) onStatusUpdate;
  final bool isDark;

  const VideoCard({
    super.key,
    required this.video,
    required this.onView,
    required this.onDownload,
    required this.onStatusUpdate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // p-4 = 16px (lebih compact)
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768; // md breakpoint
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Video Icon
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12), // p-2.5 md:p-3
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF404040)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.videocam,
                    size: isMobile ? 20 : 24, // w-5 h-5 md:w-6 md:h-6
                    color: isDark
                        ? const Color(0xFFD4D4D4)
                        : const Color(0xFF737373),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16), // gap-3 md:gap-4

                // Video Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.filename,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15, // text-sm md:text-base
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6), // mb-1.5
                      Wrap(
                        spacing: isMobile ? 8 : 10, // gap-2 md:gap-3
                        runSpacing: 6,
                        children: [
                          _buildInfoChip(
                            Icons.calendar_today,
                            video.uploadDate,
                            isMobile,
                          ),
                          _buildInfoChip(
                            Icons.access_time,
                            video.uploadTime,
                            isMobile,
                          ),
                          _buildInfoChip(
                            Icons.storage,
                            video.size,
                            isMobile,
                          ),
                          if (video.blurType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF404040).withOpacity(0.3)
                                    : const Color(0xFFF5F5F5),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF404040)
                                      : const Color(0xFFE5E5E5),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                video.blurType == 'gaussian'
                                    ? 'Gaussian'
                                    : 'Pixelation',
                                style: TextStyle(
                                  fontSize: 11, // text-xs
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFD4D4D4)
                                      : const Color(0xFF525252),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons & Status Badge (Desktop)
                if (!isMobile) ...[
                  const SizedBox(width: 12),
                  _buildButton(
                    context,
                    onPressed: onView,
                    icon: Icons.visibility,
                    label: 'Lihat',
                    isOutlined: true,
                    isMobile: isMobile,
                  ),
                  const SizedBox(width: 6),
                  _buildButton(
                    context,
                    onPressed: onDownload,
                    icon: Icons.download,
                    label: 'Unduh',
                    isOutlined: true,
                    isMobile: isMobile,
                  ),
                  if (video.status == VideoStatus.newReport) ...[
                    const SizedBox(width: 6),
                    _buildButton(
                      context,
                      onPressed: () =>
                          onStatusUpdate(video.id, VideoStatus.processing),
                      icon: Icons.access_time,
                      label: 'Proses',
                      backgroundColor: const Color(0xFF3B82F6),
                      isMobile: isMobile,
                    ),
                  ],
                  if (video.status == VideoStatus.processing) ...[
                    const SizedBox(width: 6),
                    _buildButton(
                      context,
                      onPressed: () =>
                          onStatusUpdate(video.id, VideoStatus.completed),
                      icon: Icons.check_circle,
                      label: 'Selesai',
                      backgroundColor: const Color(0xFF22C55E),
                      isMobile: isMobile,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildStatusBadge(context, video.status, false),
                ] else ...[
                  // Mobile: status badge di kanan
                  const SizedBox(width: 8),
                  _buildStatusBadge(context, video.status, true),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isMobile ? 14 : 16, // w-3.5 h-3.5 md:w-4 md:h-4
          color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
        ),
        const SizedBox(width: 4), // gap-1
        Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 12 : 14, // text-xs md:text-sm
            color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      BuildContext context, VideoStatus status, bool isMobile) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case VideoStatus.newReport:
        color = const Color(0xFF3B82F6); // Blue
        icon = Icons.fiber_manual_record;
        text = 'Baru';
        break;
      case VideoStatus.processing:
        color = const Color(0xFFF59E0B); // Orange/Yellow
        icon = Icons.access_time_rounded;
        text = 'Diproses';
        break;
      case VideoStatus.completed:
        color = const Color(0xFF22C55E); // Green
        icon = Icons.check_circle_rounded;
        text = 'Selesai';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10, // px-2 py-0.5 / px-3 py-1.5
        vertical: isMobile ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: isMobile ? 11 : 13,
              color: Colors.white), // w-3 h-3 / w-4 h-4
          SizedBox(width: isMobile ? 3 : 4), // gap-1 / gap-1.5
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 10 : 11, // text-xs
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    bool isOutlined = false,
    required bool isMobile,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D4),
            width: 1,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? (label.isEmpty ? 10 : 12) : 14,
            vertical: 10,
          ),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isMobile ? 14 : 15, // w-3.5 h-3.5 md:w-4 md:h-4
              color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF525252),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5), // gap-1.5
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13, // text-xs md:text-sm
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFD4D4D4)
                      : const Color(0xFF525252),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: 10,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 15),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Video Detail Dialog
class VideoDetailDialog extends StatelessWidget {
  final VideoModel video;
  final Function(String, VideoStatus) onStatusUpdate;

  const VideoDetailDialog({
    super.key,
    required this.video,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(
            maxWidth: 900, maxHeight: 700), // max-w-4xl max-h-[90vh]
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171717) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF262626)
                        : const Color(0xFFE5E5E5),
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
                          style: TextStyle(
                            fontSize: 20, // text-lg md:text-xl
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Informasi lengkap mengenai laporan yang diterima',
                          style: TextStyle(
                            fontSize: 14, // text-sm
                            color: isDark
                                ? const Color(0xFFA3A3A3)
                                : const Color(0xFF737373),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Row(
                      children: [
                        Text(
                          'Status:',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(width: 12),
                        _buildStatusBadge(video.status),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Video Preview
                    _buildSection(
                      context,
                      'Video',
                      Icons.videocam,
                      Colors.blue,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Preview video tidak tersedia',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Video dapat diunduh untuk dilihat',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.videocam, video.filename),
                          _buildInfoRow(Icons.calendar_today, video.uploadDate),
                          _buildInfoRow(Icons.access_time, video.uploadTime),
                          _buildInfoRow(Icons.storage, video.size),
                          if (video.blurType != null)
                            _buildInfoRow(
                              Icons.blur_on,
                              'Blur: ${video.blurType == "gaussian" ? "Gaussian" : "Pixelation"}',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location
                    if (video.location != null) ...[
                      _buildSection(
                        context,
                        'Lokasi Kejadian',
                        Icons.location_on,
                        Colors.red,
                        Text(video.location!),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Description
                    if (video.description != null) ...[
                      _buildSection(
                        context,
                        'Deskripsi Kejadian',
                        Icons.description,
                        Colors.orange,
                        Text(video.description!),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Contact Info
                    if (video.email != null || video.phone != null) ...[
                      _buildSection(
                        context,
                        'Informasi Kontak Pelapor (Opsional)',
                        Icons.contact_phone,
                        Colors.green,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (video.email != null)
                              _buildContactInfo(
                                Icons.email,
                                'Email',
                                video.email!,
                                Colors.green,
                              ),
                            if (video.email != null && video.phone != null)
                              const SizedBox(height: 12),
                            if (video.phone != null)
                              _buildContactInfo(
                                Icons.phone,
                                'Telepon',
                                video.phone!,
                                Colors.purple,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  if (video.status == VideoStatus.newReport)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onStatusUpdate(video.id, VideoStatus.processing);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.hourglass_empty),
                        label: const Text('Mulai Proses Laporan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  if (video.status == VideoStatus.processing)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onStatusUpdate(video.id, VideoStatus.completed);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Selesaikan Laporan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  if (video.status == VideoStatus.newReport ||
                      video.status == VideoStatus.processing)
                    const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Download video
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Unduh Video'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(VideoStatus status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case VideoStatus.newReport:
        color = Colors.blue;
        icon = Icons.fiber_manual_record;
        text = 'Baru';
        break;
      case VideoStatus.processing:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = 'Sedang Diproses';
        break;
      case VideoStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Selesai';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
