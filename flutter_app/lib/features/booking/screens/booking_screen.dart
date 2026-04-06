import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../models/club.dart';
import '../../../services/supabase_service.dart';
import '../../../services/notification_service.dart';

final _clubsProvider = FutureProvider<List<Club>>((ref) async {
  return SupabaseService().getActiveClubs();
});

final _myBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getMyBookings();
});

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  Club? _selectedClub;
  String _selectedZone = 'basic';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationHours = 2;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(_clubsProvider);
    final bookingsAsync = ref.watch(_myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Бронирование')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // My active bookings
          bookingsAsync.when(
            data: (bookings) {
              final active = bookings.where((b) => b['status'] == 'confirmed').toList();
              if (active.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Активные бронирования',
                      style: TextStyle(color: context.text1,
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...active.map((b) => _BookingCard(booking: b, onCancel: () async {
                    await SupabaseService().cancelBooking(b['id'] as String);
                    ref.invalidate(_myBookingsProvider);
                  })),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // New booking form
          Text('Новое бронирование',
              style: TextStyle(color: context.text1,
                  fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),

          // Club selector
          Text('Клуб', style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 6),
          clubsAsync.when(
            data: (clubs) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Club>(
                  value: _selectedClub,
                  hint: Text('Выберите клуб', style: TextStyle(color: context.text3)),
                  isExpanded: true,
                  dropdownColor: context.card,
                  items: clubs.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name, style: TextStyle(color: context.text1)),
                  )).toList(),
                  onChanged: (c) => setState(() => _selectedClub = c),
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Ошибка загрузки', style: TextStyle(color: AppTheme.error)),
          ),
          const SizedBox(height: 16),

          // Zone selector
          Text('Зона', style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: ['basic', 'pro', 'vip'].map((zone) {
              final selected = _selectedZone == zone;
              final label = zone == 'basic' ? 'Базовая' : zone == 'pro' ? 'Про' : 'VIP';
              final color = zone == 'vip' ? const Color(0xFFFBBF24) :
                  zone == 'pro' ? AppTheme.neonPurple : AppTheme.success;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedZone = zone),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.15) : context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? color : context.border),
                    ),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? color : context.text3,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 14,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Date picker
          Text('Дата', style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: context.text3, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                    style: TextStyle(color: context.text1, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time picker
          Text('Время', style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) setState(() => _selectedTime = time);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, color: context.text3, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: context.text1, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Duration
          Text('Длительность', style: TextStyle(color: context.text2, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [1, 2, 3, 4, 5].map((h) {
              final selected = _durationHours == h;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _durationHours = h),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary.withValues(alpha: 0.15) : context.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppTheme.primary : context.border),
                    ),
                    child: Text('$h ч',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? AppTheme.primary : context.text3,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Submit
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _selectedClub != null ? AppTheme.neonGlow(radius: 16) : [],
            ),
            child: ElevatedButton(
              onPressed: _selectedClub == null || _loading ? null : _submitBooking,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Забронировать'),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
    setState(() => _loading = true);
    try {
      final bookingTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      await SupabaseService().createBooking(
        clubId: _selectedClub!.id,
        zone: _selectedZone,
        bookingTime: bookingTime,
        durationHours: _durationHours,
      );

      // Schedule reminder notification
      NotificationService().scheduleBookingReminder(
        bookingId: '${_selectedClub!.id}_${bookingTime.millisecondsSinceEpoch}',
        bookingTime: bookingTime,
        clubName: _selectedClub!.name,
      );

      ref.invalidate(_myBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бронирование создано!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCancel;
  const _BookingCard({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final clubName = (booking['clubs'] as Map<String, dynamic>?)?['name'] ?? '';
    final zone = booking['zone'] as String? ?? 'basic';
    final time = DateTime.tryParse(booking['booking_time'] as String? ?? '');
    final duration = booking['duration_hours'] as int? ?? 2;

    final zoneColor = zone == 'vip' ? const Color(0xFFFBBF24) :
        zone == 'pro' ? AppTheme.neonPurple : AppTheme.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zoneColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_seat_rounded, color: zoneColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clubName, style: TextStyle(
                    color: context.text1, fontWeight: FontWeight.w600)),
                if (time != null)
                  Text(
                    '${time.day}.${time.month.toString().padLeft(2, '0')} в ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · $duration ч',
                    style: TextStyle(color: context.text3, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.error, size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
