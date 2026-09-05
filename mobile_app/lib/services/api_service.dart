import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models.dart';

enum ApiExceptionKind { network, server, unknown }

/// Carries only the error category and status code so screens can map it to
/// friendly localized messages without leaking raw technical text.
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode});
  final ApiExceptionKind kind;
  final int? statusCode;
  @override
  String toString() => 'ApiException(${kind.name}, statusCode: $statusCode)';
}

ApiException _mapDioError(DioException error) {
  const networkTypes = {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  };
  final kind = switch (error.type) {
    DioExceptionType.badResponse => ApiExceptionKind.server,
    _ when networkTypes.contains(error.type) => ApiExceptionKind.network,
    _ => ApiExceptionKind.unknown,
  };
  return ApiException(kind, statusCode: error.response?.statusCode);
}

class ApiService {
  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000'),
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 10),
        ));
  final Dio _dio;

  Future<String> separate(File file, SeparationMode mode,
      ProcessingQuality quality, void Function(int) onProgress) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: file.uri.pathSegments.last),
        'mode':
            mode == SeparationMode.keepVocals ? 'keep_vocals' : 'keep_music',
        'quality': quality.wireName,
      });
      final response = await _dio.post<Map<String, dynamic>>('/api/v1/separate',
          data: form,
          onSendProgress: (sent, total) =>
              onProgress(total == 0 ? 0 : (sent * 100 ~/ total)));
      return response.data!['job_id'] as String;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<JobStatus> status(String jobId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/status/$jobId');
      final data = response.data!;
      return JobStatus(data['progress'] as int? ?? 0, data['status'] as String,
          stage: data['stage'] as String?, error: data['error'] as String?);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Project> result(Project project) async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/api/v1/result/${project.jobId}');
      final data = response.data!;
      return project.copyWith(
          vocalsUrl: data['vocals_url'] as String,
          instrumentalUrl: data['instrumental_url'] as String,
          videoUrl: data['video_url_if_needed'] as String?);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      await _dio.delete<void>('/api/v1/jobs/$jobId');
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<File> downloadOutput(String url, String fileName,
      {void Function(int progress)? onProgress}) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final exportDirectory =
        Directory('${documentsDirectory.path}${Platform.pathSeparator}exports');
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target =
        File('${exportDirectory.path}${Platform.pathSeparator}$safeName');
    try {
      await _dio.download(url, target.path,
          onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received * 100 ~/ total);
        }
      });
      return target;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }
}
