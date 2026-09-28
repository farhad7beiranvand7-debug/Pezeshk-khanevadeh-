import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthApp());
}

// ==========================================
// موتور تبدیل تاریخ جلالی به میلادی و بالعکس
// ==========================================
class JalaliDate {
  final int year;
  final int month;
  final int day;

  JalaliDate(this.year, this.month, this.day);

  static JalaliDate fromDateTime(DateTime date) {
    int gy = date.year;
    int gm = date.month;
    int gd = date.day;

    List<int> gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int g_day_no = 365 * gy + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) - 80 + gd + gdm[gm - 1];
    int jy = -1595 + (33 * (g_day_no ~/ 12053));
    g_day_no %= 12053;
    jy += 4 * (g_day_no ~/ 1461);
    g_day_no %= 1461;
    if (g_day_no > 365) {
      jy += ((g_day_no - 1) ~/ 365);
      g_day_no = (g_day_no - 1) % 365;
    }
    int jm;
    int jd;
    if (g_day_no < 186) {
      jm = 1 + (g_day_no ~/ 31);
      jd = 1 + (g_day_no % 31);
    } else {
      jm = 7 + ((g_day_no - 186) ~/ 30);
      jd = 1 + ((g_day_no - 186) % 30);
    }
    return JalaliDate(jy, jm, jd);
  }

  DateTime toDateTime() {
    int jy = year;
    int jm = month;
    int jd = day;
    jy += 1595;
    int days = -355668 + (365 * jy) + ((jy ~/ 33) * 8) + (((jy % 33) + 3) ~/ 4) + jd + ((jm < 7) ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
    int gy = 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gy += 100 * (--days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += ((days - 1) ~/ 365);
      days = (days - 1) % 365;
    }
    int gd = days + 1;
    List<int> salm = [0, 31, ((gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0)) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int gm = 0;
    while (gm < 13 && gd > salm[gm]) {
      gd -= salm[gm];
      gm++;
    }
    return DateTime(gy, gm, gd);
  }

  String format() {
    return '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
  }
}

// ==========================================
// مدل داده‌ها
// ==========================================
class Member {
  final String id;
  final String fullName;
  final int birthYear;
  final int birthMonth;
  final int birthDay;
  final String gender; // 'مرد' | 'زن'
  final bool hasDiabetes;
  final bool hasHypertension;
  final bool hasHypothyroidism;
  final bool isPregnant;
  final int pregnancyWeek;

  Member({
    required this.id,
    required this.fullName,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.gender,
    this.hasDiabetes = false,
    this.hasHypertension = false,
    this.hasHypothyroidism = false,
    this.isPregnant = false,
    this.pregnancyWeek = 0,
  });

  DateTime get birthDateTime => JalaliDate(birthYear, birthMonth, birthDay).toDateTime();

  int get ageInDays => DateTime.now().difference(birthDateTime).inDays;
  int get ageInMonths => (ageInDays / 30.4375).floor();
  int get ageInYears => (ageInDays / 365.25).floor();

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'birthYear': birthYear,
    'birthMonth': birthMonth,
    'birthDay': birthDay,
    'gender': gender,
    'hasDiabetes': hasDiabetes,
    'hasHypertension': hasHypertension,
    'hasHypothyroidism': hasHypothyroidism,
    'isPregnant': isPregnant,
    'pregnancyWeek': pregnancyWeek,
  };

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    fullName: json['fullName'],
    birthYear: json['birthYear'],
    birthMonth: json['birthMonth'],
    birthDay: json['birthDay'],
    gender: json['gender'],
    hasDiabetes: json['hasDiabetes'] ?? false,
    hasHypertension: json['hasHypertension'] ?? false,
    hasHypothyroidism: json['hasHypothyroidism'] ?? false,
    isPregnant: json['isPregnant'] ?? false,
    pregnancyWeek: json['pregnancyWeek'] ?? 0,
  );
}

