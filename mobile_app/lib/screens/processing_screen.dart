import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import '../widgets/waveform.dart';
import 'home_screen.dart';
import 'preview_screen.dart';

enum _Stage { upload, analyze, separate, finalize }

enum _ErrorType {
  upload,
  network,
  expired,
  fileTooLarge,
  unsupportedFormat,
  unreadableFile,
  processingFailed,
  generic,
}

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  final ApiService _api = ApiService();
  Timer? _timer;
  int _uploadPercent = 0;
  int _lastProgress = 0;
  int _consecutiveFailures = 0;
  bool _started = false;
  bool _connectionWarning = false;
  String? _serverStage;
  String? _serverStatus;
  _ErrorType? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _error = null;
      _uploadPercent = 0;
      _lastProgress = 0;
      _started = false;
      _serverStage = null;
      _serverStatus = null;
      _consecutiveFailures = 0;
      _connectionWarning = false;
    });
    try {
      final id = await _api.separate(
        File(widget.project.originalPath),
        SeparationMode.keepVocals,
        widget.project.quality,
        (percent) {
          if (mounted) setState(() => _uploadPercent = percent);
        },
      );
      if (!mounted) return;
      final project = widget.project.copyWith(jobId: id);
      setState(() => _started = true);
      _timer =
          Timer.periodic(const Duration(seconds: 1), (_) => _poll(project));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _errorTypeFromApi(error));
    } catch (_) {
      if (mounted) setState(() => _error = _ErrorType.generic);
    }
  }

  _ErrorType _errorTypeFromApi(ApiException error) {
    if (error.kind == ApiExceptionKind.network) return _ErrorType.upload;
    return switch (error.statusCode) {
      413 => _ErrorType.fileTooLarge,
      415 => _ErrorType.unsupportedFormat,
      422 => _ErrorType.unreadableFile,
      _ => _ErrorType.generic,
    };
  }

  Future<void> _poll(Project project) async {
    try {
      final state = await _api.status(project.jobId!);
      if (!mounted) return;
      _consecutiveFailures = 0;
      setState(() {
        _connectionWarning = false;
        _lastProgress = state.progress;
        _serverStage = state.stage;
        _serverStatus = state.status;
      });
      if (state.status == 'done') {
        _timer?.cancel();
        final complete = await _api.result(project);
        ref.read(projectsProvider.notifier).update(
              (projects) => [
                complete,
                ...projects.where((item) => item.jobId != complete.jobId),
              ],
            );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PreviewScreen(project: complete)),
        );
      } else if (state.status == 'failed') {
        _timer?.cancel();
        setState(() => _error = _ErrorType.processingFailed);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        _timer?.cancel();
        setState(() => _error = _ErrorType.expired);
        return;
      }
      _registerPollFailure(error.kind == ApiExceptionKind.network
          ? _ErrorType.network
          : _ErrorType.generic);
    } catch (_) {
      if (!mounted) return;
      _registerPollFailure(_ErrorType.generic);
    }
  }

  void _registerPollFailure(_ErrorType kind) {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= 5) {
      _timer?.cancel();
      setState(() => _error = kind);
    } else {
      setState(() => _connectionWarning = true);
    }
  }

  _Stage get _currentStage {
    if (!_started) return _Stage.upload;
    if (_serverStatus == 'done') return _Stage.finalize;
    switch (_serverStage) {
      case 'analyzing':
        return _Stage.analyze;
      case 'separating':
        return _Stage.separate;
      case 'finalizing':
        return _Stage.finalize;
    }
    // Honest coarse fallback when the backend does not send a stage.
    if (_lastProgress >= 85) return _Stage.finalize;
    if (_lastProgress >= 20) return _Stage.separate;
    return _Stage.analyze;
  }

  String _messageFor(_ErrorType type, AppLocalizations strings) =>
      switch (type) {
        _ErrorType.upload => strings.uploadFailed,
        _ErrorType.network => strings.networkFailed,
        _ErrorType.expired => strings.jobExpired,
        _ErrorType.fileTooLarge => strings.fileTooLarge,
        _ErrorType.unsupportedFormat => strings.unsupportedFormat,
        _ErrorType.unreadableFile => strings.unreadableFile,
        _ErrorType.processingFailed => strings.processingFailed,
        _ErrorType.generic => strings.failedGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final error = _error;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: error != null
                ? _buildError(context, strings, error)
                : _buildProcessing(context, strings),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(BuildContext context, AppLocalizations strings) {
    final showUploadPercent =
        !_started && _uploadPercent > 0 && _uploadPercent < 100;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Waveform(),
        const SizedBox(height: 32),
        _StageTimeline(
          current: _currentStage,
          titleFor: (stage) => switch (stage) {
            _Stage.upload => showUploadPercent
                ? strings.uploadPercent(_uploadPercent)
                : strings.stageUpload,
            _Stage.analyze => strings.stageAnalyze,
            _Stage.separate => strings.stageSeparate,
            _Stage.finalize => strings.stageFinalize,
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: LinearProgressIndicator(
            value: _started
                ? null
                : (_uploadPercent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.project.isVideo) ...[
          Text(
            strings.longVideoNote,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
        ],
        if (_connectionWarning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StatusDot(color: AppColors.warning, size: 7),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  strings.connectionLost,
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildError(
      BuildContext context, AppLocalizations strings, _ErrorType error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 52, color: AppColors.errorText),
        const SizedBox(height: 16),
        Text(strings.failedTitle,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          _messageFor(error, strings),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.retry),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.back),
        ),
      ],
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.current, required this.titleFor});

  final _Stage current;
  final String Function(_Stage) titleFor;

  static const stages = _Stage.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          _StageRow(
            state: stages[i].index < current.index
                ? _StageState.done
                : stages[i] == current
                    ? _StageState.active
                    : _StageState.upcoming,
            title: titleFor(stages[i]),
          ),
          if (i < stages.length - 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Container(
                width: 2,
                height: 14,
                color: AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

enum _StageState { done, active, upcoming }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.state,
    required this.title,
  });

  final _StageState state;
  final String title;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme;
    final style = switch (state) {
      _StageState.done =>
        base.bodyMedium?.copyWith(color: AppColors.secondaryText),
      _StageState.active => base.bodyLarge?.copyWith(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w800,
          fontSize: 15),
      _StageState.upcoming =>
        base.bodyMedium?.copyWith(color: AppColors.helperText),
    };
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Center(
            child: switch (state) {
              _StageState.done => const StatusDot(color: AppColors.success),
              _StageState.active =>
                const StatusDot(color: AppColors.warning, size: 10),
              _StageState.upcoming => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.6),
                  ),
                ),
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: style)),
      ],
    );
  }
}
