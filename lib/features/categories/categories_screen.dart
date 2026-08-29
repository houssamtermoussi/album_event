import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/poster_repository.dart';
import '../../widgets/category_card.dart';
import 'create_category_sheet.dart';

final categoriesStreamProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
      final repo = ref.watch(categoryRepositoryProvider);
      return repo.watchCategories();
    });

final allPostersProvider = StreamProvider.autoDispose<List<PosterModel>>((ref) {
  final repo = ref.watch(posterRepositoryProvider);
  return repo.watchPosters();
});

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateSheet(BuildContext context, {String? id, String? name}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          CreateCategorySheet(existingId: id, initialName: name),
    );
  }

  void _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: const Text(
          'Cette action supprimera également toutes les affiches de cette catégorie. Elle est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoryRepositoryProvider).deleteCategory(category.id);
              Navigator.of(context).pop();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPosterOptions(
    BuildContext context,
    WidgetRef ref,
    PosterModel poster,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletePoster(context, ref, poster);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePoster(
    BuildContext context,
    WidgetRef ref,
    PosterModel poster,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'affiche ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(posterRepositoryProvider)
                  .deletePoster(poster.id, poster.imagePath);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, PosterModel poster) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImagePage(poster: poster),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allPostersAsync = ref.watch(allPostersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.s16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une affiche par titre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(allPostersAsync)
                : _buildCategoriesList(categoriesAsync, allPostersAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(AsyncValue<List<CategoryModel>> categoriesAsync, AsyncValue<List<PosterModel>> allPostersAsync) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aucune catégorie'),
                const SizedBox(height: AppSizes.s12),
                const Text(
                  'Créez votre première catégorie\npour commencer à organiser vos affiches.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.s24),
                ElevatedButton(
                  onPressed: () => _showCreateSheet(context),
                  child: const Text('+ Créer une catégorie'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final posterCount = allPostersAsync.value?.where((p) => p.categoryId == category.id).length ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.s8),
              child: CategoryCard(
                category: category,
                posterCount: posterCount,
                onTap: () {
                  context.push('/category/${category.id}');
                },
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Modifier le nom'),
                            onTap: () {
                              Navigator.pop(context);
                              _showCreateSheet(
                                context,
                                id: category.id,
                                name: category.name,
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            title: const Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _deleteCategory(context, ref, category);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<PosterModel>> allPostersAsync) {
    return allPostersAsync.when(
      data: (posters) {
        final filteredPosters = posters.where((p) {
          final title = p.title?.toLowerCase() ?? '';
          return title.contains(_searchQuery.toLowerCase());
        }).toList();

        if (filteredPosters.isEmpty) {
          return const Center(child: Text('Aucun résultat trouvé'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSizes.s16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSizes.s12,
            mainAxisSpacing: AppSizes.s12,
            childAspectRatio: 0.75, // format portrait
          ),
          itemCount: filteredPosters.length,
          itemBuilder: (context, index) {
            final poster = filteredPosters[index];
            return GestureDetector(
              onTap: () => _openFullscreen(context, poster),
              onLongPress: () => _showPosterOptions(context, ref, poster),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    child: Image.file(
                      File(poster.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? AppColors.grey100
                              : AppColors.grey900,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.grey600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (poster.title != null && poster.title!.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(AppSizes.radiusMedium),
                            bottomRight: Radius.circular(AppSizes.radiusMedium),
                          ),
                        ),
                        child: Text(
                          poster.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }
}

// ─── Page plein écran ────────────────────────────────────────────────────────
class _FullscreenImagePage extends StatelessWidget {
  final PosterModel poster;
  const _FullscreenImagePage({required this.poster});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: poster.title != null && poster.title!.isNotEmpty
            ? Text(
                poster.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(
            File(poster.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (ctx, error, stack) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
