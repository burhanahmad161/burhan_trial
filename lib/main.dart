import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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

  Future<String?> checkUserExists(String phoneNumber) async {
    final CollectionReference users = FirebaseFirestore.instance.collection('LoginCredentials');

    final querySnapshot = await users
        .where('PhoneNumber', isEqualTo: phoneNumber)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Return phone number if the user exists
      return phoneNumber;
    }
    return null; // Return null if the phone number doesn't exist
  }

  Future<void> createUserAccount(String phoneNumber) async {
    final CollectionReference users = FirebaseFirestore.instance.collection('LoginCredentials');

    // Add the new user with phone number and points initialized to 0
    await users.add({
      'PhoneNumber': phoneNumber,
      'Points': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController phoneNumberController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '4K HD Wallpapers',
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
              controller: phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String phoneNumber = phoneNumberController.text;

                // Check if phone number is valid (11 digits)
                if (phoneNumber.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Phone number is not valid!'),
                    ),
                  );
                  return;
                }

                String? existingPhone = await checkUserExists(phoneNumber);

                if (existingPhone != null) {
                  // If user exists, navigate to Screen2
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Screen2(username: phoneNumber),
                    ),
                  );
                } else {
                  // If user doesn't exist, ask if they want to create an account
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('User Not Found'),
                        content: const Text('Do you want to create a new account with this phone number?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              // Create a new user with phone number and points = 0
                              await createUserAccount(phoneNumber);

                              Navigator.pop(context);

                              // Navigate to Screen2 after creating the account
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Screen2(username: phoneNumber),
                                ),
                              );
                            },
                            child: const Text('Create Account'),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }
}
