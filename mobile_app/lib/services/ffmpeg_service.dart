import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class FfmpegService {
  Future<File> muxVideo({required File original, required File vocals, required File output}) async {
    final session = await FFmpegKit.execute('-y -i "${original.path}" -i "${vocals.path}" -c:v copy -map 0:v:0 -map 1:a:0 -shortest "${output.path}"');
    final code = await session.getReturnCode();
    if (code?.isValueSuccess() != true) throw StateError('Unable to create cleaned video');
    return output;
  }
}
