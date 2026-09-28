import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/person.dart';
import 'models/care_item.dart';
import 'services/care_engine.dart';
import 'services/jalali_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PezeshkKhanevadehApp());
}

class PezeshkKhanevadehApp extends StatelessWidget {
  const PezeshkKhanevadehApp({super.key});

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
        fontFamily: 'Vazirmatn',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF004D40),
          surface: const Color(0xFFF7FBF9),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  List<Person> _people = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('family_members');
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        setState(() {
          _people = decoded.map((e) => Person.fromJson(e)).toList();
          _loading = false;
        });
        return;
      } catch (_) {}
    }

    // عضو نمونه پیش‌فرض در صورت خالی بودن
    final defaultPerson = Person(
      id: 'default_child',
      firstName: 'کودک',
      lastName: 'نمونه',
      gender: 'پسر',
      birthDate: DateTime.now().subtract(const Duration(days: 75)), // حدود ۲.۵ ماهه
    );
    _people = [defaultPerson];
    await _savePeople();
    setState(() => _loading = false);
  }

  Future<void> _savePeople() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_people.map((p) => p.toJson()).toList());
    await prefs.setString('family_members', raw);
  }

  void _addOrUpdatePerson(Person person) {
    setState(() {
      final index = _people.indexWhere((p) => p.id == person.id);
      if (index >= 0) {
        _people[index] = person;
      } else {
        _people.add(person);
      }
    });
    _savePeople();
  }

  void _deletePerson(String id) {
    setState(() {
      _people.removeWhere((p) => p.id == id);
    });
    _savePeople();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      HomeScreen(people: _people),
      FamilyScreen(
        people: _people,
        onSave: _addOrUpdatePerson,
        onDelete: _deletePerson,
      ),
      const HealthCentersScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.vaccines_outlined),
            selectedIcon: Icon(Icons.vaccines),
            label: 'برنامه مراقبت و واکسن',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'اعضای خانواده',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: 'مراکز سلامت',
          ),
        ],
      ),
    );
  }
}

// ---------------- صفحه اصلی (واکسن‌ها و سررسیدها) ----------------
class HomeScreen extends StatefulWidget {
  final List<Person> people;
  const HomeScreen({super.key, required this.people});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedPersonId;

