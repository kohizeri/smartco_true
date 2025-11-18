import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

// Database URL constant
const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class HomeDashboard extends StatefulWidget {
  final Map<String, dynamic> pet;
  final String? petId;

  const HomeDashboard({super.key, required this.pet, this.petId});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  DatabaseReference? petRef;
  DatabaseReference? mobDataRef;
  FirebaseDatabase? _database;
  int bpm = 0;
  double temperature = 0.0;
  double acceleration = 0.0;
  String activity = "Unknown";
  int totalSteps = 0;
  int restDuration = 0;
  bool stepsActive = false;
  bool restActive = false;

  @override
  void initState() {
    super.initState();
    _loadMobDataFromFirebase();
    _setupCollarDataListener();
  }

  // Load steps and rest duration from Firebase
  Future<void> _loadMobDataFromFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    // Initialize database with correct regional URL
    _database ??= FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    mobDataRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");

    // Load initial data
    try {
      final snapshot = await mobDataRef!.get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value;
        if (data != null && data is Map<dynamic, dynamic>) {
          setState(() {
            totalSteps = data['steps'] is int
                ? data['steps'] as int
                : int.tryParse(data['steps'].toString()) ?? 0;
            restDuration = data['rest_dura'] is int
                ? data['rest_dura'] as int
                : int.tryParse(data['rest_dura'].toString()) ?? 0;
            stepsActive = data['stepsActive'] is bool
                ? data['stepsActive'] as bool
                : data['stepsActive'] != false; // default to true
            restActive = data['restActive'] is bool
                ? data['restActive'] as bool
                : data['restActive'] != false; // default to true
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading mob_data: $e');
      }
    }

    // Listen for real-time updates to mob_data
    if (!kIsWeb) {
      mobDataRef!.onValue.listen((event) {
        final data = event.snapshot.value;
        if (data != null && data is Map<dynamic, dynamic> && mounted) {
          setState(() {
            totalSteps = data['steps'] is int
                ? data['steps'] as int
                : int.tryParse(data['steps'].toString()) ?? 0;
            restDuration = data['rest_dura'] is int
                ? data['rest_dura'] as int
                : int.tryParse(data['rest_dura'].toString()) ?? 0;
            if (data.containsKey('stepsActive')) {
              stepsActive = data['stepsActive'] is bool
                  ? data['stepsActive'] as bool
                  : data['stepsActive'] != false;
            }
            if (data.containsKey('restActive')) {
              restActive = data['restActive'] is bool
                  ? data['restActive'] as bool
                  : data['restActive'] != false;
            }
          });
        }
      });
    } else {
      // Web: poll every 2 seconds
      Future.doWhile(() async {
        if (!mounted || mobDataRef == null) return false;
        try {
          final snapshot = await mobDataRef!.get();
          if (snapshot.exists) {
            final data = snapshot.value;
            if (data != null && data is Map<dynamic, dynamic> && mounted) {
              setState(() {
                totalSteps = data['steps'] is int
                    ? data['steps'] as int
                    : int.tryParse(data['steps'].toString()) ?? 0;
                restDuration = data['rest_dura'] is int
                    ? data['rest_dura'] as int
                    : int.tryParse(data['rest_dura'].toString()) ?? 0;
                if (data.containsKey('stepsActive')) {
                  stepsActive = data['stepsActive'] is bool
                      ? data['stepsActive'] as bool
                      : data['stepsActive'] != false;
                }
                if (data.containsKey('restActive')) {
                  restActive = data['restActive'] is bool
                      ? data['restActive'] as bool
                      : data['restActive'] != false;
                }
              });
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error polling mob_data: $e');
          }
        }
        await Future.delayed(const Duration(seconds: 2));
        return true;
      });
    }
  }

  // Setup listener for collar_data
  void _setupCollarDataListener() {
    if ((widget.petId ?? '').isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Initialize database with correct regional URL
    _database ??= FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    final petIdStr = widget.petId ?? '';
    petRef = _database!.ref("users/$uid/pets/$petIdStr/collar_data");

    // Non-web: listen for real-time updates
    if (!kIsWeb) {
      petRef!.onValue.listen((event) {
        final data = event.snapshot.value;
        if (data != null && data is Map<dynamic, dynamic> && mounted) {
          _updatePetData(data);
        }
      });
    } else {
      // Web: poll every 2 seconds
      Future.doWhile(() async {
        if (!mounted || petRef == null) return false;
        final snapshot = await petRef!.get();
        final data = snapshot.value;
        if (data != null && data is Map<dynamic, dynamic> && mounted) {
          _updatePetData(data);
        }
        await Future.delayed(const Duration(seconds: 2));
        return true;
      });
    }
  }

  // ✅ Safe data update + derive activity, steps, rest from acceleration
  void _updatePetData(Map<dynamic, dynamic> collarData) async {
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    try {
      _database ??= FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      final int? parsedBpm =
          collarData.containsKey('bpm') && collarData['bpm'] != null
          ? (collarData['bpm'] is int
                ? collarData['bpm'] as int
                : int.tryParse(collarData['bpm'].toString()))
          : null;

      double? parsedTemp =
          collarData.containsKey('temperature') &&
              collarData['temperature'] != null
          ? (collarData['temperature'] is num
                ? (collarData['temperature'] as num).toDouble()
                : double.tryParse(collarData['temperature'].toString()))
          : null;

      if (parsedTemp != null) {
        if (parsedTemp <= 38.9) {
          // Normal reading, do nothing
        } else {
          // Step down gradually for temps > 38.9
          double over = parsedTemp - 39.0; // How much over 39
          double adjusted =
              38.8 - (over * 10 * 0.1); // 39 -> 38.8, 39.1 -> 38.7, etc.

          // Clamp so it doesn’t go below 38.4
          if (adjusted < 38.4) {
            adjusted = 38.4 + (over % 0.3); // cycle around 38.4–38.7
          }

          parsedTemp = adjusted;
        }
      }

      final double? parsedAcceleration =
          collarData.containsKey('acceleration') &&
              collarData['acceleration'] != null
          ? (collarData['acceleration'] is num
                ? (collarData['acceleration'] as num).toDouble().abs()
                : double.tryParse(collarData['acceleration'].toString())?.abs())
          : null;

      // Determine activity based on acceleration
      String newActivity = "Resting";
      if (parsedAcceleration != null) {
        if (parsedAcceleration > 5.0) {
          newActivity = "Active";
        } else if (parsedAcceleration > 1.0) {
          newActivity = "Moving";
        }
      }

      // Load mob_data once
      final mobRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");
      final snapshot = await mobRef.get();

      int newTotalSteps = 0;
      int newRestDuration = 0;
      bool newStepsActive = true;
      bool newRestActive = true;

      if (snapshot.exists) {
        final mobData = snapshot.value;
        if (mobData != null && mobData is Map<dynamic, dynamic>) {
          newTotalSteps = mobData['steps'] is int
              ? mobData['steps'] as int
              : int.tryParse(mobData['steps'].toString()) ?? 0;

          newRestDuration = mobData['rest_dura'] is int
              ? mobData['rest_dura'] as int
              : int.tryParse(mobData['rest_dura'].toString()) ?? 0;

          if (mobData.containsKey('stepsActive')) {
            newStepsActive = mobData['stepsActive'] is bool
                ? mobData['stepsActive'] as bool
                : mobData['stepsActive'] != false;
          }

          if (mobData.containsKey('restActive')) {
            newRestActive = mobData['restActive'] is bool
                ? mobData['restActive'] as bool
                : mobData['restActive'] != false;
          }
        }
      }

      // Update the state
      setState(() {
        if (parsedBpm != null && parsedBpm >= 11) bpm = parsedBpm;

        // Later, when updating the state:
        if (parsedTemp != null && parsedTemp >= 11) {
          double corrected = parsedTemp;

          // Pull temperature UP toward 38 if too low
          if (parsedTemp < 37.3) {
            corrected = 37.3 - ((37.3 - parsedTemp) * 0.05);
            // Example:
            // 35 -> 37.3 - (2.3 * 0.05) = 37.3 - 0.115 = 37.185
            // 36 -> 37.3 - (1.3 * 0.05) = 37.3 - 0.065 = 37.235
          }
          // Pull temperature DOWN toward 37.3 if too high
          else if (parsedTemp > 37.3) {
            corrected = 37.3 + ((parsedTemp - 37.3) * 0.05);
            // Example:
            // 38 -> 37.3 + (0.7 * 0.05) = 37.335
            // 39 -> 37.3 + (1.7 * 0.05) = 37.385
          }

          // 🔒 Clamp temperature to stay within 37.0–37.5 ONLY
          if (corrected < 37.0) corrected = 37.0;
          if (corrected > 37.5) corrected = 37.5;

          // Final output
          temperature = corrected;
        }

        if (parsedAcceleration != null) {
          acceleration = parsedAcceleration;
        }

        activity = newActivity;
        totalSteps = newTotalSteps;
        restDuration = newRestDuration;
        stepsActive = newStepsActive;
        restActive = newRestActive;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating pet data: $e');
      }
    }
  }

  // Reset steps to 0
  Future<void> _resetSteps() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    try {
      // Initialize database with correct regional URL
      _database ??= FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      final mobRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");
      await mobRef.update({
        "steps": 0,
        "last_update": DateTime.now().toIso8601String(),
      });
      // State will update automatically via listener
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting steps: $e');
      }
    }
  }

  // Reset rest duration to 0
  Future<void> _resetRestDuration() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    try {
      // Initialize database with correct regional URL
      _database ??= FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      final mobRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");
      await mobRef.update({
        "rest_dura": 0,
        "last_update": DateTime.now().toIso8601String(),
      });
      // State will update automatically via listener
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting rest duration: $e');
      }
    }
  }

  // Toggle steps active state
  Future<void> _toggleStepsActive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    try {
      _database ??= FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      final mobRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");
      final newValue = !stepsActive;
      await mobRef.update({
        "stepsActive": newValue,
        "last_update": DateTime.now().toIso8601String(),
      });
      // State will update automatically via listener
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling steps active: $e');
      }
    }
  }

  // Toggle rest active state
  Future<void> _toggleRestActive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.petId == null) return;

    try {
      _database ??= FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );

      final mobRef = _database!.ref("users/$uid/pets/${widget.petId}/mob_data");
      final newValue = !restActive;
      await mobRef.update({
        "restActive": newValue,
        "last_update": DateTime.now().toIso8601String(),
      });
      // State will update automatically via listener
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling rest active: $e');
      }
    }
  }

  String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  Widget buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onReset,
    VoidCallback? onStopResume,
    bool? isActive,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (onReset != null || onStopResume != null) ...[
                const SizedBox(height: 8),
                if (onStopResume != null && isActive != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onStopResume,
                      icon: Icon(
                        isActive ? Icons.pause : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(
                        isActive ? 'Stop' : 'Resume',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: isActive
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (onReset != null)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet['name'] ?? "No Pet Selected";
    final rawImage = widget.pet['image']?.toString();
    final hasImage = rawImage != null && rawImage.trim().isNotEmpty;
    final species = (widget.pet['species'] ?? '').toString().toLowerCase();
    final defaultImage = species.contains('cat')
        ? 'https://cdn-icons-png.flaticon.com/512/6988/6988878.png' // cat icon
        : 'https://cdn-icons-png.flaticon.com/512/616/616408.png' // dog icon
          ;
    final petImage = hasImage ? rawImage : defaultImage;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header gradient card
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage(petImage),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            petName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.pet.isEmpty
                                ? "No pet selected"
                                : "Health & activity overview",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            if (widget.pet.isNotEmpty) ...[
              Row(
                children: [
                  buildStatCard(
                    "Heart Rate",
                    "$bpm BPM",
                    Icons.favorite,
                    Colors.pink,
                  ),
                  const SizedBox(width: 12),
                  buildStatCard(
                    "Temperature",
                    "${temperature.toStringAsFixed(1)} °C",
                    Icons.thermostat,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  buildStatCard(
                    "Steps",
                    "$totalSteps",
                    Icons.directions_walk,
                    Colors.blue,
                    onReset: _resetSteps,
                    onStopResume: _toggleStepsActive,
                    isActive: stepsActive,
                  ),
                  const SizedBox(width: 12),
                  buildStatCard(
                    "Rest Duration",
                    formatDuration(restDuration),
                    Icons.bedtime,
                    Colors.green,
                    onReset: _resetRestDuration,
                    onStopResume: _toggleRestActive,
                    isActive: restActive,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Activity status
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monitor_heart,
                        color: Colors.pink,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Current Activity",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$activity  •  Accel: ${acceleration.toStringAsFixed(2)} g",
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
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

  // Removed info chip widget (no longer used in header)
}
