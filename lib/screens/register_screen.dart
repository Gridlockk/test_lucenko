import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sending_status_banner.dart';
import '../widgets/submission_success_view.dart';

/// Окно регистрации
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSending = false;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _submittedLogin = '';
  String _submittedTime = '';
  UserModel? _registeredUser;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Отправка формы регистрации на FastAPI сервер
  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Реальный вызов REST API эндпоинта POST /api/auth/register
      final authResult = await _authService.register(
        username: username,
        email: email,
        password: password,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      setState(() {
        _isSending = false;
        _isSuccess = true;
        _submittedLogin = '$username ($email)';
        _submittedTime = timeStr;
        _registeredUser = authResult.user;
      });

      // Зеленый SnackBar с сообщением от сервера
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  authResult.message.isNotEmpty
                      ? authResult.message
                      : 'Регистрация прошла успешно!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      // Красный SnackBar с ошибкой (например, 409 Email занят)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      // Уведомление о сетевой ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Не удалось подключиться к серверу (${ApiConfig.baseUrl}). Проверьте сеть и запущен ли бэкенд.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _isSuccess = false;
      _isSending = false;
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess ? _buildSuccessView() : _buildRegisterForm(theme),
      ),
    );
  }

  Widget _buildSuccessView() {
    return SubmissionSuccessView(
      mode: 'Регистрация',
      login: _submittedLogin,
      timestamp: _submittedTime,
      serverStatus: '201 Created (FastAPI)',
      subtitle: 'Аккаунт успешно создан и сохранен в базе данных.',
      onProceed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
          arguments: _registeredUser,
        );
      },
      proceedLabel: 'Перейти в личный кабинет',
      onReset: _resetForm,
    );
  }

  Widget _buildRegisterForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Иконка
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Заголовок
          Text(
            'Создание аккаунта',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Заполните поля для быстрой регистрации',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Баннер статуса отправки
          if (_isSending) ...[
            const SendingStatusBanner(),
            const SizedBox(height: 20),
          ],

          // Поле: Логин / Имя пользователя
          TextFormField(
            controller: _usernameController,
            enabled: !_isSending,
            decoration: const InputDecoration(
              labelText: 'Логин / Имя пользователя',
              hintText: 'ivan_ivanov',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите логин';
              }
              if (value.trim().length < 3) {
                return 'Логин должен быть не менее 3 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Поле: Email
          TextFormField(
            controller: _emailController,
            enabled: !_isSending,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email адрес',
              hintText: 'user@example.com',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, укажите email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Введите корректный email адрес';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Поле: Пароль
          TextFormField(
            controller: _passwordController,
            enabled: !_isSending,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Пожалуйста, введите пароль';
              }
              if (value.length < 6) {
                return 'Пароль должен содержать минимум 6 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Поле: Подтверждение пароля
          TextFormField(
            controller: _confirmPasswordController,
            enabled: !_isSending,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Подтверждение пароля',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Подтвердите пароль';
              }
              if (value != _passwordController.text) {
                return 'Пароли не совпадают';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Кнопка регистрации
          FilledButton(
            onPressed: _isSending ? null : _submitRegister,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor:
                  const Color(0xFF4F46E5).withValues(alpha: 0.6),
            ),
            child: _isSending
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Регистрация на сервере...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Зарегистрироваться',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          // Переход ко входу
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Уже зарегистрированы?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              TextButton(
                onPressed: _isSending
                    ? null
                    : () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                child: const Text(
                  'Войти',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
