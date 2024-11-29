import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:math'; // Importing dart:math for random number generation

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
  int _adCounter = 0; // Counter to track ads watched
  DateTime? _lastAdWatchTime; // Variable to store the last ad watch time

  List<String> imageUrls = []; // List to store image URLs from Firestore
  List<bool> isImageBlurred = []; // Track whether each image is blurred

  @override
  void initState() {
    super.initState();
    loadAd();
    _loadUnityAds();
    _fetchInitialPoints(); // Fetch initial points based on username
    _fetchInitialTimestamp(); // Fetch initial timestamp when the screen is loaded
    _fetchImageUrls(); // Fetch image URLs from Firebase
  }

  // Fetch initial points from Firestore
  Future<void> _fetchInitialPoints() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('PhoneNumber', isEqualTo: widget.username) // Use username for fetching
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _points = querySnapshot.docs.first.data()['Points'] ?? 0; // Fetch the initial points
      });
    }
  }

  // Fetch initial timestamp when the screen is loaded
  Future<void> _fetchInitialTimestamp() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('PhoneNumber', isEqualTo: widget.username) // Use username for fetching
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        Timestamp timestamp = querySnapshot.docs.first.data()['lastAdWatchTimestamp'] ?? 0;
        _lastAdWatchTime = timestamp.toDate(); // Store last ad watch time
      });
    }
  }

  // Fetch image URLs from Firestore
  Future<void> _fetchImageUrls() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('Images') // Collection where images are stored
        .get();

    List<String> fetchedUrls = [];
    for (var doc in querySnapshot.docs) {
      String imageUrl = doc.data()['imageURL'] ?? ''; // Assuming field name is 'imageUrl'
      if (imageUrl.isNotEmpty) {
        fetchedUrls.add(imageUrl);
      }
    }

    setState(() {
      imageUrls = fetchedUrls; // Update the imageUrls list
      isImageBlurred = List.generate(fetchedUrls.length, (_) => true); // Initially, all images are blurred
    });
  }

  Future<void> _updatePointsAndTimestampInFirestore(int newPoints) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('PhoneNumber', isEqualTo: widget.username) // Use username for updating
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String docId = querySnapshot.docs.first.id; // Get document ID
      await FirebaseFirestore.instance.collection('LoginCredentials').doc(docId).update({
        'Points': newPoints,
        'lastAdWatchTimestamp': Timestamp.now(), // Update last ad watch time to current time
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
  Future<void> _transferPoints(String recipientPhone, int pointsToTransfer) async {
    if (_points < pointsToTransfer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points to transfer!')),
      );
      return;
    }

    final recipientQuery = await FirebaseFirestore.instance
        .collection('LoginCredentials')
        .where('PhoneNumber', isEqualTo: recipientPhone)
        .get();

    if (recipientQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient not found!')),
      );
      return;
    }

    String recipientDocId = recipientQuery.docs.first.id;
    int recipientPoints = recipientQuery.docs.first.data()['Points'] ?? 0;

    try {
      // Update sender's points
      final senderQuery = await FirebaseFirestore.instance
          .collection('LoginCredentials')
          .where('PhoneNumber', isEqualTo: widget.username)
          .get();

      if (senderQuery.docs.isNotEmpty) {
        String senderDocId = senderQuery.docs.first.id;

        await FirebaseFirestore.instance
            .collection('LoginCredentials')
            .doc(senderDocId)
            .update({'Points': _points - pointsToTransfer});

        setState(() {
          _points -= pointsToTransfer; // Update local state
        });
      }

      // Update recipient's points
      await FirebaseFirestore.instance
          .collection('LoginCredentials')
          .doc(recipientDocId)
          .update({'Points': recipientPoints + pointsToTransfer});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points transferred successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error transferring points: $e')),
      );
    }
  }

  void sharePoints() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController phoneNumberController =
        TextEditingController();
        final TextEditingController pointsController = TextEditingController();

        return AlertDialog(
          title: const Text('Share Points'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: 'Points'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String recipientPhone = phoneNumberController.text.trim();
                int pointsToTransfer =
                    int.tryParse(pointsController.text.trim()) ?? 0;

                if (pointsToTransfer <= 0 || recipientPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid input!')),
                  );
                  return;
                }

                // Perform the transfer
                await _transferPoints(recipientPhone, pointsToTransfer);
                Navigator.of(context).pop();
              },
              child: const Text('Share'),
            ),
          ],
        );
      },
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
          setState(() {
            _points += 1; // Award 1 point
            _adCounter++; // Increment ad counter
          });
          _updatePointsAndTimestampInFirestore(_points); // Update points and timestamp in Firestore
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
        setState(() {
          _points += 1; // Award 1 point
          _adCounter++; // Increment ad counter
        });
        _updatePointsAndTimestampInFirestore(_points); // Update points and timestamp in Firestore
      },
      onFailed: (placementId, error, message) =>
          print('Unity Video Ad $placementId failed: $error $message'),
      onSkipped: (placementId) =>
          print('Unity Video Ad $placementId skipped'),
    );
  }

  // Method to handle image blur removal on button press
  void _removeImageBlur(int index) {
    if (_points >= 10) {
      setState(() {
        isImageBlurred[index] = false; // Remove blur for the specific image
        _points -= 10; // Deduct 10 points
      });
      _updatePointsAndTimestampInFirestore(_points); // Update points in Firestore
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points to watch this image!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if 1 hour has passed since last ad watched
    bool canWatchAd = _lastAdWatchTime != null &&
        DateTime.now().difference(_lastAdWatchTime!).inHours >= 1;

    return Scaffold(
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Row containing Points text and Watch Ad button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Points: $_points',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 100), // Add spacing between the two elements
                  ElevatedButton(
                    onPressed: showAd,
                    child: const Text('Watch Ad'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: sharePoints,
                  child: const Text('Share Points'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  "Transform your screen, transform your vibe, one wallpaper at a time!",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.yellow,
                  ),
                  textAlign: TextAlign.center, // Ensures the text is centered within the Text widget
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return Card(
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                              height: 200,
                              width: double.infinity,
                              color: isImageBlurred[index]
                                  ? Colors.black.withOpacity(0.8)
                                  : Colors.transparent,
                              colorBlendMode: BlendMode.darken,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: ElevatedButton(
                              onPressed: () => _removeImageBlur(index),
                              child: const Text('Unlock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
        ? "interstitialVideoAdPlacementIdAndroid"
        : "interstitialVideoAdPlacementIdIOS";
  }

  static String get rewardedVideoAdPlacementId {
    return Platform.isAndroid
        ? "rewardedVideoAdPlacementIdAndroid"
        : "rewardedVideoAdPlacementIdIOS";
  }
}
