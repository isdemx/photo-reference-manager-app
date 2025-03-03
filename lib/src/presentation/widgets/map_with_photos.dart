// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'dart:io';
// import 'package:photographers_reference_app/src/domain/entities/photo.dart';
// //import 'package:geolocator/geolocator.dart';
// import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

// class PhotoMapWidget extends StatefulWidget {
//   final List<Photo> photos; // Список фото с данными геолокации
//   final Photo? activePhoto; // Активное фото для центрирования

//   const PhotoMapWidget({super.key, required this.photos, this.activePhoto});

//   @override
//   _PhotoMapWidgetState createState() => _PhotoMapWidgetState();
// }

// class _PhotoMapWidgetState extends State<PhotoMapWidget> {
//   LatLng? initialCenter;

//   @override
//   void initState() {
//     super.initState();
//     _setInitialCenter();
//   }

//   Future<void> _setInitialCenter() async {
//     // Проверяем, есть ли геолокация у активного фото
//     if (widget.activePhoto?.geoLocation != null) {
//       final geo = widget.activePhoto!.geoLocation!;
//       setState(() {
//         initialCenter = LatLng(geo['lat']!, geo['lon']!);
//       });
//     } else {
//       // Получаем текущее местоположение пользователя
//       final position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high);
//       setState(() {
//         initialCenter = LatLng(position.latitude, position.longitude);
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Photo Map'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: initialCenter == null
//           ? const Center(child: CircularProgressIndicator())
//           : FlutterMap(
//               options: MapOptions(
//                 initialCenter: initialCenter!,
//                 initialZoom: 18.0,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate:
//                       'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                   subdomains: const ['a', 'b', 'c'],
//                 ),
//                 MarkerLayer(
//                   markers: widget.photos
//                       .where((photo) => photo.geoLocation != null)
//                       .map((photo) {
//                     final geo = photo.geoLocation!;
//                     return Marker(
//                       point: LatLng(geo['lat']!, geo['lon']!),
//                       child: CircleAvatar(
//                         backgroundImage: FileImage(File(PhotoPathHelper().getFullPath(photo.fileName))),
//                         radius: 25,
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ],
//             ),
//     );
//   }
// }
