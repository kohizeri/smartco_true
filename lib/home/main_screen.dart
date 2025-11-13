import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'home_dashboard.dart';
import 'gps_tracking.dart';
import 'health_records.dart';
import 'reminders.dart';
import 'settings.dart';
import 'notif.dart';
import '../auth/login_screen.dart';

const String _databaseURL =
    'https://smartcollar-c69c1-default-rtdb.asia-southeast1.firebasedatabase.app';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedPet;
  final String? petId;

  const MainScreen({super.key, this.selectedPet, this.petId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int currentPetIndex = 0;
  DatabaseReference? usersRef;
  DatabaseReference? notificationsRef;
  String? currentEmail;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentEmail = user.email;
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: _databaseURL,
      );
      usersRef = database.ref("users");
      notificationsRef = database.ref("users/${user.uid}/notifications");
    }
  }

  /// Switch pets using arrows
  void _switchPet(int direction, List<Map<String, dynamic>> petsList) {
    if (petsList.isEmpty) return;
    setState(() {
      currentPetIndex =
          (currentPetIndex + direction + petsList.length) % petsList.length;
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Show modern modal sheet with pets
  void _showPetListDialog(List<Map<String, dynamic>> petsList) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Select Pet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final pet = petsList[index];
                      final name = pet['name'] ?? 'Unnamed Pet';
                      final breed = pet['breed'] ?? '';
                      final isSelected = index == currentPetIndex;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink.shade50,
                          child: const Icon(
                            Icons.pets,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: breed.isNotEmpty ? Text(breed) : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFFE91E63),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            currentPetIndex = index;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: petsList.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddPetForm(BuildContext context) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final speciesController = TextEditingController();
    final breedController = TextEditingController();
    final collarIdController = TextEditingController();
    String selectedGender = "Male";

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _databaseURL,
    );
    final petsRef = database.ref("users/$uid/pets");

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

              final petRef = petsRef.push();
              final newPetId = petRef.key!;

              await petRef.set({
                "petId": newPetId,
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

  /// Handle bottom nav
  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (usersRef == null || currentEmail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DatabaseEvent>(
      stream: usersRef!.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return _buildNoPetsUI();
        }

        final usersMap = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        List<Map<String, dynamic>> petsList = [];
        List<String> petIds = [];

        // ✅ Collect own pets + shared pets
        usersMap.forEach((uid, userData) {
          final userMap = Map<String, dynamic>.from(userData);
          if (userMap.containsKey("pets")) {
            final petsMap = Map<String, dynamic>.from(userMap["pets"]);
            petsMap.forEach((petId, petData) {
              final pet = Map<String, dynamic>.from(petData);

              // Own pets
              if (uid == FirebaseAuth.instance.currentUser?.uid) {
                petsList.add(pet);
                petIds.add(petId);
              }
              // Shared pets (check if current user UID is inside shared_with)
              else if (pet.containsKey("shared_with")) {
                final sharedWithMap = Map<String, dynamic>.from(
                  pet["shared_with"],
                );
                final currentUid = FirebaseAuth.instance.currentUser?.uid;

                if (currentUid != null &&
                    sharedWithMap.containsKey(currentUid)) {
                  petsList.add(pet);
                  petIds.add(petId);
                }
              }
            });
          }
        });

        if (petsList.isEmpty) {
          return _buildNoPetsUI();
        }

        // Ensure valid index
        if (currentPetIndex >= petsList.length) currentPetIndex = 0;

        final currentPet = petsList[currentPetIndex];
        final currentPetId = petIds[currentPetIndex];
        final currentPetName = currentPet['name'] ?? "Pet";

        final pages = [
          HomeDashboard(pet: currentPet, petId: currentPetId),
          GpsTrackingPage(pet: currentPet, petId: currentPetId),
          HealthRecordsPage(pet: currentPet, petId: currentPetId),
          RemindersPage(petId: currentPetId),
          SettingsPage(pet: currentPet, petId: currentPetId),
        ];

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(90),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                        ),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                        onPressed: () => _switchPet(-1, petsList),
                      ),
                      GestureDetector(
                        onTap: () => _showPetListDialog(petsList),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: const Icon(
                                  Icons.pets,
                                  size: 16,
                                  color: Color(0xFFE91E63),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                currentPetName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<DatabaseEvent>(
                            stream: notificationsRef?.onValue,
                            builder: (context, snapshot) {
                              int unreadCount = 0;
                              if (snapshot.hasData &&
                                  snapshot.data?.snapshot.value != null) {
                                final data = Map<String, dynamic>.from(
                                  snapshot.data!.snapshot.value as Map,
                                );
                                unreadCount = data.values
                                    .where((notif) {
                                      final notifMap =
                                          Map<String, dynamic>.from(notif as Map);
                                      return notifMap['read'] != true;
                                    })
                                    .length;
                              }
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.15),
                                    ),
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const NotificationsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: unreadCount == 1
                                          ? Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 16,
                                                minHeight: 16,
                                              ),
                                              child: Text(
                                                unreadCount > 99
                                                    ? '99+'
                                                    : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                    ),
                                ],
                              );
                            },
                          ),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.15),
                            ),
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            onPressed: () => _switchPet(1, petsList),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: pages[_selectedIndex],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            indicatorColor: Colors.pink.shade50,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'GPS',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Health',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  /// UI when no pets exist
  Widget _buildNoPetsUI() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print("Logged in as: ${user.email}");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartCollar"),
        backgroundColor: Colors.pink,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: Center(
        child: Card(
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 80, color: Colors.pink),
                const SizedBox(height: 16),
                const Text(
                  "No Pets Found",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Get started by adding a pet profile or logout.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // ➕ Add Pet button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add Pet"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // ✅ Call the add pet dialog directly
                    _showAddPetForm(context);
                  },
                ),
                const SizedBox(height: 12),

                // 🚪 Logout button
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