class HealthServiceItem {
  final String title;
  final String category; // واکسیناسیون، غربالگری، مراقبت مزمن، بارداری، پایش رشد
  final String description;
  final String targetDate;
  final bool isOverdue;
  final IconData icon;
  final Color color;

  HealthServiceItem({
    required this.title,
    required this.category,
    required this.description,
    required this.targetDate,
    this.isOverdue = false,
    required this.icon,
    required this.color,
  });
}

// ==========================================
// موتور استخراج خدمات سامانه سیب وزارت بهداشت
// ==========================================
class SibHealthEngine {
  static List<HealthServiceItem> calculateServices(Member member) {
    List<HealthServiceItem> services = [];
    final int ageDays = member.ageInDays;
    final int ageMonths = member.ageInMonths;
    final int ageYears = member.ageInYears;
    final DateTime bDate = member.birthDateTime;

    void addVaccine(String name, int targetDays, String desc) {
      DateTime vDate = bDate.add(Duration(days: targetDays));
      bool isOverdue = DateTime.now().isAfter(vDate.add(const Duration(days: 30)));
      services.add(HealthServiceItem(
        title: name,
        category: 'واکسیناسیون کشوری',
        description: desc,
        targetDate: JalaliDate.fromDateTime(vDate).format(),
        isOverdue: isOverdue,
        icon: Icons.vaccines,
        color: Colors.teal,
      ));
    }

    // ۱. جدول واکسیناسیون کشوری سامانه سیب
    if (ageYears <= 7) {
      if (ageMonths <= 2) addVaccine('واکسن بدو تولد (ب.ث.ژ، هپاتیت B، فلج اطفال خوراکی)', 0, 'تزریق در زایشگاه یا بدو تولد');
      if (ageMonths <= 4) addVaccine('واکسن ۲ ماهگی (پنج‌گانه ۱، فلج اطفال خوراکی)', 60, 'پنتاوالان (دیفتری، کزاز، سیاه‌سرفه، هپاتیت ب، هموفیلوس)');
      if (ageMonths <= 6) addVaccine('واکسن ۴ ماهگی (پنج‌گانه ۲، قطره فلج اطفال، IPV تزریقی)', 120, 'فلج اطفال تزریقی به همراه پنج‌گانه دوم');
      if (ageMonths <= 8) addVaccine('واکسن ۶ ماهگی (پنج‌گانه ۳، فلج اطفال خوراکی)', 180, 'نوبت سوم پنج‌گانه و فلج اطفال خوراکی');
      if (ageMonths <= 15) addVaccine('واکسن ۱۲ ماهگی (MMR نوبت اول)', 365, 'سرخک، سرخجه و اوریون');
      if (ageMonths <= 24) addVaccine('واکسن ۱۸ ماهگی (سه‌گانه، قطره فلج اطفال، MMR نوبت دوم)', 548, 'یادآور اول و نوبت دوم MMR');
      if (ageYears <= 7) addVaccine('واکسن ۶ سالگی (سه‌گانه یادآور دوم، قطره فلج اطفال)', 2190, 'پیش از ورود به مدرسه');
    }

    // ۲. پایش رشد و غربالگری نوزادی
    if (ageDays <= 28) {
      DateTime scrDate = bDate.add(const Duration(days: 3));
      services.add(HealthServiceItem(
        title: 'غربالگری نوزادی (هیپوتیروئیدی و فاویسم)',
        category: 'غربالگری نوزادی',
        description: 'خون‌گیری از پاشنه پا در روز ۳ تا ۵ تولد در خانه بهداشت/پایگاه سلامت',
        targetDate: JalaliDate.fromDateTime(scrDate).format(),
        isOverdue: ageDays > 5,
        icon: Icons.child_care,
        color: Colors.amber.shade800,
      ));
    }

    if (ageYears < 5) {
      services.add(HealthServiceItem(
        title: 'پایش رشد، بینایی و تکامل کودک',
        category: 'پایش رشد و تکامل',
        description: 'ثبت قد، وزن، دور سر و ارزیابی ASQ بر اساس بسته‌های سلامت کودک سامانه سیب',
        targetDate: 'مراقبت دوره‌ای جاری',
        isOverdue: false,
        icon: Icons.monitor_weight_outlined,
        color: Colors.green,
      ));
    }

    // ۳. خدمات میانسالان و سالمندان (سامانه سیب)
    if (ageYears >= 30) {
      services.add(HealthServiceItem(
        title: 'ارزیابی خطرسنجی سکته‌های قلبی و مغزی (ایراپن)',
        category: 'بسته خدمت میانسالان',
        description: 'تعیین احتمال ۱۰ ساله حوادث قلبی عروقی، اندازه‌گیری رایگان کلسترول و قند ناشتا',
        targetDate: 'سالانه',
        isOverdue: false,
        icon: Icons.favorite_border,
        color: Colors.redAccent,
      ));
    }

    if (ageYears >= 50 && ageYears <= 74) {
      services.add(HealthServiceItem(
        title: 'غربالگری سرطان روده بزرگ (تست FIT)',
        category: 'غربالگری سرطان',
        description: 'انجام آزمایش خون مخفی در مدفوع هر ۲ سال یک‌بار در پایگاه سلامت',
        targetDate: 'هر دو سال یک‌بار',
        isOverdue: false,
        icon: Icons.biotech,
        color: Colors.purple,
      ));
    }

    if (member.gender == 'زن' && ageYears >= 30 && ageYears <= 69) {
      services.add(HealthServiceItem(
        title: 'غربالگری سلامت زنان (پستان و دهانه رحم)',
        category: 'سلامت زنان',
        description: 'معاینه دوره‌ای پستان توسط ماما/پزشک و پاپ اسمیر/HPV مطابق شیوه نامه کشوری',
        targetDate: 'دوره‌ای',
        isOverdue: false,
        icon: Icons.female,
        color: Colors.pink,
      ));
    }

    // ۴. مراقبت‌های بیماری‌های مزمن (دیابت، فشارخون، هیپوتیروئیدی)
    if (member.hasDiabetes) {
      services.add(HealthServiceItem(
        title: 'مراقبت ۳ ماهه دیابت (قند ناشتا و HbA1c)',
        category: 'بیماری‌های مزمن',
        description: 'اندازه‌گیری FBS، هموگلوبین گلیکوزیله و بررسی قند پایگاه سلامت/خانه بهداشت',
        targetDate: 'هر ۳ ماه یک‌بار',
        isOverdue: false,
        icon: Icons.water_drop,
        color: Colors.blue,
      ));
      services.add(HealthServiceItem(
        title: 'معاینه سالانه پای دیابتی و شبکیه چشم',
        category: 'بیماری‌های مزمن',
        description: 'ارجاع سالانه توسط پزشک خانواده به چشم‌پزشک و بررسی حس پا با مونوفیلامنت',
        targetDate: 'سالانه',
        isOverdue: false,
        icon: Icons.remove_red_eye,
        color: Colors.indigo,
      ));
    }

    if (member.hasHypertension) {
      services.add(HealthServiceItem(
        title: 'مراقبت ماهانه کنترل فشار خون',
        category: 'بیماری‌های مزمن',
        description: 'ثبت فشار خون در سامانه سیب، پایش دارویی و بررسی علائم خطر قلبی و کلیوی',
        targetDate: 'ماهانه',
        isOverdue: false,
        icon: Icons.speed,
        color: Colors.deepOrange,
      ));
    }

    if (member.hasHypothyroidism) {
      services.add(HealthServiceItem(
        title: 'پایش دوره‌ای کم‌کاری تیروئید (آزمایش TSH)',
        category: 'بیماری‌های مزمن',
        description: 'ارزیابی آزمایشگاهی هورمون‌های تیروئید هر ۳ تا ۶ ماه جهت تنظیم دوز لووتیروکسین',
        targetDate: 'هر ۳ تا ۶ ماه',
        isOverdue: false,
        icon: Icons.medication,
        color: Colors.brown,
      ));
    }

    // ۵. مراقبت‌های بارداری (۸ نوبت استاندارد سیب)
    if (member.gender == 'زن' && member.isPregnant) {
      int week = member.pregnancyWeek;
      String nextCare = 'مراقبت نوبت بعدی';
      if (week <= 10) nextCare = 'مراقبت اول (هفته ۶ تا ۱۰ بارداری) + آزمایش‌های کامل اولیه و سونو NT';
      else if (week <= 20) nextCare = 'مراقبت دوم (هفته ۱۶ تا ۲۰) + سونوگرافی آنومالی اسکن و غربالگری مرحله ۲';
      else if (week <= 30) nextCare = 'مراقبت سوم و چهارم (هفته ۲۴ تا ۳۰) + تست تحمل گلوکز (GDM) و تزریق روگام در صورت نیاز';
      else if (week <= 35) nextCare = 'مراقبت پنجم (هفته ۳۱ تا ۳۴) + بررسی وزن‌گیری، فشارخون و ضربان قلب جنین';
      else if (week <= 37) nextCare = 'مراقبت ششم (هفته ۳۵ تا ۳۷) + آمادگی برای زایمان طبیعی ایمن و بررسی پره‌اکلامپسی';
      else nextCare = 'مراقبت‌های هفتگی (هفته ۳۸ تا ۴۰) + کنترل حرکات جنین و معرفی به زایشگاه';

      services.add(HealthServiceItem(
        title: 'بسته خدمت مادر باردار (هفته $week)',
        category: 'مراقبت بارداری',
        description: nextCare,
        targetDate: 'هفته جاری یا آینده',
        isOverdue: false,
        icon: Icons.pregnant_woman,
        color: Colors.purpleAccent,
      ));
    }

    return services;
  }
}

