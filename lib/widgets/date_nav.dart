import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

class DateNav extends ConsumerWidget {
  const DateNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dateFormat = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 1));
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  locale: const Locale('tr', 'TR'),
                );
                if (picked != null) {
                  ref.read(selectedDateProvider.notifier).state = picked;
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateFormat.format(selectedDate),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (_isToday(selectedDate))
                    Text(
                      'Bugün',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1));
            },
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
