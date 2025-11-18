import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class PetProfilePage extends StatefulWidget {
  final String petId;

  const PetProfilePage({super.key, required this.petId});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _databaseURL,
  );
  Map<String, dynamic>? petData;
  bool isLoading = true;

  final Map<String, List<String>> dogBreeds = {
    "Small": [
      "Pomeranian",
      "Shih Tzu",
      "Chihuahua",
      "Pug",
      "Yorkshire Terrier",
      "Corgi",
    ],
    "Medium": [
      "Beagle",
      "Bulldog",
      "Cocker Spaniel",
      "Border Collie",
      "Siberian Husky",
    ],
    "Large": [
      "German Shepherd",
      "Labrador Retriever",
      "Golden Retriever",
      "Rottweiler",
      "Doberman",
    ],
  };

  final Map<String, List<String>> catBreeds = {
    "Popular": [
      "Persian",
      "Siamese",
      "Maine Coon",
      "Ragdoll",
      "Bengal",
      "Sphynx",
      "British Shorthair",
    ],
    "Others": [
      "Abyssinian",
      "Scottish Fold",
      "Russian Blue",
      "Birman",
      "Oriental Shorthair",
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchPetData();
  }

  Future<void> _fetchPetData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final petRef = _database.ref('users/$uid/pets/${widget.petId}');
    final snapshot = await petRef.get();

    if (snapshot.exists) {
      setState(() {
        petData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Pet data not found.")));
      }
    }
  }

  void _showEditDialog() {
    if (petData == null) return;
    final nameController = TextEditingController(text: petData?['name'] ?? '');
    final ageController = TextEditingController(
      text: petData?['age']?.toString() ?? '',
    );
    final collarController = TextEditingController(
      text: petData?['collarId'] ?? '',
    );

    String selectedGender = petData?['gender'] ?? "Male";
    String selectedSpecies = petData?['species'] ?? "Dog";
    String selectedBreed = petData?['breed'] ?? "";

    // Ensure initial breed is valid for the species
    final initialBreeds = selectedSpecies == "Dog"
        ? dogBreeds.values.expand((b) => b).toList()
        : catBreeds.values.expand((b) => b).toList();
    if (!initialBreeds.contains(selectedBreed)) {
      selectedBreed = ""; // Reset if breed doesn't match species
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final breeds = selectedSpecies == "Dog"
                ? dogBreeds.values.expand((b) => b).toList()
                : catBreeds.values.expand((b) => b).toList();

            // Handle case where selectedBreed is not in the new breeds list
            String? currentBreed =
                selectedBreed.isNotEmpty && breeds.contains(selectedBreed)
                ? selectedBreed
                : null;

            return AlertDialog(
              title: const Text("Edit Pet Information"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Pet Name"),
                    ),
                    TextField(
                      controller: ageController,
                      decoration: const InputDecoration(
                        labelText: "Age (years)",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedSpecies,
                      decoration: const InputDecoration(labelText: "Species"),
                      items: ["Dog", "Cat"]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            selectedSpecies = v;
                            // Reset breed when species changes
                            currentBreed = null;
                            selectedBreed = ""; // Clear selection
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: currentBreed,
                      hint: const Text("Select Breed"),
                      decoration: const InputDecoration(labelText: "Breed"),
                      isExpanded: true,
                      items: breeds
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            selectedBreed = v;
                            currentBreed = v;
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: "Gender"),
                      items: ["Male", "Female"]
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedGender = v);
                      },
                    ),
                    TextField(
                      controller: collarController,
                      decoration: const InputDecoration(
                        labelText: "Collar ID (optional)",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    final petRef = _database.ref(
                      'users/$uid/pets/${widget.petId}',
                    );

                    final updates = {
                      "name": nameController.text.trim(),
                      "age": int.tryParse(ageController.text.trim()) ?? 0,
                      "species": selectedSpecies,
                      "breed": selectedBreed,
                      "gender": selectedGender,
                      "collarId": collarController.text.trim(),
                    };

                    await petRef.update(updates);

                    // Update local state
                    // Use a temporary map to avoid null issues on the main petData
                    final updatedPetData = Map<String, dynamic>.from(petData!);
                    updatedPetData.addAll(updates);

                    // We must call the parent's setState to update the UI
                    // (this dialog's setState only updates the dialog)
                    this.setState(() {
                      petData = updatedPetData;
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pet info updated successfully"),
                        ),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddWeightDialog() {
    final weightController = TextEditingController(
      text: petData?['weight']?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add / Update Weight"),
        content: TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Weight (kg)"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              final petRef = _database.ref('users/$uid/pets/${widget.petId}');
              final weight = double.tryParse(weightController.text.trim());
              if (weight != null) {
                await petRef.update({"weight": weight});
                setState(() => petData?['weight'] = weight);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Weight updated successfully"),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a valid number"),
                    ),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading and null data cases first
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Loading...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (petData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Pet data could not be loaded.")),
      );
    }

    // Data is loaded, proceed with building UI
    final species = (petData?['species'] ?? '').toString().toLowerCase();
    final petIcon = species.contains('cat')
        ? Icons.pets
        : Icons.pets; // Using 'pets' for both, you can change one

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(petData?['name'] ?? "Pet Profile"),
        backgroundColor: Colors.pink,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _showEditDialog),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header card with avatar
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
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24, // Background for icon
                      child: Icon(petIcon, size: 40, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            petData?['name'] ?? "Unnamed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${petData?['breed'] ?? 'Unknown Breed'} • ${petData?['species'] ?? 'Unknown Species'}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info card
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow("Age", "${petData?['age'] ?? '...'} years"),
                    _buildInfoRow("Gender", petData?['gender'] ?? "Unknown"),
                    _buildInfoRow(
                      "Collar ID",
                      petData?['collarId'] != null &&
                              petData!['collarId'].isNotEmpty
                          ? petData!['collarId']
                          : "None",
                    ),
                    _buildInfoRow(
                      "Weight",
                      petData?['weight'] != null
                          ? "${petData?['weight']} kg"
                          : "Not set",
                    ),
                    _buildInfoRow(
                      "Created At",
                      _formatDate(petData?['createdAt']),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- SHARED WITH CARD ---
            _buildSharedWithCard(),

            // ------------------------------
            const SizedBox(height: 16),

            // Actions
            FilledButton.icon(
              onPressed: _showAddWeightDialog,
              icon: const Icon(Icons.monitor_weight),
              label: const Text("Add / Update Weight"),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER METHOD FOR SHARED WITH CARD ---
  Widget _buildSharedWithCard() {
    // 1. Access the shared_with data
    final sharedData = petData?['shared_with'];

    // 2. Check if data exists and is the correct type
    if (sharedData == null || sharedData is! Map || sharedData.isEmpty) {
      return Card(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Shared With",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Divider(height: 16),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "This pet is not shared with anyone.",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Cast the data (it's a Map<String, dynamic> where values are also maps)
    final sharedMap = Map<String, dynamic>.from(sharedData);

    // 4. Create the list of widgets (ListTiles)
    final List<Widget> sharedUserTiles = [];
    sharedMap.forEach((shareeId, shareInfo) {
      if (shareInfo is Map) {
        final email = shareInfo['email']?.toString() ?? 'Unknown Email';
        final role = shareInfo['role']?.toString() ?? 'Unknown Role';
        sharedUserTiles.add(
          ListTile(
            leading: Icon(
              role.toLowerCase() == 'vet'
                  ? Icons.medical_services_outlined
                  : Icons.person_outline,
              color: Colors.pink.shade700,
            ),
            title: Text(email),
            subtitle: Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            // --- ADDED TRAILING ICON BUTTON ---
            trailing: IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: Colors.red.shade700,
              ),
              onPressed: () {
                _confirmRemoveSharee(
                  shareeId,
                  email,
                ); // Pass ID and email for dialog
              },
            ),
            // ----------------------------------
          ),
        );
      }
    });

    // 5. Return the Card
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Shared With",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16),
            ...sharedUserTiles, // Spread operator to add all tiles
          ],
        ),
      ),
    );
  }
  // ---------------------------------------------

  // --- NEW METHOD TO CONFIRM AND REMOVE A SHAREE ---
  void _confirmRemoveSharee(String shareeId, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Access"),
        content: Text("Are you sure you want to remove access for $email?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white, // Text color
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog first
              _removeSharee(shareeId); // Then perform removal
            },
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSharee(String shareeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (petData == null) return;

    final shareeRef = _database.ref(
      'users/$uid/pets/${widget.petId}/shared_with/$shareeId',
    );

    try {
      await shareeRef.remove();

      // Update local state to reflect removal
      setState(() {
        (petData?['shared_with'] as Map?)?.remove(shareeId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User access removed successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to remove access: $e")));
      }
    }
  }
  // -----------------------------------------------

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      // Format to YYYY-MM-DD
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Invalid Date";
    }
  }
}
