class VideoModel {
  final String id;
  final String filename;
  final String uploadDate;
  final String uploadTime;
  final String size;
  final String status; // processed / pending
  final String? blurType;

  VideoModel({
    required this.id,
    required this.filename,
    required this.uploadDate,
    required this.uploadTime,
    required this.size,
    required this.status,
    this.blurType,
  });
}
