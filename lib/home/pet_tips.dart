// pet_tips.dart
class PetHealthInfo {
  final String species;
  final String breed;
  final String normalTemp;
  final String normalBpm;
  final double minWeight;
  final double maxWeight;
  final List<String> breedTips; // renamed from speciesTips
  final Map<String, String> ageTips; // one tip per age

  PetHealthInfo({
    required this.species,
    required this.breed,
    required this.normalTemp,
    required this.normalBpm,
    required this.minWeight,
    required this.maxWeight,
    required this.breedTips,
    required this.ageTips,
  });
}

// Example data for selected dog breeds
final List<PetHealthInfo> petHealthData = [
  PetHealthInfo(
    species: "Dog",
    breed: "Labrador Retriever",
    normalTemp: "38.5–39.2 °C",
    normalBpm: "60–100 bpm",
    minWeight: 25,
    maxWeight: 36,
    breedTips: [
      "Labradors love to swim; make sure to supervise water activities.",
      "Regularly monitor weight; Labradors are prone to obesity.",
    ],
    ageTips: {
      "young": "Socialize young Labradors to avoid behavioral issues.",
      "adult": "Maintain consistent exercise for adult Labradors.",
      "old": "Monitor joint health in older Labradors.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "German Shepherd",
    normalTemp: "38.3–39.0 °C",
    normalBpm: "60–95 bpm",
    minWeight: 22,
    maxWeight: 40,
    breedTips: [
      "German Shepherds are prone to hip dysplasia; monitor mobility.",
      "Provide mental stimulation to prevent boredom.",
    ],
    ageTips: {
      "young": "Socialize and train young German Shepherds early.",
      "adult": "Ensure daily exercise and mental challenges.",
      "old": "Provide joint supplements if needed.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Golden Retriever",
    normalTemp: "38.4–39.1 °C",
    normalBpm: "60–105 bpm",
    minWeight: 25,
    maxWeight: 34,
    breedTips: [
      "Golden Retrievers need daily exercise to avoid obesity and boredom.",
      "Regular grooming helps prevent matting and skin issues.",
    ],
    ageTips: {
      "young": "Socialize young Goldens and start basic obedience training.",
      "adult": "Maintain consistent exercise routines.",
      "old": "Provide soft bedding and reduce high-impact activity.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Bulldog",
    normalTemp: "38.5–39.0 °C",
    normalBpm: "70–120 bpm",
    minWeight: 18,
    maxWeight: 23,
    breedTips: [
      "Bulldogs can have breathing issues; avoid overheating.",
      "Monitor weight closely; they are prone to obesity.",
    ],
    ageTips: {
      "young": "Provide gentle play for young Bulldogs; avoid overexertion.",
      "adult": "Control exercise to prevent respiratory stress.",
      "old": "Monitor breathing and joint health.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Beagle",
    normalTemp: "38.3–39.2 °C",
    normalBpm: "70–120 bpm",
    minWeight: 9,
    maxWeight: 11,
    breedTips: [
      "Beagles have a strong sense of smell; provide regular scent games.",
      "Monitor their diet; Beagles are prone to overeating.",
    ],
    ageTips: {
      "young": "Encourage early training to manage stubborn behavior.",
      "adult": "Provide daily walks to manage weight and energy.",
      "old": "Monitor joints and maintain moderate activity levels.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Poodle",
    normalTemp: "38.5–39.3 °C",
    normalBpm: "60–120 bpm",
    minWeight: 20,
    maxWeight: 32,
    breedTips: [
      "Poodles need regular grooming to prevent matting.",
      "Provide mental stimulation; Poodles are highly intelligent.",
    ],
    ageTips: {
      "young": "Start socialization and obedience training early.",
      "adult": "Maintain daily mental and physical exercise.",
      "old": "Monitor for arthritis and provide soft resting areas.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Rottweiler",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "60–100 bpm",
    minWeight: 35,
    maxWeight: 60,
    breedTips: [
      "Rottweilers need consistent training and socialization.",
      "Monitor weight to prevent joint issues due to their size.",
    ],
    ageTips: {
      "young": "Supervise play and start early socialization.",
      "adult": "Maintain strength training and controlled exercise.",
      "old": "Monitor joint and heart health carefully.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Yorkshire Terrier",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "90–140 bpm",
    minWeight: 2,
    maxWeight: 3.2,
    breedTips: [
      "Yorkshire Terriers require dental care; prone to dental disease.",
      "Protect from cold weather; they are small and delicate.",
    ],
    ageTips: {
      "young": "Provide gentle socialization and play.",
      "adult": "Maintain dental hygiene and regular exercise.",
      "old": "Monitor teeth and mobility closely.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Dachshund",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "70–120 bpm",
    minWeight: 7,
    maxWeight: 15,
    breedTips: [
      "Dachshunds are prone to back issues; avoid excessive jumping.",
      "Provide daily exercise to prevent obesity and maintain spine health.",
    ],
    ageTips: {
      "young": "Introduce gentle exercise to strengthen muscles safely.",
      "adult": "Use ramps instead of stairs to protect the spine.",
      "old": "Provide orthopedic bedding and monitor mobility closely.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Shih Tzu",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "80–120 bpm",
    minWeight: 4,
    maxWeight: 7,
    breedTips: [
      "Shih Tzus require regular grooming to prevent coat matting.",
      "Monitor for breathing issues; they are brachycephalic dogs.",
    ],
    ageTips: {
      "young": "Socialize early to avoid stubborn behaviors.",
      "adult": "Maintain dental hygiene and coat care routines.",
      "old": "Check for eye and breathing issues regularly.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Pomeranian",
    normalTemp: "38.3–39.2 °C",
    normalBpm: "100–160 bpm",
    minWeight: 1.9,
    maxWeight: 3.5,
    breedTips: [
      "Pomeranians need dental care; prone to tooth decay.",
      "Brush their coat regularly to prevent matting.",
    ],
    ageTips: {
      "young": "Socialize and train gently to avoid behavioral issues.",
      "adult": "Provide regular exercise to manage high energy levels.",
      "old": "Monitor heart and joint health closely.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Chihuahua",
    normalTemp: "37.8–39.2 °C",
    normalBpm: "90–160 bpm",
    minWeight: 1.5,
    maxWeight: 3,
    breedTips: [
      "Chihuahuas are prone to dental problems; maintain teeth cleaning.",
      "Keep warm; they are sensitive to cold due to small size.",
    ],
    ageTips: {
      "young": "Provide early socialization and gentle handling.",
      "adult": "Monitor teeth and provide regular playtime.",
      "old": "Check mobility and teeth regularly for health issues.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Siberian Husky",
    normalTemp: "38.3–39.4 °C",
    normalBpm: "60–100 bpm",
    minWeight: 20,
    maxWeight: 27,
    breedTips: [
      "Siberian Huskies need lots of exercise; they are high-energy dogs.",
      "Monitor coat during shedding season to prevent matting.",
    ],
    ageTips: {
      "young":
          "Introduce socialization early; Huskies can be independent-minded.",
      "adult":
          "Provide daily running or mental stimulation to prevent boredom.",
      "old": "Check joints and mobility regularly due to high activity levels.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Doberman Pinscher",
    normalTemp: "38.0–39.3 °C",
    normalBpm: "60–100 bpm",
    minWeight: 30,
    maxWeight: 40,
    breedTips: [
      "Dobermans are prone to heart issues; regular vet checkups are important.",
      "They need structured training and socialization.",
    ],
    ageTips: {
      "young": "Start training early for obedience and social skills.",
      "adult": "Provide mental stimulation and regular exercise.",
      "old": "Monitor heart health and adjust exercise accordingly.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Border Collie",
    normalTemp: "38.3–39.2 °C",
    normalBpm: "70–120 bpm",
    minWeight: 14,
    maxWeight: 20,
    breedTips: [
      "Border Collies are extremely intelligent; provide mental challenges daily.",
      "Regular exercise is crucial to prevent destructive behavior.",
    ],
    ageTips: {
      "young": "Introduce obedience training and mental games early.",
      "adult": "Maintain high activity levels and problem-solving tasks.",
      "old": "Reduce strenuous exercise and provide joint support.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Corgi",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "60–120 bpm",
    minWeight: 10,
    maxWeight: 14,
    breedTips: [
      "Corgis are prone to back problems; avoid jumping from heights.",
      "Monitor weight to prevent obesity which can strain the spine.",
    ],
    ageTips: {
      "young": "Encourage gentle exercise and socialization.",
      "adult": "Provide controlled activity to maintain fitness.",
      "old": "Support joint health and avoid overexertion.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Great Dane",
    normalTemp: "37.8–38.9 °C",
    normalBpm: "60–100 bpm",
    minWeight: 45,
    maxWeight: 90,
    breedTips: [
      "Great Danes are prone to bloat; feed smaller, frequent meals.",
      "Support joints and bones due to their large size.",
    ],
    ageTips: {
      "young":
          "Provide safe exercise and socialization without overstraining bones.",
      "adult": "Monitor for heart and joint issues regularly.",
      "old": "Offer soft bedding and gentle exercise to protect joints.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Pit Bull Terrier",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "60–120 bpm",
    minWeight: 14,
    maxWeight: 32,
    breedTips: [
      "Pit Bulls can have sensitive skin; check for allergies regularly.",
      "Provide mental stimulation and consistent training.",
    ],
    ageTips: {
      "young": "Start training early for good behavior and social skills.",
      "adult": "Maintain regular exercise and engagement.",
      "old": "Monitor mobility and reduce high-impact activity.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Pug",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "60–120 bpm",
    minWeight: 6,
    maxWeight: 9,
    breedTips: [
      "Pugs are prone to breathing difficulties; avoid excessive heat.",
      "Monitor weight to prevent obesity which can worsen respiratory issues.",
    ],
    ageTips: {
      "young": "Ensure playtime but avoid overheating.",
      "adult": "Keep weight under control and provide moderate activity.",
      "old": "Monitor breathing and joint health; provide soft resting areas.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Aspin",
    normalTemp: "38.0–39.2 °C",
    normalBpm: "70–120 bpm",
    minWeight: 10,
    maxWeight: 20,
    breedTips: [
      "Aspins are hardy and adaptable; regular checkups are still recommended.",
      "Monitor diet and exercise to prevent obesity.",
    ],
    ageTips: {
      "young": "Socialize young Aspins to ensure good behavior.",
      "adult": "Maintain regular exercise and balanced diet.",
      "old": "Provide comfortable resting areas and monitor joints.",
    },
  ),
  PetHealthInfo(
    species: "Dog",
    breed: "Mixed Breed",
    normalTemp: "38–39.2 °C",
    normalBpm: "60–120 bpm",
    minWeight: 5,
    maxWeight: 50,
    breedTips: [
      "Mixed breed dogs have varying characteristics; monitor health closely.",
      "General preventive care applies since breed specifics are unknown.",
    ],
    ageTips: {
      "young":
          "Provide socialization and basic training for overall development.",
      "adult": "Maintain consistent exercise and a balanced diet.",
      "old":
          "Monitor overall health, joints, and weight as specifics are unknown.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Persian",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.0,
    maxWeight: 5.5,
    breedTips: [
      "Persians require regular grooming due to long fur.",
      "Monitor eyes for tear staining and infections.",
    ],
    ageTips: {
      "young": "Introduce grooming routines early to prevent matting.",
      "adult": "Maintain regular grooming and dental care.",
      "old":
          "Watch for kidney or respiratory issues; maintain gentle handling.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Siamese",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 5.0,
    breedTips: [
      "Siamese cats are vocal and social; engage them frequently.",
      "Monitor weight as they are prone to slender body conditions.",
    ],
    ageTips: {
      "young": "Provide interactive toys and early socialization.",
      "adult": "Keep them mentally stimulated and monitor diet.",
      "old": "Ensure comfortable resting spots and regular vet checkups.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Maine Coon",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.0,
    maxWeight: 8.0,
    breedTips: [
      "Maine Coons have thick fur; brush regularly to prevent tangles.",
      "Monitor joint health due to their large size.",
    ],
    ageTips: {
      "young": "Socialize and play gently to support healthy growth.",
      "adult": "Maintain grooming and moderate exercise.",
      "old": "Watch for arthritis and weight management issues.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "British Shorthair",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.0,
    maxWeight: 7.5,
    breedTips: [
      "British Shorthairs are prone to obesity; monitor diet closely.",
      "Provide scratching posts to maintain claw health.",
    ],
    ageTips: {
      "young": "Encourage play and exercise to develop muscles.",
      "adult": "Monitor weight and provide regular activity.",
      "old": "Adjust diet and monitor joints as mobility may decrease.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Ragdoll",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.5,
    maxWeight: 9.0,
    breedTips: [
      "Ragdolls are calm and affectionate; handle them gently.",
      "Monitor weight as they can gain easily due to low activity.",
    ],
    ageTips: {
      "young": "Introduce gentle play to encourage movement and bonding.",
      "adult": "Maintain a balanced diet and moderate activity.",
      "old": "Provide comfortable bedding and monitor for joint issues.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Bengal",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.0,
    maxWeight: 7.0,
    breedTips: [
      "Bengals are active and playful; ensure plenty of exercise.",
      "Monitor for scratches and rough play as they are energetic.",
    ],
    ageTips: {
      "young": "Provide climbing structures and toys to burn energy.",
      "adult": "Maintain mental stimulation and regular exercise.",
      "old": "Adjust activity levels and watch for signs of arthritis.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Scottish Fold",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.0,
    maxWeight: 6.0,
    breedTips: [
      "Scottish Folds have unique folded ears; check regularly for infections.",
      "Monitor weight as they are prone to obesity.",
    ],
    ageTips: {
      "young": "Handle ears gently and socialize early.",
      "adult": "Maintain a balanced diet and monitor ear health.",
      "old": "Check for joint issues due to potential cartilage problems.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Abyssinian",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.0,
    maxWeight: 5.5,
    breedTips: [
      "Abyssinians are active and curious; provide plenty of toys.",
      "Ensure they have safe climbing spaces to prevent injuries.",
    ],
    ageTips: {
      "young": "Encourage exploration and play safely.",
      "adult": "Provide regular mental stimulation and interactive toys.",
      "old": "Reduce climbing risk and maintain joint health.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Sphynx",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 7.0,
    breedTips: [
      "Sphynx cats lack fur; keep them warm and bathe them regularly.",
      "Monitor skin for oil build-up and infections.",
    ],
    ageTips: {
      "young": "Keep them warm and handle skin gently during play.",
      "adult": "Maintain regular cleaning and monitor for skin issues.",
      "old": "Ensure warmth and watch for joint stiffness or sensitivity.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "American Shorthair",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 6.0,
    breedTips: [
      "American Shorthairs are calm and adaptable; monitor diet to prevent obesity.",
      "Provide moderate exercise to maintain healthy weight.",
    ],
    ageTips: {
      "young": "Encourage play and socialization.",
      "adult": "Maintain a balanced diet and regular activity.",
      "old": "Adjust activity levels and monitor joint health.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Russian Blue",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 6.0,
    breedTips: [
      "Russian Blues are shy and reserved; provide a calm environment.",
      "Monitor weight; they can gain easily if overfed.",
    ],
    ageTips: {
      "young": "Socialize gently and encourage play.",
      "adult": "Maintain diet and moderate exercise.",
      "old": "Provide quiet areas and watch for joint issues.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Norwegian Forest Cat",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.0,
    maxWeight: 9.0,
    breedTips: [
      "Norwegian Forest Cats are strong climbers; provide safe climbing spaces.",
      "Groom thick fur regularly to prevent matting.",
    ],
    ageTips: {
      "young": "Ensure safe climbing areas and play opportunities.",
      "adult": "Maintain grooming and activity levels.",
      "old": "Provide comfortable resting spots and monitor joints.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Birman",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 6.5,
    breedTips: [
      "Birmans are gentle and affectionate; provide cozy resting places.",
      "Monitor fur for tangles and maintain grooming.",
    ],
    ageTips: {
      "young": "Encourage gentle play and socialization.",
      "adult": "Maintain grooming and mental stimulation.",
      "old": "Provide soft bedding and monitor mobility.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Oriental Shorthair",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 5.5,
    breedTips: [
      "Oriental Shorthairs are vocal and active; provide interactive play.",
      "Monitor weight; they are muscular but can overeat.",
    ],
    ageTips: {
      "young": "Engage in interactive games to stimulate them.",
      "adult": "Maintain regular playtime and monitor diet.",
      "old": "Adjust activity and ensure comfortable resting spots.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Tonkinese",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 5.5,
    breedTips: [
      "Tonkinese cats are social and playful; ensure companionship.",
      "Monitor diet and exercise to prevent obesity.",
    ],
    ageTips: {
      "young": "Provide social interaction and playtime.",
      "adult": "Maintain diet and stimulate with games.",
      "old": "Ensure comfort and monitor for age-related health issues.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Burmese",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 5.5,
    breedTips: [
      "Burmese cats are affectionate and energetic; provide interactive toys.",
      "Keep track of diet to maintain healthy weight.",
    ],
    ageTips: {
      "young": "Encourage play and socialization early.",
      "adult": "Monitor activity and diet for healthy weight.",
      "old": "Provide soft bedding and gentle exercise.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Himalayan",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 3.5,
    maxWeight: 6.0,
    breedTips: [
      "Himalayans require regular grooming due to long fur.",
      "Monitor for breathing issues as they can have flat faces.",
    ],
    ageTips: {
      "young": "Introduce grooming early to get them accustomed.",
      "adult": "Maintain regular grooming and monitor health.",
      "old": "Provide easy access to litter and feeding areas.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Turkish Angora",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 5.5,
    breedTips: [
      "Turkish Angoras are active and playful; provide vertical spaces.",
      "Monitor coat health and maintain grooming.",
    ],
    ageTips: {
      "young": "Provide climbing and play opportunities.",
      "adult": "Maintain mental stimulation and grooming.",
      "old": "Ensure easy access to favorite spots and gentle care.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Savannah Cat",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 4.5,
    maxWeight: 9.0,
    breedTips: [
      "Savannah Cats are energetic and intelligent; provide space and puzzles.",
      "Monitor behavior closely as they require engagement.",
    ],
    ageTips: {
      "young": "Socialize and stimulate early with games.",
      "adult": "Provide enrichment and keep active.",
      "old": "Reduce high-intensity play but maintain mental stimulation.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Puspin",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 5.5,
    breedTips: [
      "Puspins are hardy cats; still, monitor health and vaccinations.",
      "Provide a balanced diet and regular grooming, especially for long-haired types.",
    ],
    ageTips: {
      "young": "Ensure early socialization and playtime.",
      "adult": "Keep active and provide mental stimulation.",
      "old": "Provide comfortable resting areas and monitor health regularly.",
    },
  ),
  PetHealthInfo(
    species: "Cat",
    breed: "Mixed Breed",
    normalTemp: "38.0–39.0 °C",
    normalBpm: "140–220 bpm",
    minWeight: 2.5,
    maxWeight: 6.0,
    breedTips: [
      "General cat care is recommended as breed specifics are unknown.",
      "Monitor diet, activity, and health regularly due to unknown breed traits.",
    ],
    ageTips: {
      "young": "Ensure socialization and basic training.",
      "adult": "Maintain regular exercise and diet monitoring.",
      "old": "Provide comfort and monitor age-related health concerns.",
    },
  ),
];
