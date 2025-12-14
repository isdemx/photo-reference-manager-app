import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class AddToEditWidget extends StatelessWidget {
  final VoidCallback onEdit;

  const AddToEditWidget({
    super.key,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Iconsax.edit, color: Colors.white),
      onPressed: onEdit,
      tooltip: 'Edit photo',
    );
  }

}