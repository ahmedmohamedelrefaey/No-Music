import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/integrations.dart';
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
          ),
          mode: SeparationMode.keepVocals,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final projects = ref.watch(projectsProvider);
    final scheme = Theme.of(context).colorScheme;

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
              style: const TextStyle(
                fontSize: 30,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.heroSubtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.6,
              ),
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
            FilledButton.icon(
              onPressed: _file == null ? null : _startProcessing,
              icon: const Icon(Icons.music_off_rounded),
              label: Text(strings.removeMusic),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    strings.autoDeleteNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              strings.recentProjects,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
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
          color:
              hasFile ? scheme.primary : scheme.outline.withValues(alpha: .55),
        ),
        child: Material(
          color: hasFile
              ? scheme.primary.withValues(alpha: .08)
              : const Color(0xFF1A1A1A),
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasFile ? file!.uri.pathSegments.last : formats,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 8),
                    Text(
                      changeFileLabel,
                      style: TextStyle(color: scheme.primary, fontSize: 12),
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
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
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
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined,
              size: 30, color: scheme.onSurfaceVariant),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
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
    final statusColor =
        isComplete ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              project.isVideo ? Icons.movie_outlined : Icons.audiotrack_rounded,
              color: const Color(0xFFA78BFA),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isComplete ? completeLabel : processingLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
