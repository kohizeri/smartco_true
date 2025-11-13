import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'pet_tips.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class _TipSection {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> tips;

  const _TipSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.tips,
  });
}

class HealthRecordsPage extends StatefulWidget {
  final Map<String, dynamic> pet;
  final String? petId;

  const HealthRecordsPage({super.key, required this.pet, this.petId});

  @override
  State<HealthRecordsPage> createState() => _HealthRecordsPageState();
}

class _HealthRecordsPageState extends State<HealthRecordsPage> {
  List<int> bpmHistory = [];
  List<double> tempHistory = [];

  int? lastSavedBpm;
  double? lastSavedTemp;
  StreamSubscription? _bpmSubscription;
  StreamSubscription? _tempSubscription;

  // Chart navigation state (0 = BPM, 1 = Temperature)
  int _currentChartIndex = 0;
  static const List<int> _historyOptions = [10, 20, 50];
  int _historyLimit = 10;
  bool _isHistoryLoading = false;

  String? _petSpecies;
  String? _petBreed;
  double? _petAgeYears;
  double? _petWeightKg;
  String? _petWeightUnit;
  PetHealthInfo? _matchedHealthInfo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPetDetails();
    if (!mounted) return;

    await _loadExistingHistory();
    if (!mounted) return;

    _initFirebaseListeners();
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    _tempSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingHistory() async {
    if (widget.petId == null || widget.petId!.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (mounted) {
      setState(() {
        _isHistoryLoading = true;
      });
    }

    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    final bpmHistoryRef = database.ref(
      "users/$uid/pets/${widget.petId}/history/bpm_readings",
    );
    final tempHistoryRef = database.ref(
      "users/$uid/pets/${widget.petId}/history/temp_readings",
    );

    try {
      final bpmSnap = await bpmHistoryRef.get();
      final tempSnap = await tempHistoryRef.get();

      List<int> loadedBpm = [];
      List<double> loadedTemp = [];

      if (bpmSnap.exists && bpmSnap.value is Map<dynamic, dynamic>) {
        final bpmMap = bpmSnap.value as Map<dynamic, dynamic>;
        final sorted = bpmMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        loadedBpm = sorted
            .map((e) => int.tryParse(e.value.toString()) ?? 0)
            .toList();
      }

      if (tempSnap.exists && tempSnap.value is Map<dynamic, dynamic>) {
        final tempMap = tempSnap.value as Map<dynamic, dynamic>;
        final sorted = tempMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        loadedTemp = sorted
            .map((e) => double.tryParse(e.value.toString()) ?? 0.0)
            .toList();
      }

      if (!mounted) return;
      setState(() {
        bpmHistory = loadedBpm.takeLast(_historyLimit).toList();
        tempHistory = loadedTemp.takeLast(_historyLimit).toList();

        if (bpmHistory.isNotEmpty) lastSavedBpm = bpmHistory.last;
        if (tempHistory.isNotEmpty) lastSavedTemp = tempHistory.last;
        _isHistoryLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isHistoryLoading = false;
        });
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  String _possessiveName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'your pet';
    if (trimmed.endsWith('s') || trimmed.endsWith('S')) {
      return "$trimmed'";
    }
    return "$trimmed's";
  }

  List<_TipSection> _buildPersonalizedTipSections() {
    final petNameRaw = (widget.pet['name'] ?? '').toString().trim();
    final displayName = petNameRaw.isEmpty ? 'your pet' : petNameRaw;
    final possessiveName = _possessiveName(displayName);

    final speciesRaw = (_petSpecies ?? widget.pet['species'] ?? '').toString();
    final breedRaw = (_petBreed ?? widget.pet['breed'] ?? '').toString();
    final speciesLabel = speciesRaw.trim().isEmpty
        ? 'Pet'
        : _toTitleCase(speciesRaw.trim());
    final breedLabel = breedRaw.trim().isEmpty
        ? speciesLabel
        : _toTitleCase(breedRaw.trim());

    final info = _matchedHealthInfo;
    final ageYears = _petAgeYears;
    final weightKg = _petWeightKg;
    final weightUnit = (_petWeightUnit ?? 'kg').trim();

    final bool isDog = speciesLabel.toLowerCase().contains('dog');
    final bool isCat = speciesLabel.toLowerCase().contains('cat');

    String? ageBracket;
    if (ageYears != null && ageYears >= 0) {
      if (ageYears < 1) {
        ageBracket = 'young';
      } else if (ageYears < 7) {
        ageBracket = 'adult';
      } else {
        ageBracket = 'old';
      }
    }

    String? ageLabel;
    if (ageBracket != null) {
      switch (ageBracket) {
        case 'young':
          ageLabel = isDog
              ? 'Puppy (0–1 year)'
              : isCat
              ? 'Kitten (0–1 year)'
              : 'Young (0–1 year)';
          break;
        case 'adult':
          ageLabel = 'Adult (1–7 years)';
          break;
        case 'old':
          ageLabel = isDog || isCat ? 'Senior (7+ years)' : 'Senior (7+ years)';
          break;
      }
    }

    String? weightStatus;
    if (info != null && weightKg != null) {
      final withinRange =
          weightKg >= info.minWeight && weightKg <= info.maxWeight;
      final idealRange =
          '${info.minWeight.toStringAsFixed(0)}–${info.maxWeight.toStringAsFixed(0)} kg';
      final currentKgLabel = weightKg % 1 == 0
          ? '${weightKg.toStringAsFixed(0)} kg'
          : '${weightKg.toStringAsFixed(1)} kg';
      String displayWeight = currentKgLabel;
      if (weightUnit.toLowerCase().contains('lb')) {
        final lbs = weightKg * 2.20462262185;
        final lbsLabel = lbs % 1 == 0
            ? '${lbs.toStringAsFixed(0)} lb'
            : '${lbs.toStringAsFixed(1)} lb';
        displayWeight = '$lbsLabel (${currentKgLabel})';
      }
      final statusLabel = withinRange
          ? 'within the ideal range'
          : weightKg < info.minWeight
          ? 'below the ideal range'
          : 'above the ideal range';
      weightStatus =
          'Current weight: $displayWeight — $statusLabel ($idealRange).';
    } else if (weightKg != null) {
      final currentKgLabel = weightKg % 1 == 0
          ? '${weightKg.toStringAsFixed(0)} kg'
          : '${weightKg.toStringAsFixed(1)} kg';
      if (weightUnit.toLowerCase().contains('lb')) {
        final lbs = weightKg * 2.20462262185;
        final lbsLabel = lbs % 1 == 0
            ? '${lbs.toStringAsFixed(0)} lb'
            : '${lbs.toStringAsFixed(1)} lb';
        weightStatus =
            'Current recorded weight: $lbsLabel (${currentKgLabel}).';
      } else {
        weightStatus = 'Current recorded weight: $currentKgLabel.';
      }
    }

    final vitalsTips = <String>[];
    if (info != null) {
      vitalsTips.add(
        'Normal temperature range for ${breedLabel.toLowerCase()} ${speciesLabel.toLowerCase()}s: ${info.normalTemp}.',
      );
      vitalsTips.add('Normal resting heart rate: ${info.normalBpm}.');
    } else {
      vitalsTips.add(
        'Normal temperature typically ranges between 38–39 °C for healthy pets.',
      );
      vitalsTips.add(
        'Resting heart rate usually falls between 60–120 bpm depending on size and age.',
      );
    }
    if (ageLabel != null) {
      final formattedAge = ageYears != null
          ? (ageYears % 1 == 0
                ? '${ageYears.toInt()} year${ageYears == 1 ? '' : 's'}'
                : '${ageYears.toStringAsFixed(1)} years')
          : 'unknown age';
      vitalsTips.add('$possessiveName current age: $formattedAge ($ageLabel).');
    }

    final weightTips = <String>[];
    if (weightStatus != null) {
      weightTips.add(weightStatus);
    } else if (info != null) {
      weightTips.add(
        'Ideal weight range: ${info.minWeight.toStringAsFixed(0)}–${info.maxWeight.toStringAsFixed(0)} kg for ${breedLabel.toLowerCase()} ${speciesLabel.toLowerCase()}s.',
      );
    } else {
      weightTips.add(
        'Track ${displayName.toLowerCase()}\'s weight during vet visits to watch for sudden changes.',
      );
    }
    weightTips.add(
      'Serve measured meals and refresh water daily to support a healthy metabolism.',
    );
    if (isDog) {
      weightTips.add(
        'Choose high-quality protein to support muscle tone in ${breedLabel.toLowerCase()} dogs.',
      );
    } else if (isCat) {
      weightTips.add(
        'Offer moisture-rich meals or fountain water to encourage hydration.',
      );
    } else {
      weightTips.add(
        'Adjust calories based on activity level and vet guidance.',
      );
    }

    final breedSpecificTips = <String>[];
    if (info != null && info.breedTips.isNotEmpty) {
      breedSpecificTips.addAll(info.breedTips.take(2));
    } else {
      breedSpecificTips.add(
        'Provide routine grooming and health checks tailored to ${breedLabel.toLowerCase()} traits.',
      );
      breedSpecificTips.add(
        'Watch for breed-specific sensitivities and discuss them with your veterinarian.',
      );
    }

    final ageTips = <String>[];
    if (ageBracket != null) {
      final tip = info?.ageTips[ageBracket];
      if (tip != null && tip.isNotEmpty) {
        ageTips.add(tip);
      } else {
        switch (ageBracket) {
          case 'young':
            ageTips.add(
              'Young pets thrive on frequent, positive training sessions and gentle socialization.',
            );
            break;
          case 'adult':
            ageTips.add(
              'Adults need consistent routines—balance exercise, mental games, and downtime.',
            );
            break;
          case 'old':
            ageTips.add(
              'Senior pets benefit from low-impact activity, supportive bedding, and biannual checkups.',
            );
            break;
        }
      }
    } else {
      ageTips.add(
        'Schedule regular wellness visits to tailor care as your pet ages.',
      );
    }
    ageTips.add(
      'Monitor behavior changes—early intervention makes age transitions smoother.',
    );

    final preventiveTips = <String>[
      'Log temperature, heart rate, and activity trends in the app for your next vet visit.',
      'Keep vaccinations, parasite prevention, and microchip details up to date.',
      'Rotate engaging toys and enrichment to keep ${displayName.toLowerCase()} mentally stimulated.',
      'Maintain a calm recovery space after intense play or outings.',
    ];

    return [
      _TipSection(
        icon: Icons.favorite,
        title: 'Vitals Overview',
        color: Colors.pink,
        tips: vitalsTips,
      ),
      _TipSection(
        icon: Icons.restaurant,
        title: 'Weight & Nutrition',
        color: Colors.green,
        tips: weightTips,
      ),
      _TipSection(
        icon: Icons.pets,
        title: '$breedLabel Essentials',
        color: Colors.blue,
        tips: breedSpecificTips,
      ),
      _TipSection(
        icon: Icons.access_time,
        title: ageLabel ?? 'Age-Based Care',
        color: Colors.deepPurple,
        tips: ageTips,
      ),
      _TipSection(
        icon: Icons.shield,
        title: 'Daily Preventive Care',
        color: Colors.orange,
        tips: preventiveTips,
      ),
    ];
  }

  double? _convertWeightToKg(double? value, String? unit) {
    if (value == null) return null;
    if (unit == null) return value;
    final normalized = unit.trim().toLowerCase();
    if (normalized.contains('lb')) {
      return value * 0.45359237;
    }
    return value;
  }

  PetHealthInfo? _matchHealthInfo(String species, String breed) {
    final speciesLower = species.toLowerCase().trim();
    final breedLower = breed.toLowerCase().trim();
    if (breedLower.isNotEmpty) {
      for (final info in petHealthData) {
        if (info.breed.toLowerCase() == breedLower) {
          return info;
        }
      }
    }

    if (speciesLower.isNotEmpty) {
      for (final info in petHealthData) {
        if (info.species.toLowerCase() == speciesLower &&
            info.breed.toLowerCase() == 'mixed breed') {
          return info;
        }
      }
    }

    return null;
  }

  Future<void> _loadPetDetails() async {
    if (widget.petId == null || widget.petId!.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );

    final petRef = database.ref("users/$uid/pets/${widget.petId}");

    try {
      final snapshot = await petRef.get();
      Map<String, dynamic> data = {};
      if (snapshot.exists && snapshot.value is Map) {
        data = Map<String, dynamic>.from(snapshot.value as Map);
      } else if (widget.pet.isNotEmpty) {
        data = Map<String, dynamic>.from(widget.pet);
      }

      final species = (data['species'] ?? widget.pet['species'] ?? '')
          .toString();
      final breed = (data['breed'] ?? widget.pet['breed'] ?? '').toString();
      final ageValue = _parseDouble(data['age'] ?? widget.pet['age']);
      final weightValue = _parseDouble(
        data['weight'] ??
            data['weightKg'] ??
            data['weight_kg'] ??
            data['weightInKg'] ??
            widget.pet['weight'] ??
            widget.pet['weightKg'],
      );
      final weightUnit =
          (data['weightUnit'] ??
                  data['weight_unit'] ??
                  data['weightUnits'] ??
                  widget.pet['weightUnit'] ??
                  widget.pet['weight_unit'] ??
                  'kg')
              .toString();

      final info = _matchHealthInfo(species, breed);
      final weightKg = _convertWeightToKg(weightValue, weightUnit);

      if (!mounted) return;
      setState(() {
        _petSpecies = species;
        _petBreed = breed;
        _petAgeYears = ageValue;
        _petWeightKg = weightKg;
        _petWeightUnit = weightUnit;
        _matchedHealthInfo = info;
      });
    } catch (e) {
      // ignore errors silently; tips will fall back to generic guidance
    }
  }

  void _initFirebaseListeners() {
    if (widget.petId == null || widget.petId!.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
  }

  Widget buildBpmGraph() {
    return SizedBox(
      key: const ValueKey('bpm-graph'),
      height: 200,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(title: AxisTitle(text: "Reading #")),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: "BPM"),
          minimum: 0,
          maximum: 200,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          LineSeries<int, int>(
            dataSource: bpmHistory,
            xValueMapper: (int bpm, int index) => index,
            yValueMapper: (int bpm, _) => bpm,
            name: "BPM",
            color: Colors.redAccent,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget buildTempGraph() {
    return SizedBox(
      key: const ValueKey('temp-graph'),
      height: 200,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(title: AxisTitle(text: "Reading #")),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: "Temperature (°C)"),
          minimum: 0,
          maximum: 50,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          LineSeries<double, int>(
            dataSource: tempHistory,
            xValueMapper: (double temp, int index) => index,
            yValueMapper: (double temp, _) => temp,
            name: "Temp °C",
            color: Colors.deepOrange,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ],
      ),
    );
  }

  Widget _buildChartIndicator(int index) {
    final isActive = _currentChartIndex == index;
    return Container(
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? (index == 0 ? Colors.pink : Colors.orange)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required List<String> tips,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet['name'] ?? "No Pet Selected";
    final tipSections = _buildPersonalizedTipSections();

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Health Records",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              petName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Chart Section with Navigation
              Card(
                elevation: 5,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setState(() {
                                _currentChartIndex =
                                    (_currentChartIndex - 1 + 2) % 2;
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _currentChartIndex == 0
                                        ? Colors.pink.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _currentChartIndex == 0
                                        ? Icons.favorite
                                        : Icons.thermostat,
                                    color: _currentChartIndex == 0
                                        ? Colors.pink
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _currentChartIndex == 0
                                        ? "Heart Rate"
                                        : "Temperature",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setState(() {
                                _currentChartIndex =
                                    (_currentChartIndex + 1) % 2;
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _historyLimit,
                                borderRadius: BorderRadius.circular(16),
                                icon: const Icon(Icons.expand_more, size: 18),
                                items: _historyOptions
                                    .map(
                                      (limit) => DropdownMenuItem<int>(
                                        value: limit,
                                        child: Text('Last $limit'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null || value == _historyLimit)
                                    return;
                                  setState(() {
                                    _historyLimit = value;
                                  });
                                  _loadExistingHistory();
                                },
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isHistoryLoading
                            ? const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _currentChartIndex == 0
                            ? (bpmHistory.isEmpty
                                  ? Padding(
                                      key: const ValueKey('bpm-empty'),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        "No BPM data yet.",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : buildBpmGraph())
                            : (tempHistory.isEmpty
                                  ? Padding(
                                      key: const ValueKey('temp-empty'),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        "No temperature data yet.",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : buildTempGraph()),
                      ),
                      const SizedBox(height: 8),
                      // Chart indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildChartIndicator(0),
                          const SizedBox(width: 8),
                          _buildChartIndicator(1),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Educational Tips & Articles Section
              const Text(
                "Educational Tips & Articles",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Preventive Care Tips",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              for (int i = 0; i < tipSections.length; i++) ...[
                _buildTipCard(
                  icon: tipSections[i].icon,
                  title: tipSections[i].title,
                  tips: tipSections[i].tips,
                  color: tipSections[i].color,
                ),
                if (i < tipSections.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// 🧩 Helper extension to easily get last N elements of a list
extension TakeLastExtension<E> on List<E> {
  Iterable<E> takeLast(int n) => skip(length > n ? length - n : 0);
}
