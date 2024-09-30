// lib/src/presentation/blocs/tag_event.dart

part of 'tag_bloc.dart';

abstract class TagEvent extends Equatable {
  const TagEvent();

  @override
  List<Object> get props => [];
}

class LoadTags extends TagEvent {}

class AddTag extends TagEvent {
  final Tag tag;

  const AddTag(this.tag);

  @override
  List<Object> get props => [tag];
}

class DeleteTag extends TagEvent {
  final String id;

  const DeleteTag(this.id);

  @override
  List<Object> get props => [id];
}

class UpdateTag extends TagEvent {
  final Tag tag;

  const UpdateTag(this.tag);

  @override
  List<Object> get props => [tag];
}
