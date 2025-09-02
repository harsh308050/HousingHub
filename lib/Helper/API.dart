import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

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

      // Save to Firestore using the specified structure
      // "Properties/[User MailID]/Available/[propertyid]/{formdata}"
      await _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Available')
          .doc(propertyId)
          .set(finalPropertyData);

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

      // Check if property exists in Available collection
      final availableDocRef = _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Available')
          .doc(propertyId);

      final availableDocSnap = await availableDocRef.get();

      // Check if property exists in Unavailable collection
      final unavailableDocRef = _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Unavailable')
          .doc(propertyId);

      final unavailableDocSnap = await unavailableDocRef.get();

      // Delete from the appropriate collection
      if (availableDocSnap.exists) {
        await availableDocRef.delete();
        print(
            'Property deleted from Available collection with ID: $propertyId');
      } else if (unavailableDocSnap.exists) {
        await unavailableDocRef.delete();
        print(
            'Property deleted from Unavailable collection with ID: $propertyId');
      } else {
        print('Property not found in either collection: $propertyId');
        throw Exception('Property not found in either collection');
      }
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

      // Get the property document
      final propertyRef = _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Available')
          .doc(propertyId);

      final propertySnap = await propertyRef.get();
      if (!propertySnap.exists) {
        throw Exception('Property not found');
      }

      // Get property data
      Map<String, dynamic> propertyData =
          propertySnap.data() as Map<String, dynamic>;

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

      // Move property to Unavailable collection with updated data
      await _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Unavailable')
          .doc(propertyId)
          .set({
        ...propertyData,
        'isAvailable': false,
        'statusChangedAt': FieldValue.serverTimestamp(),
      });

      // Delete from Available collection
      await propertyRef.delete();

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

      // Get the property document from Unavailable collection
      final propertyRef = _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Unavailable')
          .doc(propertyId);

      final propertySnap = await propertyRef.get();
      if (!propertySnap.exists) {
        throw Exception('Property not found');
      }

      // Get property data
      Map<String, dynamic> propertyData =
          propertySnap.data() as Map<String, dynamic>;

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

      // Move property to Available collection with updated data
      await _firestore
          .collection('Properties')
          .doc(user.email)
          .collection('Available')
          .doc(propertyId)
          .set({
        ...propertyData,
        'isAvailable': true,
        'statusChangedAt': FieldValue.serverTimestamp(),
      });

      // Delete from Unavailable collection
      await propertyRef.delete();

      print('Property marked as available with ID: $propertyId');
    } catch (e) {
      print('Error updating property status: $e');
      throw Exception('Failed to update property status: $e');
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
}
