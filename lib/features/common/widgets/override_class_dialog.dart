// lib/features/teacher/widgets/override_class_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/timetable_entry.dart';
import '../../../core/models/timetable_override.dart';
import '../../../main.dart';

class OverrideClassDialog extends ConsumerStatefulWidget {
  final TimetableEntry entry;
  final String subjectName;
  final String dateString; // Format: YYYY-MM-DD
  final String currentTeacherId; // Pass the logged-in teacher's ID from the parent

  const OverrideClassDialog({
    super.key,
    required this.entry,
    required this.subjectName,
    required this.dateString,
    required this.currentTeacherId,
  });

  @override
  ConsumerState<OverrideClassDialog> createState() =>
      _OverrideClassDialogState();
}

class _OverrideClassDialogState extends ConsumerState<OverrideClassDialog> {
  bool _isCancelled = true;
  bool _isLoading = false;

  final _reasonCtrl = TextEditingController();
  final _newStartCtrl = TextEditingController();
  final _newEndCtrl = TextEditingController();
  final _newRoomCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newStartCtrl.text = widget.entry.startTime;
    _newEndCtrl.text = widget.entry.endTime;
    _newRoomCtrl.text = widget.entry.room;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _newStartCtrl.dispose();
    _newEndCtrl.dispose();
    _newRoomCtrl.dispose();
    super.dispose();
  }

  // Returns null if valid, or an error message string if not.
  String? _validateRescheduleFields() {
    final timeRegex = RegExp(r'^\d{2}:\d{2}$');

    if (!timeRegex.hasMatch(_newStartCtrl.text.trim())) {
      return 'Start time must be in HH:mm format (e.g. 10:30)';
    }
    if (!timeRegex.hasMatch(_newEndCtrl.text.trim())) {
      return 'End time must be in HH:mm format (e.g. 11:30)';
    }
    if (_newRoomCtrl.text.trim().isEmpty) {
      return 'Please enter the new room';
    }

    // Make sure end is actually after start
    final startParts = _newStartCtrl.text.split(':');
    final endParts = _newEndCtrl.text.split(':');
    final startMins =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (endMins <= startMins) {
      return 'End time must be after start time';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage: ${widget.subjectName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scheduled: ${widget.entry.startTime} – ${widget.entry.endTime}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Cancel Class'),
                  icon: Icon(Icons.cancel),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Reschedule'),
                  icon: Icon(Icons.update),
                ),
              ],
              selected: {_isCancelled},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() => _isCancelled = newSelection.first);
              },
            ),

            const SizedBox(height: 24),

            if (_isCancelled) ...[
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for cancellation (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Urgent meeting, Sick leave…',
                ),
                maxLines: 2,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newStartCtrl,
                      decoration: const InputDecoration(
                        labelText: 'New Start',
                        border: OutlineInputBorder(),
                        hintText: 'HH:mm',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _newEndCtrl,
                      decoration: const InputDecoration(
                        labelText: 'New End',
                        border: OutlineInputBorder(),
                        hintText: 'HH:mm',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newRoomCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Room',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Go Back'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submitOverride,
          style: FilledButton.styleFrom(
            backgroundColor: _isCancelled ? Colors.red : Colors.blue,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Text(
            _isCancelled ? 'Confirm Cancellation' : 'Update Class',
          ),
        ),
      ],
    );
  }

  Future<void> _submitOverride() async {
    // Validate reschedule fields before hitting Firestore
    if (!_isCancelled) {
      final error = _validateRescheduleFields();
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final overrideData = TimetableOverride(
        id: const Uuid().v4(),
        // FIX 1: correct field name from TimetableOverride model
        originalEntryId: widget.entry.id,
        date: widget.dateString,
        section: widget.entry.section,
        // FIX 2: correct field name + safe source (no .first on empty list)
        createdByTeacherId: widget.currentTeacherId,
        // FIX 3: required field that was missing entirely
        createdAt: DateTime.now(),
        isCancelled: _isCancelled,
        reason: _isCancelled ? _reasonCtrl.text.trim() : null,
        newStartTime: _isCancelled ? null : _newStartCtrl.text.trim(),
        newEndTime: _isCancelled ? null : _newEndCtrl.text.trim(),
        newRoom: _isCancelled ? null : _newRoomCtrl.text.trim(),
      );

      await ref
          .read(timetableRepoProvider)
          .createOverride(overrideData, widget.subjectName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCancelled
                  ? 'Class cancelled and students notified!'
                  : 'Class rescheduled and students notified!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}