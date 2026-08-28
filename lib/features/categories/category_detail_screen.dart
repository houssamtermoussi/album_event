import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/poster_repository.dart';

// Stream des affiches pour une catégorie donnée
final categoryPostersProvider = StreamProvider.autoDispose
    .family<List<PosterModel>, String>((ref, categoryId) {
      final repo = ref.watch(posterRepositoryProvider);
      return repo.watchPostersByCategory(categoryId);
    });

// Données de la catégorie (nom, etc.)
final singleCategoryProvider = FutureProvider.autoDispose
    .family<CategoryModel, String>((ref, id) {
      final repo = ref.watch(categoryRepositoryProvider);
      return repo.getCategory(id);
    });

class CategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Ajout d'une affiche via galerie ────────────────────────────────────────
  Future<void> _addPoster(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    try {
      await ref
          .read(posterRepositoryProvider)
          .addPoster(imagePath: image.path, categoryId: widget.categoryId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur lors de l\'ajout : $e')));
      }
    }
  }

  // ─── Menu contextuel d'une affiche ──────────────────────────────────────────
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
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = XFile(poster.imagePath);
                await Share.shareXFiles([file], text: poster.title);
              },
            ),
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

  // ─── Confirmation de suppression d'une affiche ───────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(singleCategoryProvider(widget.categoryId));
    final postersAsync = ref.watch(categoryPostersProvider(widget.categoryId));

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
          final filteredPosters = posters.where((p) {
            final title = p.title?.toLowerCase() ?? '';
            return title.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.s16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par titre...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
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
                child: filteredPosters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: AppSizes.s64,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.grey300
                                  : AppColors.grey800,
                            ),
                            const SizedBox(height: AppSizes.s16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucune affiche'
                                  : 'Aucun résultat',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSizes.s8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Appuyez sur + pour ajouter une affiche.'
                                  : 'Aucune affiche ne correspond à votre recherche.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSizes.s16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSizes.s12,
                              mainAxisSpacing: AppSizes.s12,
                              childAspectRatio: 0.75, // format portrait
                            ),
                        itemCount: filteredPosters.length,
                        itemBuilder: (context, index) {
                          final poster = filteredPosters[index];
                          return GestureDetector(
                            onLongPress: () =>
                                _showPosterOptions(context, ref, poster),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMedium,
                                  ),
                                  child: Image.file(
                                    File(poster.imagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, error, stack) =>
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.light
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
                                if (poster.title != null &&
                                    poster.title!.isNotEmpty)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(
                                            AppSizes.radiusMedium,
                                          ),
                                          bottomRight: Radius.circular(
                                            AppSizes.radiusMedium,
                                          ),
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
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
      ),
    );
  }
}
