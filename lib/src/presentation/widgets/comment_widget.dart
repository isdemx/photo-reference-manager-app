// lib/src/presentation/widgets/comment_widget.dart

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/presentation/widgets/ok_button_widget.dart';

class CommentWidget extends StatefulWidget {
  final String initialComment;
  final Function(String) onCommentSaved;

  const CommentWidget({
    super.key,
    required this.initialComment,
    required this.onCommentSaved,
  });

  @override
  _CommentWidgetState createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _showOkButton = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment);
  }

  void _onTextChanged() {
    setState(() {
      _showOkButton = true;
    });
  }

  void _onOkPressed() {
    widget.onCommentSaved(_controller.text.trim());
    setState(() {
      _isEditing = false;
      _showOkButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_isEditing) {
          setState(() {
            _isEditing = true;
          });
        }
      },
      child: _isEditing
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => _onTextChanged(),
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter comment',
                    ),
                  ),
                ),
                if (_showOkButton)
                  OkButtonWidget(
                    onPressed: _onOkPressed,
                  ),
              ],
            )
          : Text(
              widget.initialComment.isEmpty
                  ? 'Tap to add a comment'
                  : widget.initialComment,
              style: const TextStyle(color: Colors.white),
            ),
    );
  }
}
