import 'package:photographers_reference_app/src/domain/entities/category.dart';

List<Category> sortCategories({
  List<Category> categories = const [],
  String? categoryId,
  String move = '',
}) {
  // Если категории еще не отсортированы по sortOrder
  categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  if (categoryId != null && move.isNotEmpty) {
    // Найдем категорию по categoryId
    final index = categories.indexWhere((category) => category.id == categoryId);

    if (index != -1) {
      // Перемещаем категорию вверх или вниз в массиве
      if (move == 'up' && index > 0) {
        final temp = categories[index];
        categories[index] = categories[index - 1];
        categories[index - 1] = temp;
      } else if (move == 'down' && index < categories.length - 1) {
        final temp = categories[index];
        categories[index] = categories[index + 1];
        categories[index + 1] = temp;
      }
    }
  }

  // Присваиваем новый порядок sortOrder
  for (var i = 0; i < categories.length; i++) {
    categories[i] = categories[i].copyWith(sortOrder: i + 1);
  }

  return categories;
}
