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
import 'package:rxdart/rxdart.dart' as rx;
import 'package:housinghub/config/ApiKeys.dart';

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
  final int? securityDeposit;
  final String? minimumBookingPeriod;
  // New fields for sell properties extension
  final String listingType; // "rent" or "sale"
  final String? salePrice; // for sale properties
  final String?
      furnishingStatus; // "Furnished", "Semi-Furnished", "Unfurnished"
  final int? propertyAge; // in years
  final String? ownershipType; // "Freehold", "Leasehold", "Co-operative"

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
    this.securityDeposit,
    this.minimumBookingPeriod,
    this.listingType = "rent", // default to rent for backward compatibility
    this.salePrice,
    this.furnishingStatus,
    this.propertyAge,
    this.ownershipType,
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
      securityDeposit: data['securityDeposit'] is num
          ? (data['securityDeposit'] as num).toInt()
          : null,
      minimumBookingPeriod: data['minimumBookingPeriod'] as String?,
      // New sale-related fields with defaults for backward compatibility
      listingType: data['listingType']?.toString() ?? 'rent',
      salePrice: data['salePrice']?.toString(),
      furnishingStatus: data['furnishingStatus']?.toString(),
      propertyAge: data['propertyAge'] is num
          ? (data['propertyAge'] as num).toInt()
          : null,
      ownershipType: data['ownershipType']?.toString(),
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
      'securityDeposit': securityDeposit,
      'minimumBookingPeriod': minimumBookingPeriod,
      // New sale-related fields
      'listingType': listingType,
      'salePrice': salePrice,
      'furnishingStatus': furnishingStatus,
      'propertyAge': propertyAge,
      'ownershipType': ownershipType,
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
        'approvalStatus': 'not-submitted',
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
      final cloudinary = CloudinaryPublic(
        ApiKeys.cloudinaryCloudName,
        ApiKeys.cloudinaryUploadPreset,
        cache: false,
      );

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
      final cloudinary = CloudinaryPublic(
        ApiKeys.cloudinaryCloudName,
        ApiKeys.cloudinaryUploadPreset,
        cache: false,
      );

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
  static Future<List<Property>> getPropertiesByCity(String city,
      {String? listingType}) async {
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
                // Apply listing type filter if specified
                if (listingType != null && listingType != 'all') {
                  String propertyListingType =
                      data['listingType']?.toString() ?? 'rent';
                  if (propertyListingType != listingType) continue;
                }

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
        headers: {'X-CSCAPI-KEY': ApiKeys.cscApiKey},
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
        headers: {'X-CSCAPI-KEY': ApiKeys.cscApiKey},
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
        // Prefer locality (city). Do not default to village/subLocality here.
        // Keep district (subAdministrativeArea) separately for smarter resolution.
        String? detectedCity = place.locality;
        String? detectedDistrict = place.subAdministrativeArea;

        return {
          'city': detectedCity,
          'state': detectedState,
          'district': detectedDistrict,
        };
      }

      return {'city': 'Unknown City', 'state': null, 'district': null};
    } catch (e) {
      print('Error getting location address: $e');
      return {'city': 'Unknown City', 'state': null, 'district': null};
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

        // Execute the query without orderBy to avoid complex indexes
        QuerySnapshot propertiesSnapshot =
            await propertiesQuery.limit(limit).get();

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
        // IMPORTANT: All reads must come before all writes in a transaction
        // Read property document first
        final propSnap = await tx.get(propertyDoc);
        if (!propSnap.exists) return; // nothing to do

        // Read tenant metadata document
        final metaSnap = await tx.get(tenantDoc);

        // Now perform all writes after all reads are complete
        // Delete property doc
        tx.delete(propertyDoc);

        // Decrement counter if meta exists
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
        // Make sure ownerEmail exists for collectionGroup aggregations
        final ownerEmail =
            (propertyData['ownerEmail']?.toString() ?? '').trim().toLowerCase();
        if (ownerEmail.isNotEmpty) {
          dataToSave['ownerEmail'] = ownerEmail;
        }

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
    // Prevent users from messaging themselves
    if (senderEmail.toLowerCase().trim() ==
        receiverEmail.toLowerCase().trim()) {
      throw Exception('You cannot send messages to yourself');
    }

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

    // Create notification for the receiver
    try {
      final senderProfile = await getUserProfileInfo(senderEmail);
      final senderName = senderProfile['displayName'] ?? 'Someone';

      await createChatNotification(
        senderEmail: senderEmail,
        receiverEmail: receiverEmail,
        senderName: senderName,
        messageText: text ?? '',
      );
    } catch (e) {
      print('Error creating notification: $e');
      // Don't let notification errors break message sending
    }
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

    // Simplified query to avoid composite index requirement
    // Remove orderBy and just filter by receiverId and isRead
    const int limit = 300;
    Query<Map<String, dynamic>> q = _chatsCol(roomId)
        .where('receiverId', isEqualTo: me)
        .where('isRead', isEqualTo: false)
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

  // Get stream of unread message count for a user
  static Stream<int> getUnreadMessageCountStream(String userEmail) {
    final normalizedEmail = _normEmail(userEmail);

    return _firestore
        .collection('Messages')
        .where('participants', arrayContains: normalizedEmail)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['unreadCounts'] is Map) {
          final unreadCounts = data['unreadCounts'] as Map;
          final count = unreadCounts[normalizedEmail] ?? 0;
          totalUnread += count as int;
        }
      }
      return totalUnread;
    }).handleError((error) {
      print('Error in unread message count stream: $error');
      return 0;
    });
  }

  // Upload any chat attachment to Cloudinary (auto resource type)
  static Future<String> uploadChatAttachment(File file,
      {String folder = 'chat_attachments'}) async {
    try {
      final cloudinary = CloudinaryPublic(
          ApiKeys.cloudinaryCloudName, ApiKeys.cloudinaryUploadPreset,
          cache: false);
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

  // Get live count of unique views for an owner across all properties.
  // Definition of a unique view: one tenant viewing one property at least once.
  // Implementation detail:
  // - Each tenant has at most one document per property in Tenants/{email}/RecentViews/{propertyId}
  // - We store ownerEmail inside each RecentViews document (via propertyData)
  // - Therefore, the total number of RecentViews docs filtered by ownerEmail equals unique (tenant, property) pairs
  static Stream<int> streamOwnerUniqueViewsCount(String ownerEmail) {
    if (ownerEmail.isEmpty) return Stream.value(0);
    final owner = ownerEmail.trim().toLowerCase();
    try {
      // Primary source: OwnerViews/{owner}/Unique -> one doc per (tenant, property)
      return _firestore
          .collection('OwnerViews')
          .doc(owner)
          .collection('Unique')
          .snapshots()
          .map((snap) => snap.docs.length)
          .handleError((e) {
        developer.log('Error streaming OwnerViews unique count: $e');
        return 0;
      });
    } catch (e) {
      developer.log('OwnerViews stream setup failed: $e');
      return Stream.value(0);
    }
  }

  // Track a unique view for an owner by a tenant for a property.
  // Idempotent: uses docId = propertyId__tenantEmail to ensure one per pair.
  static Future<void> trackUniqueOwnerView({
    required String ownerEmail,
    required String tenantEmail,
    required String propertyId,
  }) async {
    if (ownerEmail.isEmpty || tenantEmail.isEmpty || propertyId.isEmpty) return;
    try {
      final owner = ownerEmail.trim().toLowerCase();
      final tenant = tenantEmail.trim().toLowerCase();
      final docId = '${propertyId}__${tenant}';
      final ref = _firestore
          .collection('OwnerViews')
          .doc(owner)
          .collection('Unique')
          .doc(docId);

      await ref.set({
        'ownerEmail': owner,
        'tenantEmail': tenant,
        'propertyId': propertyId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error tracking unique owner view: $e');
      // non-critical, swallow
    }
  }

  // Get user profile information (name and profile picture) by email
  // This function checks both Tenant and Owner collections
  static Future<Map<String, String>> getUserProfileInfo(String email) async {
    if (email.isEmpty) {
      return {
        'displayName': 'Unknown User',
        'profilePicture': '',
        'userType': 'unknown'
      };
    }

    try {
      // First check if user is a tenant
      final tenantDoc = await _firestore.collection('Tenants').doc(email).get();
      if (tenantDoc.exists) {
        final data = tenantDoc.data()!;
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        final profilePicture = data['photoUrl'] as String? ?? '';

        String displayName = '';
        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          displayName = '$firstName $lastName';
        } else if (firstName.isNotEmpty) {
          displayName = firstName;
        } else {
          // Fallback to email-based name
          displayName = _formatDisplayNameFromEmail(email);
        }

        return {
          'displayName': displayName,
          'profilePicture': profilePicture,
          'userType': 'tenant'
        };
      }

      // Check if user is an owner
      final ownerDoc = await _firestore.collection('Owners').doc(email).get();
      if (ownerDoc.exists) {
        final data = ownerDoc.data()!;
        final fullName = data['fullName'] as String? ?? '';
        final profilePicture = data['profilePicture'] as String? ??
            ''; // Add support for owner profile picture

        String displayName = '';
        if (fullName.isNotEmpty) {
          displayName = fullName;
        } else {
          // Fallback to email-based name
          displayName = _formatDisplayNameFromEmail(email);
        }

        return {
          'displayName': displayName,
          'profilePicture': profilePicture,
          'userType': 'owner'
        };
      }

      // If not found in either collection, return email-based fallback
      return {
        'displayName': _formatDisplayNameFromEmail(email),
        'profilePicture': '',
        'userType': 'unknown'
      };
    } catch (e) {
      print('Error fetching user profile info: $e');
      return {
        'displayName': _formatDisplayNameFromEmail(email),
        'profilePicture': '',
        'userType': 'unknown'
      };
    }
  }

  // =============================
  // OWNER APPROVAL (KYC-lite)
  // States: 'pending' | 'approved' | 'rejected'
  // Fields stored in Owners/<email> document:
  //   approvalStatus: string
  //   idProof: { type: string, url: string, uploadedAt: Timestamp }
  //   approvalRequestedAt: Timestamp
  //   approvalUpdatedAt: Timestamp
  //   rejectionReason?: string

  /// Upload owner identity proof and set approvalStatus to 'pending'.
  static Future<void> uploadOwnerIdProofAndRequestApproval({
    required String email,
    required File proofImageFile,
    required String proofType,
  }) async {
    try {
      if (email.isEmpty) throw Exception('Email required');
      // Upload proof image
      final url =
          await uploadImageToCloudinary(proofImageFile, 'owner_id_proofs');

      final docRef = _firestore.collection('Owners').doc(email);
      await docRef.set({
        'approvalStatus': 'pending',
        'approvalRequestedAt': FieldValue.serverTimestamp(),
        'approvalUpdatedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
        'idProof': {
          'type': proofType,
          'url': url,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error requesting owner approval: $e');
      rethrow;
    }
  }

  /// Stream approval status string for an owner email.
  static Stream<String?> streamOwnerApprovalStatus(String email) {
    return _firestore.collection('Owners').doc(email).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      return data['approvalStatus']?.toString();
    });
  }

  /// Get current approval status once.
  static Future<String?> getOwnerApprovalStatus(String email) async {
    try {
      final snap = await _firestore.collection('Owners').doc(email).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      return data['approvalStatus']?.toString();
    } catch (e) {
      print('Error getting approval status: $e');
      return null;
    }
  }

  /// Convenience: re-submit approval with a new proof image.
  static Future<void> resubmitOwnerApproval({
    required String email,
    required File proofImageFile,
    required String proofType,
  }) async {
    return uploadOwnerIdProofAndRequestApproval(
        email: email, proofImageFile: proofImageFile, proofType: proofType);
  }

  // Helper function to format display name from email (fallback)
  static String _formatDisplayNameFromEmail(String email) {
    if (email.isEmpty) return 'Unknown User';
    final username = email.split('@')[0];
    final parts = username.split('.');
    if (parts.length >= 2) {
      return '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    }
    return _capitalize(username);
  }

  // Helper function to capitalize first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Get user initials for avatar (from actual name or email fallback)
  static String getUserInitials(String displayName, String email) {
    if (displayName.isNotEmpty && displayName != 'Unknown User') {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
      } else if (parts.isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }

    // Fallback to email-based initials
    if (email.isEmpty) return '?';
    final parts = email.split('@')[0].split('.');
    if (parts.length >= 2) {
      return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
    }
    return email[0].toUpperCase();
  }

  // Add profile picture support for owners
  static Future<void> updateOwnerProfilePicture(
      String email, String profilePictureUrl) async {
    try {
      await _firestore.collection('Owners').doc(email).update({
        'profilePicture': profilePictureUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating owner profile picture: $e');
      rethrow;
    }
  }

  // User presence tracking functions

  // Update user's last seen timestamp (call when user is active)
  static Future<void> updateUserPresence(String email) async {
    try {
      await _firestore.collection('UserPresence').doc(email).set({
        'email': email,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
        'isTyping': false, // Always set to false when updating presence
        'typingFor': null,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user presence: $e');
    }
  }

  // Set user offline (call when user closes app or goes to background)
  static Future<void> setUserOffline(String email) async {
    try {
      await _firestore.collection('UserPresence').doc(email).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'isTyping': false,
        'typingFor': null,
      });
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Set typing status (call when user is typing in a chat)
  static Future<void> setTypingStatus(String email, String typingFor) async {
    try {
      await _firestore.collection('UserPresence').doc(email).set({
        'isTyping': true,
        'typingFor': typingFor,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting typing status: $e');
    }
  }

  // Clear typing status (call when user stops typing or leaves chat)
  static Future<void> clearTypingStatus(String email) async {
    try {
      await _firestore.collection('UserPresence').doc(email).set({
        'isTyping': false,
        'typingFor': null,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error clearing typing status: $e');
    }
  }

  // Get user presence stream for real-time updates
  static Stream<DocumentSnapshot> getUserPresenceStream(String email) {
    return _firestore.collection('UserPresence').doc(email).snapshots();
  }

  // Get user online status and last seen
  static Future<Map<String, dynamic>> getUserPresence(String email) async {
    try {
      final doc = await _firestore.collection('UserPresence').doc(email).get();
      if (doc.exists) {
        final data = doc.data()!;
        final isOnline = data['isOnline'] ?? false;
        final lastSeen = data['lastSeen'] as Timestamp?;

        return {
          'isOnline': isOnline,
          'lastSeen': lastSeen,
        };
      }
      return {
        'isOnline': false,
        'lastSeen': null,
      };
    } catch (e) {
      print('Error getting user presence: $e');
      return {
        'isOnline': false,
        'lastSeen': null,
      };
    }
  }

  // Update user's typing status in a specific conversation
  static Future<void> updateTypingStatus(
      String currentEmail, String otherEmail, bool isTyping) async {
    try {
      final conversationId = chatRoomIdFor(currentEmail, otherEmail);
      print(
          '[TYPING] Updating typing status: $currentEmail -> $otherEmail, isTyping: $isTyping, conversationId: $conversationId');

      final updateData = {
        'email': currentEmail,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
        'typingIn': isTyping ? conversationId : null,
        'typingTimestamp': isTyping ? FieldValue.serverTimestamp() : null,
      };

      print('[TYPING] Update data: $updateData');

      await _firestore.collection('UserPresence').doc(currentEmail).set(
            updateData,
            SetOptions(merge: true),
          );
      print('[TYPING] Typing status updated successfully in Firestore');
    } catch (e) {
      print('[TYPING] Error updating typing status: $e');
      print('[TYPING] Stack trace: ${StackTrace.current}');
    }
  }

  // Get typing status stream for a specific conversation
  static Stream<bool> getTypingStatusStream(
      String otherEmail, String currentEmail) {
    final conversationId = chatRoomIdFor(currentEmail, otherEmail);
    print(
        '[TYPING] Setting up typing stream for: $otherEmail, conversationId: $conversationId');
    return _firestore
        .collection('UserPresence')
        .doc(otherEmail)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        print(
            '[TYPING] User presence document does not exist for: $otherEmail');
        return false;
      }
      final data = doc.data()!;
      final typingIn = data['typingIn'] as String?;
      final typingTimestamp = data['typingTimestamp'] as Timestamp?;

      print(
          '[TYPING] Received data for $otherEmail: typingIn=$typingIn, typingTimestamp=$typingTimestamp, expectedConversationId=$conversationId');

      // Check if user is typing in this conversation and the typing status is recent (within 3 seconds for ultra-fast response)
      if (typingIn == conversationId && typingTimestamp != null) {
        final now = DateTime.now();
        final typingTime = typingTimestamp.toDate();
        final differenceMs = now.difference(typingTime).inMilliseconds;
        final isTyping = differenceMs <=
            3000; // 3000ms = 3 seconds for minimal delay while handling network latency
        print(
            '[TYPING] User $otherEmail isTyping: $isTyping (difference: ${differenceMs}ms, threshold: 3000ms)');
        return isTyping; // Consider typing active only if updated within last 3 seconds
      }
      print('[TYPING] User $otherEmail not typing in this conversation');
      return false;
    });
  }

  // Format last seen time for display
  static String formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'Last seen: Unknown';

    final now = DateTime.now();
    final lastSeenDate = lastSeen.toDate();
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes < 1) {
      return 'Last seen: Just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen: ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Last seen: ${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Last seen: Yesterday';
    } else if (difference.inDays < 7) {
      return 'Last seen: ${difference.inDays}d ago';
    } else {
      // Format as date if more than a week
      return 'Last seen: ${lastSeenDate.day}/${lastSeenDate.month}/${lastSeenDate.year}';
    }
  }

  // Get user's mobile number by email
  static Future<String?> getUserMobileNumber(String email) async {
    try {
      // First check if user is a tenant
      final tenantDoc = await _firestore.collection('Tenants').doc(email).get();
      if (tenantDoc.exists) {
        final data = tenantDoc.data()!;
        return data['mobileNumber'] as String?;
      }

      // Check if user is an owner
      final ownerDoc = await _firestore.collection('Owners').doc(email).get();
      if (ownerDoc.exists) {
        final data = ownerDoc.data()!;
        return data['mobileNumber'] as String?;
      }

      return null;
    } catch (e) {
      print('Error getting user mobile number: $e');
      return null;
    }
  }

  // Notification System Functions

  // Create a notification when someone sends a message
  static Future<void> createChatNotification({
    required String senderEmail,
    required String receiverEmail,
    required String senderName,
    required String messageText,
  }) async {
    try {
      // Create notification ID
      final notificationId =
          '${senderEmail}_${receiverEmail}_${DateTime.now().millisecondsSinceEpoch}';

      // Determine notification message
      String notificationTitle;
      String notificationBody;

      if (messageText.isNotEmpty) {
        notificationTitle = '$senderName sent a message';
        notificationBody = messageText.length > 50
            ? '${messageText.substring(0, 50)}...'
            : messageText;
      } else {
        notificationTitle = '$senderName sent an attachment';
        notificationBody = 'Photo';
      }

      await _firestore.collection('Notifications').doc(notificationId).set({
        'id': notificationId,
        'senderEmail': senderEmail,
        'receiverEmail': receiverEmail,
        'senderName': senderName,
        'title': notificationTitle,
        'body': notificationBody,
        'type': 'chat_message',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': chatRoomIdFor(senderEmail, receiverEmail),
      });
    } catch (e) {
      print('Error creating chat notification: $e');
    }
  }

  // Get notifications for a user - handles both chat and booking notifications
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getNotificationsStream(String userEmail) {
    try {
      // Use a query that can handle both receiverEmail (chat) and recipientEmail (booking)
      // We need to use two separate queries and merge the results
      Stream<QuerySnapshot<Map<String, dynamic>>> chatNotifications = _firestore
          .collection('Notifications')
          .where('receiverEmail', isEqualTo: userEmail)
          .limit(100)
          .snapshots();

      Stream<QuerySnapshot<Map<String, dynamic>>> bookingNotifications =
          _firestore
              .collection('Notifications')
              .where('recipientEmail', isEqualTo: userEmail)
              .limit(100)
              .snapshots();

      // Merge the two streams
      return rx.CombineLatestStream.combine2(
          chatNotifications, bookingNotifications,
          (QuerySnapshot<Map<String, dynamic>> chatSnap,
              QuerySnapshot<Map<String, dynamic>> bookingSnap) {
        // Combine both results into a single list
        return [...chatSnap.docs, ...bookingSnap.docs];
      }).handleError((error) {
        print('Error in notification stream: $error');
        // If any error occurs, fall back to basic query
        return getNotificationsStreamFallback(userEmail)
            .map((snapshot) => snapshot.docs.toList());
      });
    } catch (e) {
      print('Error setting up notification streams: $e');
      return getNotificationsStreamFallback(userEmail)
          .map((snapshot) => snapshot.docs.toList());
    }
  }

  // Get notifications for a user (fallback without ordering)
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      getNotificationsStreamFallback(String userEmail) {
    // Simple fallback that only checks receiverEmail
    // This is used if the combined stream approach fails
    return _firestore
        .collection('Notifications')
        .where('receiverEmail', isEqualTo: userEmail)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('Notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for a user - handles both chat and booking notifications
  static Future<void> markAllNotificationsAsRead(String userEmail) async {
    try {
      // Get chat notifications
      final chatNotifications = await _firestore
          .collection('Notifications')
          .where('receiverEmail', isEqualTo: userEmail)
          .where('isRead', isEqualTo: false)
          .get();

      // Get booking notifications
      final bookingNotifications = await _firestore
          .collection('Notifications')
          .where('recipientEmail', isEqualTo: userEmail)
          .where('isRead', isEqualTo: false)
          .get();

      // Create a batch to update all notifications
      final batch = _firestore.batch();

      // Add chat notifications to batch
      for (final doc in chatNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Add booking notifications to batch
      for (final doc in bookingNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Commit the batch
      await batch.commit();

      print(
          'Marked ${chatNotifications.docs.length + bookingNotifications.docs.length} notifications as read');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notification count
  static Future<int> getUnreadNotificationCount(String userEmail) async {
    try {
      final snapshot = await _firestore
          .collection('Notifications')
          .where('receiverEmail', isEqualTo: userEmail)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  // =============================
  // BOOKING MANAGEMENT METHODS
  // =============================

  // Import booking models
  // Note: Add this import at the top of the file
  // import 'package:housinghub/Helper/BookingModels.dart';

  // Create a new booking request
  static Future<String> createBooking({
    required String tenantEmail,
    required String ownerEmail,
    required String propertyId,
    required Map<String, dynamic> propertyData,
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> idProof,
    required DateTime checkInDate,
    int bookingPeriodMonths = 1,
    required double amount,
    String? ownerName,
    String? ownerMobileNumber,
    String? notes,
    String? paymentId,
    String? paymentSignature,
    DateTime? paymentCompletedAt,
    String? paymentStatus,
  }) async {
    try {
      // Prevent users from booking their own properties
      if (tenantEmail.toLowerCase().trim() == ownerEmail.toLowerCase().trim()) {
        throw Exception('You cannot book your own property');
      }

      final bookingId = const Uuid().v4();

      // Resolve owner details (name and mobile) from provided args, propertyData, or owner profile fallback
      String ownerNameResolved = (ownerName ??
              propertyData['ownerName']?.toString() ??
              propertyData['ownerFullName']?.toString() ??
              '')
          .trim();
      String ownerMobileResolved = (ownerMobileNumber ??
              propertyData['ownerPhone']?.toString() ??
              propertyData['ownerMobileNumber']?.toString() ??
              propertyData['ownerContact']?.toString() ??
              '')
          .trim();

      // If still missing, try fetching from Owners profile
      if (ownerNameResolved.isEmpty || ownerMobileResolved.isEmpty) {
        try {
          final ownerDoc =
              await _firestore.collection('Owners').doc(ownerEmail).get();
          if (ownerDoc.exists) {
            final od = ownerDoc.data()!;
            if (ownerNameResolved.isEmpty) {
              final first = (od['firstName']?.toString() ?? '').trim();
              final last = (od['lastName']?.toString() ?? '').trim();
              final full = [first, last].where((e) => e.isNotEmpty).join(' ');
              ownerNameResolved = (od['fullName']?.toString() ??
                      od['ownerName']?.toString() ??
                      od['name']?.toString() ??
                      full)
                  .trim();
            }
            if (ownerMobileResolved.isEmpty) {
              ownerMobileResolved = (od['phoneNumber']?.toString() ??
                      od['mobileNumber']?.toString() ??
                      od['contact']?.toString() ??
                      od['phone']?.toString() ??
                      '')
                  .trim();
            }
          }
        } catch (e) {
          // Best-effort; ignore lookup failures
          print('Warning: Could not resolve owner profile: $e');
        }
      }

      // Compute checkout date
      final DateTime checkoutDate =
          _computeCheckoutDate(checkInDate, bookingPeriodMonths);

      final bookingData = {
        'bookingId': bookingId,
        'tenantEmail': tenantEmail,
        'ownerEmail': ownerEmail,
        if (ownerNameResolved.isNotEmpty) 'ownerName': ownerNameResolved,
        if (ownerMobileResolved.isNotEmpty)
          'ownerMobileNumber': ownerMobileResolved,
        'propertyId': propertyId,
        'propertyData': propertyData,
        'tenantData': tenantData,
        'idProof': idProof,
        'status': paymentStatus == 'Completed'
            ? 'Pending'
            : 'Draft', // Draft until payment is completed
        'paymentInfo': {
          'amount': amount,
          'status': paymentStatus ?? 'Pending',
          'currency': 'INR',
          'paymentMethod': 'Razorpay',
          'paymentId': paymentId,
          'paymentSignature': paymentSignature,
          'paymentCompletedAt': paymentCompletedAt?.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'checkInDate': Timestamp.fromDate(checkInDate),
        'checkoutDate': Timestamp.fromDate(checkoutDate),
        'bookingPeriodMonths': bookingPeriodMonths,
        'notes': notes,
      };

      // Store in tenant's bookings collection
      await _firestore
          .collection('Tenants')
          .doc(tenantEmail)
          .collection('Bookings')
          .doc(bookingId)
          .set(bookingData);

      // Store in owner's bookings collection
      await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .doc(bookingId)
          .set(bookingData);

      // Store in central bookings collection
      await _firestore.collection('Bookings').doc(bookingId).set(bookingData);

      // Create notification for owner
      await createBookingNotification(
        recipientEmail: ownerEmail,
        senderEmail: tenantEmail, // Add sender email (tenant)
        type: 'booking_request',
        message:
            'New booking request from ${tenantData['firstName']} ${tenantData['lastName']} for ${propertyData['title']}',
        bookingId: bookingId,
      );

      print('Booking created successfully with ID: $bookingId');
      return bookingId;
    } catch (e) {
      print('Error creating booking: $e');
      throw Exception('Failed to create booking: $e');
    }
  }

  // Helper: compute checkout date by adding months
  static DateTime _computeCheckoutDate(DateTime checkIn, int months) {
    final y = checkIn.year;
    final m = checkIn.month;
    final d = checkIn.day;
    final nm = m + months;
    final ny = y + ((nm - 1) ~/ 12);
    final nmon = ((nm - 1) % 12) + 1;
    final lastDay = DateTime(ny, nmon + 1, 0).day;
    final nd = d.clamp(1, lastDay);
    return DateTime(ny, nmon, nd);
  }

  // Update booking status (approve/reject)
  static Future<void> updateBookingStatus({
    required String bookingId,
    required String tenantEmail,
    required String ownerEmail,
    required String newStatus,
    String? rejectionReason,
    Map<String, dynamic>? paymentInfo,
  }) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      if (paymentInfo != null) {
        updateData['paymentInfo'] = paymentInfo;
      }

      // Get booking details first to access property information
      final bookingDoc = await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data()!;
      final propertyId = bookingData['propertyId'] as String?;

      // Handle property availability changes when booking is approved/accepted
      if ((newStatus == 'Approved' || newStatus == 'Accepted') &&
          propertyId != null) {
        // Mark property as unavailable since booking is approved
        try {
          // Prepare tenant snapshot and period/date info
          final tenantData = Map<String, dynamic>.from(
              bookingData['tenantData'] as Map<String, dynamic>? ?? {});
          tenantData['tenantEmail'] = tenantEmail;

          DateTime checkIn = DateTime.now();
          final ciRaw = bookingData['checkInDate'];
          if (ciRaw is Timestamp) checkIn = ciRaw.toDate();
          if (ciRaw is String) {
            final parsed = DateTime.tryParse(ciRaw);
            if (parsed != null) checkIn = parsed;
          }
          final period = (bookingData['bookingPeriodMonths'] is int)
              ? bookingData['bookingPeriodMonths'] as int
              : 1;
          final checkout = (bookingData['checkoutDate'] is Timestamp)
              ? (bookingData['checkoutDate'] as Timestamp).toDate()
              : _computeCheckoutDate(checkIn, period);

          // Derive rent/securityDeposit for snapshot
          final Map<String, dynamic> prop =
              Map<String, dynamic>.from(bookingData['propertyData'] ?? {});
          final double rentAmount = (() {
            final v = prop['rent'] ?? prop['price'] ?? prop['monthlyRent'];
            if (v is num) return v.toDouble();
            final s = v?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
            return s.isEmpty ? 0.0 : (double.tryParse(s) ?? 0.0);
          })();
          final double depositAmount = (() {
            final v = prop['deposit'] ?? prop['securityDeposit'];
            if (v is num) return v.toDouble();
            final s = v?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
            return s.isEmpty ? 0.0 : (double.tryParse(s) ?? 0.0);
          })();

          final updatedData = <String, dynamic>{
            'currentTenant': tenantData,
            'currentBookingId': bookingId,
            'currentBookingStatus': 'Approved',
            'checkInDate': Timestamp.fromDate(checkIn),
            'checkoutDate': Timestamp.fromDate(checkout),
            'bookingPeriodMonths': period,
            'autoRevertAt': Timestamp.fromDate(checkout),
            'currentRent': rentAmount,
            'currentSecurityDeposit': depositAmount,
          };

          await markPropertyAsUnavailable(propertyId, updatedData);
          print(
              'Property $propertyId marked as unavailable after booking approval');

          // Cancel all other pending bookings for this property
          await _cancelOtherPendingBookingsForProperty(
              propertyId, bookingId, ownerEmail);
        } catch (e) {
          print('Warning: Could not update property availability: $e');
          // Don't fail the entire booking update if property update fails
        }
      }

      // Handle property availability changes when booking is rejected/cancelled
      else if ((newStatus == 'Rejected' || newStatus == 'Cancelled') &&
          propertyId != null) {
        // Property should remain available for other bookings
        // We don't need to do anything here as property should already be available
        print('Booking $newStatus - property $propertyId remains available');
      }

      // Handle property availability when booking is completed or tenant moves out
      else if ((newStatus == 'Completed' || newStatus == 'CheckedOut') &&
          propertyId != null) {
        // Mark property as available again and clear any tenant-related fields
        // to mirror the auto-revert cleanup behavior.
        try {
          await markPropertyAsAvailable(propertyId, {
            'currentTenant': null,
            'currentBookingId': null,
            'currentBookingStatus': null,
            'autoRevertAt': null,
            'checkInDate': null,
            'checkoutDate': null,
            'bookingPeriodMonths': null,
            'currentRent': null,
            'currentSecurityDeposit': null,
          });
          print(
              'Property $propertyId marked as available and cleaned after booking completion');
        } catch (e) {
          print(
              'Warning: Could not update property availability/cleanup after completion: $e');
          // Don't fail the entire booking update
        }
      }

      // Update in tenant's collection
      await _firestore
          .collection('Tenants')
          .doc(tenantEmail)
          .collection('Bookings')
          .doc(bookingId)
          .update(updateData);

      // Update in owner's collection
      await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .doc(bookingId)
          .update(updateData);

      // Update in central collection
      await _firestore.collection('Bookings').doc(bookingId).update(updateData);

      // Create notification for tenant
      String notificationMessage;
      String notificationType;

      switch (newStatus) {
        case 'Approved':
          notificationMessage = 'Your booking request has been approved!';
          notificationType = 'booking_approved';
          break;
        case 'Rejected':
          notificationMessage =
              'Your booking request has been rejected. ${rejectionReason ?? ''}';
          notificationType = 'booking_rejected';
          break;
        case 'CheckedIn':
          notificationMessage =
              'You have successfully checked in to your property.';
          notificationType = 'booking_checkin';
          break;
        case 'CheckedOut':
          notificationMessage =
              'You have successfully checked out from your property.';
          notificationType = 'booking_checkout';
          break;
        case 'Completed':
          notificationMessage = 'Your booking has been marked as completed.';
          notificationType = 'booking_completed';
          break;
        default:
          notificationMessage =
              'Your booking status has been updated to $newStatus';
          notificationType = 'booking_status_update';
      }

      await createBookingNotification(
        recipientEmail: tenantEmail,
        senderEmail: ownerEmail, // Add sender email (owner)
        type: notificationType,
        message: notificationMessage,
        bookingId: bookingId,
      );

      print('Booking status updated successfully: $bookingId -> $newStatus');
    } catch (e) {
      print('Error updating booking status: $e');
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Auto revert properties whose booking period has ended back to Available
  static Future<void> autoRevertExpiredBookingsForOwner(
      String ownerEmail) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final unavailSnap = await _firestore
          .collection('Properties')
          .doc(ownerEmail)
          .collection('Unavailable')
          .where('autoRevertAt', isLessThanOrEqualTo: now)
          .get();

      for (final doc in unavailSnap.docs) {
        final propertyId = doc.id;
        try {
          await markPropertyAsAvailable(propertyId, {
            'currentTenant': null,
            'currentBookingId': null,
            'currentBookingStatus': null,
            'autoRevertAt': null,
          });
          print('Auto-reverted property $propertyId to Available');
        } catch (e) {
          print('Warning: Failed to auto-revert $propertyId: $e');
        }
      }
    } catch (e) {
      print('Error during auto-revert check: $e');
    }
  }

  // Cancel other pending bookings for the same property when one is approved
  static Future<void> _cancelOtherPendingBookingsForProperty(
      String propertyId, String approvedBookingId, String ownerEmail) async {
    try {
      // Get all pending bookings for this property from owner's collection
      final pendingBookingsQuery = await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', whereIn: ['Pending']).get();

      // Cancel each pending booking except the approved one
      for (final doc in pendingBookingsQuery.docs) {
        if (doc.id != approvedBookingId) {
          final bookingData = doc.data();
          final tenantEmail = bookingData['tenantEmail'] as String;

          // Update status to cancelled with reason
          await updateBookingStatus(
            bookingId: doc.id,
            tenantEmail: tenantEmail,
            ownerEmail: ownerEmail,
            newStatus: 'Cancelled',
            rejectionReason: 'Property has been booked by another tenant',
          );

          print('Auto-cancelled booking ${doc.id} for property $propertyId');
        }
      }
    } catch (e) {
      print('Error cancelling other pending bookings: $e');
      // Don't throw error as this is a cleanup operation
    }
  }

  // Get tenant bookings
  static Future<List<Map<String, dynamic>>> getTenantBookings(
      String tenantEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('Tenants')
          .doc(tenantEmail)
          .collection('Bookings')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      print('Error fetching tenant bookings: $e');
      throw Exception('Failed to fetch tenant bookings: $e');
    }
  }

  // Get owner bookings
  static Future<List<Map<String, dynamic>>> getOwnerBookings(
      String ownerEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      print('Error fetching owner bookings: $e');
      throw Exception('Failed to fetch owner bookings: $e');
    }
  }

  // Get pending bookings for owner
  static Future<List<Map<String, dynamic>>> getPendingBookingsForOwner(
      String ownerEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .where('status', isEqualTo: 'Pending')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      print('Error fetching pending bookings: $e');
      throw Exception('Failed to fetch pending bookings: $e');
    }
  }

  // Stream tenant bookings (raw QuerySnapshot)
  static Stream<QuerySnapshot> streamTenantBookingsRaw(String tenantEmail) {
    return _firestore
        .collection('Tenants')
        .doc(tenantEmail)
        .collection('Bookings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream owner bookings (raw QuerySnapshot)
  static Stream<QuerySnapshot> streamOwnerBookingsRaw(String ownerEmail) {
    return _firestore
        .collection('Owners')
        .doc(ownerEmail)
        .collection('Bookings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream pending bookings for owner
  static Stream<QuerySnapshot> streamPendingBookingsForOwner(
      String ownerEmail) {
    return _firestore
        .collection('Owners')
        .doc(ownerEmail)
        .collection('Bookings')
        .where('status', isEqualTo: 'Pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream tenant bookings with processed data
  static Stream<List<Map<String, dynamic>>> streamTenantBookings(
      String tenantEmail) {
    return _firestore
        .collection('Tenants')
        .doc(tenantEmail)
        .collection('Bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['bookingId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Stream owner bookings with processed data
  static Stream<List<Map<String, dynamic>>> streamOwnerBookings(
      String ownerEmail) {
    return _firestore
        .collection('Owners')
        .doc(ownerEmail)
        .collection('Bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['bookingId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Cancel booking
  static Future<void> cancelBooking({
    required String bookingId,
    required String tenantEmail,
    required String ownerEmail,
    String? cancellationReason,
  }) async {
    try {
      await updateBookingStatus(
        bookingId: bookingId,
        tenantEmail: tenantEmail,
        ownerEmail: ownerEmail,
        newStatus: 'Cancelled',
        rejectionReason: cancellationReason,
      );

      // Create notification for owner
      await createBookingNotification(
        recipientEmail: ownerEmail,
        senderEmail: tenantEmail, // Add sender email (tenant)
        type: 'booking_cancelled',
        message:
            'Booking has been cancelled by tenant. ${cancellationReason ?? ''}',
        bookingId: bookingId,
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Get count of pending bookings for owner
  static Future<int> getPendingBookingsCount(String ownerEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('Owners')
          .doc(ownerEmail)
          .collection('Bookings')
          .where('status', whereIn: ['Pending']).get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting pending bookings count: $e');
      return 0;
    }
  }

  // Stream for pending bookings count
  static Stream<int> streamPendingBookingsCount(String ownerEmail) {
    return _firestore
        .collection('Owners')
        .doc(ownerEmail)
        .collection('Bookings')
        .where('status', whereIn: ['Pending'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get booking by ID
  static Future<Map<String, dynamic>?> getBookingById({
    required String bookingId,
    required String userEmail,
    required bool isOwner,
  }) async {
    try {
      final collection = isOwner ? 'Owners' : 'Tenants';
      final doc = await _firestore
          .collection(collection)
          .doc(userEmail)
          .collection('Bookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        return {
          ...doc.data()!,
          'id': doc.id,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching booking by ID: $e');
      throw Exception('Failed to fetch booking: $e');
    }
  }

  // Update payment information
  static Future<void> updateBookingPayment({
    required String bookingId,
    required String tenantEmail,
    required String ownerEmail,
    required Map<String, dynamic> paymentInfo,
  }) async {
    try {
      final updateData = {
        'paymentInfo': paymentInfo,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in all collections
      await Future.wait([
        _firestore
            .collection('Tenants')
            .doc(tenantEmail)
            .collection('Bookings')
            .doc(bookingId)
            .update(updateData),
        _firestore
            .collection('Owners')
            .doc(ownerEmail)
            .collection('Bookings')
            .doc(bookingId)
            .update(updateData),
        _firestore.collection('Bookings').doc(bookingId).update(updateData),
      ]);

      print('Booking payment updated successfully: $bookingId');
    } catch (e) {
      print('Error updating booking payment: $e');
      throw Exception('Failed to update payment: $e');
    }
  }

  // Update booking with receipt URL
  static Future<void> updateBookingWithReceiptUrl({
    required String bookingId,
    required String tenantEmail,
    required String ownerEmail,
    required String receiptUrl,
    String? ownerName,
    String? ownerMobileNumber,
  }) async {
    try {
      // Resolve owner fields if not provided
      String ownerNameResolved = (ownerName ?? '').trim();
      String ownerMobileResolved = (ownerMobileNumber ?? '').trim();
      if (ownerNameResolved.isEmpty || ownerMobileResolved.isEmpty) {
        // Try to pull from central booking or owner profile
        try {
          final central =
              await _firestore.collection('Bookings').doc(bookingId).get();
          final centralData = central.data();
          if (centralData != null) {
            if (ownerNameResolved.isEmpty) {
              ownerNameResolved =
                  (centralData['ownerName']?.toString() ?? '').trim();
              if (ownerNameResolved.isEmpty) {
                final pd = centralData['propertyData'] as Map<String, dynamic>?;
                if (pd != null) {
                  ownerNameResolved = (pd['ownerName']?.toString() ??
                          pd['ownerFullName']?.toString() ??
                          '')
                      .trim();
                }
              }
            }
            if (ownerMobileResolved.isEmpty) {
              ownerMobileResolved =
                  (centralData['ownerMobileNumber']?.toString() ?? '').trim();
              if (ownerMobileResolved.isEmpty) {
                final pd = centralData['propertyData'] as Map<String, dynamic>?;
                if (pd != null) {
                  ownerMobileResolved = (pd['ownerPhone']?.toString() ??
                          pd['ownerMobileNumber']?.toString() ??
                          pd['ownerContact']?.toString() ??
                          '')
                      .trim();
                }
              }
            }
          }
        } catch (e) {
          print('Warning: Could not resolve owner from booking: $e');
        }
      }
      if (ownerNameResolved.isEmpty || ownerMobileResolved.isEmpty) {
        try {
          final ownerDoc =
              await _firestore.collection('Owners').doc(ownerEmail).get();
          if (ownerDoc.exists) {
            final od = ownerDoc.data()!;
            if (ownerNameResolved.isEmpty) {
              final first = (od['firstName']?.toString() ?? '').trim();
              final last = (od['lastName']?.toString() ?? '').trim();
              final full = [first, last].where((e) => e.isNotEmpty).join(' ');
              ownerNameResolved = (od['fullName']?.toString() ??
                      od['ownerName']?.toString() ??
                      od['name']?.toString() ??
                      full)
                  .trim();
            }
            if (ownerMobileResolved.isEmpty) {
              ownerMobileResolved = (od['phoneNumber']?.toString() ??
                      od['mobileNumber']?.toString() ??
                      od['contact']?.toString() ??
                      od['phone']?.toString() ??
                      '')
                  .trim();
            }
          }
        } catch (e) {
          print('Warning: Could not resolve owner profile: $e');
        }
      }

      final updateData = {
        'receiptUrl': receiptUrl,
        'receiptGeneratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (ownerNameResolved.isNotEmpty) 'ownerName': ownerNameResolved,
        if (ownerMobileResolved.isNotEmpty)
          'ownerMobileNumber': ownerMobileResolved,
      };

      // Update in all collections using the bookingId directly
      await Future.wait([
        _firestore
            .collection('Tenants')
            .doc(tenantEmail)
            .collection('Bookings')
            .doc(bookingId)
            .update(updateData),
        if (ownerEmail.isNotEmpty)
          _firestore
              .collection('Owners')
              .doc(ownerEmail)
              .collection('Bookings')
              .doc(bookingId)
              .update(updateData),
        _firestore.collection('Bookings').doc(bookingId).update(updateData),
      ]);

      print('Booking receipt URL updated successfully: $bookingId');
    } catch (e) {
      print('Error updating booking receipt URL: $e');
      throw Exception('Failed to update receipt URL: $e');
    }
  }

  // Create booking notification
  static Future<void> createBookingNotification({
    required String recipientEmail,
    required String type,
    required String message,
    required String bookingId,
    String? senderEmail, // Optional sender email for proper ID structure
  }) async {
    try {
      // Create notification ID following the same pattern as chat notifications
      // Format: senderEmail_recipientEmail_timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sender =
          senderEmail ?? 'system'; // Use 'system' if no sender specified
      final notificationId = '${sender}_${recipientEmail}_$timestamp';

      final notificationData = {
        'notificationId': notificationId,
        'recipientEmail': recipientEmail,
        'senderEmail': sender,
        'type': type,
        'message': message,
        'bookingId': bookingId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      await _firestore
          .collection('Notifications')
          .doc(notificationId)
          .set(notificationData);
    } catch (e) {
      print('Error creating booking notification: $e');
    }
  }

  // Get user documents for ID proof selection
  static Future<List<Map<String, dynamic>>> getTenantDocuments(
      String tenantEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('Tenants')
          .doc(tenantEmail)
          .collection('Documents')
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'documentId': doc.id,
              })
          .toList();
    } catch (e) {
      print('Error fetching tenant documents: $e');
      throw Exception('Failed to fetch documents: $e');
    }
  }

  // Get notification count stream - handles both chat and booking notifications
  static Stream<int> getUnreadNotificationCountStream(String userEmail) {
    // Get unread chat notifications count
    Stream<QuerySnapshot<Map<String, dynamic>>> chatNotifications = _firestore
        .collection('Notifications')
        .where('receiverEmail', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .snapshots();

    // Get unread booking notifications count
    Stream<QuerySnapshot<Map<String, dynamic>>> bookingNotifications =
        _firestore
            .collection('Notifications')
            .where('recipientEmail', isEqualTo: userEmail)
            .where('isRead', isEqualTo: false)
            .snapshots();

    // Combine both streams and return the total count
    return rx.CombineLatestStream.combine2(
        chatNotifications, bookingNotifications,
        (QuerySnapshot<Map<String, dynamic>> chatSnap,
            QuerySnapshot<Map<String, dynamic>> bookingSnap) {
      return chatSnap.docs.length + bookingSnap.docs.length;
    }).handleError((error) {
      print('Error in unread notification count stream: $error');
      // Fallback to just chat notifications if there's an error
      return 0;
    });
  }

  // Delete old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications(String userEmail) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final oldNotifications = await _firestore
          .collection('Notifications')
          .where('receiverEmail', isEqualTo: userEmail)
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  // =============================
  // ACCOUNT SWITCHING HELPERS
  // =============================

  // Check if user has both tenant and owner accounts
  static Future<Map<String, bool>> getUserAccountTypes(String email) async {
    if (email.isEmpty) {
      return {'isTenant': false, 'isOwner': false};
    }

    try {
      // Check if user exists in both collections
      final tenantDoc = await _firestore.collection('Tenants').doc(email).get();
      final ownerDoc = await _firestore.collection('Owners').doc(email).get();

      return {
        'isTenant': tenantDoc.exists,
        'isOwner': ownerDoc.exists,
      };
    } catch (e) {
      print('Error checking user account types: $e');
      return {'isTenant': false, 'isOwner': false};
    }
  }

  // Check if user can switch to owner account (exists and approved)
  static Future<bool> canSwitchToOwnerAccount(String email) async {
    if (email.isEmpty) return false;

    try {
      final ownerDoc = await _firestore.collection('Owners').doc(email).get();
      if (!ownerDoc.exists) return false;

      final data = ownerDoc.data() as Map<String, dynamic>;
      final approvalStatus = data['approvalStatus']?.toString() ?? '';

      // User can switch if they have an approved owner account
      return approvalStatus == 'approved';
    } catch (e) {
      print('Error checking owner account status: $e');
      return false;
    }
  }

  // Check if user can switch to tenant account (exists)
  static Future<bool> canSwitchToTenantAccount(String email) async {
    if (email.isEmpty) return false;

    try {
      final tenantDoc = await _firestore.collection('Tenants').doc(email).get();
      return tenantDoc.exists;
    } catch (e) {
      print('Error checking tenant account status: $e');
      return false;
    }
  }

  // Get account switching info for current user
  static Future<Map<String, dynamic>> getAccountSwitchingInfo(
      String email) async {
    if (email.isEmpty) {
      return {
        'canSwitchToOwner': false,
        'canSwitchToTenant': false,
        'ownerApprovalStatus': null,
        'hasOwnerAccount': false,
        'hasTenantAccount': false,
      };
    }

    try {
      final accountTypes = await getUserAccountTypes(email);
      final canSwitchToOwner = await canSwitchToOwnerAccount(email);
      final canSwitchToTenant = await canSwitchToTenantAccount(email);

      String? ownerApprovalStatus;
      if (accountTypes['isOwner'] == true) {
        final ownerDoc = await _firestore.collection('Owners').doc(email).get();
        if (ownerDoc.exists) {
          final data = ownerDoc.data() as Map<String, dynamic>;
          ownerApprovalStatus = data['approvalStatus']?.toString();
        }
      }

      return {
        'canSwitchToOwner': canSwitchToOwner,
        'canSwitchToTenant': canSwitchToTenant,
        'ownerApprovalStatus': ownerApprovalStatus,
        'hasOwnerAccount': accountTypes['isOwner'] ?? false,
        'hasTenantAccount': accountTypes['isTenant'] ?? false,
      };
    } catch (e) {
      print('Error getting account switching info: $e');
      return {
        'canSwitchToOwner': false,
        'canSwitchToTenant': false,
        'ownerApprovalStatus': null,
        'hasOwnerAccount': false,
        'hasTenantAccount': false,
      };
    }
  }

  // ==================== MOBILE NUMBER VALIDATION ====================

  /// Validates if a mobile number is already used by another account
  /// Returns true if mobile number is unique (can be used)
  /// Returns false if mobile number is already linked to another email
  /// Allows same mobile number for same email across different account types (tenant/owner)
  static Future<bool> isMobileNumberUnique(String mobileNumber,
      {String? excludeEmail, String? currentEmail}) async {
    if (mobileNumber.isEmpty) return false;

    try {
      Set<String> foundEmails = {};

      // Check in tenants collection
      final tenantQuery = await _firestore
          .collection('Tenants')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .get();

      for (var doc in tenantQuery.docs) {
        final docEmail = doc.id;
        // If excludeEmail is provided, skip checking that specific email
        if (excludeEmail != null && docEmail == excludeEmail) {
          continue;
        }
        foundEmails.add(docEmail);
      }

      // Check in owners collection
      final ownerQuery = await _firestore
          .collection('Owners')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .get();

      for (var doc in ownerQuery.docs) {
        final docEmail = doc.id;
        // If excludeEmail is provided, skip checking that specific email
        if (excludeEmail != null && docEmail == excludeEmail) {
          continue;
        }
        foundEmails.add(docEmail);
      }

      // If no emails found, mobile number is unique
      if (foundEmails.isEmpty) {
        return true;
      }

      // If currentEmail is provided and all found emails match currentEmail,
      // then it's the same person trying to create another account type
      if (currentEmail != null &&
          foundEmails.length == 1 &&
          foundEmails.contains(currentEmail)) {
        return true; // Allow same email to use same mobile across account types
      }

      // If multiple different emails or email doesn't match currentEmail, not allowed
      return false;
    } catch (e) {
      print('Error checking mobile number uniqueness: $e');
      return false; // Return false on error to be safe
    }
  }

  /// Gets the email associated with a mobile number
  /// Returns the email if found, null if not found or error
  static Future<String?> getEmailByMobileNumber(String mobileNumber) async {
    if (mobileNumber.isEmpty) return null;

    try {
      // Check in tenants collection first
      final tenantQuery = await _firestore
          .collection('Tenants')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (tenantQuery.docs.isNotEmpty) {
        return tenantQuery.docs.first.id; // Document ID is the email
      }

      // Check in owners collection
      final ownerQuery = await _firestore
          .collection('Owners')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();

      if (ownerQuery.docs.isNotEmpty) {
        return ownerQuery.docs.first.id; // Document ID is the email
      }

      return null; // Not found
    } catch (e) {
      print('Error getting email by mobile number: $e');
      return null;
    }
  }

  /// Validates mobile number during signup process
  /// Throws exception with user-friendly message if validation fails
  /// Allows same mobile number for same email across different account types
  static Future<void> validateMobileForSignup(String mobileNumber,
      {String? currentEmail}) async {
    if (mobileNumber.isEmpty) {
      throw Exception('Mobile number is required');
    }

    // Basic format validation (optional - adjust pattern as needed)
    final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{0,15}$');
    if (!phoneRegex
        .hasMatch(mobileNumber.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      throw Exception('Please enter a valid mobile number');
    }

    final isUnique =
        await isMobileNumberUnique(mobileNumber, currentEmail: currentEmail);
    if (!isUnique) {
      throw Exception(
          'This mobile number is already linked with another account. Please use a different number.');
    }
  }

  /// Validates mobile number consistency during login
  /// Checks if the logged-in user's mobile number matches Firestore data
  static Future<bool> validateMobileConsistency(String email) async {
    if (email.isEmpty) return false;

    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return false;

      // Get stored mobile number from Firestore
      final storedMobile = await getUserMobileNumber(email);
      if (storedMobile == null) {
        print('Warning: No mobile number found in Firestore for email: $email');
        return true; // Allow login but log warning
      }

      // For now, we'll just verify the data exists and is consistent
      // Additional validation can be added here if needed
      return true;
    } catch (e) {
      print('Error validating mobile consistency: $e');
      return true; // Allow login on error to prevent blocking users
    }
  }

  // ============================================================================
  // BANNER MANAGEMENT
  // ============================================================================

  /// Fetch all active banners ordered by their 'order' field
  static Future<List<Map<String, dynamic>>> getActiveBanners() async {
    try {
      final querySnapshot = await _firestore
          .collection('Banners')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error fetching active banners: $e');
      return [];
    }
  }

  /// Fetch all banners (active and inactive)
  static Future<List<Map<String, dynamic>>> getAllBanners() async {
    try {
      final querySnapshot =
          await _firestore.collection('Banners').orderBy('order').get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error fetching all banners: $e');
      return [];
    }
  }

  /// Stream of active banners for real-time updates
  // Get single active banner stream
  static Stream<Map<String, dynamic>?> getActiveBannerStream() {
    return _firestore.collection('Banners').snapshots().handleError((error) {
      print('Error fetching banner stream: $error');
    }).map((snapshot) {
      print('Banners snapshot received: ${snapshot.docs.length} documents');

      // Filter active banners
      final activeBanners =
          snapshot.docs.where((doc) => doc.data()['isActive'] == true).toList();

      if (activeBanners.isEmpty) {
        print('No active banners found');
        return null;
      }

      // Return the first active banner
      final bannerDoc = activeBanners.first;
      final data = bannerDoc.data();
      data['id'] = bannerDoc.id;

      print('Active banner: ${data['title']}');
      return data;
    });
  }

  // ==================== App Control Methods ====================

  /// Check if app is under maintenance
  static Future<bool> isAppUnderMaintenance() async {
    try {
      final docSnapshot =
          await _firestore.collection('AppControl').doc('Application').get();

      if (!docSnapshot.exists) {
        return false; // Default to not under maintenance if doc doesn't exist
      }

      final data = docSnapshot.data();
      return data?['UnderMaintenance'] ?? false;
    } catch (e) {
      print('Error checking maintenance status: $e');
      return false; // Default to not under maintenance on error
    }
  }

  /// Stream to listen for maintenance status changes in real-time
  static Stream<bool> maintenanceStatusStream() {
    return _firestore
        .collection('AppControl')
        .doc('Application')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      return snapshot.data()?['UnderMaintenance'] ?? false;
    });
  }
}
