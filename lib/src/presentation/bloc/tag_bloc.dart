// lib/src/presentation/blocs/tag_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_repository.dart';

part 'tag_event.dart';
part 'tag_state.dart';

class TagBloc extends Bloc<TagEvent, TagState> {
  final TagRepository tagRepository;

  TagBloc({required this.tagRepository}) : super(TagInitial()) {
    on<LoadTags>(_onLoadTags);
    on<AddTag>(_onAddTag);
    on<DeleteTag>(_onDeleteTag);
    on<UpdateTag>(_onUpdateTag);
  }

  Future<void> _onLoadTags(LoadTags event, Emitter<TagState> emit) async {
    emit(TagLoading());
    try {
      final tags = await tagRepository.getTags();
      print('!!!!! On Load Tags');
      emit(TagLoaded(tags));
    } catch (e) {
      emit(const TagError('Failed to load tags'));
    }
  }

  Future<void> _onAddTag(AddTag event, Emitter<TagState> emit) async {
    print('!!!!!!!!!!On tag add');
    try {
      await tagRepository.addTag(event.tag);
      add(LoadTags());
    } catch (e) {
      emit(const TagError('Failed to add tag'));
    }
  }

  Future<void> _onDeleteTag(DeleteTag event, Emitter<TagState> emit) async {
    try {
      await tagRepository.deleteTag(event.id);
      add(LoadTags());
    } catch (e) {
      emit(const TagError('Failed to delete tag'));
    }
  }

  Future<void> _onUpdateTag(UpdateTag event, Emitter<TagState> emit) async {
    try {
      await tagRepository.updateTag(event.tag);
      add(LoadTags());
    } catch (e) {
      emit(const TagError('Failed to update tag'));
    }
  }
}
