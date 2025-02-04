import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';

class MyCollagesScreen extends StatelessWidget {
  const MyCollagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat =
        DateFormat('yyyy-MM-dd HH:mm'); // Формат: ГГГГ-ММ-ДД ЧЧ:ММ
    return BlocBuilder<CollageBloc, CollageState>(
      builder: (context, state) {
        if (state is CollageLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (state is CollagesLoaded) {
          return BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, photoState) {
              if (photoState is PhotoLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded) {
                final allPhotos = photoState.photos;

                // Сортируем коллажи по дате создания (сначала новые)
                final sortedCollages = state.collages.toList()
                  ..sort((a, b) {
                    final aDate = a.dateUpdated ?? DateTime(2000, 1, 1);
                    final bDate = b.dateUpdated ?? DateTime(2000, 1, 1);
                    return bDate.compareTo(aDate); // Сначала новые
                  });

                return Scaffold(
                  appBar: AppBar(title: const Text('All Collages')),
                  body: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: sortedCollages.length,
                          itemBuilder: (context, index) {
                            final c = sortedCollages[index];

                            // Определяем, какую дату показать: создание или обновление
                            final bool isUpdated = c.dateUpdated != null &&
                                c.dateUpdated != c.dateCreated;
                            final String dateText = isUpdated
                                ? 'Updated: ${dateFormat.format(c.dateUpdated!)}'
                                : 'Created: ${dateFormat.format(c.dateCreated!)}';

                            return ListTile(
                              title: Text(c.title),
                              subtitle: Text(dateText),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoCollageWidget(
                                      key: ValueKey(c.title),
                                      photos: [allPhotos.first],
                                      allPhotos: allPhotos,
                                      initialCollage: c,
                                    ),
                                  ),
                                );
                              },
                              trailing: IconButton(
                                icon: const Icon(Iconsax.trash,
                                    color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Confirm Deletion'),
                                      content: Text(
                                          'Do you really want to delete "${c.title}"?'),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                        TextButton(
                                          child: const Text('Delete'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            context
                                                .read<CollageBloc>()
                                                .add(DeleteCollage(c.id));
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16), // Отступ перед кнопкой
                    ],
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoCollageWidget(
                            key: const ValueKey('new_photo_collage_widget'),
                            photos: [allPhotos.first],
                            allPhotos: allPhotos,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Iconsax.add),
                    label: const Text('Create New Collage'),
                    backgroundColor: Colors.black, // Цвет кнопки
                  ),
                );
              } else {
                return const Center(child: Text('No photos loaded.'));
              }
            },
          );
        } else if (state is CollageError) {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: Center(child: Text('Error: ${state.message}')),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: const Center(child: Text('No data or unknown state')),
          );
        }
      },
    );
  }
}
