import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/integrations.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import '../widgets/waveform.dart';

enum _PreviewTab { original, result }

enum _QualityVerdict { good, medium, tryDeep }

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.project});

  final Project project;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ApiService _api = ApiService();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  VideoPlayerController? _videoController;

  _PreviewTab _tab = _PreviewTab.result;
  String? _loadedSource;
  bool _videoFailed = false;
  bool _isExporting = false;
  bool _isExportingVideo = false;
  bool _deleting = false;
  bool _deleted = false;
  int _exportProgress = 0;

  bool get _isVideo => widget.project.isVideo;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    if (_isVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVideo());
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _player.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _selectTab(_PreviewTab tab) {
    if (tab == _tab) return;
    _player.pause();
    _videoController?.pause();
    setState(() {
      _tab = tab;
      _loadedSource = null;
      _videoFailed = false;
    });
    if (_isVideo) _ensureVideo();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  void _disposeVideo() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
  }

  /// Keeps exactly one video controller alive, swapped per tab.
  Future<void> _ensureVideo() async {
    if (!_isVideo) return;
    final resultUrl = widget.project.videoUrl;
    if (_tab == _PreviewTab.result &&
        (resultUrl == null || resultUrl.isEmpty)) {
      _disposeVideo();
      return;
    }
    final next = _tab == _PreviewTab.original
        ? VideoPlayerController.file(File(widget.project.originalPath))
        : VideoPlayerController.networkUrl(Uri.parse(resultUrl!));
    if (_videoController?.dataSource == next.dataSource) {
      await next.dispose();
      return;
    }
    _disposeVideo();
    _videoController = next;
    next.addListener(_onVideoTick);
    try {
      await next.initialize();
      if (!mounted || _videoController != next) {
        await next.dispose();
        return;
      }
      setState(() {});
    } catch (_) {
      if (mounted && _videoController == next) {
        _disposeVideo();
        setState(() => _videoFailed = true);
      }
    }
  }

  Future<void> _toggleVideo() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _playOrPause() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    final strings = AppLocalizations.of(context)!;
    final source = _sourceFor(_tab);
    try {
      if (_loadedSource != source) {
        if (_tab == _PreviewTab.original) {
          await _player.setFilePath(widget.project.originalPath);
        } else {
          await _player.setUrl(source);
        }
        _loadedSource = source;
      }
      await _player.play();
    } on PlayerException catch (_) {
      _showMessage(strings.playError);
    } on PlayerInterruptedException catch (_) {
      _showMessage(strings.interruptedError);
    }
  }

  String _sourceFor(_PreviewTab tab) => switch (tab) {
        _PreviewTab.original => widget.project.originalPath,
        _PreviewTab.result => widget.project.vocalsUrl ?? '',
      };

  String _fileNameFor(bool video) {
    final stem = widget.project.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return video ? '${stem}_processed.mp4' : '${stem}_vocals.wav';
  }

  Future<void> _exportAudio() async {
    final url = widget.project.vocalsUrl;
    if (url == null || url.isEmpty) {
      _showMessage(AppLocalizations.of(context)!.exportUnavailable);
      return;
    }
    await _runExport(isVideo: false, url: url);
  }

  Future<void> _exportVideo() async {
    final url = widget.project.videoUrl;
    if (url == null || url.isEmpty) {
      _showMessage(AppLocalizations.of(context)!.videoExportUnavailable);
      return;
    }
    await _runExport(isVideo: true, url: url);
  }

  Future<void> _runExport({required bool isVideo, required String url}) async {
    final strings = AppLocalizations.of(context)!;
    setState(() {
      _isExporting = true;
      _isExportingVideo = isVideo;
      _exportProgress = 0;
    });
    try {
      final file = await _api.downloadOutput(
        url,
        _fileNameFor(isVideo),
        onProgress: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
      );
      Integrations.track(
          isVideo ? 'video_export_completed' : 'export_completed');
      await _shareFile(
        file,
        subject:
            'MuteMusic AI - ${isVideo ? strings.exportVideo : strings.exportAudio}',
        failureMessage: strings.shareFailed,
      );
    } on ApiException catch (_) {
      _showMessage(
          isVideo ? strings.videoDownloadFailed : strings.downloadFailed);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportingVideo = false;
        });
      }
    }
  }

  Future<void> _shareFile(File file,
      {required String subject, required String failureMessage}) async {
    final strings = AppLocalizations.of(context)!;
    if (!await file.exists()) {
      _showMessage(strings.fileMissing);
      return;
    }
    try {
      await Share.shareXFiles([XFile(file.path)], subject: subject);
    } catch (_) {
      _showMessage(failureMessage);
    }
  }

  Future<void> _deleteFromServer() async {
    final strings = AppLocalizations.of(context)!;
    final jobId = widget.project.jobId;
    if (jobId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteConfirmTitle),
        content: Text(strings.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.deleteNow),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _api.deleteJob(jobId);
      if (!mounted) return;
      setState(() => _deleted = true);
    } on ApiException catch (_) {
      _showMessage(strings.deleteFailed);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(strings.previewTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.previewHeading,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(strings.previewSubtitle,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              SegmentedButton<_PreviewTab>(
                segments: [
                  ButtonSegment(
                      value: _PreviewTab.original,
                      label: Text(strings.tabOriginal)),
                  ButtonSegment(
                      value: _PreviewTab.result,
                      label: Text(strings.tabResult)),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) => _selectTab(selection.first),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _isVideo ? _buildVideoArea(strings) : _buildAudioArea(),
                      const SizedBox(height: 12),
                      Text(
                        _tab == _PreviewTab.original
                            ? strings.tabOriginal
                            : (_isVideo
                                ? strings.tabResult
                                : strings.resultLabel),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      _QualityCard(project: widget.project, strings: strings),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isExporting) ...[
                LinearProgressIndicator(
                    value: _exportProgress > 0 ? _exportProgress / 100 : null),
                const SizedBox(height: 8),
                Text(
                  _isExportingVideo
                      ? strings.preparingVideo(_exportProgress)
                      : strings.preparingFile(_exportProgress),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              if (_isVideo)
                FilledButton.icon(
                  onPressed: _isExporting || _deleted ? null : _exportVideo,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: Text(strings.exportVideo),
                ),
              if (_isVideo) const SizedBox(height: 10),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.secondaryText,
                  disabledForegroundColor: AppColors.disabledText,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _isExporting || _deleted ? null : _exportAudio,
                icon: const Icon(Icons.audiotrack_rounded),
                label: Text(
                    _isVideo ? strings.exportAudioOnly : strings.exportAudio),
              ),
              const SizedBox(height: 10),
              _buildDeleteSection(strings),
              const SizedBox(height: 10),
              Text(
                _isVideo ? strings.videoExportNote : strings.audioExportNote,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                strings.autoDeleteNotice,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioArea() {
    return Column(
      children: [
        const Waveform(),
        const SizedBox(height: 18),
        Center(
          child: IconButton.filled(
            iconSize: 58,
            onPressed: _playOrPause,
            icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea(AppLocalizations strings) {
    if (_tab == _PreviewTab.result &&
        (widget.project.videoUrl == null || widget.project.videoUrl!.isEmpty)) {
      return _VideoInfoPanel(message: strings.videoPreviewUnavailable);
    }
    if (_videoFailed) {
      return _VideoInfoPanel(message: strings.videoPlayError);
    }
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          _PlayOverlay(
            playing: controller.value.isPlaying,
            onTap: _toggleVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteSection(AppLocalizations strings) {
    if (_deleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: .4)),
        ),
        child: Row(
          children: [
            const StatusDot(color: AppColors.success, size: 8),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.deletedSuccess,
                style: const TextStyle(
                    color: AppColors.successText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (widget.project.jobId == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: _deleting || _isExporting ? null : _deleteFromServer,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.error.withValues(alpha: .55)),
        foregroundColor: AppColors.secondaryText,
      ),
      icon: _deleting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.delete_outline_rounded,
              color: AppColors.errorText),
      label: Text(_deleting ? strings.deleting : strings.deleteFromServer),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.project, required this.strings});

  final Project project;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final isDeep = project.quality == ProcessingQuality.deep;
    final verdict = isDeep
        ? _QualityVerdict.good
        : (project.isVideo ? _QualityVerdict.tryDeep : _QualityVerdict.medium);
    final (label, description, color) = switch (verdict) {
      _QualityVerdict.good => (
          strings.qualityGood,
          strings.qualityGoodDesc,
          AppColors.success,
        ),
      _QualityVerdict.medium => (
          strings.qualityMedium,
          strings.qualityMediumDesc,
          AppColors.warning,
        ),
      _QualityVerdict.tryDeep => (
          strings.qualityTryDeep,
          strings.qualityTryDeepDesc,
          AppColors.primaryLight,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(strings.qualityCardTitle,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusDot(color: color, size: 7),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(strings.qualityDisclaimer,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _VideoInfoPanel extends StatelessWidget {
  const _VideoInfoPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_file_outlined,
                size: 34, color: AppColors.helperText),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 36,
          ),
        ),
      );
}
