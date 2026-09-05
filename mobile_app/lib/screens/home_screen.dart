import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/integrations.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import 'processing_screen.dart';
import 'settings_screen.dart';

final projectsProvider = StateProvider<List<Project>>((_) => const []);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  File? _file;
  ProcessingQuality _quality = ProcessingQuality.deep;

  Future<void> _pickFile() async {
    await HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _file = File(path));
  }

  void _startProcessing() {
    final file = _file;
    if (file == null) return;
    final path = file.path.toLowerCase();
    final isVideo =
        ['.mp4', '.mov', '.mkv', '.avi', '.webm'].any(path.endsWith);
    Integrations.track('import_started');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          project: Project(
            name: file.uri.pathSegments.last,
            originalPath: file.path,
            isVideo: isVideo,
            quality: _quality,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x447C3AED),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MuteMusic AI',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: strings.settings,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              strings.heroTitle,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 10),
            Text(
              strings.heroSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            _UploadCard(
              file: _file,
              title: strings.uploadPrompt,
              formats: strings.supportedFormats,
              selectedFileLabel: strings.selectedFile,
              changeFileLabel: strings.chooseAnotherFile,
              onTap: _pickFile,
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormatChip('MP3'),
                _FormatChip('WAV'),
                _FormatChip('MP4'),
                _FormatChip('MOV'),
              ],
            ),
            const SizedBox(height: 24),
            _QualitySelector(
              selected: _quality,
              strings: strings,
              onSelect: (quality) => setState(() => _quality = quality),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _file == null ? null : _startProcessing,
              icon: const Icon(Icons.music_off_rounded),
              label: Text(strings.removeMusic),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 16, color: AppColors.primaryLight),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    strings.autoDeleteNotice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              strings.recentProjects,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (projects.isEmpty)
              _EmptyProjectsCard(
                title: strings.noRecentProjects,
                subtitle: strings.startFirstProject,
              )
            else
              ...projects.map(
                (project) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentProjectCard(
                    project: project,
                    completeLabel: strings.complete,
                    processingLabel: strings.inProgress,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.selected,
    required this.strings,
    required this.onSelect,
  });

  final ProcessingQuality selected;
  final AppLocalizations strings;
  final ValueChanged<ProcessingQuality> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.qualityTitle,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QualityCard(
                  title: strings.qualityFast,
                  description: strings.qualityFastDesc,
                  selected: selected == ProcessingQuality.fast,
                  onTap: () => onSelect(ProcessingQuality.fast),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QualityCard(
                  title: strings.qualityDeep,
                  description: strings.qualityDeepDesc,
                  aiTag: strings.qualityDeepTag,
                  selected: selected == ProcessingQuality.deep,
                  onTap: () => onSelect(ProcessingQuality.deep),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline,
                  size: 14, color: AppColors.helperText),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                selected == ProcessingQuality.deep
                    ? '${strings.qualityHonestNote} ${strings.qualityDeepNote}'
                    : strings.qualityHonestNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.aiTag,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? aiTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryText.withValues(alpha: .92)
                      : AppColors.helperText,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              if (aiTag != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: selected ? Colors.white : AppColors.primaryLight,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        aiTag!,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primaryText
                              : AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.file,
    required this.title,
    required this.formats,
    required this.selectedFileLabel,
    required this.changeFileLabel,
    required this.onTap,
  });

  final File? file;
  final String title;
  final String formats;
  final String selectedFileLabel;
  final String changeFileLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFile = file != null;
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _DashedRoundedBorderPainter(
          color: hasFile ? scheme.primary : AppColors.border,
        ),
        child: Material(
          color: hasFile
              ? scheme.primary.withValues(alpha: .08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      hasFile
                          ? Icons.check_circle_outline_rounded
                          : Icons.video_file_outlined,
                      color: hasFile ? const Color(0xFF10B981) : scheme.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    hasFile ? selectedFileLabel : title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasFile ? file!.uri.pathSegments.last : formats,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.helperText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 8),
                    Text(
                      changeFileLabel,
                      style: const TextStyle(
                          color: AppColors.primaryLight, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText),
        ),
      );
}

class _EmptyProjectsCard extends StatelessWidget {
  const _EmptyProjectsCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined,
              size: 30, color: scheme.onSurfaceVariant),
          const SizedBox(height: 9),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  const _RecentProjectCard({
    required this.project,
    required this.completeLabel,
    required this.processingLabel,
  });

  final Project project;
  final String completeLabel;
  final String processingLabel;

  @override
  Widget build(BuildContext context) {
    final isComplete = project.vocalsUrl != null;
    final statusColor = isComplete ? AppColors.success : AppColors.warning;
    final statusTextColor =
        isComplete ? AppColors.successText : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              project.isVideo ? Icons.movie_outlined : Icons.audiotrack_rounded,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(color: statusColor, size: 7),
                const SizedBox(width: 6),
                Text(
                  isComplete ? completeLabel : processingLabel,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 5).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
