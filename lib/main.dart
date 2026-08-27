import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'data/database/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/poster_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Database
  final db = AppDatabase();
  final categoryRepo = CategoryRepository(db);
  final posterRepo = PosterRepository(db);

  runApp(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categoryRepo),
        posterRepositoryProvider.overrideWithValue(posterRepo),
        // Add prefs provider later if needed
      ],
      child: const EGApp(),
    ),
  );
}

class EGApp extends ConsumerWidget {
  const EGApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'EG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
