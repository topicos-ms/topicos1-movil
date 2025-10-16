class RecommendedCourse {
  final String courseId;
  final String code;
  final String name;
  final int credits;
  final String levelId;
  final String levelName;
  final int levelOrder;
  final List<String> prerequisites;
  bool isSelected;

  RecommendedCourse({
    required this.courseId,
    required this.code,
    required this.name,
    required this.credits,
    required this.levelId,
    required this.levelName,
    required this.levelOrder,
    required this.prerequisites,
    this.isSelected = false,
  });

  factory RecommendedCourse.fromJson(Map<String, dynamic> json) {
    return RecommendedCourse(
      courseId: json['courseId'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      credits: json['credits'] ?? 0,
      levelId: json['levelId'] ?? '',
      levelName: json['levelName'] ?? '',
      levelOrder: json['levelOrder'] ?? 0,
      prerequisites: (json['prerequisites'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}

class StudentEnrollmentInfo {
  final String enrollmentId;
  final String studentId;
  final String termId;
  final String termName;

  StudentEnrollmentInfo({
    required this.enrollmentId,
    required this.studentId,
    required this.termId,
    required this.termName,
  });
}

class CourseEnrollmentRequest {
  final String enrollmentId;
  final String courseSectionId;

  CourseEnrollmentRequest({
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
