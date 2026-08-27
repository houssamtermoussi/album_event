import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  throw UnimplementedError('categoryRepositoryProvider must be overridden with a valid instance');
});

class CategoryRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CategoryRepository(this._db);

  Stream<List<CategoryModel>> watchCategories() {
    return _db.select(_db.categories).watch();
  }

  Future<List<CategoryModel>> getCategories() {
    return _db.select(_db.categories).get();
  }

  Future<CategoryModel> getCategory(String id) async {
    return await (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> addCategory(String name) async {
    final now = DateTime.now();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: _uuid.v4(),
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateCategory(String id, String newName) async {
    final now = DateTime.now();
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: drift.Value(newName),
        updatedAt: drift.Value(now),
      ),
    );
  }

  /// Supprime la catégorie ET toutes ses affiches (+ leurs fichiers sur disque).
  Future<void> deleteCategory(String id) async {
    // 1. Récupérer toutes les affiches de la catégorie
    final posters = await (_db.select(_db.posters)
          ..where((p) => p.categoryId.equals(id)))
        .get();

    // 2. Supprimer les fichiers image associés
    for (final poster in posters) {
      try {
        final file = File(poster.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // On continue même si un fichier ne peut pas être supprimé
      }
    }

    // 3. Supprimer les affiches de la base
    await (_db.delete(_db.posters)..where((p) => p.categoryId.equals(id))).go();

    // 4. Supprimer la catégorie
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
