// lib/src/presentation/blocs/photo_event.dart

part of 'photo_bloc.dart';

abstract class PhotoEvent extends Equatable {
  const PhotoEvent();

  @override
  List<Object> get props => [];
}

class LoadPhotos extends PhotoEvent {}

class AddPhoto extends PhotoEvent {
  final Photo photo;

  const AddPhoto(this.photo);

  @override
  List<Object> get props => [photo];
}

class DeletePhoto extends PhotoEvent {
  final String id;

  const DeletePhoto(this.id);

  @override
  List<Object> get props => [id];
}

class UpdatePhoto extends PhotoEvent {
  final Photo photo;

  const UpdatePhoto(this.photo);

  @override
  List<Object> get props => [photo];
}
