import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../auth/login_screen.dart';
import 'package:smartcollar_mobileapp/home/notif.dart';
import 'notif_edit.dart';
import 'pet_profile.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic>? pet;
  final String? petId;

  const SettingsPage({super.key, this.pet, this.petId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: _databaseURL,
  );

  /// ✅ Fixed Logout
  void _logout(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final database = FirebaseDatabase.instanceFor(
            app: FirebaseAuth.instance.app,
            databaseURL: _databaseURL,
          );
          await database
              .ref('users/$uid/devices/$fcmToken/isOnline')
              .set(false);
          print("isOnline set to false for device $fcmToken");
        }
      }

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print("Error during logout: $e");
    }
  }

  /// Load theme preference
  @override
  void initState() {
    super.initState();
  }

  /// Show Add Pet Form
  void _showAddPetForm(BuildContext context) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final collarIdController = TextEditingController();
    String selectedGender = "Male";
    String selectedSpecies = "Dog";
    String? selectedBreed;

    // 🐶🐱 Extended breed options
    final Map<String, List<String>> breedOptions = {
      "Dog": [
        "Labrador Retriever",
        "German Shepherd",
        "Golden Retriever",
        "Bulldog",
        "Beagle",
        "Poodle",
        "Rottweiler",
        "Yorkshire Terrier",
        "Dachshund",
        "Shih Tzu",
        "Pomeranian",
        "Chihuahua",
        "Siberian Husky",
        "Doberman Pinscher",
        "Border Collie",
        "Corgi",
        "Great Dane",
        "Pit Bull Terrier",
        "Pug",
        "Aspin",
        "Mixed Breed",
      ],
      "Cat": [
        "Persian",
        "Siamese",
        "Maine Coon",
        "British Shorthair",
        "Ragdoll",
        "Bengal",
        "Scottish Fold",
        "Abyssinian",
        "Sphynx",
        "American Shorthair",
        "Russian Blue",
        "Norwegian Forest Cat",
        "Birman",
        "Oriental Shorthair",
        "Tonkinese",
        "Burmese",
        "Himalayan",
        "Turkish Angora",
        "Savannah Cat",
        "Puspin",
        "Mixed Breed",
      ],
    };

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final petsRef = _database.ref("users/$uid/pets");

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Add New Pet",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  DropdownButtonFormField<String>(
                    value: selectedSpecies,
                    decoration: const InputDecoration(labelText: "Species"),
                    items: ["Dog", "Cat"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSpecies = value;
                          selectedBreed = null; // reset when species changes
                        });
                      }
                    },
                  ),

                  // 🧾 Scrollable breed dropdown
                  DropdownButtonFormField<String>(
                    value: selectedBreed,
                    decoration: const InputDecoration(labelText: "Breed"),
                    items: [
                      for (final breed in breedOptions[selectedSpecies]!)
                        DropdownMenuItem(value: breed, child: Text(breed)),
                    ],
                    onChanged: (value) {
                      setState(() => selectedBreed = value);
                    },
                    menuMaxHeight: 250, // makes dropdown scrollable
                  ),

                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(labelText: "Gender"),
                    items: ["Male", "Female"]
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedGender = v);
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  if (selectedBreed == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select a breed")),
                    );
                    return;
                  }

                  final collarId = collarIdController.text.trim();
                  final petRef = collarId.isNotEmpty
                      ? petsRef.child(collarId)
                      : petsRef.push();

                  final newPetId = petRef.key!;

                  await petRef.set({
                    "petId": newPetId,
                    "collarId": collarId,
                    "name": nameController.text.trim(),
                    "age": int.tryParse(ageController.text.trim()) ?? 0,
                    "species": selectedSpecies,
                    "breed": selectedBreed,
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
      },
    );
  }

  /// Share Pet Profile
  void _showSharePetDialog(BuildContext context) {
    if (widget.petId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No pet selected")));
      return;
    }

    final emailController = TextEditingController();
    String selectedRole = "family"; // default role

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Share Pet Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "User Email"),
              ),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Role"),
                items: ["family", "vet"]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedRole = v;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: const Text("Share"),
              onPressed: () async {
                final usersRef = _database.ref("users");
                final snapshot = await usersRef.get();

                String? targetUid;
                String? targetEmail;

                for (var entry in snapshot.children) {
                  final email = entry.child("email").value?.toString();
                  if (email == emailController.text.trim()) {
                    targetUid = entry.key;
                    targetEmail = email;
                    break;
                  }
                }

                if (targetUid == null) {
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User not found")),
                    );
                  }
                  return;
                }

                // ✅ Create share request instead of directly sharing
                final ownerUid = FirebaseAuth.instance.currentUser!.uid;
                final requestId = "${ownerUid}_${widget.petId}";
                
                // Check if pet is already shared with this user
                final sharedWithSnapshot = await _database
                    .ref("users/$ownerUid/pets/${widget.petId}/shared_with/$targetUid")
                    .get();
                
                if (sharedWithSnapshot.exists) {
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pet is already shared with this user")),
                    );
                  }
                  return;
                }
                
                // Check if there's already a pending request
                final existingRequestSnapshot = await _database
                    .ref("users/$targetUid/share_requests/$requestId")
                    .get();
                
                if (existingRequestSnapshot.exists) {
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("A share request is already pending for this user")),
                    );
                  }
                  return;
                }
                
                // Get pet name for the request
                final petSnapshot = await _database
                    .ref("users/$ownerUid/pets/${widget.petId}")
                    .get();
                final petName = petSnapshot.child("name").value?.toString() ?? "Unknown Pet";
                
                // Store request under target user's share_requests
                await _database
                    .ref("users/$targetUid/share_requests/$requestId")
                    .set({
                      "ownerUid": ownerUid,
                      "petId": widget.petId,
                      "petName": petName,
                      "role": selectedRole,
                      "ownerEmail": FirebaseAuth.instance.currentUser?.email ?? "",
                      "requestedAt": ServerValue.timestamp,
                    });

                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Share request sent to $targetEmail")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Remove Pet
  void _removePet(BuildContext context) async {
    if (widget.petId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No pet selected")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: Text(
            "Are you sure you want to remove '${widget.pet?['name'] ?? 'this pet'}'? This action cannot be undone.",
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete"),
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;

                final petRef = _database.ref("users/$uid/pets/${widget.petId}");

                await petRef.remove();
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pet removed successfully")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: const Text("View and edit your profile"),
            onTap: () {
              if (widget.petId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PetProfilePage(petId: widget.petId!),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No pet selected")),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () => _logout(context),
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Pet Settings",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text("Add Pet"),
            onTap: () => _showAddPetForm(context),
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blue),
            title: const Text("Share Pet Profile"),
            onTap: () => _showSharePetDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Remove Pet"),
            onTap: () => _removePet(context),
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Preferences",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.notifications_active,
                color: Colors.orange,
              ),
              title: const Text("Show All Notifications"),
              onTap: () {
                if (widget.petId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationsPage(petId: widget.petId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No pet selected")),
                  );
                }
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.purple),
              title: const Text("Edit Notifications"),
              subtitle: const Text("Manage reminder and alert settings"),
              onTap: () {
                if (widget.petId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NotifEditPage(petId: widget.petId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No pet selected")),
                  );
                }
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text("About App"),
              subtitle: const Text("Smart Collar Monitoring v1.0"),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Smart Collar Monitoring",
                  applicationVersion: "1.0",
                  applicationLegalese: "© 2025 SmartCollar Dev Team",
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
