import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

Future<String?> showPlayerNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _PlayerNameDialog(),
  );
}

class _PlayerNameDialog extends StatefulWidget {
  const _PlayerNameDialog();

  @override
  State<_PlayerNameDialog> createState() => _PlayerNameDialogState();
}

class _PlayerNameDialogState extends State<_PlayerNameDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'الرجاء إدخال اسم');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اسم اللاعب'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'أدخل اسمك',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
            child: Text('تأكيد'),
          ),
        ),
      ],
    );
  }
}
