import 'package:flutter/material.dart';
import 'package:mynotes/core/theme/notely_tokens.dart';
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
              Icon(Icons.timer_outlined, color: notely.text2),
              const SizedBox(width: 12),
              Text(
                'Self-destruct settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: notely.text2),
            title: const Text('Timed destruction'),
            subtitle: Text(
              _date != null
                  ? '${_date!.month}/${_date!.day}/${_date!.year} ${_date!.hour.toString().padLeft(2, '0')}:${_date!.minute.toString().padLeft(2, '0')}'
                  : 'Not set',
            ),
            trailing: FilledButton.tonal(
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
              child: const Text('Pick'),
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.visibility_off_outlined, color: notely.text2),
            title: const Text('Delete after first read'),
            subtitle: const Text('Note disappears once opened'),
            value: _onRead,
            onChanged: (value) {
              setState(() => _onRead = value);
            },
          ),
          if (_hasSettings) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(<String, dynamic>{
                    'date': null,
                    'onRead': false,
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove self-destruct'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, dynamic>{
                  'date': _date,
                  'onRead': _onRead,
                });
              },
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
