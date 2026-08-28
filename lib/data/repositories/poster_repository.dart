import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart' as drift;

final posterRepositoryProvider = Provider<PosterRepository>((ref) {
  throw UnimplementedError(
    'posterRepositoryProvider must be overridden with a valid instance',
  );
});

class PosterRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  PosterRepository(this._db);

  Stream<List<PosterModel>> watchPosters() {
    return (_db.select(_db.posters)..orderBy([
          (t) => drift.OrderingTerm(
            expression: t.createdAt,
            mode: drift.OrderingMode.desc,
          ),
        ]))
        .watch();
  }

  Stream<List<PosterModel>> watchPostersByCategory(String categoryId) {
    return (_db.select(_db.posters)
          ..where((p) => p.categoryId.equals(categoryId))
          ..orderBy([
            (t) => drift.OrderingTerm(
              expression: t.createdAt,
              mode: drift.OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<void> addPoster({
    required String imagePath,
    required String categoryId,
    String? title,
  }) async {
    final now = DateTime.now();
    await _db
        .into(_db.posters)
        .insert(
          PostersCompanion.insert(
            id: _uuid.v4(),
            imagePath: imagePath,
            categoryId: categoryId,
            title: drift.Value(title),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updatePoster({
    required String id,
    String? title,
    String? categoryId,
  }) async {
    final now = DateTime.now();

    var companion = PostersCompanion(updatedAt: drift.Value(now));

    if (title != null) {
      companion = companion.copyWith(title: drift.Value(title));
    }
    if (categoryId != null) {
      companion = companion.copyWith(categoryId: drift.Value(categoryId));
    }

    await (_db.update(
      _db.posters,
    )..where((p) => p.id.equals(id))).write(companion);
  }

  Future<void> deletePoster(String id, String imagePath) async {
    // 1. Delete from database
    await (_db.delete(_db.posters)..where((p) => p.id.equals(id))).go();

    // 2. Delete file from local storage
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore file deletion errors, just log them if needed
    }
  }

  Future<List<PosterModel>> searchPosters(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    final lowercaseQuery = '%${query.toLowerCase()}%';
    return await (_db.select(
      _db.posters,
    )..where((p) => p.title.lower().like(lowercaseQuery))).get();
  }
}
