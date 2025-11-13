import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'vet_pet.dart';

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
  final uid = FirebaseAuth.instance.currentUser!.uid;

  late DatabaseReference sharedPetsRef;

  IconData _speciesIcon(String species) {
    final normalized = species.toLowerCase();
    if (normalized.contains('cat')) return Icons.pets; // cat icon fallback
    if (normalized.contains('bird')) return Icons.flutter_dash;
    if (normalized.contains('fish')) return Icons.water;
    if (normalized.contains('horse')) return Icons.airline_stops;
    return Icons.pets;
  }

  Color _speciesColor(String species) {
    final normalized = species.toLowerCase();
    if (normalized.contains('cat')) return const Color(0xFF9C27B0);
    if (normalized.contains('dog')) return const Color(0xFF03A9F4);
    if (normalized.contains('bird')) return const Color(0xFFFFC107);
    if (normalized.contains('fish')) return const Color(0xFF4CAF50);
    return const Color(0xFF607D8B);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
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
                  if (sharedWith.containsKey(uid)) {
                    final sharedEntry = sharedWith[uid];
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
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
                              Icons.medical_services_rounded,
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
                    final childAspectRatio = constraints.maxWidth >= 480
                        ? 0.78
                        : 0.72;

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
                                        color: speciesColor.withOpacity(0.85),
                                      ),
                                      _ChipLabel(
                                        label: pet.role.toUpperCase(),
                                        color: speciesColor.darken(0.12),
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
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 21,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Open profile',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: speciesColor.darken(0.2),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                            color: speciesColor.darken(0.2),
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
