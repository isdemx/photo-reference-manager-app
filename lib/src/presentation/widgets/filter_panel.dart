import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

class FilterPanel extends StatelessWidget {
  final List<Tag> tags;

  /// true = AND, false = OR
  final bool useAndMode;
  final VoidCallback onToggleLogic;

  bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  const FilterPanel({
    super.key,
    required this.tags,
    required this.useAndMode,
    required this.onToggleLogic,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagCategoryBloc, TagCategoryState>(
      builder: (context, catState) {
        final categories = catState is TagCategoryLoaded
            ? catState.categories
            : <TagCategory>[];

        return BlocBuilder<FilterBloc, FilterState>(
          builder: (context, filterState) {
            final grouped = _groupTagsByCategoryId(tags);

            String catName(String? id) {
              if (id == null || id.isEmpty) return 'No category';
              final cat = categories.firstWhere(
                (c) => c.id == id,
                orElse: () => TagCategory(
                  id: '',
                  name: 'Unknown',
                  sortOrder: 0,
                  dateCreated: DateTime.now(),
                ),
              );
              return cat.id.isEmpty ? 'Unknown' : cat.name;
            }

            return Container
            (
              padding: const EdgeInsets.all(8.0),
              color: Colors.black.withOpacity(isMacOS ? 0.9 : 0.27),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------- Row: заголовок + OR / AND + Clear
                  Row(
                    children: [
                      const Text(
                        'Tags:',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('OR'),
                        selected: !useAndMode,
                        onSelected: (_) => onToggleLogic(),
                        selectedColor: Colors.blueGrey.shade700,
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('AND'),
                        selected: useAndMode,
                        onSelected: (_) => onToggleLogic(),
                        selectedColor: Colors.blueGrey.shade700,
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          context
                              .read<FilterBloc>()
                              .add(const ClearFiltersEvent());
                        },
                        icon: const Icon(Icons.clear,
                            size: 16, color: Colors.white70),
                        label: const Text(
                          'Clear',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8.0),

                  // ---------------- Список тегов, сгруппированных по категориям
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Категории с заголовками
                          for (final entry in grouped.byCat.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 4),
                              child: Text(
                                catName(entry.key),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: entry.value.map((tag) {
                                final tagFilterState =
                                    filterState.filters[tag.id] ??
                                        TagFilterState.undefined;
                                return _TagFilterChip(
                                  tag: tag,
                                  state: tagFilterState,
                                  onTap: () {
                                    context.read<FilterBloc>().add(
                                          ToggleFilterEvent(tagId: tag.id),
                                        );
                                  },
                                );
                              }).toList(),
                            ),
                          ],

                          // Без категории
                          if (grouped.uncategorized.isNotEmpty) ...[
                            const Padding(
                              padding:
                                  EdgeInsets.only(top: 12, bottom: 4),
                              child: Text(
                                'No category',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children:
                                  grouped.uncategorized.map((tag) {
                                final tagFilterState =
                                    filterState.filters[tag.id] ??
                                        TagFilterState.undefined;
                                return _TagFilterChip(
                                  tag: tag,
                                  state: tagFilterState,
                                  onTap: () {
                                    context.read<FilterBloc>().add(
                                          ToggleFilterEvent(tagId: tag.id),
                                        );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getBorderColor(TagFilterState state) {
    switch (state) {
      case TagFilterState.trueState:
        return const Color(0xFF4CAF50); // зелёная рамка
      case TagFilterState.falseState:
        return const Color(0xFFE53935); // красная рамка
      case TagFilterState.undefined:
      default:
        return Colors.transparent;
    }
  }
}

/// Маленький виджет одного тега-фильтра
class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final TagFilterState state;
  final VoidCallback onTap;

  const _TagFilterChip({
    required this.tag,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(state);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 5.0,
          vertical: 2.0,
        ),
        decoration: BoxDecoration(
          color: tag.color,
          boxShadow: [
            BoxShadow(
              color: borderColor,
              spreadRadius: 2.0,
              blurRadius: 0.0,
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          tag.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _borderColor(TagFilterState state) {
    switch (state) {
      case TagFilterState.trueState:
        return const Color(0xFF4CAF50);
      case TagFilterState.falseState:
        return const Color(0xFFE53935);
      case TagFilterState.undefined:
      default:
        return Colors.transparent;
    }
  }
}

/// Группировка тегов по tagCategoryId
class _GroupedTags {
  final Map<String?, List<Tag>> byCat;
  final List<Tag> uncategorized;

  _GroupedTags(this.byCat, this.uncategorized);
}

_GroupedTags _groupTagsByCategoryId(List<Tag> all) {
  final byCat = <String?, List<Tag>>{};
  final uncategorized = <Tag>[];

  for (final t in all) {
    final catId = t.tagCategoryId; // предполагается поле в Tag
    if (catId == null || catId.isEmpty) {
      uncategorized.add(t);
    } else {
      (byCat[catId] ??= []).add(t);
    }
  }

  // сортируем по имени внутри категорий
  for (final e in byCat.entries) {
    e.value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  uncategorized.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // опционально — сортировка по ключу категории
  final sortedByCat = Map<String?, List<Tag>>.fromEntries(
    byCat.entries.toList()
      ..sort((a, b) {
        final ak = a.key ?? '';
        final bk = b.key ?? '';
        return ak.compareTo(bk);
      }),
  );

  return _GroupedTags(sortedByCat, uncategorized);
}
