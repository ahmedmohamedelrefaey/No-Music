import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import 'processing_screen.dart';
class ImportScreen extends StatefulWidget { const ImportScreen({super.key}); @override State<ImportScreen> createState() => _ImportScreenState(); }
class _ImportScreenState extends State<ImportScreen> { File? file; SeparationMode mode = SeparationMode.keepVocals;
  Future<void> pick() async { final result = await FilePicker.platform.pickFiles(type: FileType.media); if (result?.files.single.path != null) setState(() => file = File(result!.files.single.path!)); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('استيراد')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(onPressed: pick, icon: const Icon(Icons.folder_open), label: Text(file == null ? 'اختيار ملف' : file!.uri.pathSegments.last)),
        const SizedBox(height: 24),
        SegmentedButton<SeparationMode>(segments: const [ButtonSegment(value: SeparationMode.keepVocals, label: Text('الصوت البشري')), ButtonSegment(value: SeparationMode.keepMusic, label: Text('الموسيقى'))], selected: {mode}, onSelectionChanged: (value) => setState(() => mode = value.first)),
        const Spacer(),
        FilledButton(onPressed: file == null ? null : () { final path = file!.path.toLowerCase(); Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessingScreen(project: Project(name: file!.uri.pathSegments.last, originalPath: file!.path, isVideo: ['.mp4', '.mov', '.mkv', '.avi', '.webm'].any(path.endsWith)), mode: mode))); }, child: const Text('بدء المعالجة')),
      ]),
    ),
  );
}
