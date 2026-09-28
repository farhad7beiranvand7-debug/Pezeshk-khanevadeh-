class Person {
  final String id;
  String firstName;
  String lastName;
  String gender; // 'مرد' | 'زن'
  DateTime birthDate;
  DateTime createdAt;
  List<String> conditions;
  bool pregnant;
  DateTime? pregnancyStartDate;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender = 'زن',
    required this.birthDate,
    DateTime? createdAt,
    List<String>? conditions,
    this.pregnant = false,
    this.pregnancyStartDate,
  })  : createdAt = createdAt ?? DateTime.now(),
        conditions = conditions ?? [];

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'birthDate': birthDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'conditions': conditions,
        'pregnant': pregnant,
        'pregnancyStartDate': pregnancyStartDate?.toIso8601String(),
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        gender: json['gender'] as String? ?? 'زن',
        birthDate: DateTime.parse(json['birthDate'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        conditions: (json['conditions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        pregnant: json['pregnant'] as bool? ?? false,
        pregnancyStartDate: json['pregnancyStartDate'] != null
            ? DateTime.parse(json['pregnancyStartDate'] as String)
            : null,
      );
}
