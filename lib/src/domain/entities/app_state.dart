class AppState {
  String currentFolderId;
  String currentCategoryId;
  List<String> selectedPhotoIds;

  AppState({
    required this.currentFolderId,
    required this.currentCategoryId,
    required this.selectedPhotoIds,
  });
}
