import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_sizes.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../widgets/category_card.dart';
import 'create_category_sheet.dart';

final categoriesStreamProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
      final repo = ref.watch(categoryRepositoryProvider);
      return repo.watchCategories();
    });

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

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
      body: categoriesAsync.when(
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
            padding: const EdgeInsets.all(AppSizes.s16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return CategoryCard(
                category: category,
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
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}
