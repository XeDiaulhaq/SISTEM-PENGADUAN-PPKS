class VideoModel {
  final String id;
  final String filename;
  final String uploadDate;
  final String uploadTime;
  final String size;
  final VideoStatus status;
  final String? blurType;
  final String? location;
  final String? description;
  final String? email;
  final String? phone;
  final String? videoUrl;

  VideoModel({
    required this.id,
    required this.filename,
    required this.uploadDate,
    required this.uploadTime,
    required this.size,
    required this.status,
    this.blurType,
    this.location,
    this.description,
    this.email,
    this.phone,
    this.videoUrl,
  });

  VideoModel copyWith({
    String? id,
    String? filename,
    String? uploadDate,
    String? uploadTime,
    String? size,
    VideoStatus? status,
    String? blurType,
    String? location,
    String? description,
    String? email,
    String? phone,
    String? videoUrl,
  }) {
    return VideoModel(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      uploadDate: uploadDate ?? this.uploadDate,
      uploadTime: uploadTime ?? this.uploadTime,
      size: size ?? this.size,
      status: status ?? this.status,
      blurType: blurType ?? this.blurType,
      location: location ?? this.location,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'uploadDate': uploadDate,
      'uploadTime': uploadTime,
      'size': size,
      'status': status.name,
      'blurType': blurType,
      'location': location,
      'description': description,
      'email': email,
      'phone': phone,
      'videoUrl': videoUrl,
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'],
      filename: json['filename'],
      uploadDate: json['uploadDate'],
      uploadTime: json['uploadTime'],
      size: json['size'],
      status: VideoStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => VideoStatus.newReport,
      ),
      blurType: json['blurType'],
      location: json['location'],
      description: json['description'],
      email: json['email'],
      phone: json['phone'],
      videoUrl: json['videoUrl'],
    );
  }
}

enum VideoStatus {
  newReport,
  processing,
  completed;

  String get displayName {
    switch (this) {
      case VideoStatus.newReport:
        return 'Baru';
      case VideoStatus.processing:
        return 'Diproses';
      case VideoStatus.completed:
        return 'Selesai';
    }
  }
}
