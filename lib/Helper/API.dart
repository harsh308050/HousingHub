import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

// Property model class
class Property {
  final String id;
  final String ownerId;
  final String? ownerEmail;
  final String title;
  final String description;
  final String price;
  final String location;
  final String city;
  final String? state;
  final String? pincode;
  final List<String> images;
  final String? video; // optional video URL
  final double? rating;
  final bool available;
  final String propertyType;
  final String roomType;
  final int? squareFootage;
  final int? bedrooms;
  final int? bathrooms;
  final bool? femaleAllowed;
  final bool? maleAllowed;
  final List<String> amenities;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  Property({
    required this.id,
    required this.ownerId,
    this.ownerEmail,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.city,
    this.state,
    this.pincode,
    required this.images,
    this.video,
    this.rating,
    required this.available,
    required this.propertyType,
    required this.roomType,
    this.squareFootage,
    this.bedrooms,
    this.bathrooms,
    this.femaleAllowed,
    this.maleAllowed,
    required this.amenities,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  // Get primary image URL (first in list or default)
  String get imageUrl => images.isNotEmpty
      ? images.first
      : 'https://via.placeholder.com/300x200?text=Property';

  // Create Property object from Firestore document
  factory Property.fromFirestore(DocumentSnapshot doc, String ownerId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Extract images list
    List<String> imagesList = [];
    if (data['images'] != null) {
      try {
        if (data['images'] is List) {
          imagesList = List<String>.from(data['images']);
        } else if (data['images'] is Map) {
          // Handle case where images are stored as a map with numeric keys
          Map<String, dynamic> imagesMap =
              Map<String, dynamic>.from(data['images']);
          imagesList =
              imagesMap.values.map((value) => value.toString()).toList();
        }
      } catch (e) {
        print('Error parsing images: $e');
      }
    }

    // Extract amenities list
    List<String> amenitiesList = [];
    if (data['amenities'] != null) {
      try {
        if (data['amenities'] is List) {
          amenitiesList = List<String>.from(data['amenities']);
        } else if (data['amenities'] is Map) {
          // Handle case where amenities are stored as a map with numeric keys
          Map<String, dynamic> amenitiesMap =
              Map<String, dynamic>.from(data['amenities']);
          amenitiesList =
              amenitiesMap.values.map((value) => value.toString()).toList();
        }
      } catch (e) {
        print('Error parsing amenities: $e');
      }
    }

    // Parse createdAt timestamp
    DateTime? createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }
    }

    // Format price with currency symbol if it's a number
    String formattedPrice = '';
    if (data['price'] != null) {
      if (data['price'] is num) {
        formattedPrice = '₹${data['price']}';
      } else {
        formattedPrice = data['price'].toString();
      }
    } else {
      formattedPrice = 'Price not specified';
    }

    return Property(
      id: doc.id,
      ownerId: ownerId,
      ownerEmail: data['ownerEmail'] as String?,
      title: data['title'] ?? 'Property',
      description: data['description'] ?? 'No description available',
      price: formattedPrice,
      location: data['address'] ?? 'Location not specified',
      city: data['city'] ?? '',
      state: data['state'] as String?,
      pincode: data['pincode'] as String?,
      images: imagesList,
      video: (data['video'] ?? data['videoUrl'])?.toString(),
      rating:
          data['rating'] != null ? (data['rating'] as num).toDouble() : null,
      available: data['isAvailable'] ?? true,
      propertyType: data['propertyType']?.toString() ?? 'Not specified',
      roomType: data['roomType']?.toString() ?? 'Not specified',
      squareFootage: data['squareFootage'] is num
          ? (data['squareFootage'] as num).toInt()
          : null,
      bedrooms:
          data['bedrooms'] is num ? (data['bedrooms'] as num).toInt() : null,
      bathrooms:
          data['bathrooms'] is num ? (data['bathrooms'] as num).toInt() : null,
      femaleAllowed: data['femaleAllowed'] as bool?,
      maleAllowed: data['maleAllowed'] as bool?,
      amenities: amenitiesList,
      latitude:
          data['latitude'] is num ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : null,
      createdAt: createdAt,
    );
  }

  // Convert to Map for passing to property detail page
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'address': location, // Include address for backward compatibility
      'city': city,
      'state': state,
      'pincode': pincode,
      'images': images,
      'imageUrl': imageUrl, // Include primary image for backward compatibility
      'video': video,
      'videoUrl': video, // backward compatibility key
      'rating': rating,
      'available': available,
      'propertyType': propertyType,
      'roomType': roomType,
      'squareFootage': squareFootage,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'femaleAllowed': femaleAllowed,
      'maleAllowed': maleAllowed,
      'amenities': amenities,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt?.toIso8601String(), // Convert DateTime to string
    };
  }
}

class Api {
  // Fetch all properties (available and unavailable) for the current owner
  static Future<List<Map<String, dynamic>>> getAllOwnerProperties(
      String email) async {
    try {
      final availableSnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Available')
          .orderBy('createdAt', descending: true)
          .get();

      final unavailableSnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Unavailable')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> properties = [];

      for (var doc in availableSnapshot.docs) {
        final data = doc.data();
        properties.add({
          ...data,
          'isAvailable': true,
        });
      }
      for (var doc in unavailableSnapshot.docs) {
        final data = doc.data();
        properties.add({
          ...data,
          'isAvailable': false,
        });
      }

      // Optionally sort by createdAt again if needed
      properties.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? a['createdAt'].millisecondsSinceEpoch
            : 0;
        final bTime = b['createdAt'] is Timestamp
            ? b['createdAt'].millisecondsSinceEpoch
            : 0;
        return bTime.compareTo(aTime);
      });

