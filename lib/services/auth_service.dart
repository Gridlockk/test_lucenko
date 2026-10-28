import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Конфигурация подключения к API серверу FastAPI
class ApiConfig {
  /// Возможность вручную задать IP адрес (например, '192.168.1.50' для реального телефона)
  static String? customHost;

  /// Порт FastAPI сервера (по умолчанию 8001)
  static int port = 8001;

  /// Базовый префикс API
  static String basePath = '/api';

  /// Определение хоста в зависимости от платформы
  static String get host {
    if (customHost != null && customHost!.trim().isNotEmpty) {
      return customHost!.trim();
    }
    if (kIsWeb) {
      return '127.0.0.1';
    }
    // В Android эмуляторе 10.0.2.2 перенаправляет на 127.0.0.1 хост-машины ПК
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    // Для iOS симулятора, Desktop (Windows, macOS, Linux)
    return '127.0.0.1';
  }

  /// Полный базовый URL (например: http://10.0.2.2:8001/api или http://127.0.0.1:8001/api)
  static String get baseUrl => 'http://$host:$port$basePath';
}

/// Модель данных пользователя
class UserModel {
  final dynamic id;
  final String username;
  final String email;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}

/// Результат операций авторизации и регистрации
class AuthResult {
  final bool success;
  final String message;
  final String? token;
  final UserModel? user;

  AuthResult({
    required this.success,
    required this.message,
    this.token,
    this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? 'Успешно',
      token: json['token']?.toString() ?? json['access_token']?.toString(),
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Исключение при ошибках авторизации / сети
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final List<dynamic>? errors;

  AuthException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;
}

/// Сервис авторизации и работы с FastAPI бэкендом
class AuthService {
  static const String _tokenKey = 'auth_jwt_token';
  static const String _userKey = 'auth_user_data';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Duration _timeoutDuration = const Duration(seconds: 10);

  /// Регистрация нового пользователя
  /// POST /api/auth/register
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');

    final body = jsonEncode({
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(_timeoutDuration);

      final responseData = _decodeResponseBody(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = AuthResult.fromJson(responseData);
        if (result.token != null) {
          await saveSession(result.token!, result.user);
        }
        return result;
      }
      _handleHttpError(response.statusCode, responseData);
    } on AuthException {
      rethrow;
    } on SocketException catch (_) {
      throw _networkException();
    } on http.ClientException catch (_) {
      throw _networkException();
    } on TimeoutException catch (_) {
      throw AuthException(
        message: 'Превышено время ожидания ответа от сервера (${ApiConfig.baseUrl}). Проверьте статус бэкенда.',
      );
    } catch (e) {
      throw AuthException(
        message: 'Не удалось выполнить регистрацию: ${e.toString()}',
      );
    }
  }

  /// Авторизация пользователя по логину/email и паролю
  /// POST /api/auth/login
  Future<AuthResult> login({
    required String login,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    final body = jsonEncode({
      'login': login.trim(),
      'password': password,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(_timeoutDuration);

      final responseData = _decodeResponseBody(response);

      if (response.statusCode == 200) {
        final result = AuthResult.fromJson(responseData);
        if (result.token != null) {
          await saveSession(result.token!, result.user);
        }
        return result;
      }
      _handleHttpError(response.statusCode, responseData);
    } on AuthException {
      rethrow;
    } on SocketException catch (_) {
      throw _networkException();
    } on http.ClientException catch (_) {
      throw _networkException();
    } on TimeoutException catch (_) {
      throw AuthException(
        message: 'Превышено время ожидания ответа от сервера (${ApiConfig.baseUrl}). Проверьте статус бэкенда.',
      );
    } catch (e) {
      throw AuthException(
        message: 'Не удалось выполнить авторизацию: ${e.toString()}',
      );
    }
  }

  /// Получение профиля текущего пользователя по JWT токену
  /// GET /api/auth/me
  Future<UserModel> getMe(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeoutDuration);

      final responseData = _decodeResponseBody(response);

      if (response.statusCode == 200) {
        if (responseData['user'] != null && responseData['user'] is Map<String, dynamic>) {
          final user = UserModel.fromJson(responseData['user'] as Map<String, dynamic>);
          await saveUser(user);
          return user;
        } else {
          final user = UserModel.fromJson(responseData);
          await saveUser(user);
          return user;
        }
      }
      _handleHttpError(response.statusCode, responseData);
    } on AuthException {
      rethrow;
    } on SocketException catch (_) {
      throw _networkException();
    } on http.ClientException catch (_) {
      throw _networkException();
    } on TimeoutException catch (_) {
      throw AuthException(
        message: 'Превышено время ожидания ответа от сервера (${ApiConfig.baseUrl}).',
      );
    } catch (e) {
      throw AuthException(
        message: 'Не удалось получить данные профиля: ${e.toString()}',
      );
    }
  }

  /// Проверка доступности сервера
  /// GET /api/health
  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/health');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Декодирование ответа сервера с поддержкой UTF-8
  Map<String, dynamic> _decodeResponseBody(http.Response response) {
    try {
      final decodedString = utf8.decode(response.bodyBytes);
      final json = jsonDecode(decodedString);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return {'data': json};
    } catch (_) {
      return {'raw': response.body};
    }
  }

  /// Преобразование HTTP ошибок сервера в AuthException
  Never _handleHttpError(int statusCode, Map<String, dynamic> data) {
    String? message;
    List<dynamic>? errors;

    if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
      message = data['message'].toString();
    } else if (data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        errors = detail;
        final firstError = detail.first;
        if (firstError is Map && firstError['msg'] != null) {
          message = firstError['msg'].toString();
        } else {
          message = detail.map((e) => e.toString()).join('; ');
        }
      }
    }

    if (data['errors'] is List) {
      errors = data['errors'] as List<dynamic>;
    }

    if (message == null || message.isEmpty) {
      switch (statusCode) {
        case 400:
          message = 'Некорректный запрос к серверу (400)';
          break;
        case 401:
          message = 'Неверный логин или пароль';
          break;
        case 403:
          message = 'Доступ запрещен (403)';
          break;
        case 404:
          message = 'Ресурс не найден (404)';
          break;
        case 409:
          message = 'Пользователь с таким email или логином уже существует';
          break;
        case 422:
          message = 'Ошибка валидации данных. Проверьте правильность заполнения полей.';
          break;
        case 500:
          message = 'Внутренняя ошибка сервера (500). Попробуйте позже.';
          break;
        default:
          message = 'Ошибка сервера ($statusCode)';
      }
    }

    throw AuthException(
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }

  /// Генерация стандартной сетевой ошибки
  AuthException _networkException() {
    return AuthException(
      message: 'Не удалось подключиться к серверу (${ApiConfig.baseUrl}). Проверьте сеть и запущен ли бэкенд.',
    );
  }

  // --- Методы работы с локальным хранилищем SharedPreferences ---

  /// Сохранение токена и данных пользователя в SharedPreferences
  Future<void> saveSession(String token, UserModel? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    }
  }

  /// Сохранение пользователя в SharedPreferences
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Получение сохраненного JWT токена
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Получение сохраненного пользователя
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Очистка сессии (Выход)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Проверка, авторизован ли пользователь
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
