// bin/run_seeder.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:campus_track/firebase_options.dart';
import 'package:campus_track/core/models/user.dart';
import 'package:campus_track/core/models/subject.dart';
import 'package:campus_track/core/models/timetable_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('--- SEEDER SCRIPT STARTED ---');
  await Seeder().seedIfNeeded();
  debugPrint('--- SEEDER SCRIPT FINISHED. YOU CAN CLOSE THIS APP NOW. ---');
}

class Seeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedIfNeeded() async {
    try {
      final subjectSnapshot = await _db.collection('subjects').limit(1).get();
      if (subjectSnapshot.docs.isNotEmpty) {
        debugPrint('Timetable already seeded. Please delete "subjects" and "timetable" collections to re-seed.');
        return;
      }

      debugPrint('Fetching real teachers from database...');
      final teacherSnapshot = await _db.collection('users').where('role', isEqualTo: 'teacher').get();

      if (teacherSnapshot.docs.isEmpty) {
        debugPrint('⚠️ SEEDER STOPPED: No teachers found in the database!');
        return;
      }

      final realTeachers = teacherSnapshot.docs
          .map((doc) => UserAccount.fromMap(doc.id, doc.data()))
          .toList();

      // --- IMPROVED SMART TEACHER MATCHING ---
      int fallbackIndex = 0;
      UserAccount getTeacher(String partialName) {
        try {
          return realTeachers.firstWhere(
                  (t) => t.name.toLowerCase().contains(partialName.toLowerCase())
          );
        } catch (e) {
          // If name doesn't match, distribute evenly instead of dumping on the first teacher
          final fallback = realTeachers[fallbackIndex % realTeachers.length];
          fallbackIndex++;
          debugPrint('⚠️ WARNING: Could not find "$partialName". Assigned to ${fallback.name} instead.');
          return fallback;
        }
      }

      // Map the exact faculty from your syllabus
      final sheetal = getTeacher('sheetal');
      final pradeep = getTeacher('pradeep');
      final raghbendra = getTeacher('raghbendra');
      final sangeeta = getTeacher('sangeeta');
      final swati = getTeacher('swati');
      final amit = getTeacher('amit');
      final sunita = getTeacher('sunita');
      final shivani = getTeacher('shivani');
      final sanjeev = getTeacher('sanjeev');
      final brajesh = getTeacher('brajesh');
      final shikha = getTeacher('shikha');

      final batch = _db.batch();
      const id = Uuid();

      Subject createSub(String code, String name, String sec, UserAccount teacher) {
        final s = Subject(
          id: id.v4(),
          code: code,
          name: name,
          department: 'Electronics',
          semester: sec.split('-')[0],
          section: sec,
          teacherId: teacher.id,
        );
        batch.set(_db.collection('subjects').doc(s.id), s.toMap());
        return s;
      }

      void addE(Subject subject, String day, String start, String end, String room) {
        final entry = TimetableEntry(
          id: id.v4(),
          subjectId: subject.id,
          dayOfWeek: day,
          startTime: start,
          endTime: end,
          room: room,
          section: subject.section,
          teacherIds: [subject.teacherId],
        );
        batch.set(_db.collection('timetable').doc(entry.id), entry.toMap());
      }

      // =========================================================
      // YEAR 1 (Section: I-HE)
      // =========================================================
      final de = createSub('DE', 'Digital Electronics', 'I-HE', sheetal);
      final inst = createSub('INST', 'Instrumentation', 'I-HE', pradeep);
      final ae1 = createSub('AE1', 'Analog Electronics 1', 'I-HE', raghbendra);
      final vac1 = createSub('VAC', 'VAC (E&C/Skill)', 'I-HE', sanjeev);
      final aec = createSub('AEC', 'AEC', 'I-HE', amit);

      // FIX: Split shared electives into distinct subjects
      final secIT = createSub('SEC-IT', 'SEC IT Tools', 'I-HE', swati);
      final secPy = createSub('SEC-PY', 'SEC Python', 'I-HE', sheetal);
      final geDSD = createSub('GE-DSD', 'GE DSD', 'I-HE', sheetal);
      final geDVT = createSub('GE-DVT', 'GE DVT', 'I-HE', sangeeta);

      final deL = createSub('DE-L', 'Digital Electronics Lab', 'I-HE', amit); // Co-taught with Sunita
      final instL = createSub('INST-L', 'Instrumentation Lab', 'I-HE', pradeep); // Co-taught with Swati
      final ae1L = createSub('AE1-L', 'Analog Electronics 1 Lab', 'I-HE', raghbendra); // Co-taught with Sangeeta
      final geL = createSub('GE-L', 'GE DSD/DVT Lab', 'I-HE', sheetal); // Co-taught with Raghbendra

      // Mon (1)
      addE(de, '1', '09:00', '11:00', 'New Room');
      addE(inst, '1', '11:00', '13:00', 'New Room');
      addE(vac1, '1', '15:00', '17:00', 'New Room');
      // Tue (2)
      addE(ae1, '2', '09:00', '11:00', 'New Room');
      addE(de, '2', '11:00', '12:00', 'New Room');
      addE(inst, '2', '12:00', '13:00', 'New Room');
      addE(geDSD, '2', '14:00', '15:00', 'New Room');
      addE(geDVT, '2', '14:00', '15:00', 'New Room');
      // Wed (3)
      addE(ae1L, '3', '11:00', '13:00', 'New Electronics Lab');
      addE(secIT, '3', '13:00', '15:00', 'New Electronics Lab');
      addE(secPy, '3', '13:00', '15:00', 'New Room');
      addE(vac1, '3', '15:00', '16:00', 'New Room');
      // Thu (4)
      addE(instL, '4', '11:00', '13:00', 'New Electronics Lab');
      addE(ae1, '4', '13:00', '14:00', 'New Room');
      addE(geDSD, '4', '14:00', '15:00', 'New Room');
      addE(geDVT, '4', '14:00', '15:00', 'New Room');
      addE(geL, '4', '15:00', '17:00', 'New Electronics Lab');
      addE(aec, '4', '17:00', '18:00', 'New Room');
      // Fri (5)
      addE(deL, '5', '11:00', '13:00', 'New Electronics Lab');
      addE(geDSD, '5', '14:00', '15:00', 'New Room');
      addE(geDVT, '5', '14:00', '15:00', 'New Room');
      addE(aec, '5', '15:00', '17:00', 'New Room');
      // Sat (6)
      addE(secIT, '6', '11:00', '13:00', 'New Electronics Lab');
      addE(secPy, '6', '11:00', '13:00', 'New Room');
      addE(vac1, '6', '13:00', '14:00', 'New Room');

      // =========================================================
      // YEAR 2 (Section: II-HE)
      // =========================================================
      final et = createSub('ET', 'Electrical Technology', 'II-HE', swati);
      final mp = createSub('MP', 'Microprocessor', 'II-HE', amit);
      final cs = createSub('CS', 'Communication System', 'II-HE', sangeeta);
      final iot = createSub('IOT', 'IoT / GE IoT', 'II-HE', pradeep);
      final secL = createSub('SEC-L', 'SEC LaTeX', 'II-HE', shivani); // Fixed to Shivani
      final vac2 = createSub('VAC2', 'VAC', 'II-HE', sunita);
      final aec2 = createSub('AEC2', 'AEC', 'II-HE', amit);

      final etL = createSub('ET-L', 'Electrical Technology Lab', 'II-HE', swati);
      final mpL = createSub('MP-L', 'Microprocessor Lab', 'II-HE', amit);
      final csL = createSub('CS-L', 'Communication System Lab', 'II-HE', shivani); // Co-taught
      final iotL = createSub('IOT-L', 'GE IoT Lab', 'II-HE', swati); // Co-taught

      // Mon (1)
      addE(etL, '1', '09:00', '11:00', 'New Electronics Lab');
      addE(mpL, '1', '11:00', '13:00', 'New Electronics Lab');
      // Tue (2)
      addE(csL, '2', '09:00', '11:00', 'New Electronics Lab');
      addE(mp, '2', '11:00', '13:00', 'Room 301');
      addE(iot, '2', '13:00', '14:00', 'Room 301');
      addE(et, '2', '14:00', '15:00', 'New Room');
      addE(vac2, '2', '15:00', '17:00', 'New Room');
      // Wed (3)
      addE(et, '3', '11:00', '13:00', 'New Room');
      addE(iot, '3', '13:00', '14:00', 'New Room');
      addE(aec2, '3', '15:00', '17:00', 'New Room');
      // Thu (4)
      addE(mp, '4', '11:00', '12:00', 'New Room');
      addE(cs, '4', '12:00', '13:00', 'Room 301');
      addE(secL, '4', '13:00', '15:00', 'New Electronics Lab');
      addE(vac2, '4', '15:00', '16:00', 'PANCH 301');
      // Fri (5)
      addE(cs, '5', '11:00', '13:00', 'Room 301');
      addE(iot, '5', '13:00', '14:00', 'New Electronics Lab');
      addE(iotL, '5', '14:00', '16:00', 'New Electronics Lab');
      // Sat (6)
      addE(secL, '6', '09:00', '11:00', 'New Electronics Lab');

      // =========================================================
      // YEAR 3 (Section: III-HE)
      // =========================================================
      final aiml = createSub('AIML', 'Artificial Intelligence & ML', 'III-HE', shivani);
      final sdt = createSub('SDT', 'Semiconductor Device Tech', 'III-HE', sanjeev);
      final dsp = createSub('DSP', 'Digital Signal Processing', 'III-HE', brajesh);
      final phot = createSub('PHOT', 'Photonics', 'III-HE', sunita);
      final rm = createSub('RM', 'Research Methodology', 'III-HE', shivani);

      // FIX: Split SEC into separate subjects
      final secApp = createSub('SEC-APP', 'SEC App Dev', 'III-HE', sheetal);
      final secTour = createSub('SEC-TOUR', 'SEC E-Tour', 'III-HE', sangeeta);

      final aimlL = createSub('AIML-L', 'AIML Lab', 'III-HE', shivani);
      final sdtL = createSub('SDT-L', 'Semiconductor Tech Lab', 'III-HE', sanjeev);
      final dspL = createSub('DSP-L', 'DSP Lab', 'III-HE', brajesh);
      final photL = createSub('PHOT-L', 'Photonics Lab', 'III-HE', sunita);
      final rmL = createSub('RM-L', 'Research Methodology Lab', 'III-HE', shivani);

      // Mon (1)
      addE(aiml, '1', '09:00', '11:00', 'Room 301');
      addE(sdt, '1', '11:00', '13:00', 'New Room');
      addE(secApp, '1', '13:00', '15:00', 'New Electronics Lab');
      addE(secTour, '1', '13:00', '15:00', 'New Room');
      addE(dsp, '1', '15:00', '17:00', 'New Electronics Lab');
      // Tue (2)
      addE(dspL, '2', '09:00', '11:00', 'New Electronics Lab');
      addE(sdtL, '2', '11:00', '13:00', 'New Electronics Lab');
      addE(aimlL, '2', '13:00', '15:00', 'New Electronics Lab');
      addE(aiml, '2', '15:00', '16:00', 'New Room');
      // Wed (3)
      addE(phot, '3', '10:00', '11:00', 'New Electronics Lab');
      addE(photL, '3', '11:00', '13:00', 'Physics Lab');
      addE(rmL, '3', '14:00', '16:00', 'New Room');
      // Thu (4)
      addE(sdt, '4', '10:00', '11:00', 'Room 301');
      addE(phot, '4', '11:00', '13:00', 'Room 301');
      // Fri (5)
      addE(dsp, '5', '09:00', '10:00', 'New Electronics Lab');
      addE(rm, '5', '10:00', '11:00', 'New Room');
      addE(secApp, '5', '13:00', '15:00', 'New Room');
      addE(secTour, '5', '13:00', '15:00', 'Room 301');
      // Sat (6)
      addE(rm, '6', '12:00', '14:00', 'Room 301');

      // =========================================================
      // YEAR 4 (Section: IV-HE)
      // =========================================================
      final cavd = createSub('CAVD', 'CMOS Analog VLSI Design', 'IV-HE', shikha);
      final pe = createSub('PE', 'Power Electronics', 'IV-HE', raghbendra);
      final nmc = createSub('NMC', 'Nanomaterial Characterization', 'IV-HE', sanjeev);
      final msc = createSub('MSC', 'Mobile & Satellite Comm.', 'IV-HE', brajesh);

      final cavdL = createSub('CAVD-L', 'CAVD Lab', 'IV-HE', shikha);
      final peL = createSub('PE-L', 'Power Electronics Lab', 'IV-HE', raghbendra);
      final nmcL = createSub('NMC-L', 'NMC Lab', 'IV-HE', sanjeev);
      final mscL = createSub('MSC-L', 'MSC Lab', 'IV-HE', brajesh);

      // Mon (1) & Tue (2) - No Classes for 4th Year

      // Wed (3)
      addE(cavdL, '3', '09:00', '11:00', 'New Room');
      addE(cavd, '3', '13:00', '15:00', 'Room 301');
      // Thu (4)
      addE(peL, '4', '09:00', '11:00', 'New Electronics Lab');
      addE(nmcL, '4', '13:00', '15:00', 'New Electronics Lab');
      addE(nmc, '4', '15:00', '17:00', 'New Room');
      // Fri (5)
      addE(pe, '5', '09:00', '11:00', 'New Room');
      addE(nmc, '5', '11:00', '12:00', 'New Room');
      addE(msc, '5', '12:00', '13:00', 'New Room');
      // Sat (6)
      addE(pe, '6', '09:00', '10:00', 'Room 301');
      addE(msc, '6', '10:00', '12:00', 'Room 301');
      addE(mscL, '6', '13:00', '15:00', 'New Electronics Lab');
      addE(cavd, '6', '15:00', '16:00', 'Room 301');

      // ---------------------------------------------------------
      await batch.commit();
      debugPrint('Successfully seeded all 4 years with proper Smart Teacher matching!');
    } catch (e) {
      debugPrint('Error seeding data: $e');
    }
  }
}