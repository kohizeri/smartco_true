import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'vet_pet.dart'; // Assuming this file exists and contains VetPetProfilePage

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class _SharedPet {
  final String petId;
  final String name;
  final String species;
  final String breed;
  final String ageLabel;
  final String ownerUid;
  final String role;

  const _SharedPet({
    required this.petId,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageLabel,
    required this.ownerUid,
    required this.role,
  });

  String get displaySpecies => species.isEmpty ? 'Unknown' : species;

  String get displayBreed => breed.isEmpty ? 'N/A' : breed;
}

class _ShareRequest {
  final String requestId;
  final String ownerUid;
  final String petId;
  final String petName;
  final String role;
  final String ownerEmail;

  const _ShareRequest({
    required this.requestId,
    required this.ownerUid,
    required this.petId,
    required this.petName,
    required this.role,
    required this.ownerEmail,
  });
}

class VetProfilePage extends StatefulWidget {
  const VetProfilePage({super.key});

  @override
  State<VetProfilePage> createState() => _VetProfilePageState();
}

class _VetProfilePageState extends State<VetProfilePage> {
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _databaseURL,
  );

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  String? get _uid => _currentUser?.uid;

  late DatabaseReference sharedPetsRef;

  IconData _speciesIcon(String species) {
    final normalized = species.toLowerCase();
    if (normalized.contains('cat')) return Icons.pets; // cat icon fallback
    if (normalized.contains('bird')) return Icons.flutter_dash;
    if (normalized.contains('fish')) return Icons.water;
    if (normalized.contains('horse')) return Icons.airline_stops;
    return Icons.pets; // Default
  }

  // --- COLOR FIX ---
  // Reverted to shades of pink as requested
  Color _speciesColor(String species) {
    return Colors.pink[300] ?? Colors.pink;
  }

  LinearGradient _cardGradient(Color base) {
    return LinearGradient(
      colors: [base.withOpacity(0.18), base.withOpacity(0.05)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _buildAgeLabel(dynamic value) {
    final age = _toDouble(value);
    if (age == null) return 'Unknown age';
    final suffix = age == 1 ? 'yr' : 'yrs';
    final display = age % 1 == 0
        ? age.toInt().toString()
        : age.toStringAsFixed(1);
    return '$display $suffix';
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    sharedPetsRef = _database.ref("users");
  }

  Future<void> _acceptShareRequest(_ShareRequest request) async {
    try {
      // Move request to shared_with
      await _database
          .ref("users/${request.ownerUid}/pets/${request.petId}/shared_with/$_uid")
          .set({
            "email": _currentUser?.email ?? "",
            "role": request.role,
          });

      // Remove the request
      await _database
          .ref("users/$_uid/share_requests/${request.requestId}")
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Accepted share request for ${request.petName}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error accepting request: $e")),
        );
      }
    }
  }

  Future<void> _rejectShareRequest(_ShareRequest request) async {
    try {
      // Remove the request
      await _database
          .ref("users/$_uid/share_requests/${request.requestId}")
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rejected share request for ${request.petName}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error rejecting request: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add a null-check for the user UID
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text("Error: You are not logged in.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Share Requests Section
          StreamBuilder(
            stream: _database.ref("users/$_uid/share_requests").onValue,
            builder: (context, requestsSnapshot) {
              if (requestsSnapshot.hasError) {
                return const SizedBox.shrink();
              }

              if (!requestsSnapshot.hasData || 
                  requestsSnapshot.data?.snapshot.value == null) {
                return const SizedBox.shrink();
              }

              final requestsData = Map<dynamic, dynamic>.from(
                requestsSnapshot.data!.snapshot.value as Map,
              );

              final List<_ShareRequest> requests = [];
              requestsData.forEach((requestId, requestData) {
                if (requestData is Map) {
                  requests.add(
                    _ShareRequest(
                      requestId: requestId.toString(),
                      ownerUid: requestData['ownerUid']?.toString() ?? '',
                      petId: requestData['petId']?.toString() ?? '',
                      petName: requestData['petName']?.toString() ?? 'Unknown Pet',
                      role: requestData['role']?.toString() ?? 'vet',
                      ownerEmail: requestData['ownerEmail']?.toString() ?? '',
                    ),
                  );
                }
              });

              if (requests.isEmpty) {
                return const SizedBox.shrink();
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Pending Share Requests (${requests.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  request.petName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${request.ownerEmail}'),
                                    Text('Role: ${request.role.toUpperCase()}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _acceptShareRequest(request),
                                      tooltip: 'Accept',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _rejectShareRequest(request),
                                      tooltip: 'Reject',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Shared Pets Section
          Expanded(
            child: StreamBuilder(
              stream: sharedPetsRef.onValue,
              builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading pets"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("No pets shared with you yet."));
          }

          final data = Map<dynamic, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          final List<_SharedPet> sharedPets = [];

          data.forEach((ownerUid, ownerData) {
            if (ownerData is Map && ownerData["pets"] != null) {
              final pets = Map<dynamic, dynamic>.from(ownerData["pets"] as Map);
              pets.forEach((petId, petData) {
                if (petData is Map && petData["shared_with"] != null) {
                  final sharedWith = Map<dynamic, dynamic>.from(
                    petData["shared_with"] as Map,
                  );
                  if (sharedWith.containsKey(_uid!)) {
                    final sharedEntry = sharedWith[_uid!];
                    final role =
                        sharedEntry is Map && sharedEntry['role'] != null
                        ? sharedEntry['role'].toString()
                        : 'vet';
                    final name = petData['name']?.toString() ?? 'Unnamed Pet';
                    final species = petData['species']?.toString() ?? 'Unknown';
                    final breed = petData['breed']?.toString() ?? '';
                    final ageLabel = _buildAgeLabel(petData['age']);

                    sharedPets.add(
                      _SharedPet(
                        petId: petId.toString(),
                        name: name,
                        species: species,
                        breed: breed,
                        ageLabel: ageLabel,
                        ownerUid: ownerUid.toString(),
                        role: role,
                      ),
                    );
                  }
                }
              });
            }
          });

          if (sharedPets.isEmpty) {
            return const Center(child: Text("No pets shared with you."));
          }

          sharedPets.sort((a, b) => a.name.compareTo(b.name));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    // --- COLOR FIX ---
                    // Reverted to shades of pink
                    gradient: LinearGradient(
                      colors: [Colors.pinkAccent, Color(0xFFF06292)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              // --- COLOR FIX ---
                              // Changed icon to be pet-themed
                              Icons.pets_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Shared Pets Overview',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sharedPets.length == 1
                                      ? '1 pet is currently shared with you.'
                                      : '${sharedPets.length} pets are currently shared with you.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = 2;
                    // Adjusted aspect ratio slightly
                    final childAspectRatio = constraints.maxWidth >= 480
                        ? 0.8
                        : 0.75;

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: sharedPets.length,
                      itemBuilder: (context, index) {
                        final pet = sharedPets[index];
                        final speciesColor = _speciesColor(pet.displaySpecies);
                        final speciesLabel = _titleCase(pet.displaySpecies);
                        final breedLabel = _titleCase(pet.displayBreed);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VetPetProfilePage(
                                    ownerUid: pet.ownerUid,
                                    petId: pet.petId,
                                    initialName: pet.name,
                                    initialSpecies: pet.displaySpecies,
                                  ),
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                gradient: _cardGradient(speciesColor),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: speciesColor.withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: speciesColor.withOpacity(0.15),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: speciesColor.withOpacity(0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _speciesIcon(pet.displaySpecies),
                                          color: speciesColor.darken(0.05),
                                          size: 30,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: speciesColor.darken(0.2),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    pet.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  //
                                  // --- OVERFLOW FIX ---
                                  //
                                  // Wrapped the variable-height content in an
                                  // Expanded + SingleChildScrollView to
                                  // prevent all overflow errors.
                                  //
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ChipLabel(
                                                label: speciesLabel,
                                                color: speciesColor,
                                              ),
                                              _ChipLabel(
                                                label: breedLabel,
                                                color: speciesColor.withOpacity(
                                                  0.85,
                                                ),
                                              ),
                                              _ChipLabel(
                                                label: pet.role.toUpperCase(),
                                                color: speciesColor.darken(
                                                  0.12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Age: ${pet.ageLabel}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Owner UID: ${pet.ownerUid}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.darken(0.1),
          letterSpacing: 0.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

extension _ColorShade on Color {
  Color darken([double amount = 0.2]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
