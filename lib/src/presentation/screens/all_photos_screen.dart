import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/presentation/widgets/macos/macos_ui.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/settings_dialog.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

class AllPhotosScreen extends StatefulWidget {
  const AllPhotosScreen({Key? key}) : super(key: key);

  @override
  _AllPhotosScreenState createState() => _AllPhotosScreenState();
}

class _AllPhotosScreenState extends State<AllPhotosScreen> {
  static const _prefSidebarOpen = 'macos.sidebar.open';
  bool _filterNotRef = true;
  bool _sidebarOpen = true;
  final GlobalKey<PhotoGridViewState> _gridKey =
      GlobalKey<PhotoGridViewState>();

  bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    _loadSidebarPref();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sidebarOpen = prefs.getBool(_prefSidebarOpen) ?? true;
    });
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarOpen;
    setState(() {
      _sidebarOpen = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSidebarOpen, next);
  }

  void _openSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => const SettingsDialog(appVersion: null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhotoBloc, PhotoState>(
      builder: (context, photoState) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (photoState is PhotoLoading || tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
              final tags = tagState.tags;

              if (photoState.photos.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Images')),
                  body: const Center(child: Text('No images available.')),
                );
              }

              // Создаём индекс тегов для быстрого и безопасного доступа
              final Map<String, Tag> tagIndex = {
                for (final t in tags) t.id: t,
              };

              final List<Tag> visibleTags = _filterNotRef
                  ? tags.where((tag) => tag.name != 'Not Ref').toList()
                  : tags;

              final List<Photo> photosFiltered = _filterNotRef
                  ? photoState.photos.where((photo) {
                      // Если у фото нет тегов — считаем его проходным (true)
                      if (photo.tagIds.isEmpty) return true;

                      // Проверяем: все ли теги не называются "Not Ref"
                      return photo.tagIds.every((tagId) {
                        final tag = tagIndex[tagId];
                        if (tag == null) {
                          // тег был удалён — безопасно пропускаем
                          // debugPrint(
                          //     '⚠️ Missing tagId $tagId for photo ${photo.id}');
                          return true;
                        }
                        return tag.name != 'Not Ref';
                      });
                    }).toList()
                  : photoState.photos;

              final grid = PhotoGridView(
                key: _gridKey,
                title: 'Images',
                photos: photosFiltered,
                tags: visibleTags,
                showInternalAppBar: !_isDesktop,
                actionFromParent: RawChip(
                  label: const Text('NOT REF'),
                  selected: !_filterNotRef,
                  showCheckmark: false,
                  avatar: !_filterNotRef
                      ? const Padding(
                          padding: EdgeInsets.only(left: 2, right: 2),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  onSelected: (_) {
                    setState(() {
                      _filterNotRef = !_filterNotRef;
                    });
                  },
                  selectedColor: Colors.red.shade600,
                  backgroundColor: Colors.red.shade300,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  shape: const StadiumBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  labelPadding: const EdgeInsets.only(right: 6),
                ),
              );

              return Scaffold(
                appBar: _isDesktop
                    ? MacosTopBar(
                        onToggleSidebar: _toggleSidebar,
                        onOpenNewWindow: () {
                          WindowService.openWindow(
                            route: '/all_photos',
                            args: {},
                            title: 'Refma — Images',
                          );
                        },
                        onBack: () => Navigator.of(context).maybePop(),
                        onForward: () {},
                        canGoBack: Navigator.of(context).canPop(),
                        canGoForward: false,
                        onUpload: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const UploadScreen(),
                            transitionsBuilder: (_, __, ___, child) => child,
                          ),
                        ),
                        onAllPhotos: () {},
                        onCollages: () =>
                            Navigator.pushNamed(context, '/my_collages'),
                        onTags: () => Navigator.pushNamed(context, '/all_tags'),
                        onSettings: _openSettings,
                        rightAfterSettings: _CenterBarIcon(
                          icon: Icons.filter_list_rounded,
                          onTap: () => _gridKey.currentState
                              ?.toggleFilterPanelFromHost(),
                        ),
                        title: 'Images',
                        centerActions: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CenterBarIcon(
                              icon: Icons.grid_view_rounded,
                              onTap: () =>
                                  _gridKey.currentState?.toggleLayoutFromHost(),
                            ),
                            const SizedBox(width: 4),
                            _CenterBarIcon(
                              icon: Icons.swap_vert_rounded,
                              onTap: () => _gridKey.currentState
                                  ?.toggleSortByFileSizeFromHost(),
                            ),
                          ],
                        ),
                      )
                    : null,
                body: _isDesktop
                    ? Row(
                        children: [
                          AnimatedContainer(
                            width: _sidebarOpen ? 220 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: _sidebarOpen
                                ? MacosSidebar(
                                    onMain: () => Navigator.of(context)
                                        .pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const MainScreen(),
                                      ),
                                      (_) => false,
                                    ),
                                    onAllPhotos: () {},
                                    onCollages: () => Navigator.pushNamed(
                                        context, '/my_collages'),
                                    onTags: () => Navigator.pushNamed(
                                        context, '/all_tags'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Expanded(child: grid),
                        ],
                      )
                    : grid,
              );
            } else {
              return const Center(child: Text('Failed to load images.'));
            }
          },
        );
      },
    );
  }
}

class _CenterBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CenterBarIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(icon, size: 15, color: MacosPalette.text),
      ),
    );
  }
}
