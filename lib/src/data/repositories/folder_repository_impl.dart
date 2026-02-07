// lib/src/data/repositories/folder_repository_impl.dart

import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/repositories/folder_repository.dart';
import 'package:photographers_reference_app/src/services/shared_folders_sync_service.dart';

class FolderRepositoryImpl implements FolderRepository {
  final Box<Folder> folderBox;

  FolderRepositoryImpl(this.folderBox);

  @override
  Future<void> addFolder(Folder folder) async {
    await folderBox.put(folder.id, folder);
    await _syncSharedFolders();
  }

  @override
  Future<List<Folder>> getFolders() async {
    final folders = folderBox.values.toList();

    return folders;
  }

  @override
  Future<void> deleteFolder(String id) async {
    await folderBox.delete(id);
    await _syncSharedFolders();
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    try {
      await folderBox.put(folder.id, folder);
      print('Folder SAVED ${folder.isPrivate}');
      await _syncSharedFolders();
    } catch (e) {
      print('Error saving folder: $e');
      rethrow;
    }
  }

  Future<void> _syncSharedFolders() async {
    final folders = folderBox.values.toList();
    await SharedFoldersSyncService().syncFolders(folders);
  }
}
