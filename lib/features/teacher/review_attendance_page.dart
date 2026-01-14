// lib/features/teacher/review_attendance_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/attendance.dart';
import '../../core/models/user.dart';
import '../../core/models/subject.dart';
import '../../core/models/attendance_session.dart';
import '../../main.dart';
import '../../core/utils/time_formatter.dart';

final reviewProvider = FutureProvider.autoDispose.family((ref, String sessionId) async {
  final authRepo = ref.watch(authRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);

  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final session = (await attRepo.sessionsRef.doc(sessionId).get()).data();
  if (session == null) throw Exception('Session not found');

  final subject = await ttRepo.subjectById(session.subjectId);
  final students = await authRepo.studentsInSection(session.section);

  // Pass the session date. The Repo will handle the Timezone normalization.
  final records = await attRepo.forSubjectAndDate(session.subjectId, session.createdAt);

  return {
    'me': me,
    'session': session,
    'subject': subject,
    'students': students..sort((a, b) => (a.collegeRollNo ?? a.name).compareTo(b.collegeRollNo ?? b.name)),
    'records': records,
  };
});

class ReviewAttendancePage extends ConsumerStatefulWidget {
  final String? sessionId;
  const ReviewAttendancePage({super.key, this.sessionId});

  @override
  ConsumerState<ReviewAttendancePage> createState() => _ReviewAttendancePageState();
}

class _ReviewAttendancePageState extends ConsumerState<ReviewAttendancePage> {
  final Map<String, AttendanceStatus> _marks = {};
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isEditable = true;
  bool _dataLoaded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initializeMarks(List<AttendanceRecord> records, List<UserAccount> students) {
    if (_dataLoaded) return;
    final recordsMap = { for (var r in records) r.studentId : r.status };
    for (final s in students) {
      _marks[s.id] = recordsMap[s.id] ?? AttendanceStatus.absent;
    }
    _dataLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Error: No session ID provided.')));
    }

    final asyncData = ref.watch(reviewProvider(widget.sessionId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Attendance'),
        actions: const [ProfileAvatarAction()],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(reviewProvider(widget.sessionId!)),
        ),
        data: (data) {
          final session = data['session'] as AttendanceSession;
          final subject = data['subject'] as Subject?;
          final students = data['students'] as List<UserAccount>;
          final records = data['records'] as List<AttendanceRecord>;

          _initializeMarks(records, students);

          // FIX: Allow editing for 24 hours after session creation.
          // This prevents locking out teachers if a class ends near midnight.
          final now = DateTime.now().toUtc();
          final sessionTime = session.createdAt; // stored as UTC
          final hoursDiff = now.difference(sessionTime).inHours;
          _isEditable = hoursDiff < 24;

          final q = _searchCtrl.text.trim().toLowerCase();
          final visible = students.where((s) {
            if (q.isEmpty) return true;
            return s.name.toLowerCase().contains(q) || (s.collegeRollNo ?? '').toLowerCase().contains(q) || (s.examRollNo ?? '').toLowerCase().contains(q);
          }).toList();

          final presentCount = _marks.values.where((v) => v == AttendanceStatus.present).length;
          final absentCount = _marks.values.where((v) => v == AttendanceStatus.absent).length;
          final lateCount = _marks.values.where((v) => v == AttendanceStatus.late).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject?.name ?? 'Review', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _chipInfo(Icons.school, session.section),
                        _chipInfo(Icons.schedule, TimeFormatter.formatSlot(session.slot)),
                        if (!_isEditable)
                          _chipInfo(Icons.lock, 'Editing locked', color: Colors.red.shade100),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _pill('P', presentCount, Colors.green),
                        _pill('A', absentCount, Colors.red),
                        _pill('L', lateCount, Colors.orange),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [ Expanded(child: TextField(controller: _searchCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name / CR / ER')))]),
              ),
              const Divider(height: 0),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No students match'))
                    : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final st = visible[i];
                    final status = _marks[st.id] ?? AttendanceStatus.absent;
                    return _StudentEditRow(
                      name: st.name,
                      cr: st.collegeRollNo,
                      status: status,
                      isEditable: _isEditable,
                      onStatusChanged: (newStatus) {
                        if (newStatus == null) return;
                        setState(() { _marks[st.id] = newStatus; });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor.withAlpha(250),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _isEditable ? () => _saveAttendance() : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Text(_isEditable ? 'Save Changes' : 'Editing Locked', style: TextStyle(fontWeight: FontWeight.w800, color: _isEditable ? null : Colors.grey.shade700)),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final asyncData = ref.read(reviewProvider(widget.sessionId!));
    if (asyncData.value == null) return;

    final data = asyncData.value!;
    final me = data['me'] as UserAccount;
    final session = data['session'] as AttendanceSession;

    final attendanceRepo = ref.read(attendanceRepoProvider);

    for (final mark in _marks.entries) {
      await attendanceRepo.mark(
        subjectId: session.subjectId,
        studentId: mark.key,
        // Pass session creation time; repo handles Local Midnight normalization
        date: session.createdAt,
        slot: session.slot,
        status: mark.value,
        markedByTeacherId: me.id,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance changes saved')));
    context.pop();
  }

  Widget _chipInfo(IconData icon, String text, {Color? color}) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Flexible(child: Text(text, overflow: TextOverflow.ellipsis, softWrap: false))]);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: color ?? Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: child);
  }

  Widget _pill(String label, int n, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 6, backgroundColor: color), const SizedBox(width: 6), Text('$label: $n', style: TextStyle(color: color, fontWeight: FontWeight.w700))]));
  }
}

class _StudentEditRow extends StatelessWidget {
  final String name;
  final String? cr;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus?> onStatusChanged;
  final bool isEditable;

  const _StudentEditRow({required this.name, this.cr, required this.status, required this.onStatusChanged, required this.isEditable});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.black87, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white))),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text((cr ?? '').isNotEmpty ? 'CR: $cr' : 'No Roll No.'),
      trailing: SegmentedButton<AttendanceStatus>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: AttendanceStatus.present, label: Text('P')),
          ButtonSegment(value: AttendanceStatus.absent, label: Text('A')),
          ButtonSegment(value: AttendanceStatus.late, label: Text('L')),
          ButtonSegment(value: AttendanceStatus.excused, label: Text('E')),
        ],
        selected: {status},
        onSelectionChanged: isEditable ? (sel) => onStatusChanged(sel.first) : null,
        style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: _statusColor(status).withAlpha(40),
            selectedForegroundColor: _statusColor(status),
            side: BorderSide(color: Colors.grey.shade300),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            disabledBackgroundColor: status == AttendanceStatus.absent ? Colors.red.withAlpha(15) : Colors.grey.withAlpha(15)
        ),
      ),
    );
  }

  Color _statusColor(AttendanceStatus st) => switch(st) {
    AttendanceStatus.present => Colors.green,
    AttendanceStatus.absent => Colors.red,
    AttendanceStatus.late => Colors.orange,
    AttendanceStatus.excused => Colors.blue,
  };
}