import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/schedule_model.dart';
// import '../../models/user_model.dart'; // Uncomment if we fetch users for dropdown

class ScheduleManagementPage extends StatefulWidget {
  const ScheduleManagementPage({super.key});

  @override
  State<ScheduleManagementPage> createState() => _ScheduleManagementPageState();
}

class _ScheduleManagementPageState extends State<ScheduleManagementPage> {
  final DatabaseService _databaseService = DatabaseService();
  String searchQuery = '';
  String filterStatus = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Management',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171B1F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'View and manage all pickup schedules',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TextField(
                            onChanged: (value) => setState(() => searchQuery = value),
                            decoration: const InputDecoration(
                              hintText: 'Search by area or ID...',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButton<String>(
                          value: filterStatus,
                          underline: const SizedBox(),
                          items: ['All', 'Active', 'Inactive', 'Common', 'Personal']
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => filterStatus = value!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ScheduleModel>>(
                stream: _databaseService.getAllSchedulesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                     return const Center(child: Text('No schedules found'));
                  }

                  final schedules = snapshot.data!.where((schedule) {
                    final matchesSearch = 
                      (schedule.area.toLowerCase().contains(searchQuery.toLowerCase())) ||
                      (schedule.id?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
                    
                    bool matchesFilter = true;
                    if (filterStatus == 'Active') matchesFilter = schedule.isActive;
                    if (filterStatus == 'Inactive') matchesFilter = !schedule.isActive;
                    if (filterStatus == 'Common') matchesFilter = schedule.isCommon;
                    if (filterStatus == 'Personal') matchesFilter = !schedule.isCommon;

                    return matchesSearch && matchesFilter;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      return _buildScheduleCard(schedules[index]);
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScheduleDialog(),
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    final statusColor = schedule.isActive ? Colors.green : Colors.grey;
    final statusText = schedule.isActive ? 'Active' : 'Inactive';
    final typeText = schedule.isCommon ? 'Common' : 'Personal';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event,
                  color: Color(0xFF43A047),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.area.isNotEmpty ? schedule.area : 'General Area',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${schedule.id}', // Shorten if needed
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: schedule.isCommon
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: schedule.isCommon ? Colors.blue : Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
           _buildInfoRow(Icons.calendar_today, 'Days', schedule.daysOfWeek.join(', ')),
           const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, 'Time', schedule.collectionTime),
          const SizedBox(height: 8),
           _buildInfoRow(Icons.delete_outline, 'Type', schedule.wasteType),
           if (!schedule.isCommon && schedule.citizenId != null) ...[
             const SizedBox(height: 8),
             _buildInfoRow(Icons.person, 'Citizen ID', schedule.citizenId!),
           ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _deleteSchedule(schedule),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showAddScheduleDialog() {
    final formKey = GlobalKey<FormState>();
    final areaController = TextEditingController();
    final timeController = TextEditingController();
    final citizenIdController = TextEditingController();
    final descriptionController = TextEditingController();
    final driverIdController = TextEditingController();
    final routeIdController = TextEditingController();

    const dayOrder = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    String wasteType = 'General';
    final selectedDays = <String>{'Monday'};
    bool isCommon = true;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF5FFF7),
                      Colors.green.shade50,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_note, color: Color(0xFF2E7D32)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add New Schedule',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Common Schedule (All Users)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isCommon ? 'Visible to everyone' : 'Visible to one citizen',
                        ),
                        value: isCommon,
                        onChanged: (val) {
                          setDialogState(() {
                            isCommon = val;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      if (!isCommon)
                        TextFormField(
                          controller: citizenIdController,
                          decoration: const InputDecoration(
                            labelText: 'Citizen ID / User ID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) => !isCommon && (value == null || value.isEmpty)
                              ? 'Required for personal schedule' 
                              : null,
                        ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: areaController,
                        decoration: const InputDecoration(
                          labelText: 'Area / Zone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: wasteType,
                        decoration: const InputDecoration(
                          labelText: 'Waste Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.delete_outline),
                        ),
                        items: ['General', 'Recycling', 'Organic', 'Hazardous', 'E-Waste']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => wasteType = v!),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Collection Days',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: dayOrder.map((day) {
                          final isSelected = selectedDays.contains(day);
                          return ChoiceChip(
                            label: Text(day.substring(0, 3)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(day);
                                } else if (selectedDays.length > 1) {
                                  selectedDays.remove(day);
                                }
                              });
                            },
                            selectedColor: const Color(0xFF4CAF50),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: const Color(0xFFE8F5E9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: timeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        onTap: () async {
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (!context.mounted) return;
                          if (pickedTime != null) {
                            timeController.text = pickedTime.format(context);
                          }
                        },
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: driverIdController,
                              decoration: const InputDecoration(
                                labelText: 'Driver ID (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_pin_circle_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: routeIdController,
                              decoration: const InputDecoration(
                                labelText: 'Route ID (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.alt_route),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activate schedule now'),
                        subtitle: Text(isActive ? 'Status: Active' : 'Status: Inactive'),
                        value: isActive,
                        onChanged: (value) => setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedDays.isNotEmpty) {
                      final orderedDays = dayOrder.where(selectedDays.contains).toList();
                      final newSchedule = ScheduleModel(
                        area: areaController.text.trim(),
                        wasteType: wasteType,
                        daysOfWeek: orderedDays,
                        collectionTime: timeController.text.trim(),
                        createdAt: DateTime.now(),
                        isActive: isActive,
                        isCommon: isCommon,
                        citizenId: isCommon ? null : citizenIdController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        driverId: driverIdController.text.trim().isEmpty
                            ? null
                            : driverIdController.text.trim(),
                        routeId: routeIdController.text.trim().isEmpty
                            ? null
                            : routeIdController.text.trim(),
                      );
                      
                      try {
                        await _databaseService.createSchedule(newSchedule);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Schedule created successfully'),
                            backgroundColor: Color(0xFF43A047),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _deleteSchedule(ScheduleModel schedule) {
    if (schedule.id == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             onPressed: () async {
               try {
                 await _databaseService.deleteSchedule(schedule.id!);
                 if (!context.mounted) return;
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Schedule deleted successfully')),
                 );
               } catch (e) {
                 if (!context.mounted) return;
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                 );
               }
             },
             child: const Text('Delete'),
           )
        ],
      )
    );
  }
}
