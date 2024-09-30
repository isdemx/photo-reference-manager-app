// lib/src/domain/repositories/folder_repository.dart

import 'package:photographers_reference_app/src/domain/entities/folder.dart';

abstract class FolderRepository {
  Future<void> addFolder(Folder folder);
  Future<List<Folder>> getFolders();
  Future<void> deleteFolder(String id);
  Future<void> updateFolder(Folder folder);
}
