enum SeparationMode { keepVocals, keepMusic }

class Project {
  const Project({required this.name, required this.originalPath, required this.isVideo, this.jobId, this.vocalsUrl, this.instrumentalUrl, this.videoUrl});
  final String name;
  final String originalPath;
  final bool isVideo;
  final String? jobId;
  final String? vocalsUrl;
  final String? instrumentalUrl;
  final String? videoUrl;

  Project copyWith({String? jobId, String? vocalsUrl, String? instrumentalUrl, String? videoUrl}) => Project(name: name, originalPath: originalPath, isVideo: isVideo, jobId: jobId ?? this.jobId, vocalsUrl: vocalsUrl ?? this.vocalsUrl, instrumentalUrl: instrumentalUrl ?? this.instrumentalUrl, videoUrl: videoUrl ?? this.videoUrl);
}

class JobStatus {
  const JobStatus(this.progress, this.status);
  final int progress;
  final String status;
}
