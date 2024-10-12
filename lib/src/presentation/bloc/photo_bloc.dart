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
    on<PhotosAdded>(_onPhotosAdded);
    on<DeletePhoto>(_onDeletePhoto);
    on<UpdatePhoto>(_onUpdatePhoto);
    on<ClearTemporaryFiles>(_onClearTemporaryFiles);
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
      // Обработка ошибок
    }
  }

  Future<void> _onPhotosAdded(
      PhotosAdded event, Emitter<PhotoState> emit) async {
    if (state is PhotoLoaded) {
      final currentPhotos = (state as PhotoLoaded).photos;
      emit(PhotoLoaded(List.from(currentPhotos)..addAll(event.photos)));
    } else {
      add(LoadPhotos());
    }
  }

  Future<void> _onDeletePhoto(
      DeletePhoto event, Emitter<PhotoState> emit) async {
    try {
      await photoRepository.deletePhoto(event.id);
      add(LoadPhotos());
    } catch (e) {
      emit(const PhotoError('Failed to delete photo'));
    }
  }

  Future<void> _onUpdatePhoto(
      UpdatePhoto event, Emitter<PhotoState> emit) async {
    try {
      print('UPDATE PHOTO');
      await photoRepository.updatePhoto(event.photo);
      add(LoadPhotos());
    } catch (e) {
      emit(const PhotoError('Failed to update photo'));
    }
  }

  Future<void> _onClearTemporaryFiles(
      ClearTemporaryFiles event, Emitter<PhotoState> emit) async {
    print('_onClearTemporaryFiles');
    try {
      await photoRepository.clearTemporaryFiles();
      print('Temporary files cleared');
    } catch (e) {
      print('Temporary files cleared ERROR: $e');
      emit(const PhotoError('Failed to clear temporary files'));
    }
  }
}
