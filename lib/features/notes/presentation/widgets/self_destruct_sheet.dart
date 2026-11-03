import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
import 'package:mynotes/core/format/dates.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/core/theme/widgets/notely_sheet.dart';

class SelfDestructSheet extends StatefulWidget {
  final DateTime? initialDate;
  final bool initialOnRead;

  const SelfDestructSheet({
    super.key,
    required this.initialDate,
    required this.initialOnRead,
  });

  @override
  State<SelfDestructSheet> createState() => _SelfDestructSheetState();
}

class _SelfDestructSheetState extends State<SelfDestructSheet> {
  late DateTime? _date;
  late bool _onRead;
  late bool _hasSettings;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _onRead = widget.initialOnRead;
    _hasSettings = widget.initialDate != null || widget.initialOnRead;
  }

  @override
  Widget build(BuildContext context) {
    final notely = NotelyTheme.of(context);
    return NotelySheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Self-destruct', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'The note, its versions and comments are deleted for good. Copies a collaborator already opened stay on their device.',
            style: TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.45, color: notely.text2),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: notely.text2),
            title: const Text('On a date'),
            subtitle: Text(_date != null ? formatDateTime(_date!) : 'Not set'),
            trailing: OutlinedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now().add(const Duration(hours: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    _date ?? DateTime.now().add(const Duration(hours: 1)),
                  ),
                );
                if (time == null || !mounted) return;
                setState(() {
                  _date = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              child: Text(_date == null ? 'Pick' : 'Change'),
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.visibility_off_outlined, color: notely.text2),
            title: const Text('After reading once'),
            subtitle: const Text('Deleted when you close it'),
            value: _onRead,
            onChanged: (value) {
              setState(() => _onRead = value);
            },
          ),
          if (_hasSettings) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(<String, dynamic>{
                  'date': null,
                  'onRead': false,
                });
              },
              style: TextButton.styleFrom(foregroundColor: notely.danger),
              child: const Text('Turn off self-destruct'),
            ),
          ],
          const SizedBox(height: 24),
          NotelyPrimaryButton(
            label: 'Apply',
            onPressed: () {
              Navigator.of(context).pop(<String, dynamic>{
                'date': _date,
                'onRead': _onRead,
              });
            },
          ),
        ],
      ),
    );
  }
}
