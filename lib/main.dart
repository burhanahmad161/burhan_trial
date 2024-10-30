import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math'; // Importing dart:math for random number generation

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MobileAds.instance.initialize());
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyAa_218GT3aeXjhICpQu102AnaqQ2T1GEM",
        authDomain: "sample-firebase-b6e7d.firebaseapp.com",
        projectId: "sample-firebase-b6e7d",
        storageBucket: "sample-firebase-b6e7d.appspot.com",
        messagingSenderId: "877664373675",
        appId: "1:877664373675:web:5448bee42933baa647a0ee",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Initialize Unity Ads
  UnityAds.init(
    gameId: AdManager.gameId,
    testMode: true,
    onComplete: () {
      print('Unity Ads Initialization Complete');
    },
    onFailed: (error, message) =>
        print('Unity Ads Initialization Failed: $error $message'),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SignInPage(),
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  Future<String?> authenticateUser(String username, String password) async {
    final CollectionReference users =
    FirebaseFirestore.instance.collection('LoginCredentials');

    final querySnapshot = await users
        .where('UserName', isEqualTo: username)
        .where('Password', isEqualTo: password)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Return the username if authenticated
      return username; // This will be used for fetching points
    }
    return null; // Return null if not authenticated
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign In',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'UserName',
              ),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String? username = await authenticateUser(
                  usernameController.text,
                  passwordController.text,
                );

                if (username != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Screen2(username: username),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid username or password'),
                    ),
                  );
                }
              },
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 50),
            const Text(
              'You can only sign up through the Gen-Z main app.',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class Screen2 extends StatefulWidget {
  final String username; // Accept username as a parameter

  const Screen2({Key? key, required this.username}) : super(key: key);

  @override
  _Screen2State createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  RewardedAd? _rewardedAd;
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  bool _showBanner = false;
  Map<String, bool> placements = {
    AdManager.interstitialVideoAdPlacementId: false,
    AdManager.rewardedVideoAdPlacementId: false,
  };

  int _points = 0; // Variable to store the points earned

  @override
  void initState() {
    super.initState();
    loadAd();
    _loadUnityAds();
    _fetchInitialPoints(); // Fetch initial points based on username
  }

  Future<void> _fetchInitialPoints() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('UserName', isEqualTo: widget.username) // Use username for fetching
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _points = querySnapshot.docs.first.data()['Points'] ?? 0; // Fetch the initial points
      });
    }
  }

  Future<void> _updatePointsInFirestore(int newPoints) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('UserName', isEqualTo: widget.username) // Use username for updating
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String docId = querySnapshot.docs.first.id; // Get document ID
      await FirebaseFirestore.instance.collection('LoginCredentials').doc(docId).update({
        'Points': newPoints,
      });
    }
  }

  void loadAd() {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadAd();
            },
          );
          debugPrint('$ad loaded.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void _loadUnityAds() {
    for (var placementId in placements.keys) {
      UnityAds.load(
        placementId: placementId,
        onComplete: (placementId) {
          print('Unity Load Complete $placementId');
          setState(() {
            placements[placementId] = true;
          });
        },
        onFailed: (placementId, error, message) =>
            print('Unity Load Failed $placementId: $error $message'),
      );
    }
  }

  void showAd() {
    // Randomly select between AdMob and Unity Ads
    bool showAdMob = Random().nextBool();
    if (showAdMob) {
      showRewardedAd();
    } else {
      _showAd(AdManager.rewardedVideoAdPlacementId);
    }
  }

  void showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          int randomPoints = Random().nextInt(21) + 10; // Generate random points between 10 and 30
          setState(() {
            _points += randomPoints; // Add random points to the total
          });
          _updatePointsInFirestore(_points); // Update points in Firestore
          debugPrint('User earned reward: ${reward.amount} ${reward.type}, Points: $randomPoints');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You earned $randomPoints points! Total points: $_points'),
            ),
          );
        },
      );
      _rewardedAd = null;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rewarded ad is not loaded yet. Please try again later.'),
        ),
      );
      debugPrint('Rewarded ad is not loaded yet');
    }
  }

  void _showAd(String placementId) {
    setState(() {
      placements[placementId] = false;
    });
    UnityAds.showVideoAd(
      placementId: placementId,
      onComplete: (placementId) {
        int randomPoints = Random().nextInt(21) + 10; // Generate random points between 10 and 30
        setState(() {
          _points += randomPoints; // Add random points to the total
        });
        _updatePointsInFirestore(_points); // Update points in Firestore
        print('User earned reward from Unity Ads: $randomPoints points! Total points: $_points');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You earned $randomPoints points! Total points: $_points'),
          ),
        );
      },
      onFailed: (placementId, error, message) =>
          print('Unity Video Ad $placementId failed: $error $message'),
      onSkipped: (placementId) =>
          print('Unity Video Ad $placementId skipped'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gen-Z Rewards'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.purple.shade200],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Gen-Z Cafe Rewards!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(2.0, 2.0),
                      blurRadius: 3.0,
                      color: Colors.black45,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Watch ads to earn bonus points!',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 32),
              Text(
                'Total Points: $_points',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showAd();
                },
                child: const Text('Watch Ad to Earn Points'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
class AdManager {
  static const String gameId = "5027937"; // Replace with your Unity Game ID
  static String get interstitialVideoAdPlacementId {
  return Platform.isAndroid
  ? "Interstitial_Android" // Android Interstitial Ad Placement ID
      : "Interstitial_iOS";    // iOS Interstitial Ad Placement ID
  }
  static String get rewardedVideoAdPlacementId {
    return Platform.isAndroid
        ? "Rewarded_Android" // Android Rewarded Ad Placement ID
        : "Rewarded_iOS"; // iOS Rewarded Ad Placement ID
  }
}