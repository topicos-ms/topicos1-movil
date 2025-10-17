import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: Constants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: Constants.tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: Constants.tokenKey);
  }

  Future<void> saveUserData(String userData) async {
    await _storage.write(key: Constants.userKey, value: userData);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: Constants.userKey);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: Constants.userKey);
  }

  Future<void> saveEnrollmentId({
    required String studentId,
    required String enrollmentId,
  }) async {
    await _storage.write(
      key: '${Constants.enrollmentIdKeyPrefix}$studentId',
      value: enrollmentId,
    );
  }

  Future<String?> getEnrollmentId(String studentId) async {
    return await _storage.read(
      key: '${Constants.enrollmentIdKeyPrefix}$studentId',
    );
  }

  Future<void> deleteEnrollmentId(String studentId) async {
    await _storage.delete(
      key: '${Constants.enrollmentIdKeyPrefix}$studentId',
    );
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
