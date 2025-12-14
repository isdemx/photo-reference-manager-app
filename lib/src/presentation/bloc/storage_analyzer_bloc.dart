// lib/src/presentation/bloc/storage_analyzer_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/utils/storage_analyzer.dart';

/// Events

abstract class StorageAnalyzerEvent {}

class StorageAnalyzerStarted extends StorageAnalyzerEvent {}

/// States

abstract class StorageAnalyzerState {}

class StorageAnalyzerInitial extends StorageAnalyzerState {}

class StorageAnalyzerLoading extends StorageAnalyzerState {}

class StorageAnalyzerLoaded extends StorageAnalyzerState {
  final List<FileSizeEntry> entries;

  StorageAnalyzerLoaded(this.entries);
}

class StorageAnalyzerError extends StorageAnalyzerState {
  final String message;

  StorageAnalyzerError(this.message);
}

/// Bloc

class StorageAnalyzerBloc
    extends Bloc<StorageAnalyzerEvent, StorageAnalyzerState> {
  StorageAnalyzerBloc() : super(StorageAnalyzerInitial()) {
    on<StorageAnalyzerStarted>(_onStarted);
  }

  Future<void> _onStarted(
    StorageAnalyzerStarted event,
    Emitter<StorageAnalyzerState> emit,
  ) async {
    emit(StorageAnalyzerLoading());
    try {
      final entries = await analyzeAppStorage();
      emit(StorageAnalyzerLoaded(entries));
    } catch (e) {
      emit(StorageAnalyzerError(e.toString()));
    }
  }
}