// ==========================================
// واسط کاربری (UI)
// ==========================================
class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پزشک خانواده',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Tahoma',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<Member> members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('family_members_data');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          members = decoded.map((e) => Member.fromJson(e)).toList();
        });
      } catch (e) {
        // خطای بارگذاری دادها نادیده گرفته می‌شود
      }
    }
  }

  Future<void> _saveMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(members.map((e) => e.toJson()).toList());
    await prefs.setString('family_members_data', encoded);
  }

  void _addOrUpdateMember(Member member) {
    setState(() {
      int index = members.indexWhere((m) => m.id == member.id);
      if (index >= 0) {
        members[index] = member;
      } else {
        members.add(member);
      }
    });
    _saveMembers();
  }

  void _deleteMember(String id) {
    setState(() {
      members.removeWhere((m) => m.id == id);
    });
    _saveMembers();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardScreen(members: members),
      FamilyMembersScreen(
        members: members,
        onAddOrUpdate: _addOrUpdateMember,
        onDelete: _deleteMember,
      ),
      const AboutSibScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'میز خدمت'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'اعضای خانواده'),
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'راهنمای سیب'),
        ],
      ),
    );
  }
}

// ------------------------------------------
// صفحه داشبورد (خلاصه مراقبت‌های فعال اعضا)
// ------------------------------------------
class DashboardScreen extends StatelessWidget {
  final List<Member> members;
  const DashboardScreen({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پزشک خانواده و مراقبت‌های سلامت')),
      body: members.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety_outlined, size: 75, color: Colors.teal.shade300),
                  const SizedBox(height: 16),
                  const Text('هیچ عضوی در پرونده سلامت ثبت نشده است.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('برای دریافت نوبت‌ها و مراقبت‌های سامانه سیب، ابتدا اعضای خانواده را اضافه کنید.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: members.length,
              itemBuilder: (ctx, idx) {
                final member = members[idx];
                final services = SibHealthEngine.calculateServices(member);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: CircleAvatar(
                      backgroundColor: member.gender == 'مرد' ? Colors.blue.shade100 : Colors.pink.shade100,
                      child: Icon(
                        member.gender == 'مرد' ? Icons.man : Icons.woman,
                        color: member.gender == 'مرد' ? Colors.blue : Colors.pink,
                      ),
                    ),
                    title: Text('${member.fullName} (${member.ageInYears} ساله)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('تعداد مراقبت‌های فعال سیب: ${services.length} مورد'),
                    children: services.map((s) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.color.withOpacity(0.15),
                          child: Icon(s.icon, color: s.color, size: 22),
                        ),
                        title: Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.description, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('موعد/وضعیت: ${s.targetDate}', style: TextStyle(fontSize: 11, color: s.isOverdue ? Colors.red : Colors.teal)),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------------------------
// صفحه مدیریت اعضای خانواده
// ------------------------------------------
class FamilyMembersScreen extends StatelessWidget {
  final List<Member> members;
  final Function(Member) onAddOrUpdate;
  final Function(String) onDelete;

  const FamilyMembersScreen({
    super.key,
    required this.members,
    required this.onAddOrUpdate,
    required this.onDelete,
  });

  void _openMemberDialog(BuildContext context, [Member? member]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => MemberFormBottomSheet(member: member, onSave: onAddOrUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اعضای خانواده')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMemberDialog(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('افزودن عضو جدید', style: TextStyle(color: Colors.white)),
      ),
      body: members.isEmpty
          ? const Center(child: Text('عضوی ثبت نشده است. روی دکمه افزودن بزنید.'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 80),
              itemCount: members.length,
              itemBuilder: (ctx, idx) {
                final m = members[idx];
                return Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Text(m.gender == 'مرد' ? 'آقا' : 'خانم', style: const TextStyle(fontSize: 12, color: Colors.teal)),
                    ),
                    title: Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('متولد: ${m.birthYear}/${m.birthMonth}/${m.birthDay} | سن: ${m.ageInYears} سال'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openMemberDialog(context, m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => onDelete(m.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------------------------
// فرم افزودن / ویرایش عضو خانواده
// ------------------------------------------
class MemberFormBottomSheet extends StatefulWidget {
  final Member? member;
  final Function(Member) onSave;

  const MemberFormBottomSheet({super.key, this.member, required this.onSave});

  @override
  State<MemberFormBottomSheet> createState() => _MemberFormBottomSheetState();
}

class _MemberFormBottomSheetState extends State<MemberFormBottomSheet> {
  final _nameCtrl = TextEditingController();
  int _selectedYear = 1380;
  int _selectedMonth = 1;
  int _selectedDay = 1;
  String _gender = 'زن';
  bool _diabetes = false;
  bool _hypertension = false;
  bool _hypothyroid = false;
  bool _isPregnant = false;
  int _pregnancyWeek = 8;

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      final m = widget.member!;
      _nameCtrl.text = m.fullName;
      _selectedYear = m.birthYear;
      _selectedMonth = m.birthMonth;
      _selectedDay = m.birthDay;
      _gender = m.gender;
      _diabetes = m.hasDiabetes;
      _hypertension = m.hasHypertension;
      _hypothyroid = m.hasHypothyroidism;
      _isPregnant = m.isPregnant;
      _pregnancyWeek = m.pregnancyWeek;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member == null ? 'افزودن فرد جدید به پرونده' : 'ویرایش مشخصات فرد',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'نام و نام خانوادگی',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            const Text('تاریخ تولد دقیق (هجری شمسی):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'سال', border: OutlineInputBorder()),
                    items: List.generate(100, (i) => 1405 - i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'ماه', border: OutlineInputBorder()),
                    items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                    onChanged: (val) => setState(() => _selectedMonth = val!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedDay,
                    decoration: const InputDecoration(labelText: 'روز', border: OutlineInputBorder()),
                    items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                    onChanged: (val) => setState(() => _selectedDay = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('جنسیت: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Radio<String>(value: 'زن', groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)),
                const Text('خانم'),
                const SizedBox(width: 20),
                Radio<String>(value: 'مرد', groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)),
                const Text('آقا'),
              ],
            ),
            const Divider(),
            const Text('سوابق بیماری و شرایط ویژه (جهت ثبت مراقبت‌های سیب):', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('دیابت (قند خون بالا)'),
              value: _diabetes,
              dense: true,
              onChanged: (val) => setState(() => _diabetes = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('فشار خون بالا'),
              value: _hypertension,
              dense: true,
              onChanged: (val) => setState(() => _hypertension = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('کم‌کاری تیروئید (هیپوتیروئیدی)'),
              value: _hypothyroid,
              dense: true,
              onChanged: (val) => setState(() => _hypothyroid = val ?? false),
            ),
            if (_gender == 'زن') ...[
              CheckboxListTile(
                title: const Text('باردار هستم'),
                value: _isPregnant,
                dense: true,
                onChanged: (val) => setState(() => _isPregnant = val ?? false),
              ),
              if (_isPregnant)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('سن بارداری (هفته): '),
                      Expanded(
                        child: Slider(
                          value: _pregnancyWeek.toDouble(),
                          min: 1,
                          max: 42,
                          divisions: 41,
                          label: '$_pregnancyWeek',
                          onChanged: (v) => setState(() => _pregnancyWeek = v.round()),
                        ),
                      ),
                      Text('$_pregnancyWeek هفته'),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                final newMember = Member(
                  id: widget.member?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  fullName: _nameCtrl.text.trim(),
                  birthYear: _selectedYear,
                  birthMonth: _selectedMonth,
                  birthDay: _selectedDay,
                  gender: _gender,
                  hasDiabetes: _diabetes,
                  hasHypertension: _hypertension,
                  hasHypothyroidism: _hypothyroid,
                  isPregnant: _gender == 'زن' ? _isPregnant : false,
                  pregnancyWeek: _gender == 'زن' && _isPregnant ? _pregnancyWeek : 0,
                );
                widget.onSave(newMember);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ذخیره و محاسبه خدمات بهداشتی', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------
// صفحه درباره سامانه سیب
// ------------------------------------------
class AboutSibScreen extends StatelessWidget {
  const AboutSibScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('درباره سامانه سیب وزارت بهداشت')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سامانه یکپارچه بهداشت (سیب)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  SizedBox(height: 8),
                  Text(
                    'تمامی خدمات ارائه شده در این نرم‌افزار بر اساس راهنماها و بسته‌های خدمت خانه‌های بهداشت، مراکز خدمات جامع سلامت و پایگاه‌های سلامت وزارت بهداشت درمان و آموزش پزشکی طراحی شده است.',
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.vaccines, color: Colors.teal),
            title: Text('واکسیناسیون کشوری'),
            subtitle: Text('پوشش واکسن‌های بدو تولد، ۲، ۴، ۶، ۱۲، ۱۸ ماهگی و ۶ سالگی به همراه قطره فلج اطفال و سرخک'),
          ),
          ListTile(
            leading: Icon(Icons.pregnant_woman, color: Colors.purple),
            title: Text('مراقبت مادران باردار'),
            subtitle: Text('۸ نوبت مراقبت فعال شامل بررسی وزن، فشار، غربالگری ناهنجاری‌ها و سونوگرافی‌های روتین'),
          ),
          ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text('بیماری‌های غیرواگیر و مزمن'),
            subtitle: Text('پایش مستمر دیابت، پرفشاری خون، هیپوتیروئیدی و خطرسنجی ۱۰ ساله حوادث قلبی-عروقی'),
          ),
        ],
      ),
    );
  }
}
