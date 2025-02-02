import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/repositories/collage_repository.dart';

part 'collage_event.dart';
part 'collage_state.dart';

class CollageBloc extends Bloc<CollageEvent, CollageState> {
  final CollageRepository collageRepository;

  CollageBloc({required this.collageRepository}) : super(CollageInitial()) {
    on<LoadCollages>(_onLoadCollages);
    on<AddCollage>(_onAddCollage);
    on<UpdateCollage>(_onUpdateCollage);
    on<DeleteCollage>(_onDeleteCollage);
    on<GetCollage>(_onGetCollage);
  }

  Future<void> _onLoadCollages(
      LoadCollages event, Emitter<CollageState> emit) async {
    emit(CollageLoading());
    try {
      final collages = await collageRepository.getAllCollages();
      emit(CollagesLoaded(collages));
    } catch (e) {
      emit(CollageError('Failed to load collages'));
    }
  }

  Future<void> _onAddCollage(
      AddCollage event, Emitter<CollageState> emit) async {
    try {
      await collageRepository.addCollage(event.collage);
      add(LoadCollages()); // Перезагружаем список
    } catch (e) {
      emit(CollageError('Failed to add collage'));
    }
  }

  Future<void> _onUpdateCollage(
      UpdateCollage event, Emitter<CollageState> emit) async {
    try {
      await collageRepository.updateCollage(event.collage);
      add(LoadCollages()); // или LoadCollages() / либо ничего, если нужно
    } catch (e) {
      emit(CollageError('Failed to update collage'));
    }
  }

  Future<void> _onDeleteCollage(
      DeleteCollage event, Emitter<CollageState> emit) async {
    try {
      await collageRepository.deleteCollage(event.collageId);
      add(LoadCollages());
    } catch (e) {
      emit(CollageError('Failed to delete collage'));
    }
  }

  Future<void> _onGetCollage(
      GetCollage event, Emitter<CollageState> emit) async {
    try {
      final collage = await collageRepository.getCollage(event.collageId);
      emit(CollageLoaded(collage!));
    } catch (e) {
      emit(CollageError('Failed to load collage'));
    }
  }
}
