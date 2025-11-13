import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class VetPetProfilePage extends StatefulWidget {
  final String ownerUid;
  final String petId;
  final String? initialName;
  final String? initialSpecies;

  const VetPetProfilePage({
    super.key,
    required this.ownerUid,
    required this.petId,
    this.initialName,
    this.initialSpecies,
  });

  @override
  State<VetPetProfilePage> createState() => _VetPetProfilePageState();
}

class _VetPetProfilePageState extends State<VetPetProfilePage> {
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _databaseURL,
  );

  Map<String, dynamic>? _petData;
  bool _isPetLoading = true;
  bool _isHistoryLoading = true;
  List<_ChartPoint> _bpmHistory = [];
  List<_ChartPoint> _tempHistory = [];
  late TooltipBehavior _bpmTooltip;
  late TooltipBehavior _tempTooltip;

  @override
  void initState() {
    super.initState();
    _bpmTooltip = TooltipBehavior(enable: true);
    _tempTooltip = TooltipBehavior(enable: true);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPetDetails(), _loadHistoryData()]);
  }

  Future<void> _loadPetDetails() async {
    setState(() => _isPetLoading = true);
    try {
      final ref = _database.ref(
        'users/${widget.ownerUid}/pets/${widget.petId}',
      );
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _petData = data;
            _isPetLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _petData = null;
            _isPetLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _petData = null;
        _isPetLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load pet details: $e')));
    }
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isHistoryLoading = true);
    try {
      final bpmRef = _database.ref(
        'users/${widget.ownerUid}/pets/${widget.petId}/history/bpm_readings',
      );
      final tempRef = _database.ref(
        'users/${widget.ownerUid}/pets/${widget.petId}/history/temp_readings',
      );

      final bpmSnap = await bpmRef.get();
      final tempSnap = await tempRef.get();

      final bpmPoints = _mapHistorySnapshot(bpmSnap);
      final tempPoints = _mapHistorySnapshot(tempSnap);

      if (mounted) {
        setState(() {
          _bpmHistory = bpmPoints;
          _tempHistory = tempPoints;
          _isHistoryLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bpmHistory = [];
        _tempHistory = [];
        _isHistoryLoading = false;
      });
    }
  }

  List<_ChartPoint> _mapHistorySnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) return [];
    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final entries = raw.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    final points = <_ChartPoint>[];
    for (final entry in entries) {
      final key = entry.key.toString();
      final valueRaw = entry.value;
      final timestamp = int.tryParse(key) ?? 0;
      final date = timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now();
      final value = _toDouble(valueRaw);
      if (value != null) {
        points.add(_ChartPoint(date, value));
      }
    }
    // Keep only the newest 30 points
    return points.length > 30 ? points.sublist(points.length - 30) : points;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _onRefresh() async {
    await Future.wait([_loadPetDetails(), _loadHistoryData()]);
  }

  String get _petName => _petData?['name']?.toString().trim().isNotEmpty == true
      ? _petData!['name'] as String
      : (widget.initialName ?? 'Pet Profile');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 110,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _petName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Shared by owner: ${widget.ownerUid}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildVitalsTiles(),
              const SizedBox(height: 20),
              _buildChartCard(
                title: 'Heart Rate (BPM)',
                description:
                    'Latest heart rate readings captured from the collar device.',
                color: const Color(0xFFE91E63),
                isLoading: _isHistoryLoading,
                points: _bpmHistory,
                tooltip: _bpmTooltip,
                unit: 'bpm',
                max: 220,
              ),
              const SizedBox(height: 20),
              _buildChartCard(
                title: 'Temperature (°C)',
                description:
                    'Temperature readings over time. Watch for sustained spikes.',
                color: const Color(0xFFFF9800),
                isLoading: _isHistoryLoading,
                points: _tempHistory,
                tooltip: _tempTooltip,
                unit: '°C',
                max: 45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_isPetLoading) {
      return Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_petData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          'This pet’s profile could not be loaded. It may have been removed by the owner.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }

    final info = _petData!;
    final species = info['species']?.toString() ?? 'Unknown';
    final breed = info['breed']?.toString() ?? 'Unknown';
    final age = info['age'];
    final gender = info['gender']?.toString() ?? 'Unknown';
    final weight = info['weight'];
    final collar = info['collarId']?.toString().isNotEmpty == true
        ? info['collarId'].toString()
        : 'Not assigned';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  color: Color(0xFFE91E63),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _petName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$breed • $species',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DetailChip(label: 'Gender', value: gender),
              _DetailChip(
                label: 'Age',
                value: age != null ? '$age yrs' : 'Unknown',
              ),
              _DetailChip(
                label: 'Weight',
                value: weight != null ? '${weight.toString()} kg' : 'Unknown',
              ),
              _DetailChip(label: 'Collar ID', value: collar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsTiles() {
    final bpmLatest = _bpmHistory.isNotEmpty ? _bpmHistory.last.value : null;
    final tempLatest = _tempHistory.isNotEmpty ? _tempHistory.last.value : null;

    return Row(
      children: [
        Expanded(
          child: _VitalsTile(
            title: 'Current BPM',
            value: bpmLatest != null ? bpmLatest.toStringAsFixed(0) : '--',
            subtitle: 'Last recorded heart rate',
            icon: Icons.favorite,
            color: const Color(0xFFE91E63),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _VitalsTile(
            title: 'Temperature',
            value: tempLatest != null ? tempLatest.toStringAsFixed(1) : '--',
            subtitle: 'Most recent body temp',
            icon: Icons.thermostat,
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required String description,
    required Color color,
    required bool isLoading,
    required List<_ChartPoint> points,
    required TooltipBehavior tooltip,
    required String unit,
    required double max,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  title.toLowerCase().contains('heart')
                      ? Icons.favorite
                      : Icons.thermostat,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (points.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'No recent $title data available.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.minutes,
                  dateFormat: points.length < 10 ? null : DateFormat.Hm(),
                  majorGridLines: const MajorGridLines(width: 0.2),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: unit),
                  minimum: 0,
                  maximum: max,
                  majorGridLines: const MajorGridLines(width: 0.1),
                ),
                tooltipBehavior: tooltip,
                series: <LineSeries<_ChartPoint, DateTime>>[
                  LineSeries<_ChartPoint, DateTime>(
                    dataSource: points,
                    xValueMapper: (point, _) => point.time,
                    yValueMapper: (point, _) => point.value,
                    color: color,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: false,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartPoint {
  final DateTime time;
  final double value;

  _ChartPoint(this.time, num value) : value = value.toDouble();
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _DetailChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _VitalsTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _VitalsTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
