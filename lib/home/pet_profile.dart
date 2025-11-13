import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes; // for web preview

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

    final petRef = _database.ref(
      'users/$uid/pets/${widget.petId}',
    );
    final snapshot = await petRef.get();

    if (snapshot.exists) {
      setState(() {
        petData = Map<String, dynamic>.from(snapshot.value as Map);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pet data not found.")));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = null; // ensure we don't use FileImage on web
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageBytes = null;
        });
      }
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!kIsWeb && _imageFile == null) return;
    if (kIsWeb && _imageBytes == null) return;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('pet_images')
          .child(uid)
          .child('${widget.petId}.jpg');

      if (kIsWeb) {
        await storageRef.putData(_imageBytes!);
      } else {
        await storageRef.putFile(_imageFile!);
      }
      final downloadUrl = await storageRef.getDownloadURL();

      final petRef = _database.ref(
        'users/$uid/pets/${widget.petId}',
      );
      // Save under both 'photoUrl' and 'image' for cross-screen compatibility
      await petRef.update({'photoUrl': downloadUrl, 'image': downloadUrl});

      setState(() {
        petData?['photoUrl'] = downloadUrl;
        petData?['image'] = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Picture"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final breeds = selectedSpecies == "Dog"
                ? dogBreeds.values.expand((b) => b).toList()
                : catBreeds.values.expand((b) => b).toList();

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
                            selectedBreed = "";
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedBreed.isNotEmpty
                          ? selectedBreed
                          : null, // avoid null error
                      decoration: const InputDecoration(labelText: "Breed"),
                      items: breeds
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedBreed = v);
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
                    await petRef.update({
                      "name": nameController.text.trim(),
                      "age": int.tryParse(ageController.text.trim()) ?? 0,
                      "species": selectedSpecies,
                      "breed": selectedBreed,
                      "gender": selectedGender,
                      "collarId": collarController.text.trim(),
                    });

                    setState(() {
                      petData?['name'] = nameController.text.trim();
                      petData?['age'] =
                          int.tryParse(ageController.text.trim()) ?? 0;
                      petData?['species'] = selectedSpecies;
                      petData?['breed'] = selectedBreed;
                      petData?['gender'] = selectedGender;
                      petData?['collarId'] = collarController.text.trim();
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pet info updated successfully"),
                      ),
                    );
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
          keyboardType: TextInputType.number,
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

              final petRef = _database.ref(
                'users/$uid/pets/${widget.petId}',
              );
              final weight = double.tryParse(weightController.text.trim());
              if (weight != null) {
                await petRef.update({"weight": weight});
                setState(() => petData?['weight'] = weight);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Weight updated successfully")),
                );
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
    final photoUrl = petData?['photoUrl'];
    final species = (petData?['species'] ?? '').toString().toLowerCase();
    final fallbackUrl = species.contains('cat')
        ? 'https://cdn-icons-png.flaticon.com/512/6988/6988878.png'
        : 'https://cdn-icons-png.flaticon.com/512/616/616408.png';
    final networkUrl = (photoUrl ?? petData?['image'])?.toString();
    final ImageProvider avatarImage =
        networkUrl != null && networkUrl.trim().isNotEmpty
        ? NetworkImage(networkUrl)
        : NetworkImage(fallbackUrl);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(petData?['name'] ?? "Pet Profile"),
        backgroundColor: Colors.pink,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _showEditDialog),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : petData == null
          ? const Center(child: Text("No data found"))
          : SingleChildScrollView(
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
                          GestureDetector(
                            onTap: _showImageOptions,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: _imageBytes != null && kIsWeb
                                      ? MemoryImage(_imageBytes!)
                                      : (_imageFile != null && !kIsWeb
                                            ? FileImage(_imageFile!)
                                            : avatarImage),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${petData?['breed'] ?? 'Unknown Breed'} • ${petData?['species'] ?? 'Unknown Species'}",
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
                          _buildInfoRow("Age", "${petData?['age']} years"),
                          _buildInfoRow(
                            "Gender",
                            petData?['gender'] ?? "Unknown",
                          ),
                          _buildInfoRow(
                            "Collar ID",
                            petData?['collarId'] ?? "None",
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.year}-${date.month}-${date.day}";
  }
}
