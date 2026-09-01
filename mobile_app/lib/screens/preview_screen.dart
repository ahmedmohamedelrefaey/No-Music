import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../models.dart';
import '../services/integrations.dart';
class PreviewScreen extends StatefulWidget { const PreviewScreen({super.key, required this.project}); final Project project; @override State<PreviewScreen> createState() => _PreviewScreenState(); }
class _PreviewScreenState extends State<PreviewScreen> { final player = AudioPlayer(); bool vocals = true;
  Future<void> play() async { final source = vocals ? widget.project.vocalsUrl : widget.project.instrumentalUrl; if (player.playing) { await player.pause(); } else { await player.setUrl(source!); await player.play(); } if (mounted) setState(() {}); }
  @override void dispose() { player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المعاينة')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('استمع إلى النتيجة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('الصوت البشري')), ButtonSegment(value: false, label: Text('الموسيقى'))], selected: {vocals}, onSelectionChanged: (v) { player.stop(); setState(() => vocals = v.first); }),
        const SizedBox(height: 24),
        Expanded(child: Center(child: IconButton.filled(iconSize: 58, onPressed: play, icon: Icon(player.playing ? Icons.pause : Icons.play_arrow)))),
        FilledButton.icon(onPressed: () { Integrations.track('export_completed'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف جاهز للتصدير من رابط النتيجة.'))); }, icon: const Icon(Icons.download), label: const Text('تصدير')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => Share.share(vocals ? widget.project.vocalsUrl! : widget.project.instrumentalUrl!), icon: const Icon(Icons.share_outlined), label: const Text('مشاركة')),
      ]),
    ),
  );
}
