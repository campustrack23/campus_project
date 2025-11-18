import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../services/local_storage.dart';

class Seeder {
  final LocalStorage store;
  Seeder(this.store);

  // Period times (I..IX)
  static const List<String> _times = [
    '08:30-09:30','09:30-10:30','10:30-11:30','11:30-12:30','12:30-13:30',
    '13:30-14:30','14:30-15:30','15:30-16:30','16:30-17:30',
  ];
  String _start(int p) => _times[p].split('-').first;
  String _end(int p) => _times[p].split('-').last;

  Future<void> seedIfNeeded() async {
    if (store.isSeeded) return;

    final now = DateTime.now();
    const id = Uuid();

    // Admin
    final admin = UserAccount(
      id: id.v4(),
      role: UserRole.admin,
      name: 'Admin',
      email: 'admin@college.edu',
      phone: '0000000000',
      passwordHash: UserAccount.hashPassword('Admin@123'),
      createdAt: now,
    );

    // Teachers
    final tShikha = _teacher(id, now, 'Dr. Shikha',                'shikha@college.edu', '9999901001'); // G1
    final tSS     = _teacher(id, now, 'Prof. Sangeeta Srivastava', 'ss@college.edu',     '9999901101'); // SS
    final tSA     = _teacher(id, now, 'Dr. Sunita Arya',           'sa@college.edu',     '9999901102'); // SA
    final tSN     = _teacher(id, now, 'Prof. Swati Nagpal',        'sn@college.edu',     '9999901103'); // SN
    final tAJ     = _teacher(id, now, 'Prof. Amit Jain',           'aj@college.edu',     '9999901104'); // AJ
    final tSK     = _teacher(id, now, 'Dr. Sanjeev Kumar',         'sk@college.edu',     '9999901105'); // SK
    final tRST    = _teacher(id, now, 'Dr. Raghbendra S. Tomar',   'rst@college.edu',    '9999901106'); // RST
    final tHM     = _teacher(id, now, 'Mr. Harshmani',             'hmy@college.edu',    '9999901107'); // HM
    final tVK     = _teacher(id, now, 'Mr. Vinay Kumar',           'vk@college.edu',     '9999901108'); // VK
    final tSY     = _teacher(id, now, 'Ms. Sheetal Yadav',         'sy@college.edu',     '9999901109'); // SY
    final tSHS    = _teacher(id, now, 'Dr. Shivani Sital',         'shs@college.edu',    '9999901110'); // SHS

    // IV-HE students (sample)
    final studentsIV = <UserAccount>[
      _stu(id, now, 'Akshay Kumar',        '6302', '22055558010', '9000000002', 4, 'IV-HE'),
      _stu(id, now, 'Amit Kumar',          '6304', '22055558009', '9000000004', 4, 'IV-HE'),
      _stu(id, now, 'Ashwin Parmar',       '6306', '22055558005', '9000000005', 4, 'IV-HE'),
      _stu(id, now, 'Chandan Kumar Singh', '6307', '22055558002', '9000000006', 4, 'IV-HE'),
      _stu(id, now, 'Salman Khan',         '6318', '22055558012', '9000000009', 4, 'IV-HE'),
      _stu(id, now, 'Shruti',              '6321', '22055558008', '9000000010', 4, 'IV-HE'),
      _stu(id, now, 'Yash Gulati',         '6323', '22055558003', '9000000012', 4, 'IV-HE'),
      _stu(id, now, 'Aditya Sharma',       '6329', '22055558016', '9000000015', 4, 'IV-HE'),
      _stu(id, now, 'Sankalan Saha',       '6333', '22055558020', '9000000018', 4, 'IV-HE'),
      _stu(id, now, 'Ayush Verma',         '6336', '22055558026', '9000000021', 4, 'IV-HE'),
      _stu(id, now, 'Mohit Chauhan',       '6341', '22055558021', '9000000026', 4, 'IV-HE'),
    ];

    final users = <UserAccount>[
      admin,
      tShikha, tSS, tSA, tSN, tAJ, tSK, tRST, tHM, tVK, tSY, tSHS,
      ...studentsIV,
    ];
    await store.writeList(LocalStorage.kUsers, users.map((e) => e.toMap()).toList());

    // Subjects per section (I..III kept same as before)
    final y1 = _YearKit(section: 'I-HE', id: id, owner: this);
    final subjPFP      = y1.subj('PFP',      'Programming Fundamentals (Python)', tSHS);
    final subjpfpLab  = y1.subj('PFP LAB',  'PFP Lab',                            tSHS);
    final subjSD       = y1.subj('SD',       'Semiconductor Devices',              tSN);
    final subjsdLab   = y1.subj('SD LAB',   'Semiconductor Devices Lab',          tSN);
    final subjCTN      = y1.subj('CTN',      'Circuit Theory & Network Analysis',  tSS);
    final subjctnLab  = y1.subj('CTN LAB',  'CTN Lab',                            tSS);
    final subjAEC1     = y1.subj('AEC',      'Ability Enhancement Course',         tShikha);
    final subjGE1      = y1.subj('GE',       'Generic Elective',                   tShikha);
    final subjge1Tut  = y1.subj('GE TUT',   'GE Lab/Tutorial',                    tShikha);
    final subjVAC1     = y1.subj('VAC',      'Value Addition Course',              tShikha);
    final subjSEC1     = y1.subj('SEC',      'Skill Enhancement Course',           tShikha);

    final y2 = _YearKit(section: 'II-HE', id: id, owner: this);
    final subjEM       = y2.subj('EM',       'Engineering Mathematics',            tSK);
    final subjemLab   = y2.subj('EM LAB',   'EM Lab',                             tSA);
    final subjAE2      = y2.subj('AE-II',    'Analog Electronics - II',            tAJ);
    final subjae2Lab  = y2.subj('AE-II LAB','AE-II Lab',                          tAJ);
    final subjSNS      = y2.subj('S&S',      'Signals and Systems',                tRST);
    final subjsnsLab  = y2.subj('S&S LAB',  'S&S Lab',                            tRST);
    final subjAEC2     = y2.subj('AEC',      'Ability Enhancement Course',         tShikha);
    final subjGEAIML   = y2.subj('GE/AIML',  'GE / AI-ML (DSE)',                   tHM);
    y2.subj('GE TUT',   'GE Lab/Tutorial',                    tShikha);
    final subjSEC2     = y2.subj('SEC',      'Skill Enhancement Course',           tShikha);

    final y3 = _YearKit(section: 'III-HE', id: id, owner: this);
    final subjCN       = y3.subj('CN',       'Computer Networks',                   tVK);
    final subjcnLab   = y3.subj('CN LAB',   'CN Lab',                              tVK);
    final subjES       = y3.subj('ES',       'Embedded Systems',                    tSY);
    final subjesLab   = y3.subj('ES LAB',   'ES Lab',                              tSY);
    final subjEMT      = y3.subj('EMT',      'Electromagnetics',                    tSA);
    final subjemtLab  = y3.subj('EMT LAB',  'EMT Lab',                             tSA);
    final subjVLSI     = y3.subj('VLSI',     'Basic VLSI Design',                   tSK);
    final subjvlsiLab = y3.subj('VLSI LAB', 'VLSI Lab',                            tSK);
    final subjGE3      = y3.subj('GE',       'Generic Elective',                    tShikha);
    final subjSEC3     = y3.subj('SEC',      'Skill Enhancement Course',            tShikha);

    // Year 4 (IV-HE) — adjusted per your latest request
    final y4 = _YearKit(section: 'IV-HE', id: id, owner: this);
    final subjCMOS     = y4.subj('CMOS',     'CMOS Digital VLSI Design',            tShikha);
    final subjAML      = y4.subj('AML',      'Advanced Machine Learning',           tSHS);
    final subjAES      = y4.subj('AES',      'Advanced Embedded Systems',           tSY);
    final subjCS       = y4.subj('CS',       'Control Systems',                     tRST);
    final subjcmosLab = y4.subj('CMOS LAB', 'CMOS Lab',                            tShikha);
    final subjamlLab  = y4.subj('AML LAB',  'AML Lab',                             tSHS);
    final subjaesLab  = y4.subj('AES LAB',  'AES Lab',                             tSY);
    final subjcsLab   = y4.subj('CS LAB',   'CS Lab',                              tRST);

    // Save subjects
    final subjectsAll = [
      ...y1.subjects, ...y2.subjects, ...y3.subjects, ...y4.subjects,
    ];
    await store.writeList(LocalStorage.kSubjects, subjectsAll.map((e) => e.toMap()).toList());

    // Timetable builder
    final List<TimetableEntry> tt = [];
    void addBlock(String section, String day, int fromP, int toP, Subject subj, String room, List<String> teachers) {
      for (int p = fromP; p <= toP; p++) {
        tt.add(TimetableEntry(
          id: id.v4(),
          subjectId: subj.id,
          dayOfWeek: day,
          startTime: _start(p),
          endTime: _end(p),
          room: room,
          section: section,
          teacherIds: teachers,
        ));
      }
    }

    // (I-HE) unchanged
    addBlock('I-HE','Mon',0,1, subjPFP,     '301', [tSHS.id]);
    addBlock('I-HE','Mon',2,3, subjpfpLab, 'NEL', [tSHS.id, tSN.id]);
    addBlock('I-HE','Mon',4,4, subjSD,      '301', [tSN.id]);
    addBlock('I-HE','Mon',6,8, subjVAC1,    'NR',  [tShikha.id]);
    addBlock('I-HE','Tue',2,3, subjCTN,     '301', [tSS.id]);
    addBlock('I-HE','Tue',4,4, subjAEC1,    'NR',  [tShikha.id]);
    addBlock('I-HE','Wed',0,0, subjPFP,     'NR',  [tSHS.id]);
    addBlock('I-HE','Wed',2,3, subjsdLab,  'NEL', [tSN.id, tSS.id]);
    addBlock('I-HE','Wed',5,5, subjGE1,     'NR',  [tShikha.id]);
    addBlock('I-HE','Wed',6,8, subjVAC1,    'NR',  [tShikha.id]);
    addBlock('I-HE','Thu',0,1, subjSD,      'NR',  [tSN.id]);
    addBlock('I-HE','Thu',3,3, subjCTN,     'NR',  [tSS.id]);
    addBlock('I-HE','Thu',5,5, subjGE1,     'NR',  [tShikha.id]);
    addBlock('I-HE','Thu',6,8, subjge1Tut, 'NR',  [tShikha.id]);
    addBlock('I-HE','Fri',0,0, subjAEC1,    'NR',  [tShikha.id]);
    addBlock('I-HE','Fri',2,4, subjctnLab, 'NEL', [tSS.id, tAJ.id]);
    addBlock('I-HE','Fri',5,5, subjGE1,     'NR',  [tShikha.id]);
    addBlock('I-HE','Sat',6,8, subjSEC1,    'NR',  [tShikha.id]);

    // (II-HE) unchanged
    addBlock('II-HE','Mon',0,0, subjEM,      '301', [tSK.id]);
    addBlock('II-HE','Mon',3,4, subjemLab,  'NR',  [tShikha.id, tSA.id]);
    addBlock('II-HE','Tue',1,2, subjae2Lab, 'NEL', [tAJ.id, tSA.id]);
    addBlock('II-HE','Tue',3,3, subjAE2,     '301', [tAJ.id, tSA.id]);
    addBlock('II-HE','Tue',4,5, subjEM,      'NR',  [tShikha.id]);
    addBlock('II-HE','Wed',0,1, subjSNS,     '301', [tRST.id]);
    addBlock('II-HE','Wed',2,3, subjAE2,     '301', [tAJ.id]);
    addBlock('II-HE','Wed',4,4, subjGEAIML,  'NR',  [tHM.id]);
    addBlock('II-HE','Wed',5,5, subjAEC2,    'NR',  [tShikha.id]);
    addBlock('II-HE','Wed',6,8, subjSEC2,    'NR',  [tShikha.id]);
    addBlock('II-HE','Thu',3,3, subjAE2,     '301', [tAJ.id]);
    addBlock('II-HE','Thu',4,4, subjAEC2,    'NR',  [tShikha.id]);
    addBlock('II-HE','Fri',0,1, subjSNS,     'NEL', [tRST.id]);
    addBlock('II-HE','Fri',2,2, subjsnsLab, 'NR',  [tRST.id]);
    addBlock('II-HE','Fri',4,5, subjGEAIML,  'NR',  [tHM.id]);
    addBlock('II-HE','Sat',6,8, subjSEC2,    'NR',  [tShikha.id]);

    // (III-HE) unchanged
    addBlock('III-HE','Mon',0,3, subjGE3,     'NR',  [tShikha.id]);
    addBlock('III-HE','Mon',5,8, subjSEC3,    'NR',  [tShikha.id]);
    addBlock('III-HE','Tue',0,0, subjEMT,     '301', [tSA.id]);
    addBlock('III-HE','Tue',2,2, subjCN,      'NR',  [tVK.id]);
    addBlock('III-HE','Tue',3,3, subjES,      'NR',  [tSY.id]);
    addBlock('III-HE','Tue',4,4, subjcnLab,  'NR',  [tVK.id]);
    addBlock('III-HE','Wed',4,5, subjEMT,     '301', [tSA.id]);
    addBlock('III-HE','Wed',6,7, subjesLab,  'NEL', [tSY.id, tAJ.id]);
    addBlock('III-HE','Thu',2,2, subjemtLab, 'NEL', [tSA.id]);
    addBlock('III-HE','Thu',4,4, subjvlsiLab,'NEL', [tSK.id, tSS.id]);
    addBlock('III-HE','Thu',6,8, subjVLSI,    '301', [tSK.id]);
    addBlock('III-HE','Fri',0,1, subjCN,      'NR',  [tVK.id]);
    addBlock('III-HE','Fri',4,5, subjES,      '301', [tSY.id]);
    addBlock('III-HE','Fri',6,6, subjVLSI,    '301', [tSK.id]);

    // (IV-HE) adjusted
    // Wednesday:
    addBlock('IV-HE','Wed',0,1, subjcmosLab,'NEL', [tShikha.id, tSN.id]); // I–II
    addBlock('IV-HE','Wed',2,3, subjAML,     'NR',  [tSHS.id]);           // III–IV
    addBlock('IV-HE','Wed',4,5, subjcsLab,  'NEL', [tRST.id, tSS.id]);    // V–VI (VII removed)

    // Thursday:
    addBlock('IV-HE','Thu',0,1, subjamlLab, 'NEL', [tSHS.id, tSA.id]);    // I–II
    addBlock('IV-HE','Thu',2,2, subjAML,     '301', [tSHS.id]);           // III
    // AES at V removed (12:30)
    addBlock('IV-HE','Thu',5,6, subjaesLab, 'NEL', [tSY.id, tAJ.id]);     // VI–VII (VIII removed)

    // Friday:
    addBlock('IV-HE','Fri',0,1, subjCMOS,    '301', [tShikha.id]);        // I–II
    addBlock('IV-HE','Fri',2,3, subjAES,     '301', [tSY.id]);            // III–IV
    addBlock('IV-HE','Fri',6,6, subjCS,      '301', [tRST.id]);           // VII only (VIII removed)

    // Saturday:
    addBlock('IV-HE','Sat',0,0, subjCMOS,    '301', [tShikha.id]);        // I
    addBlock('IV-HE','Sat',2,2, subjCS,      '301', [tHM.id]);            // III
    addBlock('IV-HE','Sat',3,3, subjCS,      '301', [tRST.id]);           // IV

    // Save timetable
    await store.writeList(LocalStorage.kTimetable, tt.map((e) => e.toMap()).toList());

    // Empty datasets
    await store.writeList(LocalStorage.kAttendance, []);
    await store.writeList(LocalStorage.kQueries, []);
    await store.writeList(LocalStorage.kRemarks, []);
    await store.markSeeded();
  }

