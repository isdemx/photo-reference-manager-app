part of 'collage_bloc.dart';

abstract class CollageEvent extends Equatable {
  const CollageEvent();

  @override
  List<Object?> get props => [];
}

// 📌 Загрузить список всех коллажей
class LoadCollages extends CollageEvent {}

// 📌 Добавить новый коллаж
class AddCollage extends CollageEvent {
  final Collage collage;

  const AddCollage(this.collage);

  @override
  List<Object?> get props => [collage];
}

// 📌 Обновить существующий коллаж
class UpdateCollage extends CollageEvent {
  final Collage collage;

  const UpdateCollage(this.collage);

  @override
  List<Object?> get props => [collage];
}

// 📌 Удалить коллаж
class DeleteCollage extends CollageEvent {
  final String collageId;

  const DeleteCollage(this.collageId);

  @override
  List<Object?> get props => [collageId];
}

// 📌 Получить один коллаж по ID
class GetCollage extends CollageEvent {
  final String collageId;

  const GetCollage(this.collageId);

  @override
  List<Object?> get props => [collageId];
}
