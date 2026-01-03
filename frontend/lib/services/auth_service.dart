// ignore_for_file: dead_code, unnecessary_null_comparison, use_build_context_synchronously, avoid_print, unnecessary_import, await_only_futures, unnecessary_nullable_for_final_variable_declarations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:frontend/screens/authScreen.dart';
import 'package:frontend/screens/home.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static bool isInitialize = false;

  static Future<void> initSignIn() async {
    if (!isInitialize) {
      await _googleSignIn.initialize(
        serverClientId:
            '763234425950-f40rcdg9hlljqkf5bnnsrf6u74ivv3aj.apps.googleusercontent.com',
      );
    }
    isInitialize = true;
  }

  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Must initialize fir v7.x
      await googleSignIn.initialize();

      // Authenticate / Sign In
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        // user cancelled signin
        return null;
      }

      // Get ID Token
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: "ERROR_MISSIGNG_ID_TOKEN",
          message: "Missing Google ID Toekn",
        );
      }
      // Get accessToken via authorizationClient for scopes
      const List<String> scopes = ['email', 'profile'];
      GoogleSignInClientAuthorization? authorization = await googleUser
          .authorizationClient
          .authorizationForScopes(scopes);

      // If not yet granted, request scopes (UI)
      if (authorization?.accessToken == null) {
        authorization = await googleUser.authorizationClient.authorizeScopes(
          scopes,
        );
        if (authorization.accessToken == null) {
          throw FirebaseAuthException(
            code: "ERROR_MISSING_ACCESS_TOKEN",
            message: "User did not grant required permissions",
          );
        }
      }

      final String accessToken = authorization!.accessToken;

      // Create credential for Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            "Name": user.displayName,
            "Email": user.email,
            "Id": user.uid,
            "Image": user.photoURL ?? Image.asset("images/defaultUserDP.jpg"),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }

      return userCredential;
    } on GoogleSignInException catch (e) {
      print("GoogleSignInException: ${e.code} — ${e.description}");
      rethrow;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      rethrow;
    }
  }

  // Sign out from Firebase and Google
  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await auth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      print("User signed out successfully!");
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) {
            return LoginPage();
          },
        ),
        (route) {
          return false;
        },
      );
      // message after account created....
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(20),
          ),
          content: Text("✅ Account LogedIn Successfully"),
        ),
      );
    } catch (e) {
      // message after if any error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(20),
          ),
          content: Row(
            children: [
              Text("❌"),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString(),
                  // softWrap: true,
                  // overflow: TextOverflow.fade,
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> createAccount(
    BuildContext context,
    String email,
    String password,
    String name,
  ) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      var userID = FirebaseAuth.instance.currentUser!.uid;

      var db = FirebaseFirestore.instance;

      Map<String, dynamic> data = {
        "name": name,
        "email": email,
        "userID": userID,
      };

      try {
        await db.collection("emailUsers").doc(userID.toString()).set(data);
      } catch (e) {
        print(e);
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) {
            return LoginPage();
          },
        ),
        (route) {
          return false; // nned here coz of pushAndRemoveUntil. set to false as we dont need the back button at dashboard page
        },
      );

      // message after account created....
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(20),
          ),
          content: Text("✅ Account Created Successfully"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(20),
          ),
          content: Row(
            children: [
              Text("❌"),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString(),
                  // softWrap: true,
                  // overflow: TextOverflow.fade,
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
