import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../models/club.dart';
import '../../../services/supabase_service.dart';
import '../../../services/notification_service.dart';

final _clubsProvider = FutureProvider<List<Club>>((ref) async {
  return SupabaseService().getActiveClubs();
});

final _myBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getMyBookings();
});

class BookingScreen extends ConsumerStatefulWidget {
  final String? preselectedClubId;
  const BookingScreen({super.key, this.preselectedClubId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  Club? _selectedClub;
  String _selectedZone = 'basic';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay(
    hour: TimeOfDay.now().hour + 1,
    minute: 0,
  );
  int _durationHours = 2;
  bool _loading = false;
  bool _preselected = false;

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(_clubsProvider);
    final bookingsAsync = ref.watch(_myBookingsProvider);

    // Pre-select club if provided
    if (!_preselected && widget.preselectedClubId != null) {
      clubsAsync.whenData((clubs) {
        final match = clubs.where((c) => c.id == widget.preselectedClubId);
        if (match.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_preselected) {
              setState(() {
                _selectedClub = match.first;
                _preselected = true;
              });
            }
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(ref.lang('booking.title')),
        backgroundColor: context.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info banner about grace period ──────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ref.lang('booking.info'),
                    style: TextStyle(
                        color: context.text2, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── My bookings ─────────────────────────────────
          bookingsAsync.when(
            data: (bookings) {
              final active = bookings
                  .where((b) =>
                      (b['status'] as String? ?? 'pending') == 'confirmed' ||
                      (b['status'] as String? ?? 'pending') == 'active')
                  .toList();
              if (active.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ref.lang('booking.my'),
                          style: TextStyle(
                              color: context.text1,
                              fontWeight: FontWeight.w700,
                              fontSize: 17)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${active.length}',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...active.map((b) => _BookingCard(
                        key: ValueKey(b['id']),
                        booking: b,
                        onCancel: () async {
                          await SupabaseService()
                              .cancelBooking(b['id'] as String? ?? '');
                          ref.invalidate(_myBookingsProvider);
                        },
                      )),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── New booking form ────────────────────────────
          _SectionTitle(title: ref.lang('booking.new')),
          const SizedBox(height: 14),

          // Club selector
          _Label(text: ref.lang('booking.club')),
          const SizedBox(height: 6),
          clubsAsync.when(
            data: (clubs) => GestureDetector(
              onTap: () => _showClubPicker(context, clubs),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _selectedClub != null
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : context.border),
                ),
                child: _selectedClub != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _selectedClub!.photos.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _selectedClub!.photos.first,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    color: context.surface,
                                    child: Icon(Icons.sports_esports,
                                        color: context.text3, size: 22),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedClub!.name,
                                    style: TextStyle(
                                        color: context.text1,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                Text(_selectedClub!.address,
                                    style: TextStyle(
                                        color: context.text3, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: context.text3),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: context.text3, size: 20),
                          const SizedBox(width: 10),
                          Text(ref.lang('booking.select_club'),
                              style: TextStyle(
                                  color: context.text3, fontSize: 15)),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: context.text3),
                        ],
                      ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('${ref.lang('common.error')}',
                style: const TextStyle(color: AppTheme.error)),
          ),
          const SizedBox(height: 16),

          // Zone selector
          _Label(text: ref.lang('booking.zone')),
          const SizedBox(height: 6),
          Row(
            children: [
              _ZoneChip(
                  zone: 'basic',
                  label: ref.lang('booking.zone_basic'),
                  icon: Icons.computer_rounded,
                  color: AppTheme.success,
                  selected: _selectedZone == 'basic',
                  onTap: () => setState(() => _selectedZone = 'basic')),
              const SizedBox(width: 8),
              _ZoneChip(
                  zone: 'pro',
                  label: ref.lang('booking.zone_pro'),
                  icon: Icons.speed_rounded,
                  color: AppTheme.neonPurple,
                  selected: _selectedZone == 'pro',
                  onTap: () => setState(() => _selectedZone = 'pro')),
              const SizedBox(width: 8),
              _ZoneChip(
                  zone: 'vip',
                  label: 'VIP',
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFFFBBF24),
                  selected: _selectedZone == 'vip',
                  onTap: () => setState(() => _selectedZone = 'vip')),
            ],
          ),
          const SizedBox(height: 16),

          // Date selector — horizontal scroll of 7 days
          _Label(text: ref.lang('booking.date')),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final date = DateTime.now().add(Duration(days: i));
                final selected = _selectedDate.day == date.day &&
                    _selectedDate.month == date.month;
                final dayNames = [ref.lang('booking.day_mon'), ref.lang('booking.day_tue'), ref.lang('booking.day_wed'), ref.lang('booking.day_thu'), ref.lang('booking.day_fri'), ref.lang('booking.day_sat'), ref.lang('booking.day_sun')];
                final dayName =
                    i == 0 ? ref.lang('booking.today') : dayNames[date.weekday - 1];

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : context.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected ? AppTheme.primary : context.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayName,
                            style: TextStyle(
                                color: selected
                                    ? AppTheme.primary
                                    : context.text3,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('${date.day}',
                            style: TextStyle(
                                color: selected
                                    ? AppTheme.primary
                                    : context.text1,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Time selector — grid of time slots
          _Label(text: ref.lang('booking.time')),
          const SizedBox(height: 6),
          _TimeSlotGrid(
            selectedTime: _selectedTime,
            selectedDate: _selectedDate,
            onSelect: (t) => setState(() => _selectedTime = t),
          ),
          const SizedBox(height: 16),

          // Duration
          _Label(text: ref.lang('booking.duration')),
          const SizedBox(height: 6),
          Row(
            children: [1, 2, 3, 4, 5].map((h) {
              final selected = _durationHours == h;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _durationHours = h),
                  child: Container(
                    margin: EdgeInsets.only(right: h < 5 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              selected ? AppTheme.primary : context.border),
                    ),
                    child: Text('$h ${ref.lang('booking.hours_short')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? AppTheme.primary : context.text3,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 15,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Price estimate
          if (_selectedClub != null) ...[
            _PriceEstimate(
              club: _selectedClub!,
              zone: _selectedZone,
              durationHours: _durationHours,
            ),
            const SizedBox(height: 16),
          ],

          // Grace period reminder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: Color(0xFFFBBF24), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ref.lang('booking.grace_warn'),
                    style: TextStyle(
                        color: context.text2, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _selectedClub == null || _loading ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(ref.lang('booking.submit'),
                      style: const
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 24),

          // History section
          bookingsAsync.when(
            data: (bookings) {
              final past = bookings
                  .where((b) {
                    final status = b['status'] as String? ?? 'pending';
                    return status == 'completed' ||
                        status == 'cancelled' ||
                        status == 'no_show';
                  })
                  .take(5)
                  .toList();
              if (past.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: ref.lang('booking.history')),
                  const SizedBox(height: 8),
                  ...past.map((b) => _HistoryCard(key: ValueKey(b['id']), booking: b)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showClubPicker(BuildContext context, List<Club> clubs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ref.lang('booking.select_club'),
                  style: TextStyle(
                      color: context.text1,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: clubs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = clubs[i];
                  final isSelected = _selectedClub?.id == c.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedClub = c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : context.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: c.photos.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: c.photos.first,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: context.bg,
                                    child: Icon(Icons.sports_esports,
                                        color: context.text3),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: TextStyle(
                                        color: context.text1,
                                        fontWeight: FontWeight.w600)),
                                Text(c.address,
                                    style: TextStyle(
                                        color: context.text3, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primary, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    setState(() => _loading = true);
    try {
      final bookingTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Don't allow booking in the past
      if (bookingTime.isBefore(DateTime.now())) {
        throw Exception(ref.lang('booking.past_error'));
      }

      await SupabaseService().createBooking(
        clubId: _selectedClub!.id,
        zone: _selectedZone,
        bookingTime: bookingTime,
        durationHours: _durationHours,
      );

      NotificationService().scheduleBookingReminder(
        bookingId:
            '${_selectedClub!.id}_${bookingTime.millisecondsSinceEpoch}',
        bookingTime: bookingTime,
        clubName: _selectedClub!.name,
      );

      ref.invalidate(_myBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.lang('booking.created')),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Section title ──────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            color: context.text1, fontWeight: FontWeight.w700, fontSize: 17));
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: context.text2, fontSize: 13, fontWeight: FontWeight.w500));
  }
}

// ── Zone chip ──────────────────────────────────────────────
class _ZoneChip extends StatelessWidget {
  final String zone;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ZoneChip({
    required this.zone,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : context.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : context.text3, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: selected ? color : context.text3,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time slot grid ─────────────────────────────────────────
class _TimeSlotGrid extends StatelessWidget {
  final TimeOfDay selectedTime;
  final DateTime selectedDate;
  final ValueChanged<TimeOfDay> onSelect;
  const _TimeSlotGrid({
    required this.selectedTime,
    required this.selectedDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.day == now.day &&
        selectedDate.month == now.month &&
        selectedDate.year == now.year;
    final minHour = isToday ? now.hour + 1 : 0;

    // Generate time slots from minHour to 23
    final slots = <TimeOfDay>[];
    for (int h = minHour; h < 24; h++) {
      slots.add(TimeOfDay(hour: h, minute: 0));
      if (h < 23) slots.add(TimeOfDay(hour: h, minute: 30));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: slots.map((t) {
        final selected =
            selectedTime.hour == t.hour && selectedTime.minute == t.minute;
        return GestureDetector(
          onTap: () => onSelect(t),
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : context.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? AppTheme.primary : context.border),
            ),
            child: Text(
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppTheme.primary : context.text2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Price estimate ─────────────────────────────────────────
class _PriceEstimate extends ConsumerWidget {
  final Club club;
  final String zone;
  final int durationHours;
  const _PriceEstimate({
    required this.club,
    required this.zone,
    required this.durationHours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiplier = zone == 'vip' ? 2.0 : zone == 'pro' ? 1.5 : 1.0;
    final estimated = (club.pricePerHour * multiplier * durationHours).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: context.text3, size: 20),
          const SizedBox(width: 10),
          Text('${ref.lang('booking.price')}:',
              style: TextStyle(color: context.text2, fontSize: 14)),
          const Spacer(),
          Text('~${_formatPrice(estimated)} ${ref.lang('booking.sum')}',
              style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}K';
    }
    return price.toString();
  }
}

// ── Active booking card ────────────────────────────────────
class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCancel;
  const _BookingCard({super.key, required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubData = booking['clubs'] as Map<String, dynamic>?;
    final clubName = clubData?['name'] as String? ?? '';
    final clubPhotos = (clubData?['photos'] as List?)?.cast<String>() ?? [];
    final zone = booking['zone'] as String? ?? 'basic';
    final time = DateTime.tryParse(booking['booking_time'] as String? ?? '');
    final duration = booking['duration_hours'] as int? ?? 2;
    final status = booking['status'] as String? ?? 'confirmed';
    final graceStr = booking['grace_expires_at'] as String?;
    final graceExpires =
        graceStr != null ? DateTime.tryParse(graceStr) : null;

    final zoneColor = zone == 'vip'
        ? const Color(0xFFFBBF24)
        : zone == 'pro'
            ? AppTheme.neonPurple
            : AppTheme.success;
    final zoneLabel = zone == 'vip' ? ref.lang('booking.zone_vip') : zone == 'pro' ? ref.lang('booking.zone_pro') : ref.lang('booking.zone_basic');

    // Grace period countdown
    final now = DateTime.now();
    final isGracePeriod = status == 'confirmed' &&
        graceExpires != null &&
        time != null &&
        now.isAfter(time) &&
        now.isBefore(graceExpires);
    final graceMinutesLeft = isGracePeriod
        ? graceExpires!.difference(now).inMinutes + 1
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zoneColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: clubPhotos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: clubPhotos.first,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: zoneColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.event_seat_rounded,
                            color: zoneColor, size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clubName,
                        style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    if (time != null)
                      Text(
                        '${time.day}.${time.month.toString().padLeft(2, '0')} в ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · $duration ч',
                        style:
                            TextStyle(color: context.text3, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(zoneLabel,
                    style: TextStyle(
                        color: zoneColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (isGracePeriod) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppTheme.error, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    ref.lang('booking.grace_left').replaceAll('{n}', '$graceMinutesLeft'),
                    style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(ref.lang('booking.cancel'), style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
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

// ── History card ───────────────────────────────────────────
class _HistoryCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  const _HistoryCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubName =
        (booking['clubs'] as Map<String, dynamic>?)?['name'] ?? '';
    final status = booking['status'] as String? ?? '';
    final time = DateTime.tryParse(booking['booking_time'] as String? ?? '');
    final duration = booking['duration_hours'] as int? ?? 0;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = AppTheme.success;
        statusLabel = ref.lang('booking.completed');
        statusIcon = Icons.check_circle_outline_rounded;
      case 'no_show':
        statusColor = AppTheme.error;
        statusLabel = ref.lang('booking.no_show');
        statusIcon = Icons.warning_amber_rounded;
      default:
        statusColor = context.text3;
        statusLabel = ref.lang('booking.cancelled');
        statusIcon = Icons.cancel_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clubName,
                    style: TextStyle(
                        color: context.text1,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                if (time != null)
                  Text(
                    '${time.day}.${time.month.toString().padLeft(2, '0')} · $duration ч',
                    style: TextStyle(color: context.text3, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
