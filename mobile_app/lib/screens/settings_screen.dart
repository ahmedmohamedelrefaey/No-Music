import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/integrations.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final current = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(strings.language,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text(strings.language),
              trailing: DropdownButton<Locale>(
                value: current,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surface,
                items: const [
                  DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                ],
                onChanged: (locale) {
                  if (locale != null) {
                    ref.read(localeProvider.notifier).state = locale;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(strings.privacyTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.delete_sweep_outlined,
                    size: 20, color: AppColors.primaryLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.privacyAutoDelete,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(strings.settingsIntegrations,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('RevenueCat'),
                  subtitle: Text(Integrations.revenueCatEnabled
                      ? strings.statusConfigured
                      : strings.statusRequiresCredentials),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                    title: const Text('Supabase'),
                    subtitle: Text(strings.statusRequiresCredentials)),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                    title: const Text('Sentry'),
                    subtitle: Text(strings.statusDisabled)),
                ListTile(
                    title: const Text('Firebase Analytics'),
                    subtitle: Text(strings.statusDisabled)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
