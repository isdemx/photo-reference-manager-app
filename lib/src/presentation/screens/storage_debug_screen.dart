// lib/src/presentation/screens/storage_debug_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/utils/storage_analyzer.dart';
import 'package:photographers_reference_app/src/presentation/bloc/storage_analyzer_bloc.dart';

class StorageDebugScreen extends StatelessWidget {
  const StorageDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StorageAnalyzerBloc>(
      create: (_) => StorageAnalyzerBloc()..add(StorageAnalyzerStarted()),
      child: const _StorageDebugView(),
    );
  }
}

class _StorageDebugView extends StatelessWidget {
  const _StorageDebugView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File sizes'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<StorageAnalyzerBloc>().add(StorageAnalyzerStarted());
            },
          ),
        ],
      ),
      body: BlocBuilder<StorageAnalyzerBloc, StorageAnalyzerState>(
        builder: (context, state) {
          if (state is StorageAnalyzerLoading ||
              state is StorageAnalyzerInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is StorageAnalyzerError) {
            return Center(
              child: Text(
                'Error: ${state.message}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (state is StorageAnalyzerLoaded) {
            final entries = state.entries;

            if (entries.isEmpty) {
              return const Center(
                child: Text('No files found'),
              );
            }

            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = entries[index];

                return ListTile(
                  dense: true,
                  leading: Icon(
                    e.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: e.isDirectory ? Colors.amber : Colors.white70,
                  ),
                  title: Text(
                    e.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    e.isDirectory ? 'Directory' : 'File',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    e.formattedSize,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
