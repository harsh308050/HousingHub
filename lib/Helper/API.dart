import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Api {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  // Sign in with Google
  static Future<User?> signInWithGoogle() async {
    try {
      // Sign out from any previous Google account to ensure account selection
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if there's an existing account with this email
      final email = googleUser.email;
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.isNotEmpty && !signInMethods.contains('google.com')) {
        // Account exists with different provider, try to link accounts
        print(
            "Account exists with email/password, attempting to link with Google");

        // Get the current user if any
        final currentUser = _auth.currentUser;

        if (currentUser != null && currentUser.email == email) {
          // Same user, link the accounts
          try {
            await currentUser.linkWithCredential(credential);
            print(
                "Successfully linked Google account with existing email/password account");
            return currentUser;
          } catch (e) {
            print("Error linking accounts: $e");
            // If linking fails, continue with normal Google sign in
          }
        }
      }

      // Sign in with the credential (either new account or existing Google account)
      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      print("Error signing in with Google: $e");
      rethrow;
    }
  }

  // Link Google account with existing email/password account
  static Future<bool> linkGoogleAccount() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.linkWithCredential(credential);
        return true;
      }
      return false;
    } catch (e) {
      print("Error linking Google account: $e");
      rethrow;
    }
  }

  // Handle account conflicts and linking
  static Future<User?> handleAccountConflict(
      String email, AuthCredential credential) async {
    try {
      // Get existing sign-in methods for the email
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.contains('password')) {
        // Email/password account exists, user needs to sign in first
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message:
              'An account already exists with this email. Please sign in with your email and password first, then link your Google account in settings.',
        );
      }

      // Continue with normal sign in
      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      print("Error handling account conflict: $e");
      rethrow;
    }
  }

  // Method to check if accounts can be linked
  static Future<bool> canLinkAccounts(String email) async {
    try {
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } catch (e) {
      print("Error checking link capability: $e");
      return false;
    }
  }

  // Enhanced account linking with better error handling
  static Future<UserCredential?> linkWithEmailPassword(
      String email, String password) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user is currently signed in.',
        );
      }

      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      return await currentUser.linkWithCredential(credential);
    } catch (e) {
      print("Error linking with email/password: $e");
      rethrow;
    }
  }

  // Method to set password for Google users
  static Future<bool> setPasswordForGoogleUser(String password) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user is currently signed in.',
        );
      }

      // Check if user is Google authenticated
      bool isGoogleUser = currentUser.providerData
          .any((provider) => provider.providerId == 'google.com');

      if (!isGoogleUser) {
        throw FirebaseAuthException(
          code: 'not-google-user',
          message: 'User is not authenticated with Google.',
        );
      }

      // Check if the user already has password authentication
      bool hasPasswordProvider = currentUser.providerData
          .any((provider) => provider.providerId == 'password');

      if (hasPasswordProvider) {
        print("User already has password authentication");
        return true;
      }

      // Re-authenticate with Google first to ensure fresh authentication
      // This step is critical for security operations like linking credentials
      try {
        // Get Google credentials
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'google-sign-in-cancelled',
            message: 'Google sign-in was cancelled.',
          );
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Reauthenticate
        await currentUser.reauthenticateWithCredential(credential);
        print("User re-authenticated with Google successfully");

        // Now link the password credential
        final passwordCredential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: password,
        );

        await currentUser.linkWithCredential(passwordCredential);
        print("Successfully linked password for Google user");
        return true;
      } catch (e) {
        print("Error during re-authentication or linking: $e");
        throw FirebaseAuthException(
          code: 'credential-linking-failed',
          message:
              'Failed to add password to your account. Please try again or contact support.',
        );
      }
    } catch (e) {
      print("Error setting password for Google user: $e");
      rethrow;
    }
  }

  // Add user data to Firestore
  static Future<void> addUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('Tenants').doc(uid).set(data);
    } catch (e) {
      print("Error adding user data: $e");
      rethrow;
    }
  }

  // Create a new user in Firestore if not exists
  static Future<void> createUserIfNotExists(
      String mobileNumber,
      String firstName,
      String lastName,
      String email,
      String gender,
      String password) async {
    try {
      print("API: Creating user in Firestore with email: $email");

      // Get user's UID from current auth state
      String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      print("API: Current user UID: ${uid.isEmpty ? 'empty' : uid}");

      // Create a reference to the user document in 'users' collection using email as document ID
      final docRef = _firestore.collection('Tenants').doc(email);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        print("API: User document already exists, updating instead");
      }

      // Create or update document with user data
      await docRef.set({
        'mobileNumber': mobileNumber,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'gender': gender,
        'userType': 'tenant', // Adding user type for future reference
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
        // Do not store password in Firestore
      }, SetOptions(merge: true)); // Use merge to update existing documents

      print("API: User document created/updated successfully");
    } catch (e) {
      print("API Error creating user: $e");
      print("API Error stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Get user details by email
  static Future<Map<String, dynamic>?> getUserDetailsByEmail(
      String email) async {
    try {
      final userDoc = await _firestore.collection('Tenants').doc(email).get();
      if (userDoc.exists) {
        return userDoc.data();
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting user details: $e");
      return null;
    }
  }

  // Get user details by UID
  static Future<Map<String, dynamic>?> getUserDetailsByUID(String uid) async {
    try {
      // Query Firestore for user with matching UID
      final querySnapshot = await _firestore
          .collection('Tenants')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting user details by UID: $e");
      return null;
    }
  }

  // Get current authenticated user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut(); // Also sign out from Google
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  // Sign out from Google
  static Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print("Error signing out from Google: $e");
    }
  }

  // Send email verification to the current user
  static Future<void> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        // Configure action code settings with improved branding parameters
        ActionCodeSettings actionCodeSettings = ActionCodeSettings(
          // Dynamic URL with the user's email embedded
          url:
              'https://housinghub-c2dae.firebaseapp.com/verify?email=${user.email}',
          handleCodeInApp: true,
          androidPackageName: 'com.harsh.housinghub',
          androidInstallApp: true,
          androidMinimumVersion: '12',
          iOSBundleId: 'com.harsh.housinghub',
          // Adding dynamic parameters that can be used in email templates
          dynamicLinkDomain: 'housinghubapp.page.link',
        );

        // Send verification email with custom settings
        await user.sendEmailVerification(actionCodeSettings);
        print("Customized verification email sent to ${user.email}");
      }
    } catch (e) {
      print("Error sending verification email: $e");
      rethrow;
    }
  }

  // Generate a custom verification link (for future use with custom email services)
  static Future<String> generateCustomVerificationLink(String email) async {
    try {
      // Configure action code settings with improved branding
      ActionCodeSettings actionCodeSettings = ActionCodeSettings(
        url: 'https://housinghub-c2dae.firebaseapp.com/verify?email=$email',
        handleCodeInApp: true,
        androidPackageName: 'com.harsh.housinghub',
        androidInstallApp: true,
        androidMinimumVersion: '12',
        iOSBundleId: 'com.harsh.housinghub',
        dynamicLinkDomain: 'housinghubapp.page.link',
      );

      // Generate verification link - using proper API method
      String link = await _auth
          .sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      )
          .then((_) {
        // This doesn't actually return the link, but we can construct one for demonstration
        // In a real implementation, you'd use Firebase Admin SDK or Cloud Functions
        return 'https://housinghub-c2dae.firebaseapp.com/verify?email=$email&customParam=true';
      });

      return link;
    } catch (e) {
      print("Error generating verification link: $e");
      rethrow;
    }
  }

  // Check if current user's email is verified
  static bool isEmailVerified() {
    User? user = _auth.currentUser;
    return user != null && user.emailVerified;
  }

  // Reload user to check for email verification status update
  static Future<void> reloadUser() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      print("Error reloading user: $e");
      rethrow;
    }
  }

  // Create a new owner in Firestore if not exists
  static Future<void> createOwnerIfNotExists(
      String mobileNumber,
      String fullName,
      String email,
      String propertyType,
      String city,
      String state) async {
    try {
      print("API: Creating owner in Firestore with email: $email");

      // Get user's UID from current auth state
      String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      print("API: Current owner UID: ${uid.isEmpty ? 'empty' : uid}");

      // Create a reference to the user document in 'owners' collection using email as document ID
      final docRef = _firestore.collection('Owners').doc(email);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        print("API: Owner document already exists, updating instead");
      }

      // Create or update document with user data
      await docRef.set({
        'mobileNumber': mobileNumber,
        'fullName': fullName,
        'email': email,
        'propertyType': propertyType,
        'city': city,
        'state': state,
        'userType': 'owner', // Adding user type for future reference
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
        // Do not store password in Firestore
      }, SetOptions(merge: true)); // Use merge to update existing documents

      print("API: Owner document created/updated successfully");
    } catch (e) {
      print("API Error creating owner: $e");
      print("API Error stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Get owner details by email
  static Future<Map<String, dynamic>?> getOwnerDetailsByEmail(
      String email) async {
    try {
      final userDoc = await _firestore.collection('Owners').doc(email).get();
      if (userDoc.exists) {
        return userDoc.data();
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting owner details: $e");
      return null;
    }
  }
}
