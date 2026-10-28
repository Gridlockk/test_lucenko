import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Главный экран приложения после успешной авторизации
class HomeScreen extends StatefulWidget {
  final UserModel? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  bool _isCheckingHealth = false;
  bool? _isServerOnline;
  String? _jwtToken;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _jwtToken = await _authService.getToken();

    if (_currentUser == null) {
      final savedUser = await _authService.getSavedUser();
      if (savedUser != null) {
        setState(() {
          _currentUser = savedUser;
        });
      }

      if (_jwtToken != null) {
        try {
          final remoteUser = await _authService.getMe(_jwtToken!);
          if (mounted) {
            setState(() {
              _currentUser = remoteUser;
            });
          }
        } catch (_) {
          // Если не удалось загрузить актуальный профиль, используем сохраненный
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingUser = false;
      });
    }

    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    setState(() {
      _isCheckingHealth = true;
    });

    final isOnline = await _authService.checkHealth();

    if (mounted) {
      setState(() {
        _isServerOnline = isOnline;
        _isCheckingHealth = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти из приложения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная страница'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Выйти из аккаунта',
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4F46E5).withValues(alpha: 0.05),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Карточка приветствия
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Вы успешно авторизованы!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добро пожаловать в рабочее пространство приложения',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Данные пользователя
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            const Text(
                              'Профиль пользователя',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (_isLoadingUser)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          _buildInfoRow('Логин:', _currentUser?.username ?? 'Не указан', Icons.account_circle_outlined),
                          const SizedBox(height: 12),
                          _buildInfoRow('Email:', _currentUser?.email ?? 'Не указан', Icons.alternate_email_rounded),
                          const SizedBox(height: 12),
                          _buildInfoRow('ID пользователя:', _currentUser?.id?.toString() ?? '1', Icons.tag_rounded),
                          if (_currentUser?.createdAt != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('Дата регистрации:', _currentUser!.createdAt!, Icons.calendar_today_rounded),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Статус сервера FastAPI
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.dns_rounded, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Соединение с FastAPI',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: _isCheckingHealth
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              tooltip: 'Проверить статус сервера',
                              onPressed: _isCheckingHealth ? null : _checkServerHealth,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Text(
                              'Адрес API: ',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            Expanded(
                              child: Text(
                                ApiConfig.baseUrl,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Статус сервера (/health): ',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isServerOnline == true
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isServerOnline == true
                                    ? 'Онлайн (200 OK)'
                                    : _isServerOnline == false
                                        ? 'Недоступен'
                                        : 'Проверка...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isServerOnline == true
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Кнопка выхода
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text(
                    'Выйти из учетной записи',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
