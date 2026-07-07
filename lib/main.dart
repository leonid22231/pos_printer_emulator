import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/locale_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/windows_theme.dart';
import 'ui/widgets/app_lifecycle_guard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: PosEmulatorRoot(),
    ),
  );
}

class PosEmulatorRoot extends ConsumerWidget {
  const PosEmulatorRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = ref.watch(stringsProvider);

    return MaterialApp(
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: WindowsTheme.materialTheme(),
      scrollBehavior: const NoScrollbarScrollBehavior(),
      home: const AppLifecycleGuard(child: HomeScreen()),
      key: ValueKey(locale.code),
    );
  }
}
