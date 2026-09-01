import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../services/integrations.dart';
import 'import_screen.dart';
import 'settings_screen.dart';
final projectsProvider = StateProvider<List<Project>>((_) => const []);
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('MuteMusic AI'), actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined))]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('استخرج الصوت البشري، واترك الموسيقى خلفك.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(62)), onPressed: () { Integrations.track('import_started'); Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())); }, icon: const Icon(Icons.add_circle_outline), label: const Text('استيراد فيديو أو صوت')),
          const SizedBox(height: 30),
          const Text('المشاريع الأخيرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: projects.isEmpty ? const Center(child: Text('لم تبدأ أي مشروع بعد.')) : ListView.separated(itemCount: projects.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) => Card(child: ListTile(leading: Icon(projects[i].isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined), title: Text(projects[i].name), subtitle: Text(projects[i].jobId ?? 'جاهز للرفع'))))),
        ]),
      ),
    );
  }
}
