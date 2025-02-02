import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';

class MyCollagesScreen extends StatelessWidget {
  const MyCollagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollageBloc, CollageState>(
      builder: (context, state) {
        if (state is CollageLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('All Collages')),
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is CollagesLoaded) {
          return BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, photoState) {
              if (photoState is PhotoLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded) {
                final allPhotos = photoState.photos;
                return Scaffold(
                  appBar: AppBar(title: const Text('All Collages')),
                  body: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.collages.length,
                          itemBuilder: (context, index) {
                            final c = state.collages[index];
                            return ListTile(
                              title: Text(c.title),
                              subtitle: Text('Created: ${c.dateCreated}'),
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
                    backgroundColor: Colors.black, // Указываем нужный цвет
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
