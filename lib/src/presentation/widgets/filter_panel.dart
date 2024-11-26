import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';

class FilterPanel extends StatelessWidget {
  final List<Tag> tags;

  const FilterPanel({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterBloc, FilterState>(
      builder: (context, filterState) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black.withOpacity(0.27),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: tags.map((tag) {
                      final tagFilterState =
                          filterState.filters[tag.id] ?? TagFilterState.undefined;
                      return GestureDetector(
                        onTap: () {
                          context
                              .read<FilterBloc>()
                              .add(ToggleFilterEvent(tagId: tag.id));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: tag.color,
                            boxShadow: [
                              BoxShadow(
                                color: _getBorderColor(tagFilterState),
                                spreadRadius: 1.0,
                                blurRadius: 2.0,
                              ),
                            ],
                            border: Border.all(
                              color: _getBorderColor(tagFilterState),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            tag.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () {
                  context.read<FilterBloc>().add(const ClearFiltersEvent());
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBorderColor(TagFilterState state) {
    switch (state) {
      case TagFilterState.trueState:
        return const Color(0xFF4CAF50); // Soft but vibrant green for true state
      case TagFilterState.falseState:
        return const Color(0xFFE53935); // Soft but vibrant red for false state
      case TagFilterState.undefined:
      default:
        return Colors.transparent; // Бордер отсутствует для undefined
    }
  }
}
