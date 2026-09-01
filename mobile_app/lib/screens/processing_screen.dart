import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/waveform.dart';
import 'preview_screen.dart';
class ProcessingScreen extends StatefulWidget { const ProcessingScreen({super.key, required this.project, required this.mode}); final Project project; final SeparationMode mode; @override State<ProcessingScreen> createState() => _ProcessingScreenState(); }
class _ProcessingScreenState extends State<ProcessingScreen> { final api = ApiService(); Timer? timer; int progress = 0; String? error; bool started = false;
  @override void initState() { super.initState(); start(); }
  Future<void> start() async { try { final id = await api.separate(File(widget.project.originalPath), widget.mode, (p) { if (mounted) setState(() => progress = p ~/ 4); }); if (!mounted) return; final project = widget.project.copyWith(jobId: id); setState(() => started = true); timer = Timer.periodic(const Duration(seconds: 1), (_) => poll(project)); } catch (e) { if (mounted) setState(() => error = e.toString()); } }
  Future<void> poll(Project project) async { try { final state = await api.status(project.jobId!); if (!mounted) return; setState(() => progress = state.progress); if (state.status == 'done') { timer?.cancel(); final complete = await api.result(project); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: complete))); } else if (state.status == 'failed') { timer?.cancel(); setState(() => error = 'فشلت المعالجة. تحقق من الملف وحاول مرة أخرى.'); } } catch (e) { timer?.cancel(); if (mounted) setState(() => error = e.toString()); } }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: error != null ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 52), const SizedBox(height: 16), Text(error!, textAlign: TextAlign.center), TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع'))]) : Column(mainAxisSize: MainAxisSize.min, children: [const Waveform(), const SizedBox(height: 36), SizedBox(width: 132, height: 132, child: CircularProgressIndicator(value: started ? progress / 100 : null, strokeWidth: 10)), const SizedBox(height: 20), Text('$progress%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)), const Text('جارٍ فصل الصوت، قد يستغرق الأمر بضع دقائق.')])))); }