  @override
  Widget build(BuildContext context) {
    if (widget.people.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('پزشک خانواده')),
        body: const Center(child: Text('لطفاً ابتدا از بخش اعضای خانواده یک عضو ثبت کنید.')),
      );
    }

    final selectedPerson = widget.people.firstWhere(
      (p) => p.id == _selectedPersonId,
      orElse: () => widget.people.first,
    );

    final careItems = CareEngine.generateCareItems(selectedPerson);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سامانه مراقبت و واکسیناسیون'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // انتخاب فرد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
            child: Row(
              children: [
                const Text('انتخاب پرونده: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPerson.id,
                    underline: const SizedBox(),
                    items: widget.people.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.fullName} (${p.gender})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPersonId = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          // نمایش سن و وضعیت پرونده فرد انتخاب‌شده
          Card(
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPerson.fullName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سن: ${JalaliHelper.formatAge(selectedPerson.birthDate)} | تاریخ تولد: ${JalaliHelper.toJalali(selectedPerson.birthDate)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // لیست کامل واکسن‌ها و مراقبت‌ها
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('جدول واکسن‌ها و زمان مراجعه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${careItems.length} مورد', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: careItems.length,
              itemBuilder: (context, index) {
                final item = careItems[index];
                return VaccineCareCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- کارت نمایش هر واکسن ----------------
class VaccineCareCard extends StatelessWidget {
  final CareItem item;
  const VaccineCareCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;
    IconData iconData;

    switch (item.status) {
      case DueStatus.overdue:
        statusColor = Colors.red.shade800;
        statusBgColor = Colors.red.shade50;
        iconData = Icons.warning_amber_rounded;
        break;
      case DueStatus.today:
        statusColor = Colors.green.shade800;
        statusBgColor = Colors.green.shade50;
        iconData = Icons.check_circle_outline;
        break;
      case DueStatus.upcoming:
        statusColor = Colors.blue.shade800;
        statusBgColor = Colors.blue.shade50;
        iconData = Icons.schedule;
        break;
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: statusColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      if (item.targetAge.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'موعد برنامه کشوری: ${item.targetAge}',
                            style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'تاریخ: ${JalaliHelper.toJalali(item.dueDate)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.remainingText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- مدیریت اعضای خانواده ----------------
class FamilyScreen extends StatelessWidget {
  final List<Person> people;
  final Function(Person) onSave;
  final Function(String) onDelete;

  const FamilyScreen({
    super.key,
    required this.people,
    required this.onSave,
    required this.onDelete,
  });

  void _openForm(BuildContext context, [Person? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PersonFormSheet(existing: existing, onSave: onSave),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت اعضای خانواده')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('عضو جدید'),
      ),
      body: people.isEmpty
          ? const Center(child: Text('عضوی ثبت نشده است.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: people.length,
              itemBuilder: (context, i) {
                final p = people[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.firstName.isNotEmpty ? p.firstName[0] : 'ع')),
                    title: Text(p.fullName),
                    subtitle: Text('سن: ${JalaliHelper.formatAge(p.birthDate)} | تاریخ تولد: ${JalaliHelper.toJalali(p.birthDate)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          onPressed: () => _openForm(context, p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => onDelete(p.id),
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

class PersonFormSheet extends StatefulWidget {
  final Person? existing;
  final Function(Person) onSave;

  const PersonFormSheet({super.key, this.existing, required this.onSave});

  @override
  State<PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends State<PersonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fnCtrl;
  late TextEditingController _lnCtrl;
  late String _gender;
  late DateTime _birthDate;
  bool _pregnant = false;

  @override
  void initState() {
    super.initState();
    _fnCtrl = TextEditingController(text: widget.existing?.firstName ?? '');
    _lnCtrl = TextEditingController(text: widget.existing?.lastName ?? '');
    _gender = widget.existing?.gender ?? 'دختر/زن';
    _birthDate = widget.existing?.birthDate ?? DateTime.now().subtract(const Duration(days: 365));
    _pregnant = widget.existing?.pregnant ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'افزودن عضو جدید خانواده' : 'ویرایش پرونده',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fnCtrl,
                decoration: const InputDecoration(labelText: 'نام', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'نام را وارد کنید' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lnCtrl,
                decoration: const InputDecoration(labelText: 'نام خانوادگی', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'نام خانوادگی را وارد کنید' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'جنسیت', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'پسر/مرد', child: Text('پسر / مرد')),
                  DropdownMenuItem(value: 'دختر/زن', child: Text('دختر / زن')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 14),
              ListTile(
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.cake_outlined),
                title: const Text('تاریخ تولد (شمسی)'),
                subtitle: Text(JalaliHelper.toJalali(_birthDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate,
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _birthDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final person = Person(
                        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        firstName: _fnCtrl.text,
                        lastName: _lnCtrl.text,
                        gender: _gender,
                        birthDate: _birthDate,
                        pregnant: _pregnant,
                      );
                      widget.onSave(person);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('ثبت و ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- مراکز سلامت و خطوط اضطراری ----------------
class HealthCentersScreen extends StatelessWidget {
  const HealthCentersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراکز و شماره‌های اضطراری')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.phone_in_talk, color: Colors.green),
              title: Text('سامانه پاسخگویی وزارت بهداشت (۱۹۰)'),
              subtitle: Text('مشاوره دارویی، واکسیناسیون و شکایات حوزه سلامت'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.emergency, color: Colors.red),
              title: Text('اورژانس کشور (۱۱۵)'),
              subtitle: Text('خدمات فوریت‌های پزشکی شبانه‌روزی'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.location_on, color: Colors.teal),
              title: Text('پایگاه‌های سلامت و خانه‌های بهداشت'),
              subtitle: Text('ارائه رایگان کلیه واکسن‌های مصوب کشوری طبق شناسنامه سلامت'),
            ),
          ),
        ],
      ),
    );
  }
}