      return properties;
    } catch (e) {
      print('Error fetching all owner properties: $e');
      throw Exception('Failed to fetch all properties: $e');
    }
  }

  // Fetch all properties across all owners using collectionGroup queries
  static Future<List<Map<String, dynamic>>> getAllProperties({
    bool includeUnavailable = true,
  }) async {
    try {
      final List<Map<String, dynamic>> properties = [];
      final ownersSnap = await _firestore.collection('Properties').get();
      for (final owner in ownersSnap.docs) {
        // Available
        final availSnap = await owner.reference.collection('Available').get();
        for (final doc in availSnap.docs) {
          final data = doc.data();
          properties.add({
            ...data,
            'id': data['id'] ?? doc.id,
            'ownerEmail': owner.id,
            'isAvailable': true,
          });
        }
        if (includeUnavailable) {
          final unavailSnap =
              await owner.reference.collection('Unavailable').get();
          for (final doc in unavailSnap.docs) {
            final data = doc.data();
            properties.add({
              ...data,
              'id': data['id'] ?? doc.id,
              'ownerEmail': owner.id,
              'isAvailable': false,
            });
          }
        }
      }
      // Client-side sort by createdAt desc
      properties.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        final bTime = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return bTime.compareTo(aTime);
      });
      print('Fetched properties total: ${properties.length}');
      return properties;
    } catch (e) {
      print('Error fetching all properties (iteration): $e');
      return [];
    }
  }

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

  // Store/update FCM device token for a user (used by server to send pushes)
  // Notifications removed: saveFcmToken no longer needed.

  // Create a new owner in Firestore if not exists
  static Future<void> createOwnerIfNotExists(String mobileNumber,
      String fullName, String email, String city, String state) async {
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

  // Update owner profile
  static Future<void> updateOwnerProfile(
      String email, Map<String, dynamic> updatedData) async {
    try {
      print("API: Updating owner profile for: $email");

      // Check if email is provided
      if (email.isEmpty) {
        throw Exception('Email is required to update profile');
      }

      // Reference to the owner document
      final docRef = _firestore.collection('Owners').doc(email);

      // Check if document exists
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw Exception('Owner profile not found');
      }

      // Update the document with new data
      await docRef.update(updatedData);

      print("API: Owner profile updated successfully");
    } catch (e) {
      print("API Error updating owner profile: $e");
      print("API Error stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Check if user is owner or tenant
  static Future<String> getUserType(String email) async {
    if (email.isEmpty) {
      return 'unknown';
    }

    try {
      // First check if user exists in Owners collection
      final ownerDoc = await _firestore.collection('Owners').doc(email).get();
      if (ownerDoc.exists) {
        return 'owner';
      }

      // Then check if user exists in Tenants collection
      final tenantDoc = await _firestore.collection('Tenants').doc(email).get();
      if (tenantDoc.exists) {
        return 'tenant';
      }

      // If user is not found in collections but is authenticated,
      // check providers to make a best guess
      User? currentUser = getCurrentUser();
      if (currentUser != null && currentUser.email == email) {
        // If user is a Google user, query both collections by UID as well
        if (currentUser.providerData
            .any((provider) => provider.providerId == 'google.com')) {
          // Check owners by UID
          final ownerQuery = await _firestore
              .collection('Owners')
              .where('uid', isEqualTo: currentUser.uid)
              .limit(1)
              .get();

          if (ownerQuery.docs.isNotEmpty) {
            return 'owner';
          }

          // Check tenants by UID
          final tenantQuery = await _firestore
              .collection('Tenants')
              .where('uid', isEqualTo: currentUser.uid)
              .limit(1)
              .get();

          if (tenantQuery.docs.isNotEmpty) {
            return 'tenant';
          }
        }
      }

      // Default if user not found in either collection
      return 'unknown';
    } catch (e) {
      print("Error checking user type: $e");
      return 'unknown';
    }
  }

  // PROPERTY MANAGEMENT FUNCTIONS

  // Upload an image to Cloudinary and return the URL
  static Future<String> uploadImageToCloudinary(
      File imageFile, String folder) async {
    try {
      print('Uploading image to Cloudinary: ${imageFile.path}');

      // Import Cloudinary
      final cloudinary =
          CloudinaryPublic('debf09qz0', 'HousingHub', cache: false);

      // Check if file exists and is readable
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist at path: ${imageFile.path}');
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      print('Image upload successful, URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading image to Cloudinary: $e');

      // More detailed error info
      if (e.toString().contains('400')) {
        print(
            'HTTP 400 error: This usually indicates an issue with your upload preset or configuration');
        print(
            'Verify that your upload preset "HousingHub" is unsigned and correctly configured');
      } else if (e.toString().contains('401')) {
        print(
            'HTTP 401 error: Authentication issue. Check your cloud name and upload preset');
      } else if (e.toString().contains('timeout')) {
        print(
            'Timeout error: Check your internet connection or try with a smaller file');
      }

      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload a video to Cloudinary and return the URL
  static Future<String> uploadVideoToCloudinary(
      File videoFile, String folder) async {
    try {
      print('Uploading video to Cloudinary: ${videoFile.path}');

      // Import Cloudinary
      final cloudinary =
          CloudinaryPublic('debf09qz0', 'HousingHub', cache: false);

      // Check if file exists and is readable
      if (!videoFile.existsSync()) {
        throw Exception('Video file does not exist at path: ${videoFile.path}');
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video,
        ),
      );

      print('Video upload successful, URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading video to Cloudinary: $e');

      // More detailed error info
      if (e.toString().contains('400')) {
        print(
            'HTTP 400 error: This usually indicates an issue with your upload preset or configuration');
        print(
            'Verify that your upload preset "HousingHub" is unsigned and correctly configured');
      } else if (e.toString().contains('401')) {
        print(
            'HTTP 401 error: Authentication issue. Check your cloud name and upload preset');
      } else if (e.toString().contains('timeout')) {
        print(
            'Timeout error: Check your internet connection or try with a smaller file');
      }

      throw Exception('Failed to upload video: $e');
    }
  }

  // Add a new property to Firestore
  static Future<String> addProperty(
      Map<String, dynamic> propertyData, List<File> images, File? video) async {
    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('You must be logged in to add a property');
      }

      // Generate a unique property ID
      final String propertyId = Uuid().v4();
      print('Generated property ID: $propertyId');

      // Upload images to Cloudinary
      List<String> imageUrls = [];
      for (int i = 0; i < images.length; i++) {
        print('Uploading image ${i + 1} of ${images.length}');
        String url =
            await uploadImageToCloudinary(images[i], 'property_images');
        imageUrls.add(url);
        print('Image ${i + 1} uploaded: $url');
      }

      // Upload video to Cloudinary if it exists
      String? videoUrl;
      if (video != null) {
        videoUrl = await uploadVideoToCloudinary(video, 'property_videos');
        print('Video uploaded: $videoUrl');
      }

      // Update property data with media URLs and metadata
      final Map<String, dynamic> finalPropertyData = {
        ...propertyData,
        'id': propertyId,
        'images': imageUrls,
        'video': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isAvailable': true,
        'ownerId': user.uid,
        'ownerEmail': user.email,
      };

      // Create a transaction to update both the property and owner's property count
      await _firestore.runTransaction((transaction) async {
        // Get owner document reference
        final ownerDocRef = _firestore.collection('Properties').doc(user.email);

        // Get the current owner document
        DocumentSnapshot ownerSnapshot = await transaction.get(ownerDocRef);

        // Create or update the property counter fields
        if (ownerSnapshot.exists) {
          // Owner document exists, get current counts
          Map<String, dynamic> ownerData =
              ownerSnapshot.data() as Map<String, dynamic>;
          int availableCount = (ownerData['availableProperties'] ?? 0) + 1;
          int totalCount = (ownerData['totalProperties'] ?? 0) + 1;

          // Update owner document with new counts
          transaction.update(ownerDocRef, {
            'availableProperties': availableCount,
            'totalProperties': totalCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Owner document doesn't exist, create it with initial counts
          transaction.set(ownerDocRef, {
            'availableProperties': 1,
            'totalProperties': 1,
            'unavailableProperties': 0,
            'ownerEmail': user.email,
            'ownerId': user.uid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Save the property in the Available subcollection
        final propertyRef = ownerDocRef.collection('Available').doc(propertyId);
        transaction.set(propertyRef, finalPropertyData);
      });

      print('Property added successfully with ID: $propertyId');
      return propertyId;
    } catch (e) {
      print('Error adding property: $e');
      throw Exception('Failed to add property: $e');
    }
  }

  // Update an existing property
  static Future<void> updateProperty(
      String propertyId,
      Map<String, dynamic> propertyData,
      List<File>? newImages,
      File? newVideo) async {
    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('You must be logged in to update a property');
      }

      // Check if property exists and belongs to user
      final docRef = _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Available')
          .doc(propertyId);

      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw Exception(
            'Property not found or you do not have permission to edit it');
      }

      // Get existing document data to preserve existing images if needed
      final existingData = docSnap.data() as Map<String, dynamic>;
      final bool keepExistingImages =
          propertyData['keepExistingImages'] == true;
      List<dynamic> existingImages = [];

      // If we're keeping existing images, retrieve them from existing data
      if (keepExistingImages && existingData.containsKey('images')) {
        existingImages = existingData['images'] as List<dynamic>;
      }

      // Remove the flag as we don't need to store it in Firestore
      propertyData.remove('keepExistingImages');

      // Upload new images if provided
      List<String> newImageUrls = [];
      if (newImages != null && newImages.isNotEmpty) {
        for (int i = 0; i < newImages.length; i++) {
          String url =
              await uploadImageToCloudinary(newImages[i], 'property_images');
          newImageUrls.add(url);
        }

        // Merge existing images with new ones if needed
        if (keepExistingImages &&
            propertyData.containsKey('images') &&
            propertyData['images'] is List) {
          List<dynamic> currentImages = propertyData['images'] as List<dynamic>;
          propertyData['images'] = [...currentImages, ...newImageUrls];
        } else if (keepExistingImages && existingImages.isNotEmpty) {
          // If we're keeping existing images but they weren't included in propertyData
          propertyData['images'] = [...existingImages, ...newImageUrls];
        } else {
          // Replace with only new images
          propertyData['images'] = newImageUrls;
        }
      }

      // Upload new video if provided
      if (newVideo != null) {
        String videoUrl =
            await uploadVideoToCloudinary(newVideo, 'property_videos');
        propertyData['video'] = videoUrl;
      }

      // Update property with new data
      final Map<String, dynamic> finalPropertyData = {
        ...propertyData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(finalPropertyData);
      print('Property updated successfully with ID: $propertyId');
    } catch (e) {
      print('Error updating property: $e');
      throw Exception('Failed to update property: $e');
    }
  }

  // Delete a property
  static Future<void> deleteProperty(String propertyId) async {
    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('You must be logged in to delete a property');
      }

      // Create a transaction to handle the deletion and counter updates
      await _firestore.runTransaction((transaction) async {
        // Get owner document reference
        final ownerDocRef = _firestore.collection('Properties').doc(user.email);
        final ownerSnapshot = await transaction.get(ownerDocRef);

        if (!ownerSnapshot.exists) {
          throw Exception('Owner document not found');
        }

        // Check if property exists in Available collection
        final availableDocRef =
            ownerDocRef.collection('Available').doc(propertyId);
        final availableDocSnap = await transaction.get(availableDocRef);

        // Check if property exists in Unavailable collection
        final unavailableDocRef =
            ownerDocRef.collection('Unavailable').doc(propertyId);
        final unavailableDocSnap = await transaction.get(unavailableDocRef);

        // Update counters based on where the property was found
        Map<String, dynamic> ownerData =
            ownerSnapshot.data() as Map<String, dynamic>;

        if (availableDocSnap.exists) {
          // Decrement available properties count
          int availableCount = (ownerData['availableProperties'] ?? 1) - 1;
          int totalCount = (ownerData['totalProperties'] ?? 1) - 1;

          transaction.update(ownerDocRef, {
            'availableProperties': availableCount >= 0 ? availableCount : 0,
            'totalProperties': totalCount >= 0 ? totalCount : 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Delete the property
          transaction.delete(availableDocRef);
          print(
              'Property deleted from Available collection with ID: $propertyId');
        } else if (unavailableDocSnap.exists) {
          // Decrement unavailable properties count
          int unavailableCount = (ownerData['unavailableProperties'] ?? 1) - 1;
          int totalCount = (ownerData['totalProperties'] ?? 1) - 1;

          transaction.update(ownerDocRef, {
            'unavailableProperties':
                unavailableCount >= 0 ? unavailableCount : 0,
            'totalProperties': totalCount >= 0 ? totalCount : 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Delete the property
          transaction.delete(unavailableDocRef);
          print(
              'Property deleted from Unavailable collection with ID: $propertyId');
        } else {
          print('Property not found in either collection: $propertyId');
          throw Exception('Property not found in either collection');
        }
      });
    } catch (e) {
      print('Error deleting property: $e');
      throw Exception('Failed to delete property: $e');
    }
  }

  // Mark property as unavailable (e.g., rented/sold) and optionally update its details
  static Future<void> markPropertyAsUnavailable(String propertyId,
      [Map<String, dynamic>? updatedData,
      List<File>? newImages,
      File? newVideo]) async {
    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('You must be logged in to update property status');
      }

      // Get owner document reference
      final ownerDocRef = _firestore.collection('Properties').doc(user.email);

      // Get the property document
      final propertyRef = ownerDocRef.collection('Available').doc(propertyId);

      final propertySnap = await propertyRef.get();
      if (!propertySnap.exists) {
        throw Exception('Property not found');
      }

      // Get property data
      Map<String, dynamic> propertyData =
          propertySnap.data() as Map<String, dynamic>;

      // Process images and videos if needed
      // Check if we should keep existing images
      bool keepExistingImages =
          updatedData != null && updatedData['keepExistingImages'] == true;

      // Get existing images
      List<dynamic> existingImages = [];
      if (propertyData.containsKey('images')) {
        existingImages = propertyData['images'] as List<dynamic>;
      }

      // Remove the flag as we don't need to store it in Firestore
      if (updatedData != null) {
        updatedData.remove('keepExistingImages');
      }

      // Upload new images if provided
      List<String> newImageUrls = [];
      if (newImages != null && newImages.isNotEmpty) {
        for (var image in newImages) {
          final url = await uploadImageToCloudinary(image, 'properties');
          newImageUrls.add(url);
        }
      }

      // Handle images in the updated data
      if (updatedData != null) {
        List<dynamic> imagesToUse = [];

        // If keepExistingImages flag is true, start with existing images
        if (keepExistingImages) {
          // If updated data has its own images list, use that as the base
          if (updatedData.containsKey('images') &&
              updatedData['images'] is List) {
            imagesToUse = List<dynamic>.from(updatedData['images']);
          }
          // Otherwise use existing images from the document
          else if (existingImages.isNotEmpty) {
            imagesToUse = List<dynamic>.from(existingImages);
          }
        }
        // If not keeping existing images but updated data has images, use those
        else if (updatedData.containsKey('images') &&
            updatedData['images'] is List) {
          imagesToUse = List<dynamic>.from(updatedData['images']);
        }

        // Add any new image URLs we uploaded
        if (newImageUrls.isNotEmpty) {
          imagesToUse.addAll(newImageUrls);
        }

        // Set the final image list in the updated data
        if (imagesToUse.isNotEmpty) {
          updatedData['images'] = imagesToUse;
        }
      }

      // Upload new video if provided
      if (newVideo != null) {
        final videoUrl = await uploadVideoToCloudinary(newVideo, 'properties');
        if (updatedData != null) {
          updatedData['videoUrl'] = videoUrl;
        }
      }

      // Apply any updates to the property data
      if (updatedData != null) {
        propertyData = {...propertyData, ...updatedData};
      }

      // Create final property data with unavailable status
      final Map<String, dynamic> finalPropertyData = {
        ...propertyData,
        'isAvailable': false,
        'statusChangedAt': FieldValue.serverTimestamp(),
      };

      // Update property status and counters in a transaction
      await _firestore.runTransaction((transaction) async {
        // Get the current owner document
        DocumentSnapshot ownerSnapshot = await transaction.get(ownerDocRef);

        if (ownerSnapshot.exists) {
          // Owner document exists, get current counts
          Map<String, dynamic> ownerData =
              ownerSnapshot.data() as Map<String, dynamic>;
          int availableCount = (ownerData['availableProperties'] ?? 1) - 1;
          int unavailableCount = (ownerData['unavailableProperties'] ?? 0) + 1;

          // Update owner document with new counts
          transaction.update(ownerDocRef, {
            'availableProperties': availableCount >= 0 ? availableCount : 0,
            'unavailableProperties': unavailableCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Owner document doesn't exist, create it with initial counts
          transaction.set(ownerDocRef, {
            'availableProperties': 0,
            'unavailableProperties': 1,
            'totalProperties': 1,
            'ownerEmail': user.email,
            'ownerId': user.uid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Add to Unavailable collection
        transaction.set(ownerDocRef.collection('Unavailable').doc(propertyId),
            finalPropertyData);

        // Delete from Available collection
        transaction.delete(propertyRef);
      });

      print('Property marked as unavailable with ID: $propertyId');
    } catch (e) {
      print('Error updating property status: $e');
      throw Exception('Failed to update property status: $e');
    }
  }

  // Mark property as available (e.g., back on market) and optionally update its details
  static Future<void> markPropertyAsAvailable(String propertyId,
      [Map<String, dynamic>? updatedData,
      List<File>? newImages,
      File? newVideo]) async {
    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('You must be logged in to update property status');
      }

      // Get owner document reference
      final ownerDocRef = _firestore.collection('Properties').doc(user.email);

      // Get the property document from Unavailable collection
      final propertyRef = ownerDocRef.collection('Unavailable').doc(propertyId);

      final propertySnap = await propertyRef.get();
      if (!propertySnap.exists) {
        throw Exception('Property not found');
      }

      // Get property data
      Map<String, dynamic> propertyData =
          propertySnap.data() as Map<String, dynamic>;

      // Process images and videos if needed
      // Check if we should keep existing images
      bool keepExistingImages =
          updatedData != null && updatedData['keepExistingImages'] == true;

      // Get existing images
      List<dynamic> existingImages = [];
      if (propertyData.containsKey('images')) {
        existingImages = propertyData['images'] as List<dynamic>;
      }

      // Remove the flag as we don't need to store it in Firestore
      if (updatedData != null) {
        updatedData.remove('keepExistingImages');
      }

      // Upload new images if provided
      List<String> newImageUrls = [];
      if (newImages != null && newImages.isNotEmpty) {
        for (var image in newImages) {
          final url = await uploadImageToCloudinary(image, 'properties');
          newImageUrls.add(url);
        }
      }

      // Handle images in the updated data
      if (updatedData != null) {
        List<dynamic> imagesToUse = [];

        // If keepExistingImages flag is true, start with existing images
        if (keepExistingImages) {
          // If updated data has its own images list, use that as the base
          if (updatedData.containsKey('images') &&
              updatedData['images'] is List) {
            imagesToUse = List<dynamic>.from(updatedData['images']);
          }
          // Otherwise use existing images from the document
          else if (existingImages.isNotEmpty) {
            imagesToUse = List<dynamic>.from(existingImages);
          }
        }
        // If not keeping existing images but updated data has images, use those
        else if (updatedData.containsKey('images') &&
            updatedData['images'] is List) {
          imagesToUse = List<dynamic>.from(updatedData['images']);
        }

        // Add any new image URLs we uploaded
        if (newImageUrls.isNotEmpty) {
          imagesToUse.addAll(newImageUrls);
        }

        // Set the final image list in the updated data
        if (imagesToUse.isNotEmpty) {
          updatedData['images'] = imagesToUse;
        }
      }

      // Upload new video if provided
      if (newVideo != null) {
        final videoUrl = await uploadVideoToCloudinary(newVideo, 'properties');
        if (updatedData != null) {
          updatedData['videoUrl'] = videoUrl;
        }
      }

      // Apply any updates to the property data
      if (updatedData != null) {
        propertyData = {...propertyData, ...updatedData};
      }

      // Create final property data with available status
      final Map<String, dynamic> finalPropertyData = {
        ...propertyData,
        'isAvailable': true,
        'statusChangedAt': FieldValue.serverTimestamp(),
      };

      // Update property status and counters in a transaction
      await _firestore.runTransaction((transaction) async {
        // Get the current owner document
        DocumentSnapshot ownerSnapshot = await transaction.get(ownerDocRef);

        if (ownerSnapshot.exists) {
          // Owner document exists, get current counts
          Map<String, dynamic> ownerData =
              ownerSnapshot.data() as Map<String, dynamic>;
          int availableCount = (ownerData['availableProperties'] ?? 0) + 1;
          int unavailableCount = (ownerData['unavailableProperties'] ?? 1) - 1;

          // Update owner document with new counts
          transaction.update(ownerDocRef, {
            'availableProperties': availableCount,
            'unavailableProperties':
                unavailableCount >= 0 ? unavailableCount : 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Owner document doesn't exist, create it with initial counts
          transaction.set(ownerDocRef, {
            'availableProperties': 1,
            'unavailableProperties': 0,
            'totalProperties': 1,
            'ownerEmail': user.email,
            'ownerId': user.uid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Add to Available collection
        transaction.set(ownerDocRef.collection('Available').doc(propertyId),
            finalPropertyData);

        // Delete from Unavailable collection
        transaction.delete(propertyRef);
      });

      print('Property marked as available with ID: $propertyId');
    } catch (e) {
      print('Error updating property status: $e');
      throw Exception('Failed to update property status: $e');
    }
  }

  // Get property count summary for an owner
  static Future<Map<String, dynamic>> getOwnerPropertyCounts(
      String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required to get property counts');
      }

      // Get the owner document
      final ownerDoc =
          await _firestore.collection('Properties').doc(email).get();

      if (!ownerDoc.exists) {
        // If owner document doesn't exist, return zeros
        return {
          'availableProperties': 0,
          'unavailableProperties': 0,
          'totalProperties': 0,
        };
      }

      // Return the property counts
      Map<String, dynamic> ownerData = ownerDoc.data() as Map<String, dynamic>;
      return {
        'availableProperties': ownerData['availableProperties'] ?? 0,
        'unavailableProperties': ownerData['unavailableProperties'] ?? 0,
        'totalProperties': ownerData['totalProperties'] ?? 0,
        'lastUpdated': ownerData['lastUpdated'],
      };
    } catch (e) {
      print('Error fetching owner property counts: $e');
      throw Exception('Failed to fetch property counts: $e');
    }
  }

  // Get all available properties for a specific owner
  static Future<List<Map<String, dynamic>>> getOwnerProperties(
      String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Available')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> properties = [];
      for (var doc in querySnapshot.docs) {
        properties.add({
          ...doc.data(),
          'id': doc.id,
        });
      }

      return properties;
    } catch (e) {
      print('Error fetching owner properties: $e');
      throw Exception('Failed to fetch properties: $e');
    }
  }

  // Get all unavailable (rented/sold) properties for a specific owner
  static Future<List<Map<String, dynamic>>> getOwnerUnavailableProperties(
      String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Unavailable')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> properties = [];
      for (var doc in querySnapshot.docs) {
        properties.add({
          ...doc.data(),
          'id': doc.id,
        });
      }

      return properties;
    } catch (e) {
      print('Error fetching owner unavailable properties: $e');
      throw Exception('Failed to fetch unavailable properties: $e');
    }
  }

  // Synchronize property counts for an owner (useful for fixing count discrepancies)
  static Future<void> synchronizeOwnerPropertyCounts(String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required to synchronize property counts');
      }

      // Get counts of actual properties in collections
      final availableSnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Available')
          .get();

      final unavailableSnapshot = await _firestore
          .collection('Properties')
          .doc(email)
          .collection('Unavailable')
          .get();

      // Calculate actual counts
      int availableCount = availableSnapshot.docs.length;
      int unavailableCount = unavailableSnapshot.docs.length;
      int totalCount = availableCount + unavailableCount;

      // Update the owner document with correct counts
      await _firestore.collection('Properties').doc(email).set({
        'availableProperties': availableCount,
        'unavailableProperties': unavailableCount,
        'totalProperties': totalCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'ownerEmail': email,
      }, SetOptions(merge: true));

      print('Property counts synchronized successfully for owner: $email');
      print(
          'Available: $availableCount, Unavailable: $unavailableCount, Total: $totalCount');
    } catch (e) {
      print('Error synchronizing property counts: $e');
      throw Exception('Failed to synchronize property counts: $e');
    }
  }

  // Get properties near a specific city
  static Future<List<Property>> getPropertiesByCity(String city) async {
    if (city == 'Loading...' ||
        city == 'Select City' ||
        city == 'Unknown City') {
      return [];
    }

    try {
      final firestore = FirebaseFirestore.instance;
      List<Property> properties = [];

      // Get all owners (all documents in Properties collection)
      QuerySnapshot ownersSnapshot =
          await firestore.collection('Properties').get();

      for (var ownerDoc in ownersSnapshot.docs) {
        String ownerEmail = ownerDoc.id;

        try {
          // Get available properties for this owner
          QuerySnapshot propertiesSnapshot = await firestore
              .collection('Properties')
              .doc(ownerEmail)
              .collection('Available')
              .get();

          // Process properties
          for (var propertyDoc in propertiesSnapshot.docs) {
            try {
              Map<String, dynamic> data =
                  propertyDoc.data() as Map<String, dynamic>;

              // Check if isAvailable is true (or not specified)
              bool isAvailable = data['isAvailable'] ?? true;
              if (!isAvailable) continue;

              // Only include properties in the current city (case insensitive comparison)
              String propertyCity =
                  data['city']?.toString().trim().toLowerCase() ?? '';
              String currentCity = city.trim().toLowerCase();

              if (propertyCity.isNotEmpty && propertyCity == currentCity) {
                // Create property object with owner ID
                Property property =
                    Property.fromFirestore(propertyDoc, ownerEmail);
                properties.add(property);
              }
            } catch (docError) {
              print('Error processing property document: $docError');
              continue;
            }
          }
        } catch (collectionError) {
          print(
              'Error accessing Available collection for $ownerEmail: $collectionError');
          continue;
        }
      }

      return properties;
    } catch (e) {
      print('Error fetching properties by city: $e');
      throw Exception('Failed to load properties: $e');
    }
  }

  // Get city and state data for India from API
  static Future<List<Map<String, String>>> getIndianStates() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
        headers: {
          'X-CSCAPI-KEY':
              'YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ=='
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, String>> states = [];

        for (var state in data) {
          states.add({
            'name': state['name'].toString(),
            'code': state['iso2'].toString(),
          });
        }

        // Sort states alphabetically
        states.sort((a, b) => a['name']!.compareTo(b['name']!));

        return states;
      } else {
        throw Exception('Failed to load states');
      }
    } catch (e) {
      print('Error fetching states: $e');
      throw Exception('Failed to load states: $e');
    }
  }

  // Get cities for a specific state in India
  static Future<List<String>> getCitiesForState(String stateCode) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.countrystatecity.in/v1/countries/IN/states/$stateCode/cities'),
        headers: {
          'X-CSCAPI-KEY':
              'YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ=='
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<String> cities =
            data.map((city) => city['name'].toString()).toList();

        // Sort cities alphabetically
        cities.sort();

        return cities;
      } else {
        throw Exception('Failed to load cities');
      }
    } catch (e) {
      print('Error fetching cities: $e');
      throw Exception('Failed to load cities: $e');
    }
  }

  // Get city and state from location coordinates
  static Future<Map<String, String?>> getCityFromLocation(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String? detectedState = place.administrativeArea;
        String? detectedCity = place.locality ?? place.subAdministrativeArea;

        return {'city': detectedCity, 'state': detectedState};
      }

      return {'city': 'Unknown City', 'state': null};
    } catch (e) {
      print('Error getting location address: $e');
      return {'city': 'Unknown City', 'state': null};
    }
  }

  // Get all available properties (for searching/browsing)
  static Future<List<Map<String, dynamic>>> getAllAvailableProperties({
    String? city,
    String? propertyType,
    int? minPrice,
    int? maxPrice,
    bool? maleAllowed,
    bool? femaleAllowed,
    String? roomType,
    List<String>? amenities,
    int limit = 20,
  }) async {
    try {
      // Start with base query to get all owner documents
      Query ownersQuery = _firestore.collection('Properties');

      // Get all owner documents
      QuerySnapshot ownersSnapshot = await ownersQuery.get();

      List<Map<String, dynamic>> allProperties = [];

      // For each owner, get their available properties
      for (var ownerDoc in ownersSnapshot.docs) {
        // Set up query for this owner's available properties
        Query propertiesQuery = _firestore
            .collection('Properties')
            .doc(ownerDoc.id)
            .collection('Available');

        // Apply filters if provided
        if (city != null && city.isNotEmpty) {
          propertiesQuery = propertiesQuery.where('city', isEqualTo: city);
        }

        if (propertyType != null && propertyType.isNotEmpty) {
          propertiesQuery =
              propertiesQuery.where('propertyType', isEqualTo: propertyType);
        }

        if (minPrice != null) {
          propertiesQuery =
              propertiesQuery.where('price', isGreaterThanOrEqualTo: minPrice);
        }

        if (maxPrice != null) {
          propertiesQuery =
              propertiesQuery.where('price', isLessThanOrEqualTo: maxPrice);
        }

        if (maleAllowed != null) {
          propertiesQuery =
              propertiesQuery.where('maleAllowed', isEqualTo: maleAllowed);
        }

        if (femaleAllowed != null) {
          propertiesQuery =
              propertiesQuery.where('femaleAllowed', isEqualTo: femaleAllowed);
        }

        if (roomType != null && roomType.isNotEmpty) {
          propertiesQuery =
              propertiesQuery.where('roomType', isEqualTo: roomType);
        }

        // Note: Filtering by amenities requires a different approach due to Firestore limitations
        // with array queries. We'll do this manually after retrieving results.

        // Execute the query
        QuerySnapshot propertiesSnapshot = await propertiesQuery
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();

        // Process the results
        for (var propertyDoc in propertiesSnapshot.docs) {
          Map<String, dynamic> propertyData =
              propertyDoc.data() as Map<String, dynamic>;

          // If amenities filter is applied, check manually
          if (amenities != null && amenities.isNotEmpty) {
            List<dynamic> propertyAmenities = propertyData['amenities'] ?? [];
            bool hasAllAmenities = amenities
                .every((amenity) => propertyAmenities.contains(amenity));

            if (!hasAllAmenities)
              continue; // Skip this property if it doesn't have all requested amenities
          }

          // Add owner email for reference
          propertyData['ownerEmail'] = ownerDoc.id;

          // Add the property to our results
          allProperties.add({
            ...propertyData,
            'id': propertyDoc.id,
          });
        }
      }

      // Sort by createdAt if needed
      allProperties.sort((a, b) {
        Timestamp? aTimestamp = a['createdAt'] as Timestamp?;
        Timestamp? bTimestamp = b['createdAt'] as Timestamp?;

        if (aTimestamp == null || bTimestamp == null) return 0;
        return bTimestamp
            .compareTo(aTimestamp); // Descending order (newest first)
      });

      // Limit final results if there are too many
      if (allProperties.length > limit) {
        allProperties = allProperties.sublist(0, limit);
      }

      return allProperties;
    } catch (e) {
      print('Error fetching available properties: $e');
      throw Exception('Failed to fetch available properties: $e');
    }
  }

  // Get a specific property by ID
  static Future<Map<String, dynamic>?> getPropertyById(
      String ownerEmail, String propertyId,
      {bool checkUnavailable = false}) async {
    try {
      // First check in Available collection
      final availableDoc = await _firestore
          .collection('Properties')
          .doc(ownerEmail)
          .collection('Available')
          .doc(propertyId)
          .get();

      if (availableDoc.exists) {
        return {
          ...availableDoc.data()!,
          'id': availableDoc.id,
        };
      }

      // If not found and we should check Unavailable collection
      if (checkUnavailable) {
        final unavailableDoc = await _firestore
            .collection('Properties')
            .doc(ownerEmail)
            .collection('Unavailable')
            .doc(propertyId)
            .get();

        if (unavailableDoc.exists) {
          return {
            ...unavailableDoc.data()!,
            'id': unavailableDoc.id,
          };
        }
      }

      // Property not found
      return null;
    } catch (e) {
      print('Error fetching property: $e');
      throw Exception('Failed to fetch property: $e');
    }
  }

  // =============================
  // SAVED PROPERTIES (Tenant)
  // Firestore structure:
  // SavedProperties / <tenantEmail> / Properties / <propertyId>
  // =============================

  static CollectionReference _savedRootCollection() =>
      _firestore.collection('SavedProperties');

  // Save a property for tenant (stores full property data + savedAt timestamp)
  static Future<void> savePropertyForTenant(
      {required String tenantEmail,
      required String propertyId,
      required Map<String, dynamic> propertyData}) async {
    if (tenantEmail.isEmpty || propertyId.isEmpty) return;
    try {
      final tenantDoc = _savedRootCollection().doc(tenantEmail);
      final propertyDoc = tenantDoc.collection('Properties').doc(propertyId);

      await _firestore.runTransaction((tx) async {
        final propSnap = await tx.get(propertyDoc);
        final metaSnap = await tx.get(tenantDoc);

        // Create meta doc if missing
        if (!metaSnap.exists) {
          tx.set(tenantDoc, {
            'savedCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Only increment counter if the property is not already saved
        if (!propSnap.exists) {
          final dataToSave = Map<String, dynamic>.from(propertyData);
          // Ensure id present
          dataToSave['id'] = dataToSave['id'] ?? propertyId;
          dataToSave['savedAt'] = FieldValue.serverTimestamp();
          tx.set(propertyDoc, dataToSave, SetOptions(merge: true));
          tx.update(tenantDoc, {
            'savedCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Merge any fresh data without touching counter
          final dataToSave = Map<String, dynamic>.from(propertyData);
          dataToSave['id'] = dataToSave['id'] ?? propertyId;
          tx.set(propertyDoc, dataToSave, SetOptions(merge: true));
        }
      });
    } catch (e) {
      print('Error saving property for tenant: $e');
      rethrow;
    }
  }

  // Remove saved property
  static Future<void> removeSavedProperty(
      {required String tenantEmail, required String propertyId}) async {
    if (tenantEmail.isEmpty || propertyId.isEmpty) return;
    try {
      final tenantDoc = _savedRootCollection().doc(tenantEmail);
      final propertyDoc = tenantDoc.collection('Properties').doc(propertyId);

      await _firestore.runTransaction((tx) async {
        final propSnap = await tx.get(propertyDoc);
        if (!propSnap.exists) return; // nothing to do

        // Delete property doc
        tx.delete(propertyDoc);

        // Decrement counter if meta exists
        final metaSnap = await tx.get(tenantDoc);
        if (metaSnap.exists) {
          final current =
              (metaSnap.data() as Map<String, dynamic>)['savedCount'] ?? 0;
          if (current is int && current > 0) {
            tx.update(tenantDoc, {
              'savedCount': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      print('Error removing saved property: $e');
      rethrow;
    }
  }

  // Check if property is saved
  static Future<bool> isPropertySaved(
      {required String tenantEmail, required String propertyId}) async {
    if (tenantEmail.isEmpty || propertyId.isEmpty) return false;
    try {
      final doc = await _savedRootCollection()
          .doc(tenantEmail)
          .collection('Properties')
          .doc(propertyId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking saved property: $e');
      return false;
    }
  }

  // Stream of saved properties (ordered by savedAt desc)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamSavedProperties(
      String tenantEmail) {
    if (tenantEmail.isEmpty) {
      // Return empty stream
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _savedRootCollection()
        .doc(tenantEmail)
        .collection('Properties')
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  // Stream metadata (includes savedCount)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamSavedMeta(
      String tenantEmail) {
    if (tenantEmail.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return _savedRootCollection()
        .doc(tenantEmail)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        )
        .snapshots();
  }

  // Helper method for recent views collection reference
  static CollectionReference<Map<String, dynamic>>
      _recentViewsRootCollection() {
    return _firestore.collection('Tenants');
  }

  // Add or update recently viewed property
  static Future<void> addRecentlyViewedProperty({
    required String tenantEmail,
    required String propertyId,
    required Map<String, dynamic> propertyData,
  }) async {
    if (tenantEmail.isEmpty || propertyId.isEmpty) return;
    try {
      final tenantDoc = _recentViewsRootCollection().doc(tenantEmail);
      final recentViewsCollection = tenantDoc.collection('RecentViews');
      final propertyDoc = recentViewsCollection.doc(propertyId);

      // Get current count of recent views to manage limit
      final recentViewsQuery = await recentViewsCollection
          .orderBy('viewedAt', descending: true)
          .get();

      await _firestore.runTransaction((tx) async {
        // Update or create the viewed property document
        final dataToSave = Map<String, dynamic>.from(propertyData);
        dataToSave['propertyId'] = propertyId;
        dataToSave['viewedAt'] = FieldValue.serverTimestamp();

        tx.set(propertyDoc, dataToSave, SetOptions(merge: true));

        // If we have more than 10 items, delete the oldest ones
        if (recentViewsQuery.docs.length >= 10) {
          // Skip the current property if it exists in the list
          final docsToDelete = recentViewsQuery.docs
              .where((doc) => doc.id != propertyId)
              .skip(9) // Keep 9 items + the current one = 10 total
              .toList();

          for (final docToDelete in docsToDelete) {
            tx.delete(recentViewsCollection.doc(docToDelete.id));
          }
        }
      });

      developer.log('Added property $propertyId to recently viewed');
    } catch (e) {
      developer.log('Error adding recently viewed property: $e');
      // Don't rethrow as this is a non-critical feature
    }
  }

  // Fetch saved property IDs (one-off)
  static Future<Set<String>> getSavedPropertyIds(String tenantEmail) async {
    if (tenantEmail.isEmpty) return {};
    try {
      final snap = await _savedRootCollection()
          .doc(tenantEmail)
          .collection('Properties')
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      print('Error fetching saved property IDs: $e');
      return {};
    }
  }

  // =============================
  // CHAT: Tenant ↔ Owner (1:1)
  // Collection: Messages/{roomId}/Chats/{chatId}
  // roomId = min(email1,email2)_max(email1,email2)
  // Room doc keeps metadata: participants, lastMessage, lastTimestamp, unreadCounts
  // =============================
  static String _normEmail(String e) => e.trim().toLowerCase();
  static String chatRoomIdFor(String a, String b) {
    final e1 = _normEmail(a);
    final e2 = _normEmail(b);
    return e1.compareTo(e2) <= 0 ? '${e1}_$e2' : '${e2}_$e1';
  }

  static DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _firestore.collection('Messages').doc(roomId);

  static CollectionReference<Map<String, dynamic>> _chatsCol(String roomId) =>
      _roomRef(roomId).collection('Chats');

  static Future<void> _ensureRoom(String a, String b) async {
    final roomId = chatRoomIdFor(a, b);
    final room = _roomRef(roomId);
    final snap = await room.get();
    if (!snap.exists) {
      await room.set({
        'participants': [_normEmail(a), _normEmail(b)],
        'unreadCounts': {
          _normEmail(a): 0,
          _normEmail(b): 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Future<void> sendChatMessage({
    required String senderEmail,
    required String receiverEmail,
    String? text,
    String? attachmentUrl,
  }) async {
    final roomId = chatRoomIdFor(senderEmail, receiverEmail);
    await _ensureRoom(senderEmail, receiverEmail);

    final msgData = <String, dynamic>{
      'senderId': _normEmail(senderEmail),
      'receiverId': _normEmail(receiverEmail),
      'text': (text ?? '').trim(),
      'attachment': attachmentUrl,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((tx) async {
      final room = _roomRef(roomId);

      // READS FIRST: get the current room snapshot before any writes
      final roomSnap = await tx.get(room);
      Map<String, dynamic> unread = {};
      if (roomSnap.exists) {
        final data = roomSnap.data() as Map<String, dynamic>;
        if (data['unreadCounts'] is Map<String, dynamic>) {
          unread = Map<String, dynamic>.from(data['unreadCounts']);
        }
      }
      final recv = _normEmail(receiverEmail);
      unread[recv] = (unread[recv] ?? 0) + 1;

      // WRITES AFTER READS: create the chat message
      final chats = _chatsCol(roomId).doc();
      tx.set(chats, msgData);

      // Update room meta
      tx.set(
        room,
        {
          'lastMessage': (text != null && text.trim().isNotEmpty)
              ? text.trim()
              : (attachmentUrl != null ? 'Attachment' : ''),
          'lastTimestamp': FieldValue.serverTimestamp(),
          'lastSender': _normEmail(senderEmail),
          'unreadCounts': unread,
          'participants': [_normEmail(senderEmail), _normEmail(receiverEmail)],
        },
        SetOptions(merge: true),
      );
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamChatMessages(
      String a, String b) {
    final roomId = chatRoomIdFor(a, b);
    return _chatsCol(roomId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  static Future<void> markChatAsRead({
    required String currentEmail,
    required String otherEmail,
  }) async {
    final me = _normEmail(currentEmail);
    final other = _normEmail(otherEmail);
    final roomId = chatRoomIdFor(me, other);
    final room = _roomRef(roomId);

    // Mark messages as read (batched in chunks)
    const int limit = 300;
    Query<Map<String, dynamic>> q = _chatsCol(roomId)
        .where('receiverId', isEqualTo: me)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .limit(limit);
    final snap = await q.get();
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    batch.set(
        room,
        {
          'unreadCounts': {me: 0},
          'lastReadAt': {_normEmail(me): FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamUserRooms(
      String userEmail) {
    // Avoid requiring a composite index by not ordering at query time.
    // Consumers should sort client-side by 'lastTimestamp' desc.
    return _firestore
        .collection('Messages')
        .where('participants', arrayContains: _normEmail(userEmail))
        .snapshots();
  }

  // Upload any chat attachment to Cloudinary (auto resource type)
  static Future<String> uploadChatAttachment(File file,
      {String folder = 'chat_attachments'}) async {
    try {
      final cloudinary =
          CloudinaryPublic('debf09qz0', 'HousingHub', cache: false);
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('Error uploading chat attachment: $e');
      rethrow;
    }
  }

  // Get recently viewed properties (limited to 5 by default)
  static Future<List<Property>> getRecentlyViewedProperties(String tenantEmail,
      {int limit = 5}) async {
    if (tenantEmail.isEmpty) return [];
    try {
      final snap = await _recentViewsRootCollection()
          .doc(tenantEmail)
          .collection('RecentViews')
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String? ?? '';
        return Property.fromFirestore(doc, ownerId);
      }).toList();
    } catch (e) {
      developer.log('Error fetching recently viewed properties: $e');
      return [];
    }
  }

  // Stream of recently viewed properties
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      streamRecentlyViewedProperties(String tenantEmail, {int limit = 5}) {
    if (tenantEmail.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _recentViewsRootCollection()
        .doc(tenantEmail)
        .collection('RecentViews')
        .orderBy('viewedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
