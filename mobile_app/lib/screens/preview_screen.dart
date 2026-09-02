import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/integrations.dart';
import '../widgets/waveform.dart';

enum _PreviewTrack { original, vocals, instrumental }

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.project});

  final Project project;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ApiService _api = ApiService();
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  _PreviewTrack _selectedTrack = _PreviewTrack.vocals;
  String? _loadedSource;
  bool _isExporting = false;
  int _exportProgress = 0;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _playOrPause() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    final source = _sourceFor(_selectedTrack);
    try {
      if (_loadedSource != source) {
        if (_selectedTrack == _PreviewTrack.original) {
          await _player.setFilePath(widget.project.originalPath);
        } else {
          await _player.setUrl(source);
        }
        _loadedSource = source;
      }
      await _player.play();
    } on PlayerException catch (_) {
      _showMessage('تعذّر تشغيل هذا الملف.');
    } on PlayerInterruptedException catch (_) {
      _showMessage('توقّف التشغيل قبل اكتماله.');
    }
  }

  String _sourceFor(_PreviewTrack track) => switch (track) {
        _PreviewTrack.original => widget.project.originalPath,
        _PreviewTrack.vocals => widget.project.vocalsUrl ?? '',
        _PreviewTrack.instrumental => widget.project.instrumentalUrl ?? '',
      };

  String _labelFor(_PreviewTrack track) => switch (track) {
        _PreviewTrack.original => 'الأصل',
        _PreviewTrack.vocals => 'الصوت البشري',
        _PreviewTrack.instrumental => 'الموسيقى',
      };

  String _fileNameFor(_PreviewTrack track) {
    final stem = widget.project.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final suffix = switch (track) {
      _PreviewTrack.original => 'original',
      _PreviewTrack.vocals => 'vocals',
      _PreviewTrack.instrumental => 'instrumental',
    };
    return '${stem}_$suffix.wav';
  }

  Future<void> _export() async {
    if (_selectedTrack == _PreviewTrack.original) {
      await _shareFile(File(widget.project.originalPath));
      return;
    }

    final url = _sourceFor(_selectedTrack);
    if (url.isEmpty) {
      _showMessage('ملف النتيجة غير متاح بعد.');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });
    try {
      final file = await _api.downloadOutput(
        url,
        _fileNameFor(_selectedTrack),
        onProgress: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
      );
      Integrations.track('export_completed');
      if (!mounted) return;
      await _shareFile(file);
    } on ApiException catch (error) {
      _showMessage('فشل تنزيل الملف: ${error.message}');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareFile(File file) async {
    if (!await file.exists()) {
      _showMessage('الملف غير موجود على الجهاز.');
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MuteMusic AI - ${_labelFor(_selectedTrack)}',
    );
  }

  void _selectTrack(_PreviewTrack track) {
    if (track == _selectedTrack) return;
    _player.stop();
    setState(() {
      _selectedTrack = track;
      _loadedSource = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.playing;
    return Scaffold(
      appBar: AppBar(title: const Text('المعاينة والتصدير')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('قارن النتيجة قبل الحفظ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('اختر المسار ثم استمع إليه أو صدّره إلى تطبيق آخر.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              SegmentedButton<_PreviewTrack>(
                segments: const [
                  ButtonSegment(value: _PreviewTrack.original, label: Text('الأصل')),
                  ButtonSegment(value: _PreviewTrack.vocals, label: Text('الصوت البشري')),
                  ButtonSegment(value: _PreviewTrack.instrumental, label: Text('الموسيقى')),
                ],
                selected: {_selectedTrack},
                onSelectionChanged: (selection) => _selectTrack(selection.first),
              ),
              const Spacer(),
              const Waveform(),
              const SizedBox(height: 18),
              Text(_labelFor(_selectedTrack), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 14),
              Center(child: IconButton.filled(iconSize: 58, onPressed: _playOrPause, icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow))),
              const Spacer(),
              if (_isExporting) ...[
                LinearProgressIndicator(value: _exportProgress / 100),
                const SizedBox(height: 8),
                Text('جارٍ تجهيز الملف $_exportProgress%', textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(onPressed: _isExporting ? null : _export, icon: const Icon(Icons.ios_share), label: Text(_isExporting ? 'جارٍ التصدير…' : 'تصدير ومشاركة')),
              const SizedBox(height: 10),
              Text('سيُنزّل الملف إلى مساحة التطبيق ثم يفتح قائمة المشاركة والحفظ في جهازك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
