import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/sending_status_banner.dart';
import '../widgets/submission_success_view.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Окно авторизации (Вход)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _loginEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSending = false;
  bool _isSuccess = false;
  bool _obscurePassword = true;

  String _submittedLogin = '';
  String _submittedTime = '';
  UserModel? _loggedInUser;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Отправка формы авторизации на FastAPI сервер
  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
    });

    final login = _loginEmailController.text.trim();
    final password = _passwordController.text;

    try {
      // Реальный вызов REST API эндпоинта POST /api/auth/login
      final authResult = await _authService.login(
        login: login,
        password: password,
      );

      if (!mounted) return;

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      setState(() {
        _isSending = false;
        _isSuccess = true;
        _submittedLogin = login;
        _submittedTime = timeStr;
        _loggedInUser = authResult.user;
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
                      : 'Успешная авторизация в системе!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      // Переход на главный экран
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: authResult.user),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      // Красный SnackBar с текстом ошибки
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
      _loginEmailController.clear();
      _passwordController.clear();
      _formKey.currentState?.reset();
    });
  }

  /// Диалог настройки IP адреса сервера (удобно для реального смартфона)
  Future<void> _showServerSettingsDialog() async {
    final hostController = TextEditingController(text: ApiConfig.customHost ?? '');
    final portController = TextEditingController(text: ApiConfig.port.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Параметры API сервера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Текущий адрес: ${ApiConfig.baseUrl}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'IP хоста (пусто = авто)',
                hintText: 'например 192.168.1.100',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Порт',
                hintText: '8001 или 8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final newHost = hostController.text.trim();
              final newPort = int.tryParse(portController.text.trim());
              setState(() {
                ApiConfig.customHost = newHost.isEmpty ? null : newHost;
                if (newPort != null && newPort > 0) {
                  ApiConfig.port = newPort;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess ? _buildSuccessView() : _buildLoginForm(theme),
      ),
    );
  }

  Widget _buildSuccessView() {
    return SubmissionSuccessView(
      mode: 'Авторизация (Вход)',
      login: _submittedLogin,
      timestamp: _submittedTime,
      serverStatus: '200 OK (FastAPI)',
      subtitle: 'Сессия подтверждена сервером. JWT токен сохранен.',
      onProceed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: _loggedInUser),
          ),
        );
      },
      proceedLabel: 'Перейти на главный экран',
      onReset: _resetForm,
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Верхняя панель с кнопкой настройки сервера
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              color: Colors.grey.shade500,
              tooltip: 'Настройки сервера (${ApiConfig.baseUrl})',
              onPressed: _isSending ? null : _showServerSettingsDialog,
            ),
          ),

          // Иконка
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_open_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Заголовок
          Text(
            'Вход в аккаунт',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Введите ваш логин или почту для авторизации',
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

          // Поле: Логин или Email
          TextFormField(
            controller: _loginEmailController,
            enabled: !_isSending,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Логин или Email',
              hintText: 'user@example.com или my_login',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, укажите логин или email';
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
          const SizedBox(height: 24),

          // Кнопка входа
          FilledButton(
            onPressed: _isSending ? null : _submitLogin,
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
                        'Подключение к серверу...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Войти',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          // Переход к регистрации
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ещё нет аккаунта?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              TextButton(
                onPressed: _isSending
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text(
                  'Зарегистрироваться',
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
