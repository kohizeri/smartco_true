import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Import intl package
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
  late DatabaseReference allRemindersRef; // Unified ref for all items

  // State lists to hold parsed data
  List<Map<String, dynamic>> _calendarEvents = [];
  List<Map<String, dynamic>> _remindersList = [];
  List<Map<String, dynamic>> _appointmentsList = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hideCompleted = false;
  bool _isCalendarMinimized = false;

  final GlobalKey _fabKey = GlobalKey(); // Key for the FAB
  String _petName = ''; // To store the pet's name

  @override
  void initState() {
    super.initState();
    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    // This is now the single source of truth for all reminders and appointments
    allRemindersRef = database.ref("users/${user!.uid}/reminders");

    _listenToAllEvents(); // Single listener for all data
    _selectedDay = _focusedDay;

    // Fetch the pet's name
    _fetchPetName(database);
  }

  // Fetch pet name from Firebase
  void _fetchPetName(FirebaseDatabase database) async {
    try {
      final petNameRef = database.ref(
        "users/${user!.uid}/pets/${widget.petId}/name",
      );
      final snapshot = await petNameRef.get();
      if (snapshot.exists && mounted) {
        setState(() {
          _petName = snapshot.value as String? ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching pet name: $e");
    }
  }

  // Single listener for all reminders and appointments
  void _listenToAllEvents() {
    allRemindersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final allEvents = <Map<String, dynamic>>[];
      final reminders = <Map<String, dynamic>>[];
      final appointments = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        item['id'] = key; // Add the Firebase key as 'id'

        allEvents.add(item); // Add to list for calendar markers

        // Sort into separate lists based on 'type'
        if (item['type'] == 'appointment') {
          appointments.add(item);
        } else if (item['type'] == 'reminder') {
          reminders.add(item);
        }
      });

      if (mounted) {
        setState(() {
          _calendarEvents = allEvents;
          _remindersList = reminders;
          _appointmentsList = appointments;
        });
      }
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _calendarEvents.where((event) {
      final dateTime = event['dateTime'];
      if (dateTime is int) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(dateTime);
        return isSameDay(eventDate, day);
      }
      return false;
    }).toList();
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddReminderDialog(
        allRemindersRef: allRemindersRef,
        petName: _petName, // Pass pet name
      ),
    );
  }

  Future<void> _deleteAppointment(String reminderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    try {
      // Delete from owner's reminders
      await database.ref("users/${user.uid}/reminders/$reminderId").remove();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Appointment deleted.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting appointment: $e")),
        );
      }
    }
  }

  // Show menu on FAB press
  void _showFabMenu() {
    final RenderBox? fabRenderBox =
        _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (fabRenderBox == null) return;

    final fabPosition = fabRenderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        fabPosition.dx - 220, // Position menu to the left-above of the FAB
        fabPosition.dy - 130,
        fabPosition.dx,
        fabPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'reminder',
          child: ListTile(
            leading: Icon(Icons.alarm_add),
            title: Text('Add Reminder'),
          ),
        ),
        const PopupMenuItem(
          value: 'appointment',
          child: ListTile(
            leading: Icon(Icons.medical_services_outlined),
            title: Text('Make Vet Appointment'),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).then((value) {
      if (value == 'reminder') {
        _showAddReminderDialog();
      } else if (value == 'appointment') {
        _showAddAppointmentDialog();
      }
    });
  }

  // Show dialog to add a vet appointment
  void _showAddAppointmentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddAppointmentDialog(
        petName: _petName, // Pass current pet name
        clientName:
            user?.displayName ?? user?.email ?? 'Me', // Pass current user name
        allRemindersRef: allRemindersRef, // Pass the unified ref
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  void _toggleReminderComplete(String id, bool currentState) {
    allRemindersRef.child(id).update({'completed': !currentState});
  }

  void _deleteReminder(String id) {
    allRemindersRef.child(id).remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_isCalendarMinimized)
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              eventLoader: _getEventsForDay,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0x80E91E63),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Hide Completed switch
                Text(
                  'Hide Completed',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Switch(
                  value: _hideCompleted,
                  onChanged: (value) {
                    setState(() {
                      _hideCompleted = value;
                    });
                  },
                  activeColor: const Color(0xFFE91E63),
                ),
                const SizedBox(width: 16), // spacing
                // Minimize Calendar switch
                Text('Minimize', style: TextStyle(color: Colors.grey.shade700)),
                Switch(
                  value: _isCalendarMinimized,
                  onChanged: (value) {
                    setState(() {
                      _isCalendarMinimized = value;
                    });
                  },
                  activeColor: const Color(0xFFE91E63),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [_buildReminderList(), _buildAppointmentList()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey, // Assign key
        onPressed: _showFabMenu, // Use new menu function
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReminderList() {
    // Filter reminders for the current pet
    final petReminders = _remindersList
        .where((r) => r['petName'] == _petName)
        .toList();

    // Sort reminders by date
    petReminders.sort((a, b) {
      final aDate = a['dateTime'] as int? ?? 0;
      final bDate = b['dateTime'] as int? ?? 0;
      return aDate.compareTo(bDate);
    });

    var filteredReminders = petReminders;
    if (_hideCompleted) {
      filteredReminders = petReminders
          .where((r) => r['completed'] == false)
          .toList();
    }

    if (filteredReminders.isEmpty && petReminders.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'All reminders are completed!',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (filteredReminders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No reminders for this pet yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Pet Reminders',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredReminders.length,
          itemBuilder: (context, index) {
            final r = filteredReminders[index];
            final rId = r['id'] as String;
            final isCompleted = r['completed'] as bool? ?? false;
            final rDateTime = DateTime.fromMillisecondsSinceEpoch(
              r['dateTime'] as int? ?? 0,
            );

            final isOverdue =
                rDateTime.isBefore(DateTime.now()) && !isCompleted;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isOverdue ? Colors.red.shade300 : Colors.transparent,
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Checkbox(
                  value: isCompleted,
                  onChanged: (val) => _toggleReminderComplete(rId, isCompleted),
                  activeColor: const Color(0xFFE91E63),
                ),
                title: Text(
                  r['title'] as String? ?? 'No Title',
                  style: TextStyle(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(rDateTime),
                  style: TextStyle(
                    color: isOverdue
                        ? Colors.red.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => _deleteReminder(rId),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppointmentList() {
    if (_appointmentsList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No appointments scheduled.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort by date, most recent first
    _appointmentsList.sort((a, b) {
      final aDate = a['dateTime'] as int? ?? 0;
      final bDate = b['dateTime'] as int? ?? 0;
      return bDate.compareTo(aDate);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'My Appointments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _appointmentsList.length,
          itemBuilder: (context, index) {
            final r = _appointmentsList[index];
            final rStatus = r['status'] as String? ?? 'pending';
            final rDateTime = DateTime.fromMillisecondsSinceEpoch(
              r['dateTime'] as int? ?? 0,
            );
            final rNotes = r['notes'] as String? ?? '';

            IconData statusIcon;
            Color statusColor;
            switch (rStatus) {
              case 'confirmed':
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
                break;
              case 'rejected':
                statusIcon = Icons.cancel;
                statusColor = Colors.red;
                break;
              default: // pending
                statusIcon = Icons.hourglass_empty;
                statusColor = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          rStatus.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vet: ${r['vetEmail'] ?? 'N/A'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pet: ${r['petName'] ?? 'N/A'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(rDateTime),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (rNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        rNotes,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                    if (rStatus == 'confirmed' || rStatus == 'rejected') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAppointment(r['id']),
                          ),
                        ],
                      ),
                    ],
                    if (rStatus == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (r['requestedBy'] == 'vet') ...[
                            TextButton.icon(
                              onPressed: () async {
                                final database = FirebaseDatabase.instanceFor(
                                  app: FirebaseAuth.instance.app,
                                  databaseURL: _databaseURL,
                                );

                                try {
                                  final ownerUid =
                                      r['ownerUid'] ??
                                      FirebaseAuth.instance.currentUser!.uid;
                                  final vetUid = r['vetUid'];

                                  // Update status in owner's node
                                  final ownerRef = database.ref(
                                    'users/$ownerUid/reminders/${r['id']}',
                                  );
                                  await ownerRef.update({
                                    'status': 'confirmed',
                                  });

                                  // Update status in vet's node
                                  if (vetUid != null) {
                                    final vetRef = database.ref(
                                      'users/$vetUid/appointments/${r['id']}',
                                    );
                                    await vetRef.update({
                                      'status': 'confirmed',
                                    });
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Appointment accepted.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('Error accepting appointment: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept Request'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                          ],
                          TextButton.icon(
                            onPressed: () async {
                              final database = FirebaseDatabase.instanceFor(
                                app: FirebaseAuth.instance.app,
                                databaseURL: _databaseURL,
                              );

                              try {
                                final ownerUid =
                                    r['ownerUid'] ??
                                    FirebaseAuth.instance.currentUser!.uid;
                                final vetUid = r['vetUid'];

                                // Update status in owner's node
                                final ownerRef = database.ref(
                                  'users/$ownerUid/reminders/${r['id']}',
                                );
                                await ownerRef.update({'status': 'rejected'});

                                // Update status in vet's node
                                if (vetUid != null) {
                                  final vetRef = database.ref(
                                    'users/$vetUid/appointments/${r['id']}',
                                  );
                                  await vetRef.update({'status': 'rejected'});
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Appointment rejected.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                debugPrint('Error rejecting appointment: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(
                              r['requestedBy'] == 'vet'
                                  ? 'Reject Request'
                                  : 'Cancel Request',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AddReminderDialog extends StatefulWidget {
  final DatabaseReference allRemindersRef;
  final String petName;

  const _AddReminderDialog({
    required this.allRemindersRef,
    required this.petName,
  });

  @override
  _AddReminderDialogState createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  Future<void> _pickDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Write to the unified /reminders/ path
      widget.allRemindersRef.push().set({
        'type': 'reminder',
        'title': _title,
        'petName': widget.petName, // Add petName to filter
        'dateTime': combinedDateTime.millisecondsSinceEpoch,
        'date': DateFormat('yyyy-MM-dd').format(combinedDateTime),
        'time': DateFormat('HH:mm').format(combinedDateTime),
        'completed': false,
        'notes': '', // Add empty notes
        'createdAt': ServerValue.timestamp,
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${DateFormat.yMMMd().format(_selectedDate)}'),
                  TextButton(
                    onPressed: () => _pickDate(context),
                    child: const Text('Change'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Time: ${_selectedTime.format(context)}'),
                  TextButton(
                    onPressed: () => _pickTime(context),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

// Dialog for adding a new appointment (user's perspective)
class _AddAppointmentDialog extends StatefulWidget {
  final String petName;
  final String clientName;
  final DatabaseReference allRemindersRef; // Use the unified ref

  const _AddAppointmentDialog({
    required this.petName,
    required this.clientName,
    required this.allRemindersRef,
  });

  @override
  State<_AddAppointmentDialog> createState() => _AddAppointmentDialogState();
}

class _AddAppointmentDialogState extends State<_AddAppointmentDialog> {
  late TextEditingController _vetEmailController; // Changed to vetEmail
  late TextEditingController _petNameController;
  late TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _vetEmailController = TextEditingController();
    _petNameController = TextEditingController(text: widget.petName);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _vetEmailController.dispose();
    _petNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _submit() async {
    final vetEmail = _vetEmailController.text.trim();
    final petName = _petNameController.text.trim();

    if (vetEmail.isEmpty || petName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Vet Email and Pet Name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      // Find vet UID from email
      final userSnapshot = await database
          .ref('users')
          .orderByChild('email')
          .equalTo(vetEmail)
          .get();

      if (!userSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vet not found in database.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final vetData = (userSnapshot.value as Map).entries.first;
      final vetUid = vetData.key;

      // Appointment data for owner
      final appointmentDataOwner = {
        'type': 'appointment',
        'title': 'Vet Appointment: $petName',
        'petName': petName,
        'vetEmail': vetEmail,
        'vetUid': vetUid,
        'ownerUid': FirebaseAuth.instance.currentUser!.uid,
        'ownerEmail': FirebaseAuth.instance.currentUser!.email,
        'status': 'pending',
        'requestedBy': 'user',
        'notes': _notesController.text.trim(),
        'dateTime': combinedDateTime.millisecondsSinceEpoch,
        'date': DateFormat('yyyy-MM-dd').format(combinedDateTime),
        'time': DateFormat('HH:mm').format(combinedDateTime),
        'completed': false,
        'createdAt': ServerValue.timestamp,
      };

      // Generate a single appointment key for both owner and vet
      final ownerRef = database.ref(
        'users/${FirebaseAuth.instance.currentUser!.uid}/reminders',
      );
      final newAppointmentRef = ownerRef.push(); // generates a unique key
      final appointmentId = newAppointmentRef.key; // get the ID

      // Add the ID to appointment data
      appointmentDataOwner['id'] = appointmentId;
      await newAppointmentRef.set(appointmentDataOwner);

      // Appointment data for vet (copy from owner)
      final appointmentDataVet = Map<String, dynamic>.from(
        appointmentDataOwner,
      );
      appointmentDataVet['requestedBy'] = 'user';

      // Use the same appointment ID for vet
      final vetRef = database.ref('users/$vetUid/appointments/$appointmentId');
      await vetRef.set(appointmentDataVet);

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make Vet Appointment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _vetEmailController,
              decoration: const InputDecoration(
                labelText: 'Vet Email', // Changed label
                icon: Icon(Icons.medical_services_outlined),
                hintText: 'e.g., dr.smith@vet.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _petNameController,
              decoration: const InputDecoration(
                labelText: 'Pet Name',
                icon: Icon(Icons.pets),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Date: ${DateFormat.yMMMd().format(_selectedDate)}',
                  ),
                ),
                TextButton(onPressed: _pickDate, child: const Text('Change')),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(child: Text('Time: ${_selectedTime.format(context)}')),
                TextButton(onPressed: _pickTime, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Reason / Notes (optional)',
                icon: Icon(Icons.note_add_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
          ),
          child: const Text('Request'),
        ),
      ],
    );
  }
}

// Removed the old _Appointment and _Reminder data models as they are no longer used.
