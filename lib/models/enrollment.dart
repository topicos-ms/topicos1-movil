class Enrollment {
  final String studentId;
  final String termId;
  final String enrolledOn;
  final String origin;
  final String? note;

  Enrollment({
    required this.studentId,
    required this.termId,
    required this.enrolledOn,
    required this.origin,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'term_id': termId,
      'enrolled_on': enrolledOn,
      'origin': origin,
      if (note != null) 'note': note,
    };
  }
}

class EnrollmentResponse {
  final String? jobId;
  final String? status;
  final String? message;

  EnrollmentResponse({
    this.jobId,
    this.status,
    this.message,
  });

  factory EnrollmentResponse.fromJson(Map<String, dynamic> json) {
    return EnrollmentResponse(
      jobId: json['jobId'],
      status: json['status'],
      message: json['message'],
    );
  }
}
