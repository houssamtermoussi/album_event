import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/category_repository.dart';
import '../../core/constants/app_sizes.dart';

class CreateCategorySheet extends ConsumerStatefulWidget {
  final String? existingId;
  final String? initialName;

  const CreateCategorySheet({super.key, this.existingId, this.initialName});

  @override
  ConsumerState<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<CreateCategorySheet> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (widget.existingId != null) {
        await repo.updateCategory(widget.existingId!, name);
      } else {
        await repo.addCategory(name);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.s24,
        right: AppSizes.s24,
        top: AppSizes.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existingId != null ? 'Modifier la catégorie' : 'Nouvelle catégorie',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.s24),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom de la catégorie',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSizes.s32),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.existingId != null ? 'Enregistrer' : 'Créer'),
          ),
          const SizedBox(height: AppSizes.s24),
        ],
      ),
    );
  }
}
