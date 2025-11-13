import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class NotificationsPage extends StatefulWidget {
  final String? petId; // if provided, we'll monitor that pet's mob_data

  const NotificationsPage({super.key, this.petId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  late DatabaseReference notificationsRef;

  // optional pet-specific refs
  DatabaseReference? mobDataRef;
  DatabaseReference? collarDataRef;
  DatabaseReference? notifSettingsRef;

  StreamSubscription<DatabaseEvent>? _mobSub;
  StreamSubscription<DatabaseEvent>? _collarSub;
  StreamSubscription<DatabaseEvent>? _settingsSub;

  // throttle map to avoid spamming
  final Map<String, int> _lastNotifAt = {};
  final int _notifCooldownMs = 5 * 60 * 1000; // 5 minutes

  // skip initial snapshot to avoid firing notifs on first open
  bool _skipFirstCollarEvent = true;
  bool _skipFirstMobEvent = true;

  // settings
  bool tempAlert = true;
  bool heartRateAlert = true;
  double minTemp = 36.0;
  double maxTemp = 39.0;
  int minHeartRate = 60;
  int maxHeartRate = 120;

  @override
  void initState() {
    super.initState();
    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );
    notificationsRef = database.ref("users/$uid/notifications");

    if (widget.petId != null && uid != null) {
      mobDataRef = database.ref("users/$uid/pets/${widget.petId}/mob_data");
      collarDataRef = database.ref(
        "users/$uid/pets/${widget.petId}/collar_data",
      );
      notifSettingsRef = database.ref(
        "users/$uid/pets/${widget.petId}/notification_settings",
      );
      _loadSettings();
      _startCollarDataListener();
      _startMobListener();
      _startSettingsListener();
    }
  }

  @override
  void dispose() {
    _mobSub?.cancel();
    _collarSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    bool mobDataExists = false;

    // Try to load ranges from mob_data first (preferred source)
    if (mobDataRef != null) {
      final mobDataSnap = await mobDataRef!.get();
      if (mobDataSnap.exists && mobDataSnap.value != null) {
        mobDataExists = true;
        final mobData = Map<String, dynamic>.from(mobDataSnap.value as Map);
        setState(() {
          minTemp = (mobData['minTemp'] is num)
              ? (mobData['minTemp'] as num).toDouble()
              : minTemp;
          maxTemp = (mobData['maxTemp'] is num)
              ? (mobData['maxTemp'] as num).toDouble()
              : maxTemp;
          minHeartRate = (mobData['minHeartRate'] is num)
              ? (mobData['minHeartRate'] as num).toInt()
              : minHeartRate;
          maxHeartRate = (mobData['maxHeartRate'] is num)
              ? (mobData['maxHeartRate'] as num).toInt()
              : maxHeartRate;
        });
      }
    }

    // Load alert settings from notification_settings
    if (notifSettingsRef == null) return;
    final snap = await notifSettingsRef!.get();
    if (!snap.exists || snap.value == null) return;
    final map = Map<String, dynamic>.from(snap.value as Map);
    setState(() {
      tempAlert = map['tempAlert'] ?? tempAlert;
      heartRateAlert = map['heartRateAlert'] ?? heartRateAlert;

      // Only update ranges from notification_settings if mob_data doesn't exist
      if (!mobDataExists) {
        minTemp = (map['minTemp'] is num)
            ? (map['minTemp'] as num).toDouble()
            : minTemp;
        maxTemp = (map['maxTemp'] is num)
            ? (map['maxTemp'] as num).toDouble()
            : maxTemp;
        minHeartRate = (map['minHeartRate'] is num)
            ? (map['minHeartRate'] as num).toInt()
            : minHeartRate;
        maxHeartRate = (map['maxHeartRate'] is num)
            ? (map['maxHeartRate'] as num).toInt()
            : maxHeartRate;
      }
    });
  }

  void _startSettingsListener() {
    // Listen for settings changes in mob_data and notification_settings
    if (mobDataRef == null) return;

    // Listen to mob_data for range updates
    _settingsSub = mobDataRef!.onValue.listen(
      (event) {
        final snap = event.snapshot;
        if (!snap.exists || snap.value == null) return;
        final map = Map<String, dynamic>.from(snap.value as Map);

        // Check if this update contains settings (minTemp, maxTemp, etc.)
        if (map.containsKey('minTemp') ||
            map.containsKey('maxTemp') ||
            map.containsKey('minHeartRate') ||
            map.containsKey('maxHeartRate')) {
          setState(() {
            if (map['minTemp'] != null) {
              minTemp = (map['minTemp'] is num)
                  ? (map['minTemp'] as num).toDouble()
                  : minTemp;
            }
            if (map['maxTemp'] != null) {
              maxTemp = (map['maxTemp'] is num)
                  ? (map['maxTemp'] as num).toDouble()
                  : maxTemp;
            }
            if (map['minHeartRate'] != null) {
              minHeartRate = (map['minHeartRate'] is num)
                  ? (map['minHeartRate'] as num).toInt()
                  : minHeartRate;
            }
            if (map['maxHeartRate'] != null) {
              maxHeartRate = (map['maxHeartRate'] is num)
                  ? (map['maxHeartRate'] as num).toInt()
                  : maxHeartRate;
            }
          });
        }
      },
      onError: (err) {
        // ignore
      },
    );
  }

  void _startCollarDataListener() {
    // Listen to collar_data/bpm and collar_data/Temperature for real-time monitoring
    if (collarDataRef == null) return;

    _collarSub = collarDataRef!.onValue.listen(
      (event) {
        if (_skipFirstCollarEvent) {
          _skipFirstCollarEvent = false;
          return;
        }
        final snap = event.snapshot;
        if (!snap.exists || snap.value == null) return;
        final map = Map<String, dynamic>.from(snap.value as Map);

        // Read BPM from collar_data/bpm
        int? hr;
        if (map.containsKey('bpm')) {
          hr = _toInt(map['bpm']);
        }

        // Read Temperature from collar_data/Temperature (capital T) or temperature
        double? temp;
        if (map.containsKey('Temperature')) {
          temp = _toDouble(map['Temperature']);
        } else if (map.containsKey('temperature')) {
          temp = _toDouble(map['temperature']);
        }

        final now = DateTime.now().millisecondsSinceEpoch;

        // Check temperature thresholds
        if (temp != null && tempAlert) {
          if (temp < minTemp) {
            _maybeSendNotification(
              type: 'temp_low',
              title: 'Low Temperature Alert',
              message:
                  'Temperature ${temp.toStringAsFixed(1)}°C is below minimum ${minTemp.toStringAsFixed(1)}°C',
              now: now,
            );
          } else if (temp > maxTemp) {
            _maybeSendNotification(
              type: 'temp_high',
              title: 'High Temperature Alert',
              message:
                  'Temperature ${temp.toStringAsFixed(1)}°C is above maximum ${maxTemp.toStringAsFixed(1)}°C',
              now: now,
            );
          }
        }

        // Check heart rate thresholds
        if (hr != null && heartRateAlert) {
          if (hr < minHeartRate) {
            _maybeSendNotification(
              type: 'hr_low',
              title: 'Low Heart Rate Alert',
              message: 'Heart rate $hr bpm is below minimum $minHeartRate bpm',
              now: now,
            );
          } else if (hr > maxHeartRate) {
            _maybeSendNotification(
              type: 'hr_high',
              title: 'High Heart Rate Alert',
              message: 'Heart rate $hr bpm is above maximum $maxHeartRate bpm',
              now: now,
            );
          }
        }
      },
      onError: (err) {
        // ignore for now
      },
    );
  }

  void _startMobListener() {
    // Also listen to mob_data as fallback
    if (mobDataRef == null) return;
    _mobSub = mobDataRef!.onValue.listen(
      (event) {
        if (_skipFirstMobEvent) {
          _skipFirstMobEvent = false;
          return;
        }
        final snap = event.snapshot;
        if (!snap.exists || snap.value == null) return;
        final map = Map<String, dynamic>.from(snap.value as Map);

        double? temp;
        int? hr;

        if (map.containsKey('temp')) temp = _toDouble(map['temp']);
        if (map.containsKey('temperature'))
          temp = temp ?? _toDouble(map['temperature']);
        if (map.containsKey('t')) temp = temp ?? _toDouble(map['t']);

        if (map.containsKey('heartRate')) hr = _toInt(map['heartRate']);
        if (map.containsKey('hr')) hr = hr ?? _toInt(map['hr']);
        if (map.containsKey('bpm')) hr = hr ?? _toInt(map['bpm']);

        final now = DateTime.now().millisecondsSinceEpoch;

        if (temp != null && tempAlert) {
          if (temp < minTemp) {
            _maybeSendNotification(
              type: 'temp_low',
              title: 'Low Temperature',
              message:
                  'Temperature ${temp.toStringAsFixed(1)}°C below ${minTemp.toStringAsFixed(1)}°C',
              now: now,
            );
          } else if (temp > maxTemp) {
            _maybeSendNotification(
              type: 'temp_high',
              title: 'High Temperature',
              message:
                  'Temperature ${temp.toStringAsFixed(1)}°C above ${maxTemp.toStringAsFixed(1)}°C',
              now: now,
            );
          }
        }

        if (hr != null && heartRateAlert) {
          if (hr < minHeartRate) {
            _maybeSendNotification(
              type: 'hr_low',
              title: 'Low Heart Rate',
              message: 'Heart rate $hr bpm below $minHeartRate bpm',
              now: now,
            );
          } else if (hr > maxHeartRate) {
            _maybeSendNotification(
              type: 'hr_high',
              title: 'High Heart Rate',
              message: 'Heart rate $hr bpm above $maxHeartRate bpm',
              now: now,
            );
          }
        }
      },
      onError: (err) {
        // ignore for now
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
      'title': title,
      'message': message,
      'timestamp': now,
      'type': type,
      'petId': widget.petId,
    };

    await notificationsRef.push().set(notifData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                type.contains('temp') ? Icons.thermostat : Icons.favorite,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          backgroundColor: type.contains('high') || type.contains('low')
              ? Colors.orange
              : Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Notifications')),
      body: StreamBuilder(
        stream: notificationsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('No notifications yet'));
          }

          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          final notifs =
              data.entries.map((entry) {
                final notif = Map<String, dynamic>.from(entry.value as Map);
                notif['id'] = entry.key;
                return notif;
              }).toList()..sort((a, b) {
                final at = a['timestamp'] ?? 0;
                final bt = b['timestamp'] ?? 0;
                return bt.compareTo(at);
              });

          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index];
              final type = notif['type'] ?? '';
              IconData icon;
              Color iconColor;

              // Set icon and color based on notification type
              switch (type) {
                case 'temp_low':
                  icon = Icons.thermostat;
                  iconColor = Colors.blue;
                  break;
                case 'temp_high':
                  icon = Icons.thermostat;
                  iconColor = Colors.red;
                  break;
                case 'hr_low':
                  icon = Icons.favorite;
                  iconColor = Colors.blue;
                  break;
                case 'hr_high':
                  icon = Icons.favorite;
                  iconColor = Colors.red;
                  break;
                case 'geofence':
                  icon = Icons.location_off;
                  iconColor = Colors.orange;
                  break;
                default:
                  icon = Icons.notifications;
                  iconColor = Colors.orange;
              }

              final timestamp = notif['timestamp'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(notif['timestamp'])
                  : null;

              final bool isRead = (notif['read'] == true);

              return Opacity(
                opacity: isRead ? 0.6 : 1.0,
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    title: Text(
                      notif['title'] ?? 'No title',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((notif['petId'] ?? '').toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Pet: ${notif['petId']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          notif['message'] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      tooltip: 'Delete notification',
                      onPressed: () async {
                        final id = (notif['id'] ?? '').toString();
                        if (id.isEmpty) return;
                        await notificationsRef.child(id).remove();
                      },
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (isRead) return;
                      final id = (notif['id'] ?? '').toString();
                      if (id.isEmpty) return;
                      final now = DateTime.now().millisecondsSinceEpoch;
                      await notificationsRef.child(id).update({
                        'read': true,
                        'readAt': now,
                      });
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
