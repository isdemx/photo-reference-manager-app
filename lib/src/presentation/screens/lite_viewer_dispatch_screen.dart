import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';

class LiteViewerDispatchScreen extends StatefulWidget {
  const LiteViewerDispatchScreen({
    super.key,
    required this.filePaths,
  });

  final List<String> filePaths;

  @override
  State<LiteViewerDispatchScreen> createState() =>
      _LiteViewerDispatchScreenState();
}

class _LiteViewerDispatchScreenState extends State<LiteViewerDispatchScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    debugPrint(
      '[RefmaOpenFiles][dart] LiteViewerDispatchScreen start filePaths=${widget.filePaths}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        for (final filePath in widget.filePaths) {
          debugPrint(
            '[RefmaOpenFiles][dart] LiteViewerDispatchScreen opening $filePath',
          );
          await WindowService.openLiteViewerWindow(filePath: filePath);
        }
      } finally {
        debugPrint(
          '[RefmaOpenFiles][dart] LiteViewerDispatchScreen closing main window',
        );
        final mainWindow = WindowController.main();
        await mainWindow.hide();
        await mainWindow.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(),
    );
  }
}
