part of 'collage_bloc.dart';

abstract class CollageState extends Equatable {
  const CollageState();

  @override
  List<Object?> get props => [];
}

// 📌 Начальное состояние
class CollageInitial extends CollageState {}

// 📌 Состояние загрузки
class CollageLoading extends CollageState {}

// 📌 Коллажи загружены
class CollagesLoaded extends CollageState {
  final List<Collage> collages;

  const CollagesLoaded(this.collages);

  @override
  List<Object?> get props => [collages];
}

// 📌 Ошибка загрузки
class CollageError extends CollageState {
  final String message;

  const CollageError(this.message);

  @override
  List<Object?> get props => [message];
}

// 📌 Один коллаж загружен
class CollageLoaded extends CollageState {
  final Collage collage;

  const CollageLoaded(this.collage);

  @override
  List<Object?> get props => [collage];
}
