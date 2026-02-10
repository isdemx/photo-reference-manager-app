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
  final Widget? extraAction;

  bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  const FilterPanel({
    super.key,
    required this.tags,
    required this.useAndMode,
    required this.onToggleLogic,
    this.extraAction,
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

            final panelPadding = isMacOS
                ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                : const EdgeInsets.all(8.0);

            return Container(
              padding: panelPadding,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(isMacOS ? 0.82 : 0.27),
                border: isMacOS
                    ? Border(
                        left: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMacOS) ...[
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap tag to cycle include / exclude / off',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Header controls
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ToggleButtons(
                                    isSelected: [
                                      useAndMode == false,
                                      useAndMode
                                    ],
                                    onPressed: (index) {
                                      final nextAnd = index == 1;
                                      if (nextAnd != useAndMode) {
                                        onToggleLogic();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    borderColor: Colors.transparent,
                                    selectedBorderColor: Colors.transparent,
                                    fillColor: const Color(0xFF2D3542),
                                    color: Colors.white70,
                                    selectedColor: Colors.white,
                                    constraints: const BoxConstraints(
                                      minHeight: 24,
                                      minWidth: 30,
                                    ),
                                    children: const [
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          'AND',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (extraAction != null) extraAction!,
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              context
                                  .read<FilterBloc>()
                                  .add(const ClearFiltersEvent());
                            },
                            icon: const Icon(Icons.clear,
                                size: 14, color: Colors.white70),
                            label: const Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6.0),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Категории с заголовками
                          for (final entry in grouped.byCat.entries) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 6),
                              child: Text(
                                catName(entry.key),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
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
                                  isMacOS: isMacOS,
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
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 6),
                              child: Text(
                                'No category',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: grouped.uncategorized.map((tag) {
                                final tagFilterState =
                                    filterState.filters[tag.id] ??
                                        TagFilterState.undefined;
                                return _TagFilterChip(
                                  tag: tag,
                                  state: tagFilterState,
                                  isMacOS: isMacOS,
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
}

/// Маленький виджет одного тега-фильтра
class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final TagFilterState state;
  final bool isMacOS;
  final VoidCallback onTap;

  const _TagFilterChip({
    required this.tag,
    required this.state,
    required this.isMacOS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(state);
    final bgColor = Color.alphaBlend(
      Colors.black.withOpacity(isMacOS ? 0.25 : 0.0),
      tag.color,
    );
    final chipPad = isMacOS
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 5, vertical: 2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: chipPad,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor == Colors.transparent
                ? Colors.white.withOpacity(0.08)
                : borderColor,
            width: borderColor == Colors.transparent ? 0.8 : 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state != TagFilterState.undefined) ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: borderColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              tag.name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: isMacOS ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
    e.value
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  uncategorized
      .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
