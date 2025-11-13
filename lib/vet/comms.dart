import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class CommsPage extends StatefulWidget {
  const CommsPage({super.key});

  @override
  State<CommsPage> createState() => _CommsPageState();
}

class _CommsPageState extends State<CommsPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _databaseURL,
  );

  late DatabaseReference _appointmentsRef;
  List<_Appointment> _appointments = [];
  bool _isLoading = true;
  String _filter = 'upcoming'; // 'upcoming', 'past', 'all'

  @override
  void initState() {
    super.initState();
    final vetUid = FirebaseAuth.instance.currentUser?.uid;
    if (vetUid != null) {
      _appointmentsRef = _database.ref('users/$vetUid/appointments');
      _loadAppointments();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _loadAppointments() {
    _appointmentsRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      final List<_Appointment> appointments = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              appointments.add(_Appointment.fromMap(key, value));
            } catch (e) {
              // Skip invalid entries
            }
          }
        });
      }

      appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    });
  }

  List<_Appointment> get _filteredAppointments {
    final now = DateTime.now();
    switch (_filter) {
      case 'upcoming':
        return _appointments
            .where((a) => !a.completed && a.dateTime.isAfter(now))
            .toList();
      case 'past':
        return _appointments
            .where((a) => a.completed || a.dateTime.isBefore(now))
            .toList();
      default:
        return _appointments;
    }
  }

  Future<void> _showAddAppointmentDialog() async {
    final petNameController = TextEditingController();
    final ownerEmailController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule New Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: petNameController,
                  decoration: const InputDecoration(
                    labelText: 'Pet Name',
                    prefixIcon: Icon(Icons.pets),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ownerEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Owner Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMM dd, yyyy').format(selectedDate!),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    selectedTime == null
                        ? 'Select Time'
                        : selectedTime!.format(context),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (petNameController.text.trim().isEmpty ||
                    ownerEmailController.text.trim().isEmpty ||
                    selectedDate == null ||
                    selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                final vetUid = FirebaseAuth.instance.currentUser?.uid;
                final vetEmail = FirebaseAuth.instance.currentUser?.email;
                if (vetUid == null || vetEmail == null) return;

                // Find owner UID by email
                final usersRef = _database.ref('users');
                final usersSnapshot = await usersRef.get();

                String? ownerUid;
                if (usersSnapshot.exists && usersSnapshot.value is Map) {
                  final users = Map<dynamic, dynamic>.from(
                    usersSnapshot.value as Map,
                  );
                  for (var entry in users.entries) {
                    final userData = entry.value;
                    if (userData is Map) {
                      final email = userData['email']?.toString();
                      if (email != null &&
                          email.toLowerCase().trim() ==
                              ownerEmailController.text.trim().toLowerCase()) {
                        ownerUid = entry.key.toString();
                        break;
                      }
                    }
                  }
                }

                if (ownerUid == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Owner email not found. Please verify the email address.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                final dateTime = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                // Check for overlapping confirmed appointments
                final ownerRemindersRef = _database.ref(
                  'users/$ownerUid/reminders',
                );
                final existingRemindersSnapshot = await ownerRemindersRef.get();
                
                if (existingRemindersSnapshot.exists && 
                    existingRemindersSnapshot.value is Map) {
                  final reminders = Map<dynamic, dynamic>.from(
                    existingRemindersSnapshot.value as Map,
                  );
                  
                  for (var reminder in reminders.values) {
                    if (reminder is Map) {
                      final reminderStatus = reminder['status']?.toString() ?? 'pending';
                      final reminderPetName = reminder['petName']?.toString() ?? '';
                      
                      // Only check confirmed appointments for the same pet
                      if (reminderStatus == 'confirmed' && 
                          reminderPetName == petNameController.text.trim()) {
                        final reminderDateTime = reminder['dateTime'];
                        if (reminderDateTime != null) {
                          final existingDateTime = DateTime.fromMillisecondsSinceEpoch(
                            reminderDateTime is int 
                              ? reminderDateTime 
                              : int.tryParse(reminderDateTime.toString()) ?? 0,
                          );
                          
                          // Check if appointments overlap (within 1 hour)
                          final difference = dateTime.difference(existingDateTime).abs();
                          if (difference.inMinutes < 60) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'This pet already has a confirmed appointment at ${DateFormat('MMM dd, yyyy h:mm a').format(existingDateTime)}',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            return;
                          }
                        }
                      }
                    }
                  }
                }

                // Format date and time for reminders.dart compatibility
                final dateStr =
                    '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
                final timeStr =
                    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

                // Create appointment title
                final appointmentTitle =
                    'Vet Appointment: ${petNameController.text.trim()}';

                // Store reference in vet's appointments (users/{vetUid}/appointments)
                final appointmentRef = _appointmentsRef.push();
                final appointmentId = appointmentRef.key!;

                // Store in owner's reminders (users/{ownerUid}/reminders)
                final ownerRemindersRef = _database.ref(
                  'users/$ownerUid/reminders',
                );
                final reminderKey = appointmentTitle;
                await ownerRemindersRef.child(reminderKey).set({
                  'title': appointmentTitle,
                  'date': dateStr,
                  'time': timeStr,
                  'notes': notesController.text.trim().isNotEmpty
                      ? 'Vet: $vetEmail\n${notesController.text.trim()}'
                      : 'Vet: $vetEmail',
                  'completed': false,
                  'petName': petNameController.text.trim(),
                  'vetEmail': vetEmail,
                  'vetUid': vetUid,
                  'appointmentId':
                      appointmentId, // Reference to vet's appointment
                  'dateTime': dateTime.millisecondsSinceEpoch,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'type': 'appointment', // Mark as appointment
                  'status': 'pending', // Initial status
                });

                // Store reference in vet's appointments (users/{vetUid}/appointments)
                await appointmentRef.set({
                  'petName': petNameController.text.trim(),
                  'ownerEmail': ownerEmailController.text.trim(),
                  'ownerUid': ownerUid,
                  'dateTime': dateTime.millisecondsSinceEpoch,
                  'date': dateStr,
                  'time': timeStr,
                  'notes': notesController.text.trim(),
                  'completed': false,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'reminderKey': reminderKey, // Reference to owner's reminder
                  'status': 'pending', // Initial status
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Appointment scheduled for ${ownerEmailController.text.trim()}!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCompleted(_Appointment appointment) async {
    final vetUid = FirebaseAuth.instance.currentUser?.uid;
    if (vetUid == null) return;

    // Update vet's appointment record
    await _appointmentsRef.child(appointment.id).update({
      'completed': true,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Also update owner's reminder if we have the reference
    if (appointment.ownerUid != null && appointment.reminderKey != null) {
      final ownerRemindersRef = _database.ref(
        'users/${appointment.ownerUid}/reminders',
      );
      await ownerRemindersRef.child(appointment.reminderKey!).update({
        'completed': true,
      });
    }
  }

  Future<void> _showNotesDialog(_Appointment appointment) async {
    final notesController = TextEditingController(text: appointment.notes);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes for ${appointment.petName}'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(hintText: 'Add or update notes...'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final vetEmail = FirebaseAuth.instance.currentUser?.email ?? '';
              final updatedNotes = notesController.text.trim();

              // Update vet's appointment record
              await _appointmentsRef.child(appointment.id).update({
                'notes': updatedNotes,
              });

              // Also update owner's reminder if we have the reference
              if (appointment.ownerUid != null &&
                  appointment.reminderKey != null) {
                final ownerRemindersRef = _database.ref(
                  'users/${appointment.ownerUid}/reminders',
                );
                final reminderNotes = updatedNotes.isNotEmpty
                    ? 'Vet: $vetEmail\n$updatedNotes'
                    : 'Vet: $vetEmail';
                await ownerRemindersRef.child(appointment.reminderKey!).update({
                  'notes': reminderNotes,
                });
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAppointment(_Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: Text(
          'Are you sure you want to delete the appointment for ${appointment.petName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete from vet's appointments
      await _appointmentsRef.child(appointment.id).remove();

      // Also delete from owner's reminders if we have the reference
      if (appointment.ownerUid != null && appointment.reminderKey != null) {
        final ownerRemindersRef = _database.ref(
          'users/${appointment.ownerUid}/reminders',
        );
        await ownerRemindersRef.child(appointment.reminderKey!).remove();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Upcoming',
                  isSelected: _filter == 'upcoming',
                  onTap: () => setState(() => _filter = 'upcoming'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Past',
                  isSelected: _filter == 'past',
                  onTap: () => setState(() => _filter = 'past'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All',
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),

          // Appointments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAppointments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'upcoming'
                              ? 'No upcoming appointments'
                              : _filter == 'past'
                              ? 'No past appointments'
                              : 'No appointments scheduled',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      // Refresh is handled by stream listener
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final appointment = _filteredAppointments[index];
                        return _AppointmentCard(
                          appointment: appointment,
                          onComplete: () => _markCompleted(appointment),
                          onNotes: () => _showNotesDialog(appointment),
                          onDelete: () => _deleteAppointment(appointment),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppointmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        backgroundColor: const Color(0xFFE91E63),
      ),
    );
  }
}

class _Appointment {
  final String id;
  final String petName;
  final String ownerEmail;
  final String? ownerUid;
  final DateTime dateTime;
  final String notes;
  final bool completed;
  final int? completedAt;
  final String? reminderKey; // Reference to owner's reminder
  final String status; // pending, confirmed, rejected
  final String? rejectionReason;

  _Appointment({
    required this.id,
    required this.petName,
    required this.ownerEmail,
    this.ownerUid,
    required this.dateTime,
    required this.notes,
    required this.completed,
    this.completedAt,
    this.reminderKey,
    this.status = 'pending',
    this.rejectionReason,
  });

  factory _Appointment.fromMap(String id, Map<dynamic, dynamic> map) {
    return _Appointment(
      id: id,
      petName: map['petName']?.toString() ?? 'Unknown Pet',
      ownerEmail: map['ownerEmail']?.toString() ?? 'Unknown Owner',
      ownerUid: map['ownerUid']?.toString(),
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        map['dateTime'] is int
            ? map['dateTime'] as int
            : int.tryParse(map['dateTime'].toString()) ?? 0,
      ),
      notes: map['notes']?.toString() ?? '',
      completed: map['completed'] == true,
      completedAt: map['completedAt'] is int ? map['completedAt'] as int : null,
      reminderKey: map['reminderKey']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      rejectionReason: map['rejectionReason']?.toString(),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final _Appointment appointment;
  final VoidCallback onComplete;
  final VoidCallback onNotes;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.onComplete,
    required this.onNotes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = appointment.dateTime.isBefore(DateTime.now());
    final isUpcoming = !appointment.completed && !isPast;
    final isPending = appointment.status == 'pending';
    final isConfirmed = appointment.status == 'confirmed';
    final isRejected = appointment.status == 'rejected';

    Color getBorderColor() {
      if (appointment.completed) return Colors.grey.shade300;
      if (isRejected) return Colors.red.shade200;
      if (isPending) return Colors.orange.shade200;
      if (isConfirmed) return Colors.green.shade200;
      if (isPast) return Colors.orange.shade200;
      return Colors.blue.shade200;
    }

    Color getIconColor() {
      if (appointment.completed) return Colors.grey.shade300;
      if (isRejected) return Colors.red.shade200;
      if (isPending) return Colors.orange.shade200;
      if (isConfirmed) return Colors.green.shade200;
      if (isPast) return Colors.orange.shade200;
      return Colors.blue.shade200;
    }

    IconData getIcon() {
      if (appointment.completed) return Icons.check_circle;
      if (isRejected) return Icons.cancel;
      if (isPending) return Icons.schedule;
      if (isConfirmed) return Icons.check_circle_outline;
      if (isPast) return Icons.event_busy;
      return Icons.event;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: getBorderColor(),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: getIconColor(),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getIcon(),
                    color: appointment.completed
                        ? Colors.grey.shade600
                        : isRejected
                        ? Colors.red.shade700
                        : isPending
                        ? Colors.orange.shade700
                        : isConfirmed
                        ? Colors.green.shade700
                        : isPast
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appointment.petName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (appointment.completed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          else if (isRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Rejected',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            )
                          else if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          else if (isConfirmed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Confirmed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appointment.ownerEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM dd, yyyy').format(appointment.dateTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('h:mm a').format(appointment.dateTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (appointment.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.notes,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isRejected && appointment.rejectionReason != null && appointment.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appointment.rejectionReason!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!appointment.completed && isUpcoming)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark Complete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                if (!appointment.completed && isUpcoming)
                  const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNotes,
                    icon: const Icon(Icons.note_add, size: 18),
                    label: const Text('Notes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
