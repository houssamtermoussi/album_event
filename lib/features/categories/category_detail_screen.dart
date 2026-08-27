import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/poster_repository.dart';

// Stream des affiches pour une catégorie donnée
final categoryPostersProvider =
    StreamProvider.autoDispose.family<List<PosterModel>, String>((ref, categoryId) {
  final repo = ref.watch(posterRepositoryProvider);
  return repo.watchPostersByCategory(categoryId);
});

// Données de la catégorie (nom, etc.)
final singleCategoryProvider =
    FutureProvider.autoDispose.family<CategoryModel, String>((ref, id) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getCategory(id);
});

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  // ─── Ajout d'une affiche via galerie ────────────────────────────────────────
  Future<void> _addPoster(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    try {
      await ref.read(posterRepositoryProvider).addPoster(
            imagePath: image.path,
            categoryId: categoryId,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ajout : $e')),
        );
      }
    }
  }

  // ─── Menu contextuel d'une affiche ──────────────────────────────────────────
  void _showPosterOptions(BuildContext context, WidgetRef ref, PosterModel poster) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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

  // ─── Confirmation de suppression d'une affiche ───────────────────────────────
  void _confirmDeletePoster(BuildContext context, WidgetRef ref, PosterModel poster) {
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
              ref.read(posterRepositoryProvider).deletePoster(poster.id, poster.imagePath);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(singleCategoryProvider(categoryId));
    final postersAsync = ref.watch(categoryPostersProvider(categoryId));

    return Scaffold(
      appBar: AppBar(
        title: categoryAsync.when(
          data: (cat) => Text(cat.name),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const Text('Catégorie'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPoster(context, ref),
        tooltip: 'Ajouter une affiche',
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
      body: postersAsync.when(
        data: (posters) {
          if (posters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: AppSizes.s64,
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppColors.grey300
                        : AppColors.grey800,
                  ),
                  const SizedBox(height: AppSizes.s16),
                  Text(
                    'Aucune affiche',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.s8),
                  Text(
                    'Appuyez sur + pour ajouter une affiche.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppSizes.s16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.s12,
              mainAxisSpacing: AppSizes.s12,
              childAspectRatio: 0.75, // format portrait
            ),
            itemCount: posters.length,
            itemBuilder: (context, index) {
              final poster = posters[index];
              return GestureDetector(
                onLongPress: () => _showPosterOptions(context, ref, poster),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  child: Image.file(
                    File(poster.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stack) => Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppColors.grey100
                            : AppColors.grey900,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: AppColors.grey600),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
      ),
    );
  }
}
