import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class GpsTrackingPage extends StatefulWidget {
  final Map<String, dynamic> pet;
  final String? petId;

  const GpsTrackingPage({super.key, required this.pet, this.petId});

  @override
  State<GpsTrackingPage> createState() => _GpsTrackingPageState();
}

class _GpsTrackingPageState extends State<GpsTrackingPage> {
  LatLng? currentLocation;
  late DatabaseReference gpsRef;
  final MapController _mapController = MapController();

  // Geofence
  LatLng? geofenceCenter;
  double geofenceRadius = 0.0;
  bool selectingGeofence = false;
  bool isOutsideFence = false;

  // Vet locations
  bool showVets = false;
  final List<Map<String, dynamic>> vetClinics = [
    {
      'name': 'JLC Veterinary Clinic',
      'location': LatLng(13.779836418522393, 121.06738496992348),
    },
    {
      'name': 'Oasis Animal Clinic',
      'location': LatLng(13.792654860607161, 121.07030271596126),
    },
    {
      'name': 'Elgin\'s Animal Clinic',
      'location': LatLng(13.801815599203126, 121.07232400957385),
    },
    {
      'name': 'Petaholic Veterinary Clinic',
      'location': LatLng(13.773724124891846, 121.06648752301227),
    },
    {
      'name': 'Hills Pet Station',
      'location': LatLng(13.76713839441924, 121.06108018981469),
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupGpsListener();
    _loadGeofenceFromFirebase();
  }

  // --- Listen for live GPS updates ---
  void _setupGpsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && widget.petId != null) {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );
      gpsRef = database.ref(
        "users/$uid/pets/${widget.petId}/collar_data/location",
      );

      gpsRef.onValue.listen((event) {
        final data = event.snapshot.value as Map?;
        if (data != null && mounted) {
          final lat = double.tryParse(data['latitude'].toString()) ?? 0.0;
          final lng = double.tryParse(data['longitude'].toString()) ?? 0.0;
          setState(() {
            currentLocation = LatLng(lat, lng);
          });

          // Check geofence status
          if (geofenceCenter != null && geofenceRadius > 0) {
            final distance = const Distance().as(
              LengthUnit.Meter,
              geofenceCenter!,
              currentLocation!,
            );

            setState(() {
              isOutsideFence = distance > geofenceRadius;
            });
          }
        }
      });
    }
  }

  // --- Start geofence selection ---
  void _startGeofenceSelection() {
    setState(() {
      selectingGeofence = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Tap on the map to set your home base.")),
    );
  }

  // --- Ask for radius input ---
  void _askForRadius() async {
    double tempRadius = 100.0;
    TextEditingController radiusController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Set Geofence Radius (meters)"),
          content: TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Enter radius in meters",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (radiusController.text.isNotEmpty) {
                  tempRadius = double.tryParse(radiusController.text) ?? 100.0;
                }
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    setState(() {
      geofenceRadius = tempRadius;
      selectingGeofence = false;
    });

    // Save geofence to Firebase
    _saveGeofenceToFirebase();
  }

  // --- Save geofence data to Firebase ---
  Future<void> _saveGeofenceToFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && widget.petId != null && geofenceCenter != null) {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );
      final ref = database.ref("users/$uid/pets/${widget.petId}/geofence");

      await ref.set({
        "latitude": geofenceCenter!.latitude,
        "longitude": geofenceCenter!.longitude,
        "radius": geofenceRadius,
        "timestamp": ServerValue.timestamp,
      });
    }
  }

  // --- Load existing geofence from Firebase ---
  Future<void> _loadGeofenceFromFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && widget.petId != null) {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );
      final ref = database.ref("users/$uid/pets/${widget.petId}/geofence");

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          geofenceCenter = LatLng(
            double.tryParse(data["latitude"].toString()) ?? 0.0,
            double.tryParse(data["longitude"].toString()) ?? 0.0,
          );
          geofenceRadius = double.tryParse(data["radius"].toString()) ?? 0.0;
        });
      }
    }
  }

  // --- Focus map to vet ---
  void _focusOnVet(LatLng vetLocation) {
    _mapController.move(vetLocation, 17);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pet.isEmpty) {
      return Center(
        child: Text(
          "Please select a pet from the drawer to view GPS tracking.",
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      );
    }

    // final petName = widget.pet['name'] ?? 'Your Pet'; // header removed
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // header removed per request

            // --- Map Card ---
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: Colors.black12,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 360,
                        child: currentLocation == null
                            ? const Center(child: CircularProgressIndicator())
                            : FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: currentLocation!,
                                  initialZoom: 15,
                                  onTap: (tapPosition, point) {
                                    if (selectingGeofence) {
                                      setState(() {
                                        geofenceCenter = point;
                                      });
                                      _askForRadius();
                                    }
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                                    subdomains: const ['a', 'b', 'c', 'd'],
                                    userAgentPackageName:
                                        'com.example.smartcollar_mobileapp',
                                  ),
                                  if (geofenceCenter != null)
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: geofenceCenter!,
                                          radius: geofenceRadius / 2,
                                          useRadiusInMeter: true,
                                          color: isOutsideFence
                                              ? Colors.red.withOpacity(0.25)
                                              : Colors.green.withOpacity(0.25),
                                          borderColor: isOutsideFence
                                              ? Colors.red
                                              : Colors.green,
                                          borderStrokeWidth: 2,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: currentLocation!,
                                        width: 50,
                                        height: 50,
                                        child: Icon(
                                          Icons.pets,
                                          color: isOutsideFence
                                              ? Colors.red
                                              : Colors.pink,
                                          size: 40,
                                        ),
                                      ),
                                      if (showVets)
                                        ...vetClinics.map(
                                          (vet) => Marker(
                                            point: vet['location'],
                                            width: 140,
                                            height: 90,
                                            child: Column(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  color: Colors.blue,
                                                  size: 40,
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    vet['name'],
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    // Attribution
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors, © CARTO',
                          style: TextStyle(fontSize: 9, color: Colors.black87),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter_map',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE91E63),
                        onPressed: () {
                          if (currentLocation != null) {
                            _mapController.move(currentLocation!, 15);
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Controls ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          showVets = !showVets;
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: showVets
                            ? Colors.blue
                            : const Color(0xFFE91E63),
                      ),
                      icon: Icon(
                        showVets ? Icons.visibility_off : Icons.local_hospital,
                      ),
                      label: Text(showVets ? 'Hide Clinics' : 'Nearby Clinics'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startGeofenceSelection,
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Set Geofence'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- Geofence Status ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 3,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (isOutsideFence ? Colors.red : Colors.green)
                            .withOpacity(0.15),
                    child: Icon(
                      isOutsideFence ? Icons.error : Icons.check_circle,
                      color: isOutsideFence ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    isOutsideFence
                        ? 'Collar is outside the geofence'
                        : (geofenceCenter != null
                              ? 'Collar is inside the geofence'
                              : 'No geofence set'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: geofenceCenter != null
                      ? Text('Radius: ${geofenceRadius.toStringAsFixed(0)} m')
                      : null,
                ),
              ),
            ),

            // --- Vet List ---
            if (showVets)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                child: Card(
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      itemCount: vetClinics.length,
                      itemBuilder: (context, index) {
                        final vet = vetClinics[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.local_hospital,
                            color: Colors.blue,
                          ),
                          title: Text(
                            vet['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${vet['location'].latitude}, ${vet['location'].longitude}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.navigation_outlined),
                            onPressed: () => _focusOnVet(vet['location']),
                          ),
                          onTap: () => _focusOnVet(vet['location']),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
