import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class NotifEditPage extends StatefulWidget {
  final String petId;

  const NotifEditPage({super.key, required this.petId});

  @override
  State<NotifEditPage> createState() => _NotifEditPageState();
}

class _NotifEditPageState extends State<NotifEditPage> {
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );
  final user = FirebaseAuth.instance.currentUser;
  late DatabaseReference notifRef;
  late DatabaseReference mobDataRef;
  late DatabaseReference notificationsRef;

  StreamSubscription<DatabaseEvent>? _mobSub;

  // throttle last notification times per type
  final Map<String, int> _lastNotifAt = {};
  final int _notifCooldownMs = 5 * 60 * 1000; // 5 minutes

  // Configurable values
  bool tempAlert = true;
  bool heartRateAlert = true;
  bool activityAlert = false;

  double minTemp = 36.0;
  double maxTemp = 39.0;
  int minHeartRate = 60;
  int maxHeartRate = 120;

  @override
  void initState() {
    super.initState();
    final database = _database;
    notifRef = database.ref(
      "users/${user!.uid}/pets/${widget.petId}/notification_settings",
    );
    mobDataRef = database.ref(
      "users/${user!.uid}/pets/${widget.petId}/mob_data",
    );
    notificationsRef = database.ref(
      "users/${user!.uid}/notifications",
    );

    _loadSettings();
    _startMobDataListener();
  }

  @override
  void dispose() {
    _mobSub?.cancel();
    super.dispose();
  }

  void _startMobDataListener() {
    // Listen for realtime sensor updates and evaluate thresholds
    _mobSub = mobDataRef.onValue.listen(
      (event) {
        final snap = event.snapshot;
        if (!snap.exists || snap.value == null) return;
        final map = Map<String, dynamic>.from(snap.value as Map);

        // Attempt to read common field names for temperature & heart rate
        double? temp;
        int? hr;

        if (map.containsKey('temp')) {
          temp = _toDouble(map['temp']);
        } else if (map.containsKey('temperature')) {
          temp = _toDouble(map['temperature']);
        } else if (map.containsKey('t')) {
          temp = _toDouble(map['t']);
        }

        if (map.containsKey('heartRate')) {
          hr = _toInt(map['heartRate']);
        } else if (map.containsKey('hr')) {
          hr = _toInt(map['hr']);
        } else if (map.containsKey('bpm')) {
          hr = _toInt(map['bpm']);
        }

        final now = DateTime.now().millisecondsSinceEpoch;

        // Temperature checks
        if (temp != null && tempAlert) {
          if (temp < minTemp) {
            _maybeSendNotification(
              type: 'temp_low',
              title: "Low Temperature",
              message:
                  "Pet ${widget.petId}: temperature ${temp.toStringAsFixed(1)}°C below ${minTemp.toStringAsFixed(1)}°C",
              now: now,
            );
          } else if (temp > maxTemp) {
            _maybeSendNotification(
              type: 'temp_high',
              title: "High Temperature",
              message:
                  "Pet ${widget.petId}: temperature ${temp.toStringAsFixed(1)}°C above ${maxTemp.toStringAsFixed(1)}°C",
              now: now,
            );
          }
        }

        // Heart rate checks
        if (hr != null && heartRateAlert) {
          if (hr < minHeartRate) {
            _maybeSendNotification(
              type: 'hr_low',
              title: "Low Heart Rate",
              message:
                  "Pet ${widget.petId}: heart rate $hr bpm below $minHeartRate bpm",
              now: now,
            );
          } else if (hr > maxHeartRate) {
            _maybeSendNotification(
              type: 'hr_high',
              title: "High Heart Rate",
              message:
                  "Pet ${widget.petId}: heart rate $hr bpm above $maxHeartRate bpm",
              now: now,
            );
          }
        }

        // Activity checks could be added here similarly if there's a known key
      },
      onError: (err) {
        // ignore or log
      },
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _maybeSendNotification({
    required String type,
    required String title,
    required String message,
    required int now,
  }) async {
    final last = _lastNotifAt[type] ?? 0;
    if (now - last < _notifCooldownMs) return;
    _lastNotifAt[type] = now;

    final notifData = {
      "title": title,
      "message": message,
      "timestamp": now,
      "type": type,
      "petId": widget.petId,
    };

    // Write to realtime DB so NotificationsPage will show it
    await notificationsRef.push().set(notifData);

    // Optionally show an in-app snackbar so user gets immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadSettings() async {
    // Try to load from mob_data first (preferred ranges)
    final mobDataSnapshot = await mobDataRef.get();
    if (mobDataSnapshot.exists) {
      final mobData = Map<String, dynamic>.from(mobDataSnapshot.value as Map);
      setState(() {
        minTemp = (_toDouble(mobData["minTemp"]) ?? 36.0);
        maxTemp = (_toDouble(mobData["maxTemp"]) ?? 39.0);
        minHeartRate = (_toInt(mobData["minHeartRate"]) ?? 60);
        maxHeartRate = (_toInt(mobData["maxHeartRate"]) ?? 120);
      });
    }

    // Load notification settings
    final snapshot = await notifRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        tempAlert = data["tempAlert"] ?? true;
        heartRateAlert = data["heartRateAlert"] ?? true;
        activityAlert = data["activityAlert"] ?? false;

        // Only update ranges from notification_settings if mob_data doesn't exist
        if (!mobDataSnapshot.exists) {
          minTemp = (_toDouble(data["minTemp"]) ?? 36.0);
          maxTemp = (_toDouble(data["maxTemp"]) ?? 39.0);
          minHeartRate = (_toInt(data["minHeartRate"]) ?? 60);
          maxHeartRate = (_toInt(data["maxHeartRate"]) ?? 120);
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    // Save notification settings
    await notifRef.set({
      "tempAlert": tempAlert,
      "heartRateAlert": heartRateAlert,
      "activityAlert": activityAlert,
      "minTemp": minTemp,
      "maxTemp": maxTemp,
      "minHeartRate": minHeartRate,
      "maxHeartRate": maxHeartRate,
    });

    // Save preferred ranges to mob_data
    await mobDataRef.set({
      "minTemp": minTemp,
      "maxTemp": maxTemp,
      "minHeartRate": minHeartRate,
      "maxHeartRate": maxHeartRate,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("Notification settings saved!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showTemperatureDialog() async {
    double tempMin = minTemp;
    double tempMax = maxTemp;
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.thermostat, color: Colors.orange),
              SizedBox(width: 8),
              Flexible(child: Text("Temperature Range")),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Set the acceptable temperature range (°C)",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _RangeInputField(
                        label: "Min",
                        value: tempMin,
                        onChanged: (val) {
                          tempMin = val;
                          setDialogState(() {});
                        },
                        min: 20.0,
                        max: 60.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RangeInputField(
                        label: "Max",
                        value: tempMax,
                        onChanged: (val) {
                          tempMax = val;
                          setDialogState(() {});
                        },
                        min: 30.0,
                        max: 45.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RangeSlider(
                  values: RangeValues(tempMin, tempMax),
                  min: 30.0,
                  max: 45.0,
                  divisions: 150,
                  labels: RangeLabels(
                    "${tempMax.toStringAsFixed(1)}°C",
                    "${tempMin.toStringAsFixed(1)}°C",
                  ),
                  onChanged: (values) {
                    // update local dialog values
                    tempMin = values.start;
                    tempMax = values.end;
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, {"min": tempMin, "max": tempMax}),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        minTemp = result["min"]!;
        maxTemp = result["max"]!;
      });
      // Save to mob_data immediately when range is updated
      await mobDataRef.update({"minTemp": minTemp, "maxTemp": maxTemp});
    }
  }

  Future<void> _showHeartRateDialog() async {
    int hrMin = minHeartRate;
    int hrMax = maxHeartRate;
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.red),
              SizedBox(width: 8),
              Flexible(child: Text("Heart Rate Range")),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Set the acceptable heart rate range (bpm)",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _RangeInputField(
                        label: "Min",
                        value: hrMin.toDouble(),
                        onChanged: (val) {
                          hrMin = val.toInt();
                          setDialogState(() {});
                        },
                        min: 40.0,
                        max: 200.0,
                        isInt: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RangeInputField(
                        label: "Max",
                        value: hrMax.toDouble(),
                        onChanged: (val) {
                          hrMax = val.toInt();
                          setDialogState(() {});
                        },
                        min: 40.0,
                        max: 200.0,
                        isInt: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RangeSlider(
                  values: RangeValues(hrMin.toDouble(), hrMax.toDouble()),
                  min: 40.0,
                  max: 200.0,
                  divisions: 160,
                  labels: RangeLabels("$hrMin bpm", "$hrMax bpm"),
                  onChanged: (values) {
                    hrMin = values.start.toInt();
                    hrMax = values.end.toInt();
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, {"min": hrMin, "max": hrMax}),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        minHeartRate = result["min"]!;
        maxHeartRate = result["max"]!;
      });
      // Save to mob_data immediately when range is updated
      await mobDataRef.update({
        "minHeartRate": minHeartRate,
        "maxHeartRate": maxHeartRate,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alerts Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                "Alert Types",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // note: keep UI wiring consistent with the internal state
                  _ModernSwitchTile(
                    icon: Icons.thermostat,
                    iconColor: Colors.orange,
                    title: "Temperature Alerts",
                    subtitle: "Receive alerts when temperature leaves range",
                    value: tempAlert,
                    onChanged: (v) => setState(() => tempAlert = v),
                  ),
                  const Divider(height: 1, indent: 72),
                  _ModernSwitchTile(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    title: "Heart Rate Alerts",
                    subtitle: "Receive alerts when heart rate leaves range",
                    value: heartRateAlert,
                    onChanged: (v) => setState(() => heartRateAlert = v),
                  ),
                  const Divider(height: 1, indent: 72),
                  _ModernSwitchTile(
                    icon: Icons.directions_run,
                    iconColor: Colors.blue,
                    title: "Activity Alerts",
                    subtitle: "Receive activity related alerts",
                    value: activityAlert,
                    onChanged: (v) => setState(() => activityAlert = v),
                  ),
                ],
              ),
            ),

            // Thresholds Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                "Thresholds",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ThresholdTile(
                    icon: Icons.thermostat,
                    iconColor: Colors.orange,
                    title: "Temperature Range",
                    unit: "°C",
                    minValue: minTemp,
                    maxValue: maxTemp,
                    onTap: _showTemperatureDialog,
                  ),
                  const Divider(height: 1, indent: 72),
                  _ThresholdTile(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    title: "Heart Rate Range",
                    unit: "bpm",
                    minValue: minHeartRate.toDouble(),
                    maxValue: maxHeartRate.toDouble(),
                    onTap: _showHeartRateDialog,
                  ),
                ],
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        "Save",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // quick test notification to verify NotificationsPage shows entries
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final data = {
                          'title': 'Test Alert',
                          'message':
                              'This is a test notification for pet ${widget.petId}',
                          'timestamp': now,
                          'type': 'test',
                          'petId': widget.petId,
                        };
                        await notificationsRef.push().set(data);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Send Test Notification'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModernSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

class _ThresholdTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String unit;
  final double minValue;
  final double maxValue;
  final VoidCallback onTap;

  const _ThresholdTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInt = unit == "bpm";
    final minStr = isInt
        ? minValue.toInt().toString()
        : minValue.toStringAsFixed(1);
    final maxStr = isInt
        ? maxValue.toInt().toString()
        : maxValue.toStringAsFixed(1);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$minStr - $maxStr $unit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

class _RangeInputField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final bool isInt;

  const _RangeInputField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: isInt ? value.toInt().toString() : value.toStringAsFixed(1),
    );

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      onChanged: (val) {
        final parsed = isInt
            ? int.tryParse(val)?.toDouble()
            : double.tryParse(val);
        if (parsed != null && parsed >= min && parsed <= max) {
          onChanged(parsed);
        }
      },
    );
  }
}
