import 'package:flutter/material.dart';

/// Виджет успешного завершения отправки данных и ответа от сервера
class SubmissionSuccessView extends StatelessWidget {
  final String mode;
  final String login;
  final String timestamp;
  final String serverStatus;
  final String? subtitle;
  final VoidCallback onReset;
  final VoidCallback? onProceed;
  final String proceedLabel;

  const SubmissionSuccessView({
    super.key,
    required this.mode,
    required this.login,
    required this.timestamp,
    required this.onReset,
    this.serverStatus = '200 OK (FastAPI)',
    this.subtitle,
    this.onProceed,
    this.proceedLabel = 'Перейти на главный экран',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('submission_success_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7), // soft green
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A), // vibrant green
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Данные успешно обработаны!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle ?? 'Запрос успешно отправлен и подтвержден сервером.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Карточка деталей отправки
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                icon: Icons.badge_outlined,
                title: 'Режим',
                value: mode,
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                icon: Icons.account_circle_outlined,
                title: 'Логин / Email',
                value: login,
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                icon: Icons.access_time_rounded,
                title: 'Время ответа',
                value: timestamp,
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                icon: Icons.cloud_done_outlined,
                title: 'Статус сервера',
                value: serverStatus,
                valueColor: const Color(0xFF16A34A),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Кнопка перехода на главный экран (если передана)
        if (onProceed != null) ...[
          FilledButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: Text(
              proceedLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Вернуться к форме'),
          ),
        ] else ...[
          // Обычная кнопка возврата
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text(
              'Вернуться к форме',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF1E293B),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