  // Helpers
  UserAccount _teacher(Uuid id, DateTime now, String name, String email, String phone) => UserAccount(
    id: id.v4(),
    role: UserRole.teacher,
    name: name,
    email: email,
    phone: phone,
    passwordHash: UserAccount.hashPassword('Teach@123'),
    createdAt: now,
  );

  UserAccount _stu(Uuid id, DateTime now, String name, String cr, String er, String phone, int year, String section) => UserAccount(
    id: id.v4(),
    role: UserRole.student,
    name: name,
    phone: phone,
    collegeRollNo: cr,
    examRollNo: er,
    section: section,
    year: year,
    passwordHash: UserAccount.hashPassword('Stud@123'),
    createdAt: now,
  );
}

class _YearKit {
  final String section;
  final Uuid id;
  final Seeder owner;
  final List<Subject> subjects = [];
  _YearKit({required this.section, required this.id, required this.owner});

  Subject subj(String code, String name, UserAccount leadTeacher) {
    final s = Subject(
      id: id.v4(),
      code: code,
      name: name,
      department: 'Electronics',
      semester: _semForSection(section),
      section: section,
      teacherId: leadTeacher.id,
    );
    subjects.add(s);
    return s;
  }

  static String _semForSection(String sec) => switch (sec) {
    'I-HE' => 'Sem 1',
    'II-HE' => 'Sem 3',
    'III-HE' => 'Sem 5',
    'IV-HE' => 'Sem 7',
    _ => 'Sem',
  };
}