import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/categories/category_detail_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/categories',
    redirect: (context, state) {
      // Redirige la racine vers les catégories
      if (state.matchedLocation == '/') return '/categories';
      return null;
    },
    routes: [
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) {
          final categoryId = state.pathParameters['id']!;
          return CategoryDetailScreen(categoryId: categoryId);
        },
      ),
    ],
  );
});
