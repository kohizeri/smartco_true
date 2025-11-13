import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class AppDrawer extends StatefulWidget {
  final Function(Map<String, dynamic>, String) onPetSelected;

  const AppDrawer({super.key, required this.onPetSelected});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DatabaseReference? _petsRef;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final database = FirebaseDatabase.instanceFor(
        app: _auth.app,
        databaseURL:
            "https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app",
      );
      _petsRef = database.ref("users/$uid/pets");
    }
  }

  /// Show form to add a new pet
  void _showPetForm() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final speciesController = TextEditingController();
    final breedController = TextEditingController();
    final collarIdController = TextEditingController();
    String selectedGender = "Male";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Pet"),
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
                decoration: const InputDecoration(labelText: "Age (years)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: speciesController,
                decoration: const InputDecoration(labelText: "Species"),
              ),
              TextField(
                controller: breedController,
                decoration: const InputDecoration(labelText: "Breed"),
              ),
              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: const InputDecoration(labelText: "Gender"),
                items: ["Male", "Female"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedGender = v;
                },
              ),
              TextField(
                controller: collarIdController,
                decoration: const InputDecoration(
                  labelText: "Collar ID (optional)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              if (_petsRef == null) return;

              // Generate unique petId
              final petRef = _petsRef!.push();
              final petId = petRef.key!;

              await petRef.set({
                "petId": petId,
                "collarId": collarIdController.text.trim(),
                "name": nameController.text.trim(),
                "age": int.tryParse(ageController.text.trim()) ?? 0,
                "species": speciesController.text.trim(),
                "breed": breedController.text.trim(),
                "gender": selectedGender,
                "createdAt": ServerValue.timestamp,
              });

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pet added successfully")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// Logout
  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.pink),
            child: Text(
              'My Pets',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          // Pet list
          Expanded(
            child: _petsRef == null
                ? const Center(child: Text("Not signed in"))
                : StreamBuilder<DatabaseEvent>(
                    stream: _petsRef!.onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData ||
                          snapshot.data!.snapshot.value == null) {
                        return const Center(child: Text("No pets added yet"));
                      }
                      final raw = snapshot.data!.snapshot.value!;
                      final map = Map<String, dynamic>.from(raw as Map);
                      final entries = map.entries.toList();

                      return ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final petId = entries[i].key;
                          final petData = Map<String, dynamic>.from(
                            entries[i].value,
                          );

                          final name = petData['name'] ?? 'Unnamed';
                          final species = petData['species'] ?? '';
                          final age = petData['age']?.toString() ?? '-';
                          final gender = petData['gender'] ?? '';

                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.pets),
                            ),
                            title: Text(
                              "$name ${species.isNotEmpty ? '($species)' : ''}",
                            ),
                            subtitle: Text("Age: $age  •  Gender: $gender"),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onPetSelected(petData, petId);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: "Copy collarId",
                              onPressed: () {
                                final collarId = petData['collarId'] ?? '';
                                if (collarId.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: collarId),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Copied collarId: $collarId",
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          const Divider(),

          // Add Pet + Logout
          SafeArea(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text("Add Pet"),
                  onTap: _showPetForm,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Logout"),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
