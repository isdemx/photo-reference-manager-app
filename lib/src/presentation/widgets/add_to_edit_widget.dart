import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

class AddToEditWidget extends StatelessWidget {
  final VoidCallback onEdit;

  const AddToEditWidget({
    super.key,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Iconsax.edit, color: context.appThemeColors.text),
      onPressed: onEdit,
      tooltip: 'Edit photo',
    );
  }
}
