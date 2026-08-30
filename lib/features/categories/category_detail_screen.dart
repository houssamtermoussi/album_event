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
    if (!context.mounted) return;

    // Demander le titre avant d'enregistrer
    final title = await _showTitleDialog(context);
    if (title == null) return; // L'utilisateur a annulé

    try {
      await ref
          .read(posterRepositoryProvider)
          .addPoster(
            imagePath: image.path,
            categoryId: widget.categoryId,
            title: title.trim().isEmpty ? null : title.trim(),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur lors de l\'ajout : $e')));
      }
    }
  }

  // ─── Dialog pour saisir le titre ────────────────────────────────────────────
  Future<String?> _showTitleDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Titre de l\'image'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // ─── Plein écran ─────────────────────────────────────────────────────────────
  void _openFullscreen(
    BuildContext context,
    List<PosterModel> posters,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImagePage(
          posters: posters,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ─── Renommer une affiche ────────────────────────────────────────────────────
  Future<void> _renamePoster(
    BuildContext context,
    WidgetRef ref,
    PosterModel poster,
  ) async {
    final controller = TextEditingController(text: poster.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le titre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Titre de la photo',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newTitle == null) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(posterRepositoryProvider)
          .updatePoster(id: poster.id, title: newTitle.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la modification : $e')),
        );
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier le titre'),
              onTap: () {
                Navigator.pop(ctx);
                _renamePoster(context, ref, poster);
              },
            ),
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
                            onTap: () => _openFullscreen(
                              context,
                              filteredPosters,
                              index,
                            ),
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

// ─── Page plein écran avec défilement ───────────────────────────────────────
class _FullscreenImagePage extends ConsumerStatefulWidget {
  final List<PosterModel> posters;
  final int initialIndex;

  const _FullscreenImagePage({
    required this.posters,
    required this.initialIndex,
  });

  @override
  ConsumerState<_FullscreenImagePage> createState() =>
      _FullscreenImagePageState();
}

class _FullscreenImagePageState extends ConsumerState<_FullscreenImagePage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PosterModel get _currentPoster => widget.posters[_currentIndex];

  Future<void> _renameCurrentPoster(BuildContext context) async {
    final controller =
        TextEditingController(text: _currentPoster.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le titre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Titre de la photo',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newTitle == null) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(posterRepositoryProvider)
          .updatePoster(id: _currentPoster.id, title: newTitle.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la modification : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // On écoute le stream pour avoir les titres à jour en temps réel
    final postersAsync = ref.watch(
      categoryPostersProvider(_currentPoster.categoryId),
    );

    // Résoudre la liste live (pour le titre actualisé)
    final livePosters = postersAsync.valueOrNull ?? widget.posters;
    // Trouver le poster courant dans la liste live via son id
    final livePoster = livePosters.firstWhere(
      (p) => p.id == _currentPoster.id,
      orElse: () => _currentPoster,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        title: livePoster.title != null && livePoster.title!.isNotEmpty
            ? Text(
                livePoster.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Modifier le titre',
            onPressed: () => _renameCurrentPoster(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.posters.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final poster = widget.posters[index];
              return InteractiveViewer(
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
              );
            },
          ),
          // Indicateur de position (ex: 2 / 5)
          if (widget.posters.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.posters.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
