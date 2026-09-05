enum SeparationMode { keepVocals, keepMusic }

enum ProcessingQuality {
  fast,
  deep;

  String get wireName => this == ProcessingQuality.deep ? 'deep' : 'fast';
}

class Project {
  const Project({
    required this.name,
    required this.originalPath,
    required this.isVideo,
    this.quality = ProcessingQuality.deep,
    this.jobId,
    this.vocalsUrl,
    this.instrumentalUrl,
    this.videoUrl,
    this.deleted = false,
  });
  final String name;
  final String originalPath;
  final bool isVideo;
  final ProcessingQuality quality;
  final String? jobId;
  final String? vocalsUrl;
  final String? instrumentalUrl;
  final String? videoUrl;
  final bool deleted;

  Project copyWith(
          {String? jobId,
          String? vocalsUrl,
          String? instrumentalUrl,
          String? videoUrl,
          bool? deleted}) =>
      Project(
        name: name,
        originalPath: originalPath,
        isVideo: isVideo,
        quality: quality,
        jobId: jobId ?? this.jobId,
        vocalsUrl: vocalsUrl ?? this.vocalsUrl,
        instrumentalUrl: instrumentalUrl ?? this.instrumentalUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        deleted: deleted ?? this.deleted,
      );
}

class JobStatus {
  const JobStatus(this.progress, this.status, {this.stage, this.error});
  final int progress;
  final String status;
  final String? stage;
  final String? error;
}
