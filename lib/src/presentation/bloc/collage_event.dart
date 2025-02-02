// lib/src/presentation/bloc/collage_bloc/collage_event.dart

part of 'collage_bloc.dart';


abstract class CollageEvent {
  const CollageEvent();
}

class LoadCollages extends CollageEvent {}

class AddCollage extends CollageEvent {
  final Collage collage;
  const AddCollage(this.collage);
}

class UpdateCollage extends CollageEvent {
  final Collage collage;
  const UpdateCollage(this.collage);
}

class DeleteCollage extends CollageEvent {
  final String collageId;
  const DeleteCollage(this.collageId);
}

class GetCollage extends CollageEvent {
  final String collageId;
  const GetCollage(this.collageId);
}
