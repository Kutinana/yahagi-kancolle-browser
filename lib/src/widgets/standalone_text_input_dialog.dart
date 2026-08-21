import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_input_dialog.dart';

class StandaloneTextInputDialog extends StatefulWidget {
  const StandaloneTextInputDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.fieldKey,
    required this.cancelKey,
    required this.confirmKey,
    required this.cancelLabel,
    required this.confirmLabel,
    this.keyboardType,
    this.inputFormatters,
    this.validate,
  });

  final String title;
  final String label;
  final String initialValue;
  final Key fieldKey;
  final Key cancelKey;
  final Key confirmKey;
  final String cancelLabel;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String value)? validate;

  @override
  State<StandaloneTextInputDialog> createState() =>
      _StandaloneTextInputDialogState();
}

class _StandaloneTextInputDialogState extends State<StandaloneTextInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveInputDialog(
    title: Text(widget.title),
    content: TextField(
      key: widget.fieldKey,
      controller: _controller,
      autofocus: true,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _errorText,
      ),
      textInputAction: TextInputAction.done,
      onChanged: (_) {
        if (_errorText != null) setState(() => _errorText = null);
      },
      onSubmitted: (_) => _submit(),
    ),
    actions: <Widget>[
      TextButton(
        key: widget.cancelKey,
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      TextButton(
        key: widget.confirmKey,
        onPressed: _submit,
        child: Text(widget.confirmLabel),
      ),
    ],
  );

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validate?.call(value);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.pop(context, value);
  }
}
