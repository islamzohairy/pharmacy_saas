import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';

/// Result of the PIN entry dialog.
enum PinEntryResult { verified, cancelled, forgot }

/// Modal PIN gate shown when switching to a PIN-protected profile.
///
/// Returns [PinEntryResult.verified] only after [onVerify] accepts the
/// entered PIN; [PinEntryResult.forgot] signals the caller to run the
/// no-recovery reset path.
Future<PinEntryResult> showPinEntryDialog(
  BuildContext context, {
  required Future<bool> Function(String pin) onVerify,
}) {
  return showDialog<PinEntryResult>(
    context: context,
    builder: (dialogContext) => _PinEntryDialog(onVerify: onVerify),
  ).then((result) => result ?? PinEntryResult.cancelled);
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog({required this.onVerify});

  final Future<bool> Function(String pin) onVerify;

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.onVerify(_pinController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(PinEntryResult.verified);
    } else {
      setState(() {
        _checking = false;
        _error = context.l10n.pinWrong;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.enterPinTitle),
      content: TextField(
        controller: _pinController,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: InputDecoration(
          labelText: l10n.pinLabel,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _checking ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(PinEntryResult.forgot),
          child: Text(l10n.forgotPin),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(PinEntryResult.cancelled),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
