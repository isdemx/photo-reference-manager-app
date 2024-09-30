// lib/src/presentation/blocs/photo_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/repositories/photo_repository.dart';

part 'photo_event.dart';
part 'photo_state.dart';

class PhotoBloc extends Bloc<PhotoEvent, PhotoState> {
  final PhotoRepository photoRepository;

  PhotoBloc({required this.photoRepository}) : super(PhotoInitial()) {
    on<LoadPhotos>(_onLoadPhotos);
    on<AddPhoto>(_onAddPhoto);
    on<DeletePhoto>(_onDeletePhoto);
    on<UpdatePhoto>(_onUpdatePhoto);
  }

  Future<void> _onLoadPhotos(LoadPhotos event, Emitter<PhotoState> emit) async {
    emit(PhotoLoading());
    try {
      final photos = await photoRepository.getPhotos();
      emit(PhotoLoaded(photos));
    } catch (e) {
      emit(const PhotoError('Failed to load photos'));
    }
  }

  Future<void> _onAddPhoto(AddPhoto event, Emitter<PhotoState> emit) async {
    try {
      await photoRepository.addPhoto(event.photo);
      add(LoadPhotos());
    } catch (e) {
      emit(const PhotoError('Failed to add photo'));
    }
  }

  Future<void> _onDeletePhoto(DeletePhoto event, Emitter<PhotoState> emit) async {
    try {
      await photoRepository.deletePhoto(event.id);
      add(LoadPhotos());
    } catch (e) {
      emit(const PhotoError('Failed to delete photo'));
    }
  }

  Future<void> _onUpdatePhoto(UpdatePhoto event, Emitter<PhotoState> emit) async {
    try {
      await photoRepository.updatePhoto(event.photo);
      add(LoadPhotos());
    } catch (e) {
      emit(const PhotoError('Failed to update photo'));
    }
  }
}
