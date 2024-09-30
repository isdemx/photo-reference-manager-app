// lib/src/presentation/blocs/folder_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/repositories/folder_repository.dart';

part 'folder_event.dart';
part 'folder_state.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final FolderRepository folderRepository;

  FolderBloc({required this.folderRepository}) : super(FolderInitial()) {
    on<LoadFolders>(_onLoadFolders);
    on<AddFolder>(_onAddFolder);
    on<DeleteFolder>(_onDeleteFolder);
    on<UpdateFolder>(_onUpdateFolder);
  }

  Future<void> _onLoadFolders(
      LoadFolders event, Emitter<FolderState> emit) async {
    emit(FolderLoading());
    try {
      final folders = await folderRepository.getFolders();
      emit(FolderLoaded(folders));
    } catch (e) {
      emit(const FolderError('Failed to load folders'));
    }
  }

  Future<void> _onAddFolder(
      AddFolder event, Emitter<FolderState> emit) async {
    try {
      await folderRepository.addFolder(event.folder);
      add(LoadFolders());
    } catch (e) {
      emit(const FolderError('Failed to add folder'));
    }
  }

  Future<void> _onDeleteFolder(
      DeleteFolder event, Emitter<FolderState> emit) async {
    try {
      await folderRepository.deleteFolder(event.id);
      add(LoadFolders());
    } catch (e) {
      emit(const FolderError('Failed to delete folder'));
    }
  }

  Future<void> _onUpdateFolder(
      UpdateFolder event, Emitter<FolderState> emit) async {
    try {
      await folderRepository.updateFolder(event.folder);
      add(LoadFolders());
    } catch (e) {
      emit(const FolderError('Failed to update folder'));
    }
  }
}
