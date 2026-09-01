import 'dart:io';
import 'package:dio/dio.dart';
import '../models.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override String toString() => message;
}

class ApiService {
  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000'),
          connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(minutes: 10),
        ));
  final Dio _dio;

  Future<String> separate(File file, SeparationMode mode, void Function(int) onProgress) async {
    try {
      final form = FormData.fromMap({'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last), 'mode': mode == SeparationMode.keepVocals ? 'keep_vocals' : 'keep_music'});
      final response = await _dio.post<Map<String, dynamic>>('/api/v1/separate', data: form, onSendProgress: (sent, total) => onProgress(total == 0 ? 0 : (sent * 100 ~/ total)));
      return response.data!['job_id'] as String;
    } on DioException catch (error) {
      throw ApiException(error.response?.data is Map ? ((error.response!.data as Map)['detail']?.toString() ?? error.message ?? 'Upload failed') : (error.message ?? 'Upload failed'));
    }
  }

  Future<JobStatus> status(String jobId) async {
    try { final response = await _dio.get<Map<String, dynamic>>('/api/v1/status/$jobId'); final data = response.data!; return JobStatus(data['progress'] as int, data['status'] as String, error: data['error'] as String?); } on DioException catch (error) { throw ApiException(error.message ?? 'Status request failed'); }
  }

  Future<Project> result(Project project) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/result/${project.jobId}');
    final data = response.data!;
    return project.copyWith(vocalsUrl: data['vocals_url'] as String, instrumentalUrl: data['instrumental_url'] as String, videoUrl: data['video_url_if_needed'] as String?);
  }
}
