// lib/src/presentation/screens/all_tags_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';

class AllTagsScreen extends StatefulWidget {
  const AllTagsScreen({super.key});

  @override
  State<AllTagsScreen> createState() => _AllTagsScreenState();
}

class _AllTagsScreenState extends State<AllTagsScreen> {
  Map<String, int> tagPhotoCounts = {};
  bool _manageCategoriesExpanded = true;

  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(LoadTags());
    context.read<PhotoBloc>().add(LoadPhotos());
    context.read<TagCategoryBloc>().add(const LoadTagCategories());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags & Categories'),
        actions: [
          IconButton(
            tooltip: 'Add new tag',
            icon: const Icon(Iconsax.add),
            onPressed: () => TagsHelpers.showAddTagDialog(context),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<TagBloc, TagState>(
            listener: (context, state) {
              if (state is TagError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
          BlocListener<PhotoBloc, PhotoState>(
            listener: (context, state) {
              if (state is PhotoError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
          BlocListener<TagCategoryBloc, TagCategoryState>(
            listener: (context, state) {
              if (state is TagCategoryError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
        ],
        child: BlocBuilder<TagCategoryBloc, TagCategoryState>(
          builder: (context, catState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (context, tagState) {
                return BlocBuilder<PhotoBloc, PhotoState>(
                  builder: (context, photoState) {
                    final bool loading = tagState is TagLoading ||
                        photoState is PhotoLoading ||
                        catState is TagCategoryLoading;

                    if (loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (tagState is! TagLoaded ||
                        photoState is! PhotoLoaded ||
                        (catState is! TagCategoryLoaded &&
                            catState is! TagCategoryInitial)) {
                      return const Center(child: Text('Failed to load data.'));
                    }

                    final tags = (tagState as TagLoaded).tags;
                    final photos = (photoState as PhotoLoaded).photos;
                    final categories = catState is TagCategoryLoaded
                        ? catState.categories
                        : <TagCategory>[];

                    // Подсчёт количества фото на тег
                    tagPhotoCounts = _computeTagPhotoCounts(tags, photos);

                    // Группировка тегов по категориям
                    final Map<String?, List<Tag>> grouped = {};
                    for (final t in tags) {
                      grouped.putIfAbsent(t.tagCategoryId, () => []).add(t);
                    }

                    // Сортировка тегов внутри группы по кол-ву фото (desc), затем по имени
                    for (final entry in grouped.entries) {
                      entry.value.sort((a, b) {
                        final ca = tagPhotoCounts[a.id] ?? 0;
                        final cb = tagPhotoCounts[b.id] ?? 0;
                        final byCount = cb.compareTo(ca);
                        return byCount != 0
                            ? byCount
                            : a.name
                                .toLowerCase()
                                .compareTo(b.name.toLowerCase());
                      });
                    }

                    // Порядок секций: категории по sortOrder, затем «Без категории»
                    final List<_Section> sections = [
                      for (final c in categories)
                        _Section(
                          title: c.name,
                          categoryId: c.id,
                          tags: grouped[c.id] ?? const [],
                        ),
                      _Section(
                        title: 'No Category',
                        categoryId: null,
                        tags: grouped[null] ?? const [],
                      ),
                    ];

                    return CustomScrollView(
                      slivers: [
                        // --- Секция управления категориями (CRUD + Reorder) ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: _ManageCategoriesSection(
                              expanded: _manageCategoriesExpanded,
                              categories: categories,
                              onExpandedChanged: (v) =>
                                  setState(() => _manageCategoriesExpanded = v),
                            ),
                          ),
                        ),

                        // --- Секции тегов по категориям ---
                        for (final s in sections) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                              child: Row(
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (s.tags.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  '— Empty —',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: s.tags.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Colors.white12,
                              ),
                              itemBuilder: (_, i) {
                                final tag = s.tags[i];
                                final photoCount = tagPhotoCounts[tag.id] ?? 0;
                                return _TagListTile(
                                  tag: tag,
                                  photoCount: photoCount,
                                );
                              },
                            ),
                        ],
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 48),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Подсчёт количества фотографий для каждого тега
  Map<String, int> _computeTagPhotoCounts(List<Tag> tags, List photos) {
    final Map<String, int> counts = {for (final t in tags) t.id: 0};
    for (final photo in photos) {
      for (final tagId in (photo.tagIds as List<String>)) {
        if (counts.containsKey(tagId)) {
          counts[tagId] = (counts[tagId] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  int _categoryOrder(List<TagCategory> cats, String id) {
    final idx = cats.indexWhere((c) => c.id == id);
    return idx >= 0 ? cats[idx].sortOrder : -1;
  }
}

/// Вспомогательная структура секции
class _Section {
  final String title;
  final String? categoryId;
  final List<Tag> tags;
  _Section({required this.title, required this.categoryId, required this.tags});
}

/// Элемент списка тега с назначением категории
/// Элемент списка тега с назначением категории
class _TagListTile extends StatelessWidget {
  final Tag tag;
  final int photoCount;

  const _TagListTile({
    super.key,
    required this.tag,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    final tagBloc = context.read<TagBloc>();
    final catState = context.watch<TagCategoryBloc>().state;

    final categories =
        catState is TagCategoryLoaded ? catState.categories : <TagCategory>[];

    final isCompact = MediaQuery.of(context).size.width < 600;

    // Общий dropdown категорий, чтобы не дублировать логику
    final categoryDropdown = _CategoryDropdown(
      value: tag.tagCategoryId,
      categories: categories,
      onChanged: (newCatId) {
        final updated = tag.copyWith(tagCategoryId: newCatId);
        tagBloc.add(UpdateTag(updated));
      },
    );

    // Кнопки управления тегом
    final canEdit = tag.name != 'Not Ref';
    final actionButtons = <Widget>[
      if (canEdit)
        IconButton(
          tooltip: 'Edit tag',
          icon: const Icon(
            Iconsax.edit,
            color: Color.fromARGB(255, 216, 216, 216),
          ),
          onPressed: () => TagsHelpers.showEditTagDialog(context, tag),
        ),
      if (canEdit)
        IconButton(
          tooltip: 'Change color',
          icon: Icon(
            Iconsax.colors_square,
            color: Color(tag.colorValue),
          ),
          onPressed: () => TagsHelpers.showColorPickerDialog(context, tag),
        ),
      if (canEdit)
        IconButton(
          tooltip: 'Delete tag',
          icon: const Icon(Iconsax.trash, color: Colors.red),
          onPressed: () =>
              TagsHelpers.showDeleteConfirmationDialog(context, tag),
        ),
    ];

    // --- КОМПАКТНЫЙ ВАРИАНТ (телефон / узкий экран) ---
    if (isCompact) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TagScreen(tag: tag)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя строка: аватар + название + счётчик
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(tag.colorValue),
                    child: Text(
                      tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$photoCount images',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Нижняя строка: dropdown + кнопки, могут переноситься
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    categoryDropdown,
                    ...actionButtons,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- ШИРОКИЙ ВАРИАНТ (macOS / планшет / широкий экран) ---
    return ListTile(
      key: ValueKey(tag.id),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TagScreen(tag: tag)),
        );
      },
      leading: CircleAvatar(
        backgroundColor: Color(tag.colorValue),
        child: Text(
          tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        tag.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$photoCount images',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Важно: оборачиваем trailing в ConstrainedBox,
      // чтобы он не съедал всю ширину на широких экранах.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 380, // можно подправить, если захочется
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            categoryDropdown,
            ...actionButtons,
          ],
        ),
      ),
    );
  }
}

/// Dropdown «Категория» (null = Без категории)
class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final List<TagCategory> categories;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    super.key,
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('No Category'),
      ),
      ...categories.map(
        (c) => DropdownMenuItem<String?>(
          value: c.id,
          child: Text(c.name),
        ),
      ),
    ];

    return DropdownButton<String?>(
      value: value,
      items: items,
      onChanged: onChanged,
      underline: const SizedBox.shrink(),
      hint: const Text('Категория'),
    );
  }
}

/// Секция управления категориями: CRUD + Reorder
class _ManageCategoriesSection extends StatelessWidget {
  final bool expanded;
  final List<TagCategory> categories;
  final ValueChanged<bool> onExpandedChanged;

  const _ManageCategoriesSection({
    super.key,
    required this.expanded,
    required this.categories,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TagCategoryBloc>();
    return Card(
      elevation: 0,
      color: Colors.white10,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpandedChanged,
        title: const Text(
          'Tags Categories',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          tooltip: 'Add Tags Category',
          icon: const Icon(Iconsax.add),
          onPressed: () => _showCreateDialog(context),
        ),
        children: [
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Category is not exists'),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false, // <-- ВАЖНО
              onReorder: (oldIndex, newIndex) {
                final ids = List<String>.from(categories.map((e) => e.id));
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                bloc.add(ReorderTagCategories(ids));
              },
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final c = categories[index];
                return ReorderableDragStartListener(
                  key: ValueKey('cat_${c.id}'),
                  index: index,
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(c.name),
                    // subtitle: Text(
                    //   'Order: ${c.sortOrder} • Created: ${c.dateCreated.toLocal()}',
                    //   style: const TextStyle(fontSize: 12),
                    // ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Iconsax.edit),
                          onPressed: () => _showRenameDialog(context, c),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Iconsax.trash, color: Colors.red),
                          onPressed: () => _showDeleteDialog(context, c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- Диалоги управления категориями ---

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Tag Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final bloc = context.read<TagCategoryBloc>();
              final now = DateTime.now();
              final nextOrder =
                  categories.isEmpty ? 0 : (categories.last.sortOrder + 1);
              final cat = TagCategory(
                id: UniqueKey().toString(),
                name: name,
                dateCreated: now,
                sortOrder: nextOrder,
              );
              bloc.add(AddTagCategory(cat));
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, TagCategory c) {
    final ctrl = TextEditingController(text: c.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Tag Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              context
                  .read<TagCategoryBloc>()
                  .add(UpdateTagCategory(c.copyWith(name: name)));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, TagCategory c) {
    final tagBloc = context.read<TagBloc>();
    final catBloc = context.read<TagCategoryBloc>();
    final catsState = catBloc.state;
    final allCats =
        catsState is TagCategoryLoaded ? catsState.categories : <TagCategory>[];

    // Варианты реассайна: Без категории (null) или другая категория (кроме удаляемой)
    String? selectedId;
    final options = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Erase item\'s tag category'),
      ),
      ...allCats
          .where((x) => x.id != c.id)
          .map((x) => DropdownMenuItem<String?>(
                value: x.id,
                child: Text('Move to: ${x.name}'),
              )),
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('Delete Tag Category?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose option:',
              ),
              const SizedBox(height: 12),
              DropdownButton<String?>(
                isExpanded: true,
                value: selectedId,
                items: options,
                onChanged: (v) => setState(() => selectedId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                // Отправляем удаление категории с реассайном/анассайном
                context.read<TagCategoryBloc>().add(
                      DeleteTagCategory(id: c.id, reassignTo: selectedId),
                    );
                // Обновим теги в интерфейсе (TagBloc сам получит putAll в репозитории при delete)
                tagBloc.add(LoadTags());
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
