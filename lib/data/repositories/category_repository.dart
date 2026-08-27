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

  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
