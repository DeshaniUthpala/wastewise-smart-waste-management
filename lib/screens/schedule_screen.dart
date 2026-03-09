import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule_model.dart';
import 'package:intl/intl.dart';
import 'request_pickup_screen.dart';
import '../widgets/citizen_page_header.dart';


class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9), // Light green
              Colors.white,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: CitizenPageHeader(
                title: 'Schedule',
                subtitle: 'View your collection calendar and pickup days',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null)
                    StreamBuilder<List<ScheduleModel>>(
                      stream: DatabaseService().getSchedulesStream(
                        userId: user.uid,
                        isActive: true,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildEmptyScheduleState(context);
                        }

                        final schedules = snapshot.data!;
                        final activeSchedules = schedules.where((s) => s.isActive).toList();
                        final lastScheduledDate = _findLastScheduledDate(activeSchedules);
                        final selectedSchedules = _selectedDate != null
                            ? _schedulesForDate(activeSchedules, _selectedDate!)
                            : <ScheduleModel>[];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCalendarCard(activeSchedules),
                            const SizedBox(height: 16),
                            _buildLastScheduledCard(lastScheduledDate, activeSchedules),
                            const SizedBox(height: 16),
                            _buildSelectedDateSchedules(selectedSchedules),
                          ],
                        );
                      },
                    )
                  else
                    const Center(child: Text("Please perform a login to see schedules")),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9), // Light green
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lightbulb_outline,
                                color: Color(0xFF4CAF50), // Green
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Helpful Tips',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32), // Dark green
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTip('Place bins outside by 7:00 AM', Icons.schedule),
                        _buildTip('Keep recyclables clean and dry', Icons.water_drop_outlined),
                        _buildTip('Separate organic waste properly', Icons.eco_outlined),
                        _buildTip('Tie plastic bags securely', Icons.shopping_bag_outlined),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(List<ScheduleModel> schedules) {
    final monthLabel = DateFormat('MMMM yyyy').format(_displayedMonth);
    final monthDays = _buildMonthDays(_displayedMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              _WeekDayLabel('Mon'),
              _WeekDayLabel('Tue'),
              _WeekDayLabel('Wed'),
              _WeekDayLabel('Thu'),
              _WeekDayLabel('Fri'),
              _WeekDayLabel('Sat'),
              _WeekDayLabel('Sun'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (context, index) {
              final day = monthDays[index];
              final inCurrentMonth = day.month == _displayedMonth.month;
              final isSelected = _selectedDate != null && _isSameDay(_selectedDate!, day);
              final hasSchedule = _hasScheduleOnDate(schedules, day);

              return GestureDetector(
                onTap: () {
                  if (!inCurrentMonth) return;
                  setState(() => _selectedDate = day);
                },
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : hasSchedule
                            ? const Color(0xFFE8F5E9)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          color: !inCurrentMonth
                              ? Colors.grey[400]
                              : isSelected
                                  ? Colors.white
                                  : Colors.black87,
                          fontWeight: hasSchedule || isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasSchedule)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyScheduleState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFECFDF3),
            Color(0xFFDFF5E6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -28,
              bottom: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      size: 42,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Schedule Yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin has not published your collection plan yet.\nPlease check again soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keep notifications ON to get your schedule instantly.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RequestPickupScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Request Pickup'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastScheduledCard(DateTime? lastScheduledDate, List<ScheduleModel> schedules) {
    final title = lastScheduledDate == null
        ? 'No previous schedule day'
        : DateFormat('EEEE, dd MMM yyyy').format(lastScheduledDate);
    final scheduleCount = lastScheduledDate == null
        ? 0
        : _schedulesForDate(schedules, lastScheduledDate).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Scheduled Day',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (scheduleCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$scheduleCount pickup${scheduleCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateSchedules(List<ScheduleModel> schedules) {
    final selectedLabel = _selectedDate == null
        ? 'Selected Day'
        : DateFormat('EEEE, dd MMM').format(_selectedDate!);

    if (_selectedDate == null || schedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Select a day to view schedule details'
                    : 'No pickup schedule for $selectedLabel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Schedules for $selectedLabel',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        ...schedules.map(
          (schedule) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildScheduleCard(
              schedule.wasteType,
              schedule.daysOfWeek.join(', '),
              schedule.collectionTime,
              _getIconForType(schedule.wasteType),
              _getColorForType(schedule.wasteType),
              true,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasScheduleOnDate(List<ScheduleModel> schedules, DateTime date) {
    return _schedulesForDate(schedules, date).isNotEmpty;
  }

  List<ScheduleModel> _schedulesForDate(List<ScheduleModel> schedules, DateTime date) {
    final dayName = DateFormat('EEEE').format(date).toLowerCase();
    final dateOnly = DateTime(date.year, date.month, date.day);

    return schedules.where((s) {
      final createdDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      final normalizedDays = s.daysOfWeek.map((d) => d.toString().trim().toLowerCase()).toList();
      final hasDay = normalizedDays.contains(dayName) ||
          normalizedDays.any((d) => d.startsWith(dayName.substring(0, 3)));
      return hasDay && !dateOnly.isBefore(createdDate);
    }).toList();
  }

  DateTime? _findLastScheduledDate(List<ScheduleModel> schedules) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (int i = 0; i <= 120; i++) {
      final day = todayOnly.subtract(Duration(days: i));
      if (_hasScheduleOnDate(schedules, day)) {
        return day;
      }
    }
    return null;
  }

  List<DateTime> _buildMonthDays(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = firstOfMonth.weekday - 1;
    final startDate = firstOfMonth.subtract(Duration(days: startOffset));

    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'Recyclable': return Icons.recycling;
      case 'Organic': return Icons.eco;
      case 'Hazardous': return Icons.warning;
      case 'E-Waste': return Icons.electrical_services;
      default: return Icons.delete;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'Recyclable': return Colors.blue;
      case 'Organic': return Colors.green;
      case 'Hazardous': return Colors.red;
      case 'E-Waste': return Colors.orange;
      default: return Colors.grey;
    }
  }


  Widget _buildScheduleCard(
    String title,
    String days,
    String time,
    IconData icon,
    Color color,
    bool isNext,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'NEXT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          days,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String tip, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4CAF50)), // Green
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF424242), // Dark gray
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayLabel extends StatelessWidget {
  final String label;

  const _WeekDayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
