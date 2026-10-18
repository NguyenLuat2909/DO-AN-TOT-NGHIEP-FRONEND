import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/student_dashboard.dart';
import '../models/student_course.dart';
import '../models/student_analytics.dart';
import '../models/teacher_course.dart';
import '../models/teacher_analytics.dart';
import '../models/student_course_detail.dart';
import '../models/teacher_monitoring.dart';
import '../models/learning_notification.dart';
import '../models/student_insights.dart';
import '../models/class_insights.dart';
import '../models/learning_goal.dart';

class ApiService {
  Future<List<LearningNotification>> getNotifications({
    bool teacher = false,
  }) => _list(
    '/dev/${teacher ? 'teachers/${ApiConstants.teacherId}' : 'students/${ApiConstants.studentId}'}/notifications',
    LearningNotification.fromJson,
  );
  Future<void> markNotificationRead(int id) =>
      _postJson('/dev/students/${ApiConstants.studentId}/notifications/$id/read');

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final response = await _getJson(path);
    final data = response is Map<String, dynamic> ? response['data'] : response;
    if (data is! List) throw const FormatException('Expected list');
    return data.map((v) => parse(v as Map<String, dynamic>)).toList();
  }

  Future<List<StudentTask>> getAllStudentTasks({
    int studentId = ApiConstants.studentId,
  }) => _list('/dev/students/$studentId/tasks', StudentTask.fromJson);
  Future<List<StudentLearningItem>> getContinueLearning({
    int studentId = ApiConstants.studentId,
    int? courseId,
  }) => _list(
    '/dev/students/$studentId/continue-learning${courseId == null ? '' : '?courseId=$courseId'}',
    StudentLearningItem.fromJson,
  );
  Future<List<MonitoredStudent>> getTeacherStudents(
    int courseId, {
    int teacherId = ApiConstants.teacherId,
  }) => _list(
    '/dev/teachers/$teacherId/courses/$courseId/students',
    MonitoredStudent.fromJson,
  );
  Future<MonitoredStudent> getMonitoredStudent(
    int courseId,
    int userId, {
    int teacherId = ApiConstants.teacherId,
  }) async => MonitoredStudent.fromJson(
    await _getJson(
      '/dev/teachers/$teacherId/courses/$courseId/students/$userId',
    ) as Map<String, dynamic>,
  );
  Future<List<MonitoredActivity>> getTeacherActivities(
    int courseId,
    String type, {
    int teacherId = ApiConstants.teacherId,
  }) => _list(
    '/dev/teachers/$teacherId/courses/$courseId/${type == 'assignment' ? 'assignments' : 'quizzes'}',
    MonitoredActivity.fromJson,
  );
  Future<List<ActivityStudent>> getActivityStudents(
    int courseId,
    MonitoredActivity activity, {
    int teacherId = ApiConstants.teacherId,
  }) => _list(
    '/dev/teachers/$teacherId/courses/$courseId/${activity.type == 'assignment' ? 'assignments' : 'quizzes'}/${activity.id}/students',
    ActivityStudent.fromJson,
  );
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Helper method for GET requests with UTF-8 decoding
  void dispose() => _client.close();

  Future<dynamic> _getJson(String path, {bool allowEmpty = false}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        if (allowEmpty && decodedBody.trim().isEmpty) return null;
        return jsonDecode(decodedBody);
      } else {
        throw Exception('Lỗi kết nối máy chủ (${response.statusCode})');
      }
    } catch (error, stack) {
      debugPrint('API GET $path: $error\n$stack');
      rethrow;
    }
  }

  Future<dynamic> _postJson(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Lỗi kết nối máy chủ (${response.statusCode})');
      }
    } catch (error, stack) {
      debugPrint('API POST $path: $error\n$stack');
      rethrow;
    }
  }

  // STUDENT APIs
  Future<StudentDashboard> getStudentDashboard({
    int studentId = ApiConstants.studentId,
  }) async {
    final data = await _getJson('/dev/students/$studentId/dashboard');
    if (data is Map<String, dynamic>) {
      // If wrapped in custom API response object e.g. { "data": ... }
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return StudentDashboard.fromJson(data['data'] as Map<String, dynamic>);
      }
      return StudentDashboard.fromJson(data);
    }
    throw Exception('Dữ liệu bảng điều khiển sinh viên không hợp lệ');
  }

  Future<List<StudentCourse>> getStudentCourses({
    int studentId = ApiConstants.studentId,
  }) async {
    final data = await _getJson('/dev/students/$studentId/courses');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      list = data['data'] as List;
    } else {
      throw Exception('Dữ liệu danh sách khóa học không hợp lệ');
    }

    return list
        .map((item) => StudentCourse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StudentAnalytics> getStudentCourseAnalytics({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) async {
    final url =
        '${ApiConstants.baseUrl}/dev/students/$studentId/courses/$courseId/analytics';
    debugPrint('STUDENT ANALYTICS URL: $url');
    final data = await _getJson(
      '/dev/students/$studentId/courses/$courseId/analytics',
    );
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return StudentAnalytics.fromJson(data['data'] as Map<String, dynamic>);
      }
      return StudentAnalytics.fromJson(data);
    }
    throw Exception('Dữ liệu phân tích khóa học không hợp lệ');
  }

  Future<List<LearningGoal>> getStudentGoals({
    int studentId = ApiConstants.studentId,
  }) => _list(
    '/dev/students/$studentId/goals',
    LearningGoal.fromJson,
  );

  Future<LearningGoal> createStudentGoal(
    Map<String, dynamic> request, {
    int studentId = ApiConstants.studentId,
  }) async {
    final data = await _postJson('/dev/students/$studentId/goals', body: request);
    if (data is Map<String, dynamic>) {
      return LearningGoal.fromJson(data);
    }
    throw Exception('Dữ liệu không hợp lệ');
  }

  Future<LearningGoal> cancelStudentGoal(
    int goalId, {
    int studentId = ApiConstants.studentId,
  }) async {
    final data = await _postJson('/dev/students/$studentId/goals/$goalId/cancel');
    if (data is Map<String, dynamic>) {
      return LearningGoal.fromJson(data);
    }
    throw Exception('Dữ liệu không hợp lệ');
  }

  // TEACHER APIs
  Future<StudentInsights> getGlobalStudentInsights({
    int studentId = ApiConstants.studentId,
    int days = 56,
  }) async {
    final data = await _getJson('/dev/students/$studentId/insights?days=$days');
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return StudentInsights.fromJson(data['data'] as Map<String, dynamic>);
      }
      return StudentInsights.fromJson(data);
    }
    throw Exception('Dữ liệu phân tích học tập không hợp lệ');
  }
  Future<List<TeacherCourse>> getTeacherCourses({
    int teacherId = ApiConstants.teacherId,
  }) async {
    final data = await _getJson('/dev/teachers/$teacherId/courses');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      list = data['data'] as List;
    } else {
      throw Exception('Dữ liệu danh sách khóa học giảng viên không hợp lệ');
    }

    return list
        .map((item) => TeacherCourse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TeacherAnalytics> getTeacherCourseAnalytics({
    int teacherId = ApiConstants.teacherId,
    required int courseId,
  }) async {
    final url =
        '${ApiConstants.baseUrl}/dev/teachers/$teacherId/courses/$courseId/analytics';
    debugPrint('TEACHER ANALYTICS URL: $url');
    final data = await _getJson(
      '/dev/teachers/$teacherId/courses/$courseId/analytics',
    );
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return TeacherAnalytics.fromJson(data['data'] as Map<String, dynamic>);
      }
      return TeacherAnalytics.fromJson(data);
    }
    throw Exception('Dữ liệu phân tích khóa học giảng viên không hợp lệ');
  }

  /// Sends one in-app reminder to each student; returns how many were sent.
  Future<int> sendReminders({
    int teacherId = ApiConstants.teacherId,
    required int courseId,
    required List<int> studentIds,
    required String title,
    required String message,
    String? sourceType,
    int? sourceId,
  }) async {
    final data = await _postJson(
      '/dev/teachers/$teacherId/courses/$courseId/reminders',
      body: {
        'student_ids': studentIds,
        'title': title,
        'message': message,
        if (sourceType != null && sourceId != null) ...{
          'source_type': sourceType,
          'source_id': sourceId,
        },
      },
    );
    return data is Map && data['sent'] is num ? (data['sent'] as num).toInt() : studentIds.length;
  }

  Future<ClassInsights> getClassInsights({
    int teacherId = ApiConstants.teacherId,
    required int courseId,
    int weeks = 8,
  }) async {
    final data = await _getJson(
      '/dev/teachers/$teacherId/courses/$courseId/class-insights?weeks=$weeks',
    );
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return ClassInsights.fromJson(data['data'] as Map<String, dynamic>);
      }
      return ClassInsights.fromJson(data);
    }
    throw Exception('Dữ liệu thông tin lớp học không hợp lệ');
  }

  Future<List<T>> _studentList<T>(
    int studentId,
    int courseId,
    String endpoint,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final response = await _getJson(
      '/dev/students/$studentId/courses/$courseId/$endpoint',
    );
    final data =
        response is Map<String, dynamic> && response.containsKey('data')
        ? response['data']
        : response;
    if (data is! List) throw const FormatException('Expected a list');
    return data.map((item) => parse(item as Map<String, dynamic>)).toList();
  }

  Future<List<StudentLearningItem>> getStudentLearningItems({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) => _studentList(
    studentId,
    courseId,
    'learning-items',
    StudentLearningItem.fromJson,
  );

  Future<List<StudentTask>> getStudentTasks({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) => _studentList(studentId, courseId, 'tasks', StudentTask.fromJson);

  Future<List<StudentGrade>> getStudentGrades({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) => _studentList(studentId, courseId, 'grades', StudentGrade.fromJson);

  Future<List<StudentGradeCategory>> getStudentGradeCategories({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) => _studentList(
    studentId,
    courseId,
    'grade-categories',
    StudentGradeCategory.fromJson,
  );

  Future<StudentAttendance?> getStudentAttendance({
    int studentId = ApiConstants.studentId,
    required int courseId,
  }) async {
    final response = await _getJson(
      '/dev/students/$studentId/courses/$courseId/attendance',
      allowEmpty: true,
    );
    final data =
        response is Map<String, dynamic> && response.containsKey('data')
        ? response['data']
        : response;
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected attendance object');
    }
    return StudentAttendance.fromJson(data);
  }

  // PHASE C: Learning Reflection (Student)
  Future<List<Map<String, dynamic>>> getReflections({int studentId = ApiConstants.studentId, int? courseId}) async {
    final query = courseId == null ? '' : '?courseId=$courseId';
    final response = await _getJson('/dev/students/$studentId/reflections$query');
    final data = response is Map<String, dynamic> && response.containsKey('data') ? response['data'] : response;
    if (data is! List) throw const FormatException('Expected a list of reflections');
    return data.map((item) {
      if (item is! Map<String, dynamic>) throw const FormatException('Invalid reflection item');
      return item;
    }).toList();
  }

  Future<void> addReflection(String content, int level, {int studentId = ApiConstants.studentId, int? courseId}) async {
    final payload = <String, dynamic>{'content': content, 'understandingLevel': level};
    if (courseId != null) payload['courseId'] = courseId;
    await _postJson('/dev/students/$studentId/reflections', body: payload);
  }

  // PHASE C: Teacher Notes (Teacher)
  Future<List<Map<String, dynamic>>> getTeacherNotes(int studentId, {int teacherId = ApiConstants.teacherId, int? courseId}) async {
    String url = '${ApiConstants.baseUrl}/teachers/$teacherId/notes?studentId=$studentId';
    if (courseId != null) url += '&courseId=$courseId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to get notes');
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<void> addTeacherNote(int studentId, String note, {int teacherId = ApiConstants.teacherId, int? courseId, String status = 'active'}) async {
    final payload = {'studentId': studentId, 'note': note, 'status': status};
    if (courseId != null) payload['courseId'] = courseId;
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/teachers/$teacherId/notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw Exception('Failed to add note');
  }

  Future<void> updateTeacherNoteStatus(int noteId, String status, {int teacherId = ApiConstants.teacherId}) async {
    final payload = {'status': status};
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/teachers/$teacherId/notes/$noteId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw Exception('Failed to update note status');
  }

  // PHASE D: Flashcards
  String _flashcardPath(int courseId, int studentId) =>
      '/dev/students/$studentId/courses/$courseId/flashcards';

  Future<List<Map<String, dynamic>>> getFlashcards(int courseId, {int studentId = ApiConstants.studentId}) async {
    final response = await _getJson(_flashcardPath(courseId, studentId));
    final data = response is Map<String, dynamic> && response.containsKey('data') ? response['data'] : response;
    if (data is! List) throw const FormatException('Expected a list of flashcards');
    return data.map((item) {
      if (item is! Map<String, dynamic>) throw const FormatException('Invalid flashcard item');
      return item;
    }).toList();
  }

  Future<void> addFlashcard(int courseId, String frontText, String backText, {int studentId = ApiConstants.studentId}) async {
    await _postJson(_flashcardPath(courseId, studentId), body: {'frontText': frontText, 'backText': backText});
  }

  Future<void> updateFlashcard(int courseId, int id, String frontText, String backText, {int studentId = ApiConstants.studentId}) async {
    final response = await _client.put(
      Uri.parse('${ApiConstants.baseUrl}${_flashcardPath(courseId, studentId)}/$id'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'frontText': frontText, 'backText': backText}),
    );
    if (response.statusCode != 200) throw Exception('Lỗi cập nhật thẻ (${response.statusCode})');
  }

  Future<void> deleteFlashcard(int courseId, int id, {int studentId = ApiConstants.studentId}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConstants.baseUrl}${_flashcardPath(courseId, studentId)}/$id'),
    );
    if (response.statusCode != 200) throw Exception('Lỗi xóa thẻ (${response.statusCode})');
  }

}
