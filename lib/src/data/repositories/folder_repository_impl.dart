// lib/src/data/repositories/folder_repository_impl.dart

import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/repositories/folder_repository.dart';

class FolderRepositoryImpl implements FolderRepository {
  final Box<Folder> folderBox;

  FolderRepositoryImpl(this.folderBox);

  @override
  Future<void> addFolder(Folder folder) async {
    await folderBox.put(folder.id, folder);
  }

  @override
  Future<List<Folder>> getFolders() async {
    return folderBox.values.toList();
  }

  @override
  Future<void> deleteFolder(String id) async {
    await folderBox.delete(id);
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    await folder.save();
  }
}
