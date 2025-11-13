import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class RemindersPage extends StatefulWidget {
  final String petId;

  const RemindersPage({super.key, required this.petId});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final user = FirebaseAuth.instance.currentUser;
  late DatabaseReference petRemindersRef;
  late DatabaseReference userRemindersRef; // For appointments

  Map<String, Map<String, dynamic>> remindersByTitle = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hideCompleted = false;

  @override
  void initState() {
    super.initState();
    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );
    petRemindersRef = database.ref(
      "users/${user!.uid}/pets/${widget.petId}/reminders",
    );
    userRemindersRef = database.ref(
      "users/${user!.uid}/reminders",
    );

    // Listen to pet-specific reminders
    petRemindersRef.onValue.listen((event) {
      _updateReminders(event.snapshot.value, isPetReminder: true);
    });

    // Listen to user-level reminders (appointments from vets)
    userRemindersRef.onValue.listen((event) {
      _updateReminders(event.snapshot.value, isPetReminder: false);
    });
  }

  void _updateReminders(dynamic data, {required bool isPetReminder}) {
    if (!mounted) return;

    final Map<String, Map<String, dynamic>> temp = Map.from(remindersByTitle);

    if (data != null && data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          final reminder = Map<String, dynamic>.from(value);
          reminder["id"] = key;
          reminder["isPetReminder"] = isPetReminder;
          temp[key] = reminder;
        }
      });
    } else if (data == null && isPetReminder) {
      // Remove pet reminders if data is null
      temp.removeWhere((key, value) => value["isPetReminder"] == true);
    } else if (data == null && !isPetReminder) {
      // Remove user reminders if data is null
      temp.removeWhere((key, value) => value["isPetReminder"] != true);
    }

    setState(() {
      remindersByTitle = temp;
    });
  }

  Future<void> _addOrEditReminderDialog({
    Map<String, dynamic>? reminder,
  }) async {
    // Prevent editing vet appointments
    if (reminder != null && reminder["type"] == "appointment") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vet appointments cannot be edited by owners.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final titleController = TextEditingController(
      text: reminder != null ? (reminder["title"] ?? "") : "",
    );
    final notesController = TextEditingController(
      text: reminder != null ? (reminder["notes"] ?? "") : "",
    );
    bool completed = reminder != null ? (reminder["completed"] == true) : false;

    DateTime? pickedDateTime = reminder != null && reminder["date"] != null
        ? DateTime.tryParse(reminder["date"] ?? '')?.toLocal()
        : null;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reminder == null ? "Add Reminder" : "Edit Reminder"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: pickedDateTime ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (date != null) {
                          pickedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            pickedDateTime?.hour ?? 9,
                            pickedDateTime?.minute ?? 0,
                          );
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        pickedDateTime == null
                            ? 'Pick Date'
                            : '${pickedDateTime!.year}-${pickedDateTime!.month.toString().padLeft(2, '0')}-${pickedDateTime!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: pickedDateTime != null
                              ? TimeOfDay(
                                  hour: pickedDateTime!.hour,
                                  minute: pickedDateTime!.minute,
                                )
                              : const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) {
                          final base = pickedDateTime ?? DateTime.now();
                          pickedDateTime = DateTime(
                            base.year,
                            base.month,
                            base.day,
                            time.hour,
                            time.minute,
                          );
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        pickedDateTime == null
                            ? 'Pick Time'
                            : '${pickedDateTime!.hour.toString().padLeft(2, '0')}:${pickedDateTime!.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: completed,
                onChanged: (v) => setState(() => completed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Mark as completed'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.isEmpty || pickedDateTime == null)
                return;

              final dateStr =
                  '${pickedDateTime!.year}-${pickedDateTime!.month.toString().padLeft(2, '0')}-${pickedDateTime!.day.toString().padLeft(2, '0')}';
              final timeStr =
                  '${pickedDateTime!.hour.toString().padLeft(2, '0')}:${pickedDateTime!.minute.toString().padLeft(2, '0')}';

              final payload = {
                "title": titleController.text,
                "date": dateStr,
                "time": timeStr,
                "notes": notesController.text,
                "completed": completed,
              };

              final reminderKey = titleController.text.trim();
              final isPetReminder = reminder?["isPetReminder"] != false;
              final ref = isPetReminder ? petRemindersRef : userRemindersRef;

              if (reminder == null) {
                await ref.child(reminderKey).set(payload);
              } else {
                final oldKey = reminder["id"];
                final oldIsPetReminder = reminder["isPetReminder"] != false;
                final oldRef = oldIsPetReminder ? petRemindersRef : userRemindersRef;
                
                if (oldKey != reminderKey || oldIsPetReminder != isPetReminder) {
                  await oldRef.child(oldKey).remove();
                }
                await ref.child(reminderKey).set(payload);
              }

              if (mounted) Navigator.pop(context);
            },
            child: Text(reminder == null ? "Save" : "Update"),
          ),
        ],
      ),
    );
  }

  void _deleteReminder(String reminderKey, bool isPetReminder) {
    final ref = isPetReminder ? petRemindersRef : userRemindersRef;
    ref.child(reminderKey).remove();
  }

  Future<void> _acceptAppointment(Map<String, dynamic> appointment) async {
    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    // Update owner's reminder
    await userRemindersRef.child(appointment["id"]).update({
      "status": "confirmed",
      "confirmedAt": DateTime.now().millisecondsSinceEpoch,
    });

    // Update vet's appointment
    if (appointment["vetUid"] != null && appointment["appointmentId"] != null) {
      final vetAppointmentRef = database.ref(
        "users/${appointment["vetUid"]}/appointments/${appointment["appointmentId"]}",
      );
      await vetAppointmentRef.update({
        "status": "confirmed",
        "confirmedAt": DateTime.now().millisecondsSinceEpoch,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectAppointment(Map<String, dynamic> appointment) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this appointment:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Not available at this time',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      // Update owner's reminder
      await userRemindersRef.child(appointment["id"]).update({
        "status": "rejected",
        "rejectionReason": reasonController.text.trim(),
        "rejectedAt": DateTime.now().millisecondsSinceEpoch,
      });

      // Update vet's appointment
      if (appointment["vetUid"] != null && appointment["appointmentId"] != null) {
        final vetAppointmentRef = database.ref(
          "users/${appointment["vetUid"]}/appointments/${appointment["appointmentId"]}",
        );
        await vetAppointmentRef.update({
          "status": "rejected",
          "rejectionReason": reasonController.text.trim(),
          "rejectedAt": DateTime.now().millisecondsSinceEpoch,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleAppointment(Map<String, dynamic> appointment) async {
    DateTime? pickedDateTime = appointment["dateTime"] != null
        ? DateTime.fromMillisecondsSinceEpoch(appointment["dateTime"])
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reschedule Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a new date and time for this appointment:'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: pickedDateTime ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 1),
                        );
                        if (date != null) {
                          setDialogState(() {
                            pickedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              pickedDateTime?.hour ?? 9,
                              pickedDateTime?.minute ?? 0,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        pickedDateTime == null
                            ? 'Pick Date'
                            : '${pickedDateTime!.year}-${pickedDateTime!.month.toString().padLeft(2, '0')}-${pickedDateTime!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: pickedDateTime != null
                              ? TimeOfDay(
                                  hour: pickedDateTime!.hour,
                                  minute: pickedDateTime!.minute,
                                )
                              : const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) {
                          setDialogState(() {
                            final base = pickedDateTime ?? DateTime.now();
                            pickedDateTime = DateTime(
                              base.year,
                              base.month,
                              base.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        pickedDateTime == null
                            ? 'Pick Time'
                            : '${pickedDateTime!.hour.toString().padLeft(2, '0')}:${pickedDateTime!.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (pickedDateTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a date and time'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Check for overlapping confirmed appointments
                final ownerUid = user!.uid;
                final petName = appointment["petName"]?.toString() ?? '';
                
                final existingRemindersSnapshot = await userRemindersRef.get();
                
                if (existingRemindersSnapshot.exists && 
                    existingRemindersSnapshot.value is Map) {
                  final reminders = Map<dynamic, dynamic>.from(
                    existingRemindersSnapshot.value as Map,
                  );
                  
                  for (var entry in reminders.entries) {
                    final reminder = entry.value;
                    if (reminder is Map && entry.key != appointment["id"]) {
                      final reminderStatus = reminder['status']?.toString() ?? 'pending';
                      final reminderPetName = reminder['petName']?.toString() ?? '';
                      
                      // Only check confirmed appointments for the same pet
                      if (reminderStatus == 'confirmed' && reminderPetName == petName) {
                        final reminderDateTime = reminder['dateTime'];
                        if (reminderDateTime != null) {
                          final existingDateTime = DateTime.fromMillisecondsSinceEpoch(
                            reminderDateTime is int 
                              ? reminderDateTime 
                              : int.tryParse(reminderDateTime.toString()) ?? 0,
                          );
                          
                          // Check if appointments overlap (within 1 hour)
                          final difference = pickedDateTime!.difference(existingDateTime).abs();
                          if (difference.inMinutes < 60) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'This pet already has a confirmed appointment at ${existingDateTime.year}-${existingDateTime.month.toString().padLeft(2, '0')}-${existingDateTime.day.toString().padLeft(2, '0')} ${existingDateTime.hour.toString().padLeft(2, '0')}:${existingDateTime.minute.toString().padLeft(2, '0')}',
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

                final database = FirebaseDatabase.instanceFor(
                  app: FirebaseAuth.instance.app,
                  databaseURL: _databaseURL,
                );

                final dateStr =
                    '${pickedDateTime!.year}-${pickedDateTime!.month.toString().padLeft(2, '0')}-${pickedDateTime!.day.toString().padLeft(2, '0')}';
                final timeStr =
                    '${pickedDateTime!.hour.toString().padLeft(2, '0')}:${pickedDateTime!.minute.toString().padLeft(2, '0')}';

                // Update owner's reminder
                await userRemindersRef.child(appointment["id"]).update({
                  "date": dateStr,
                  "time": timeStr,
                  "dateTime": pickedDateTime!.millisecondsSinceEpoch,
                  "status": "confirmed",
                  "originalDateTime": appointment["dateTime"],
                  "rescheduledAt": DateTime.now().millisecondsSinceEpoch,
                });

                // Update vet's appointment
                if (appointment["vetUid"] != null && appointment["appointmentId"] != null) {
                  final vetAppointmentRef = database.ref(
                    "users/${appointment["vetUid"]}/appointments/${appointment["appointmentId"]}",
                  );
                  await vetAppointmentRef.update({
                    "date": dateStr,
                    "time": timeStr,
                    "dateTime": pickedDateTime!.millisecondsSinceEpoch,
                    "status": "confirmed",
                    "originalDateTime": appointment["dateTime"],
                    "rescheduledAt": DateTime.now().millisecondsSinceEpoch,
                  });
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment rescheduled!'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              },
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRemindersForDay(DateTime day) {
    final dateOnly =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final list = remindersByTitle.values
        .where((r) => r["date"] == dateOnly)
        .toList();

    list.sort((a, b) {
      final ad = a["time"] != null && a["time"] != ''
          ? TimeOfDay(
              hour: int.parse(a["time"].split(':')[0]),
              minute: int.parse(a["time"].split(':')[1]),
            )
          : const TimeOfDay(hour: 0, minute: 0);
      final bd = b["time"] != null && b["time"] != ''
          ? TimeOfDay(
              hour: int.parse(b["time"].split(':')[0]),
              minute: int.parse(b["time"].split(':')[1]),
            )
          : const TimeOfDay(hour: 0, minute: 0);

      return ad.hour != bd.hour
          ? ad.hour.compareTo(bd.hour)
          : ad.minute.compareTo(bd.minute);
    });

    if (_hideCompleted) {
      return list.where((r) => r["completed"] != true).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reminders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Hide completed'),
                      selected: _hideCompleted,
                      onSelected: (v) => setState(() => _hideCompleted = v),
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _hideCompleted
                            ? const Color(0xFFE91E63)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getRemindersForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFE91E63),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildRemindersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditReminderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRemindersList() {
    final list = _getRemindersForDay(_selectedDay ?? _focusedDay);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No reminders for this day'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        final title = (r["title"] ?? '').toString();
        final dateStr = (r["date"] ?? '').toString();
        final timeStr = (r["time"] ?? '').toString();
        final completed = r["completed"] == true;
        final notes = (r["notes"] ?? '').toString();
        final status = (r["status"] ?? '').toString();
        final isPending = status == 'pending';
        final isConfirmed = status == 'confirmed';
        final isRejected = status == 'rejected';
        final rejectionReason = (r["rejectionReason"] ?? '').toString();

        Color getBackgroundColor() {
          if (r["type"] == "appointment") {
            if (completed) return Colors.blue.shade100;
            if (isRejected) return Colors.red.shade100;
            if (isPending) return Colors.orange.shade100;
            if (isConfirmed) return Colors.green.shade100;
            return Colors.blue.shade200;
          }
          return completed
              ? Colors.green.shade100
              : const Color(0xFFE91E63).withOpacity(0.15);
        }

        Color getIconColor() {
          if (r["type"] == "appointment") {
            if (completed) return Colors.blue.shade700;
            if (isRejected) return Colors.red.shade700;
            if (isPending) return Colors.orange.shade700;
            if (isConfirmed) return Colors.green.shade700;
            return Colors.blue.shade800;
          }
          return completed ? Colors.green : const Color(0xFFE91E63);
        }

        IconData getIcon() {
          if (r["type"] == "appointment") {
            if (completed) return Icons.medical_services;
            if (isRejected) return Icons.cancel;
            if (isPending) return Icons.schedule;
            if (isConfirmed) return Icons.check_circle_outline;
            return Icons.local_hospital;
          }
          return completed ? Icons.check_circle : Icons.alarm;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPending
                  ? Colors.orange.shade300
                  : isRejected
                  ? Colors.red.shade300
                  : isConfirmed
                  ? Colors.green.shade300
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: getBackgroundColor(),
                  child: Icon(getIcon(), color: getIconColor()),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: completed ? TextDecoration.lineThrough : null,
                          color: completed ? Colors.grey : null,
                        ),
                      ),
                    ),
                    if (isPending)
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
                            fontSize: 10,
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
                            fontSize: 10,
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
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$dateStr ${timeStr.isNotEmpty ? timeStr : ''}'),
                    if (notes.isNotEmpty)
                      Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (isRejected && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Reason: $rejectionReason',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: r["type"] == "appointment" && !isPending
                    ? IconButton(
                        tooltip: completed ? 'Mark as pending' : 'Mark as done',
                        icon: Icon(
                          completed ? Icons.undo : Icons.check,
                          color: completed ? Colors.orange : Colors.green,
                        ),
                        onPressed: () async {
                          final isPetReminder = r["isPetReminder"] != false;
                          final ref = isPetReminder ? petRemindersRef : userRemindersRef;
                          await ref.child(r["id"]).update({
                            "completed": !completed,
                          });
                          
                          // If this is a vet appointment, sync completion status to vet's appointment
                          if (r["type"] == "appointment" && r["vetUid"] != null && r["appointmentId"] != null) {
                            final database = FirebaseDatabase.instanceFor(
                              app: FirebaseAuth.instance.app,
                              databaseURL: _databaseURL,
                            );
                            final vetAppointmentRef = database.ref(
                              "users/${r["vetUid"]}/appointments/${r["appointmentId"]}",
                            );
                            await vetAppointmentRef.update({
                              "completed": !completed,
                              if (!completed) "completedAt": DateTime.now().millisecondsSinceEpoch,
                            });
                          }
                        },
                      )
                    : r["type"] != "appointment"
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: completed ? 'Mark as pending' : 'Mark as done',
                            icon: Icon(
                              completed ? Icons.undo : Icons.check,
                              color: completed ? Colors.orange : Colors.green,
                            ),
                            onPressed: () async {
                              final isPetReminder = r["isPetReminder"] != false;
                              final ref = isPetReminder ? petRemindersRef : userRemindersRef;
                              await ref.child(r["id"]).update({
                                "completed": !completed,
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _addOrEditReminderDialog(reminder: r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Reminder'),
                                  content: const Text(
                                    'Are you sure you want to delete this reminder?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                final isPetReminder = r["isPetReminder"] != false;
                                _deleteReminder(r["id"], isPetReminder);
                              }
                            },
                          ),
                        ],
                      )
                    : null,
              ),
              // Action buttons for pending appointments
              if (r["type"] == "appointment" && isPending) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptAppointment(r),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rescheduleAppointment(r),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: const Text('Reschedule'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectAppointment(r),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
