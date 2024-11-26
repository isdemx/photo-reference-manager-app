// filter_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

enum TagFilterState { trueState, falseState, undefined }

class FilterState extends Equatable {
  final Map<String, TagFilterState> filters;

  const FilterState({required this.filters});

  FilterState copyWith({Map<String, TagFilterState>? filters}) {
    return FilterState(
      filters: filters ?? this.filters,
    );
  }

  @override
  List<Object?> get props => [filters];
}

abstract class FilterEvent extends Equatable {
  const FilterEvent();

  @override
  List<Object?> get props => [];
}

class ToggleFilterEvent extends FilterEvent {
  final String tagId;

  const ToggleFilterEvent({required this.tagId});

  @override
  List<Object?> get props => [tagId];
}

class ClearFiltersEvent extends FilterEvent {
  const ClearFiltersEvent();
}

class FilterBloc extends Bloc<FilterEvent, FilterState> {
  FilterBloc() : super(const FilterState(filters: {})) {
    on<ToggleFilterEvent>((event, emit) {
      final currentState = state.filters;
      final currentTagState = currentState[event.tagId] ?? TagFilterState.undefined;

      // Цикл состояний: undefined -> trueState -> falseState -> undefined
      TagFilterState newTagState;
      switch (currentTagState) {
        case TagFilterState.undefined:
          newTagState = TagFilterState.trueState;
          break;
        case TagFilterState.trueState:
          newTagState = TagFilterState.falseState;
          break;
        case TagFilterState.falseState:
          newTagState = TagFilterState.undefined;
          break;
      }

      final newFilters = Map<String, TagFilterState>.from(currentState);
      if (newTagState == TagFilterState.undefined) {
        newFilters.remove(event.tagId);
      } else {
        newFilters[event.tagId] = newTagState;
      }

      emit(state.copyWith(filters: newFilters));
    });

    on<ClearFiltersEvent>((event, emit) {
      emit(const FilterState(filters: {}));
    });
  }
}
