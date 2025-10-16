/// Modelo para una materia recomendada
class RecommendedCourse {
  final String courseId;
  final String code;
  final String name;
  final int credits;
  final bool isPrerequisitesMet;
  final List<String> missingPrerequisites;
  bool isSelected;
  String? selectedSectionId;

  RecommendedCourse({
    required this.courseId,
    required this.code,
    required this.name,
    required this.credits,
    required this.isPrerequisitesMet,
    required this.missingPrerequisites,
    this.isSelected = false,
    this.selectedSectionId,
  });

  factory RecommendedCourse.fromJson(Map<String, dynamic> json) {
    // El backend puede enviar 'code' o 'courseCode'
    final code = json['code'] as String? ?? json['courseCode'] as String;
    
    // El backend puede enviar 'name' o 'courseName'
    final name = json['name'] as String? ?? json['courseName'] as String;
    
    // Determinar si cumple los prerequisitos
    // Si el backend envía 'isPrerequisitesMet', usarlo
    // Si no, verificar si 'prerequisites' está vacío
    final bool meetsPrerequisites;
    final List<String> missing;
    
    if (json.containsKey('isPrerequisitesMet')) {
      meetsPrerequisites = json['isPrerequisitesMet'] as bool;
      missing = (json['missingPrerequisites'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
    } else {
      // Si prerequisites está vacío, cumple los requisitos
      final prerequisites = json['prerequisites'] as List<dynamic>? ?? [];
      meetsPrerequisites = prerequisites.isEmpty;
      missing = prerequisites.map((e) => e.toString()).toList();
    }
    
    return RecommendedCourse(
      courseId: json['courseId'] as String,
      code: code,
      name: name,
      credits: json['credits'] as int,
      isPrerequisitesMet: meetsPrerequisites,
      missingPrerequisites: missing,
      isSelected: false,
    );
  }
}

/// Modelo para las secciones de una materia (grupos)
class CourseSection {
  final String id;
  final String courseId;
  final String? termId;
  final String? classroomId;
  final String? teacherId;
  final String groupLabel; // "A", "B", "C", etc.
  final String modality; // "Onsite", "Online", "Hybrid"
  final String shift; // "Morning", "Afternoon", "Evening"
  final int quotaMax;
  final int quotaAvailable;
  final String status;
  final List<Schedule> schedules;

  CourseSection({
    required this.id,
    required this.courseId,
    required this.termId,
    required this.classroomId,
    required this.teacherId,
    required this.groupLabel,
    required this.modality,
    required this.shift,
    required this.quotaMax,
    required this.quotaAvailable,
    required this.status,
    required this.schedules,
  });

  factory CourseSection.fromJson(Map<String, dynamic> json) {
    return CourseSection(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      termId: json['term_id'] as String?,
      classroomId: json['classroom_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      groupLabel: json['group_label'] as String,
      modality: json['modality'] as String? ?? 'Onsite',
      shift: json['shift'] as String? ?? 'Morning',
      quotaMax: json['quota_max'] as int,
      quotaAvailable: json['quota_available'] as int,
      status: json['status'] as String,
      schedules: (json['schedules'] as List<dynamic>?)
          ?.map((e) => Schedule.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Propiedades derivadas
  bool get hasCapacity => quotaAvailable > 0;
  int get enrolled => quotaMax - quotaAvailable;
  double get fillPercentage => ((quotaMax - quotaAvailable) / quotaMax) * 100;
  
  // Para compatibilidad con la UI
  String get code => groupLabel;
  Professor get professor => Professor(
    id: teacherId ?? '',
    name: 'Por asignar', // El backend no devuelve info del profesor en este endpoint
  );
}

class Schedule {
  final String id;
  final String courseSectionId;
  final String weekday; // "Monday", "Tuesday", etc.
  final String timeStart; // "08:00:00"
  final String timeEnd; // "09:50:00"
  final String? classroomId;
  final String dateStart;
  final String dateEnd;

  Schedule({
    required this.id,
    required this.courseSectionId,
    required this.weekday,
    required this.timeStart,
    required this.timeEnd,
    this.classroomId,
    required this.dateStart,
    required this.dateEnd,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String,
      courseSectionId: json['course_section_id'] as String,
      weekday: json['weekday'] as String,
      timeStart: json['time_start'] as String,
      timeEnd: json['time_end'] as String,
      classroomId: json['classroom_id'] as String?,
      dateStart: json['date_start'] as String,
      dateEnd: json['date_end'] as String,
    );
  }

  // Propiedades derivadas para compatibilidad
  String get day => weekday;
  String get startTime => timeStart.substring(0, 5); // "08:00:00" -> "08:00"
  String get endTime => timeEnd.substring(0, 5); // "09:50:00" -> "09:50"
  String get classroom => classroomId ?? 'Por asignar';
  String get timeRange => '$startTime - $endTime';
  String get fullSchedule => '$weekday $timeRange${classroomId != null ? " - $classroomId" : ""}';
}

class Professor {
  final String id;
  final String name;

  Professor({
    required this.id,
    required this.name,
  });

  factory Professor.fromJson(Map<String, dynamic> json) {
    return Professor(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

/// Request para inscripción en lote (batch)
class BatchEnrollmentRequest {
  final List<EnrollmentItem> items;

  BatchEnrollmentRequest({required this.items});

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class EnrollmentItem {
  final String enrollmentId;
  final String courseSectionId;

  EnrollmentItem({
    required this.enrollmentId,
    required this.courseSectionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'course_section_id': courseSectionId,
    };
  }
}

/// Response de inscripción batch
class BatchEnrollmentResponse {
  final bool success;
  final String message;
  final List<EnrolledSection>? enrolledSections;
  final String? errorCode;
  final Map<String, dynamic>? details;

  BatchEnrollmentResponse({
    required this.success,
    required this.message,
    this.enrolledSections,
    this.errorCode,
    this.details,
  });

  factory BatchEnrollmentResponse.fromJson(Map<String, dynamic> json) {
    return BatchEnrollmentResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      enrolledSections: json['enrolledSections'] != null
          ? (json['enrolledSections'] as List<dynamic>)
              .map((e) => EnrolledSection.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      errorCode: json['errorCode'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

class EnrolledSection {
  final String courseSectionId;
  final String courseName;
  final String status;

  EnrolledSection({
    required this.courseSectionId,
    required this.courseName,
    required this.status,
  });

  factory EnrolledSection.fromJson(Map<String, dynamic> json) {
    return EnrolledSection(
      courseSectionId: json['courseSectionId'] as String,
      courseName: json['courseName'] as String,
      status: json['status'] as String,
    );
  }
}

