import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:housinghub/Helper/LoadingStateManager.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // User type and authentication state
  bool isTenant = true;
  bool isLoginTab = true;
  String gender = "Male";
  bool isLoading = false;
  String? city; // Changed to nullable
  String? state; // Changed to nullable
  List<String> _states = [];
  List<String> _cities = [];
  Map<String, String> _stateCodeMap =
      {}; // Map to store state names and their codes
  bool _isGoogleSignUp = false; // Track if user came from Google Sign-In

  // For searchable dropdowns
  TextEditingController _stateSearchController = TextEditingController();
  TextEditingController _citySearchController = TextEditingController();
  bool _showStateDropdown = false;
  bool _showCityDropdown = false;
  List<String> _filteredStates = [];
  List<String> _filteredCities = [];

  // Form controllers
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Helper to check if current user is Google authenticated
  bool get isGoogleUser {
    User? user = Api.getCurrentUser();
    return user != null &&
        user.providerData
            .any((provider) => provider.providerId == 'google.com');
  }

  @override
  void initState() {
    super.initState();
    _fetchStates();

    // Initialize search controllers
    _stateSearchController.addListener(_filterStates);
    _citySearchController.addListener(_filterCities);
  }

  // Filter states based on search
  void _filterStates() {
    String query = _stateSearchController.text.toLowerCase();
    setState(() {
      _filteredStates = _states
          .where((state) => state.toLowerCase().contains(query))
          .toList();
    });
  }

  // Filter cities based on search
  void _filterCities() {
    String query = _citySearchController.text.toLowerCase();
    setState(() {
      _filteredCities =
          _cities.where((city) => city.toLowerCase().contains(query)).toList();
    });
  }

  @override
  void dispose() {
    _stateSearchController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  String stateCityAPI =
      "YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ==";
  Future<void> _fetchStates() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
        headers: {'X-CSCAPI-KEY': '$stateCityAPI'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _states = [];
          _stateCodeMap = {};

          for (var state in data) {
            String stateName = state['name'].toString();
            String stateCode = state['iso2'].toString();
            _states.add(stateName);
            _stateCodeMap[stateName] = stateCode;
          }

          // Sort states alphabetically
          _states.sort();

          // Initialize filtered states
          _filteredStates = List.from(_states);

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load states');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Models.showErrorSnackBar(
        context,
        'Failed to load states: $e',
      );
    }
  }

  Future<void> _fetchCities(String stateName) async {
    setState(() {
      isLoading = true;
    });
    try {
      if (!_stateCodeMap.containsKey(stateName)) {
        throw Exception('State code not found for $stateName');
      }

      String stateCode = _stateCodeMap[stateName]!;

      // Now fetch cities for this state
      final response = await http.get(
        Uri.parse(
            'https://api.countrystatecity.in/v1/countries/IN/states/$stateCode/cities'),
        headers: {'X-CSCAPI-KEY': '$stateCityAPI'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cities = data.map((city) => city['name'].toString()).toList();
          // Sort cities alphabetically
          _cities.sort();

          // Initialize filtered cities
          _filteredCities = List.from(_cities);

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load cities');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Models.showErrorSnackBar(
        context,
        'Failed to load cities: $e',
      );
    }
  }

  // Helper method to build a custom text form field
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: validator ??
            (value) => value!.isEmpty ? 'This field is required' : null,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: AppConfig.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppConfig.primaryColor),
          ),
        ),
      ),
    );
  }

  // Helper method to build a primary button
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          padding: EdgeInsets.symmetric(vertical: height * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: TextStyle(
                  fontSize: width * 0.045,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // Helper method to build social login buttons
  Widget _buildSocialLoginButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          padding: EdgeInsets.symmetric(vertical: height * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              color: AppConfig.primaryColor,
              size: width * 0.05,
            ),
            SizedBox(width: width * 0.04),
            Text(
              text,
              style: TextStyle(
                fontSize: width * 0.04,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build divider with text
  Widget _buildDivider() {
    final double width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.02),
          child: Text(
            'or',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  // Register method for tenant signup
  Future<void> registerTenant() async {
    log("Register button pressed");

    if (_formKey.currentState!.validate()) {
      log("Form validated successfully");

      try {
        setState(() {
          isLoading = true;
        });
        log("Setting loading state to true");

        // Trim the inputs to avoid whitespace issues
        final email = _emailController.text.trim();
        final password = (isGoogleUser && _isGoogleSignUp)
            ? '' // Empty password for Google users
            : _passwordController.text.trim();
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final mobileNumber = _mobileController.text.trim();

        log("Attempting to create user with email: $email");

        // Check if user is already authenticated (e.g., from Google Sign-In)
        User? currentUser = Api.getCurrentUser();

        if (currentUser != null && currentUser.email == email) {
          // User is already authenticated (likely from Google Sign-In), just create profile
          log("User already authenticated, creating profile only");

          // If Google user and password field was shown (for linking), set the password
          if (isGoogleUser && _isGoogleSignUp && password.isNotEmpty) {
            try {
              log("Attempting to set password for Google user: $email");
              bool success = await Api.setPasswordForGoogleUser(password);
              if (success) {
                Models.showSuccessSnackBar(context,
                    'Password set successfully! You can now sign in with email and password too.');
                log("Password set for Google user for email/password authentication");
              }
            } catch (e) {
              log("Could not set password for Google user: $e");
              Models.showErrorSnackBar(context,
                  'Could not set password. You can try again later in your profile settings.');
              // Continue with registration even if password setting fails
            }
          }
        } else {
          // First check if this email already exists in Firebase Auth
          try {
            // Try to create user in Firebase Auth
            UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                    email: email, password: password);
            log("User created in Firebase Auth with UID: ${userCredential.user?.uid}");
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              // Email exists in Firebase Auth, try to sign in instead
              log("Email already exists in Firebase Auth, trying to sign in");
              UserCredential? signInResult = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(email: email, password: password);
              if (signInResult.user == null) {
                Models.showErrorSnackBar(context,
                    'Email already registered with different password');
                setState(() {
                  isLoading = false;
                });
                return;
              }
              log("Successfully signed in to existing Firebase Auth account");
            } else {
              rethrow; // Re-throw other Firebase Auth exceptions
            }
          }
        }

        // Store additional user data in Firestore
        await Api.createUserIfNotExists(
          mobileNumber,
          firstName,
          lastName,
          email,
          gender,
          password,
        );

        log("User data stored in Firestore successfully");

        // Send email verification only if not already verified (Google users are pre-verified)
        if (currentUser == null || !currentUser.emailVerified) {
          await Api.sendEmailVerification();
        }

        // Success message
        if (currentUser != null && currentUser.emailVerified) {
          Models.showSuccessSnackBar(context,
              'Profile completed successfully! Welcome to HousingHub.');
          // Navigate directly to home for verified users
          _navigateToHomeScreen();
        } else {
          Models.showSuccessSnackBar(context,
              'Registration successful! Please check your email to verify your account.');
          // Switch to login tab for unverified users
          setState(() {
            isLoginTab = true;
            _isGoogleSignUp = false; // Reset Google signup state
            isLoading = false;
          });
        }

        log("Registration process completed");

        // Clear input fields after successful registration
        _clearInputFields();
      } on FirebaseAuthException catch (e) {
        log("FirebaseAuthException: ${e.code} - ${e.message}");
        setState(() {
          isLoading = false;
        });

        String errorMessage = "Tenant Email already exists";

        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak';
        } else if (e.code == 'email-already-in-use') {
          errorMessage =
              'An account with this email already exists. You can still register as a tenant if you use the same password.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Please enter a valid email address';
        }

        Models.showErrorSnackBar(context, errorMessage);
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        Models.showErrorSnackBar(context, 'Error: ${e.toString()}');
      }
    }
  }

  // Login method for tenant login
  Future<void> loginTenant() async {
    if (_formKey.currentState!.validate()) {
      // Import the LoadingStateManager at the top of the file
      // import 'package:housinghub/Helper/LoadingStateManager.dart';

      // Trim the inputs to avoid whitespace issues
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await LoadingStateManager.runWithLoader(
        context: context,
        loadingState: (isLoading) {
          // Only update state if the widget is still mounted
          if (mounted) {
            setState(() {
              this.isLoading = isLoading;
            });
          }
        },
        operation: () async {
          // Sign in with email and password
          User? user = await Api.signInWithEmailAndPassword(
            email,
            password,
          );

          if (user != null) {
            // Reload user to get the latest status
            await Api.reloadUser();

            // Check if email is verified
            if (!Api.isEmailVerified()) {
              // Email not verified
              Models.showWarningSnackBar(
                  context, 'Please verify your email before logging in.');

              // Offer to resend verification email
              bool shouldResend = await _showResendVerificationDialog();
              if (shouldResend && mounted) {
                await Api.sendEmailVerification();
                Models.showSuccessSnackBar(
                    context, 'Verification email sent again.');
              }

              // Sign out the user
              await Api.signOut();
              return null; // Return null to indicate login did not proceed
            }

            // Get user details from Firestore - check in tenants collection first
            Map<String, dynamic>? userData =
                await Api.getUserDetailsByEmail(email);

            if (userData != null) {
              log("User data retrieved successfully: ${userData['firstName']} ${userData['lastName']}");
              return userData; // Return the user data for success handler
            } else {
              // Not found in tenants collection, check in owners collection
              userData = await Api.getOwnerDetailsByEmail(email);
              if (userData != null) {
                log("Owner data found for tenant login: ${userData['fullName']}");
                return userData; // Return the user data for success handler
              } else {
                // Not found in either collection
                throw Exception(
                    'No account found with this email. Please register first.');
              }
            }
          } else {
            // Login failed
            throw Exception('Invalid email or password');
          }
        },
        onSuccess: (userData) {
          if (userData != null) {
            // Login successful, navigate to home page or dashboard
            _clearInputFields();
            _navigateToHomeScreen();
          }
        },
        onError: (e) {
          log("Login error: ${e.toString()}");
          String errorMessage = e is Exception
              ? e.toString().replaceAll('Exception: ', '')
              : 'Error: ${e.toString()}';
          Models.showErrorSnackBar(context, errorMessage);
        },
      );
    }
  }

  // Login method for owner login
  Future<void> loginOwner() async {
    if (_formKey.currentState!.validate()) {
      // Trim the inputs to avoid whitespace issues
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await LoadingStateManager.runWithLoader(
        context: context,
        loadingState: (isLoading) {
          // Only update state if the widget is still mounted
          if (mounted) {
            setState(() {
              this.isLoading = isLoading;
            });
          }
        },
        operation: () async {
          // Sign in with email and password
          User? user = await Api.signInWithEmailAndPassword(
            email,
            password,
          );

          if (user != null) {
            // Reload user to get the latest status
            await Api.reloadUser();

            // Check if email is verified
            if (!Api.isEmailVerified()) {
              // Will handle verification in onSuccess callback
              return false; // Return false to indicate verification needed
            }

            // Get user details from Firestore - check in owners collection
            Map<String, dynamic>? userData =
                await Api.getOwnerDetailsByEmail(email);

            if (userData != null) {
              log("Owner data retrieved successfully: ${userData['fullName']}");
              return userData; // Return the user data for success handler
            } else {
              // Not found in owners collection
              throw Exception(
                  'No owner account found with this email. Please register as an owner first.');
            }
          } else {
            // Login failed
            throw Exception('Invalid email or password');
          }
        },
        onSuccess: (result) async {
          if (result == false) {
            // Email not verified case
            bool resend = await _showResendVerificationDialog();
            if (resend && mounted) {
              await Api.sendEmailVerification();
              Models.showSuccessSnackBar(
                  context, 'Verification email sent. Please check your inbox.');
            }
          } else {
            // Login successful with user data
            _clearInputFields();
            _navigateToHomeScreen();
          }
        },
        onError: (e) {
          log("Login error: ${e.toString()}");
          String errorMessage = e is Exception
              ? e.toString().replaceAll('Exception: ', '')
              : 'Error: ${e.toString()}';
          Models.showErrorSnackBar(context, errorMessage);
        },
      );
    }
  }

  // Register method for owner signup
  Future<void> registerOwner() async {
    log("Owner register button pressed");

    if (_formKey.currentState!.validate()) {
      log("Owner form validated successfully");

      try {
        setState(() {
          isLoading = true;
        });
        log("Setting loading state to true");

        // Trim the inputs to avoid whitespace issues
        final email = _emailController.text.trim();
        final password = (isGoogleUser && _isGoogleSignUp)
            ? '' // Empty password for Google users
            : _passwordController.text.trim();
        final fullName = _fullNameController.text.trim();
        final mobileNumber = _mobileController.text.trim();
        final cityValue = city ?? ''; // Use dropdown value
        final stateValue = state ?? ''; // Use dropdown value

        // Validate that state and city are selected
        if (stateValue.isEmpty) {
          Models.showWarningSnackBar(context, 'Please select a state');
          setState(() {
            isLoading = false;
          });
          return;
        }

        if (cityValue.isEmpty) {
          Models.showWarningSnackBar(context, 'Please select a city');
          setState(() {
            isLoading = false;
          });
          return;
        }

        log("Attempting to create owner with email: $email");

        // Check if user is already authenticated (e.g., from Google Sign-In)
        User? currentUser = Api.getCurrentUser();

        if (currentUser != null && currentUser.email == email) {
          // User is already authenticated (likely from Google Sign-In), just create profile
          log("Owner already authenticated, creating profile only");

          // If Google user and password field was shown (for linking), set the password
          if (isGoogleUser && _isGoogleSignUp && password.isNotEmpty) {
            try {
              log("Attempting to set password for Google user: $email");
              bool success = await Api.setPasswordForGoogleUser(password);
              if (success) {
                Models.showSuccessSnackBar(context,
                    'Password set successfully! You can now sign in with email and password too.');
                log("Password set for Google user for email/password authentication");
              }
            } catch (e) {
              log("Could not set password for Google user: $e");
              Models.showErrorSnackBar(context,
                  'Could not set password. You can try again later in your profile settings.');
              // Continue with registration even if password setting fails
            }
          }
        } else {
          // First check if this email already exists in Firebase Auth
          try {
            // Try to create user in Firebase Auth
            UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                    email: email, password: password);
            log("Owner created in Firebase Auth with UID: ${userCredential.user?.uid}");
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              // Email exists in Firebase Auth, try to sign in instead
              log("Email already exists in Firebase Auth, trying to sign in");
              UserCredential? signInResult = await FirebaseAuth.instance
                  .signInWithEmailAndPassword(email: email, password: password);
              if (signInResult.user == null) {
                Models.showErrorSnackBar(context,
                    'Email already registered with different password');
                setState(() {
                  isLoading = false;
                });
                return;
              }
              log("Successfully signed in to existing Firebase Auth account");
            } else {
              rethrow; // Re-throw other Firebase Auth exceptions
            }
          }
        }

        // Store additional user data in Firestore
        await Api.createOwnerIfNotExists(
          mobileNumber,
          fullName,
          email,
          cityValue,
          stateValue,
        );

        log("Owner data stored in Firestore successfully");

        // Send email verification only if not already verified (Google users are pre-verified)
        if (currentUser == null || !currentUser.emailVerified) {
          await Api.sendEmailVerification();
        }

        // Success message
        if (currentUser != null && currentUser.emailVerified) {
          Models.showSuccessSnackBar(context,
              'Profile completed successfully! Welcome to HousingHub.');
          // Navigate directly to home for verified users
          _navigateToHomeScreen();
        } else {
          Models.showSuccessSnackBar(context,
              'Registration successful! Please check your email to verify your account.');
          // Switch to login tab for unverified users
          setState(() {
            isLoginTab = true;
            _isGoogleSignUp = false; // Reset Google signup state
            isLoading = false;
          });
        }

        log("Owner registration process completed");

        // Clear input fields after successful registration
        _clearInputFields();
      } on FirebaseAuthException catch (e) {
        log("FirebaseAuthException: ${e.code} - ${e.message}");
        setState(() {
          isLoading = false;
        });

        String errorMessage = 'Owner registration failed';

        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak';
        } else if (e.code == 'email-already-in-use') {
          errorMessage =
              'An account with this email already exists. You can still register as an owner if you use the same password.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Please enter a valid email address';
        }

        Models.showErrorSnackBar(context, errorMessage);
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        Models.showErrorSnackBar(context, 'Error: ${e.toString()}');
      }
    }
  }

  // Helper method to get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          Models.showWarningSnackBar(context, 'Location permission denied');
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Models.showWarningSnackBar(
            context, 'Location services are disabled. Please enable them.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      // Get address from lat/lng
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String? detectedState = place.administrativeArea;
        String? detectedCity = place.locality ?? place.subAdministrativeArea;

        if (detectedState != null && detectedCity != null) {
          // Find matching state in the dropdown list
          String? matchingState = _states.firstWhere(
            (s) =>
                s.toLowerCase().contains(detectedState.toLowerCase()) ||
                detectedState.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          );

          if (matchingState.isNotEmpty) {
            setState(() {
              state = matchingState;
              _stateSearchController.text = matchingState;
              _showStateDropdown = false; // Close state dropdown if open
            });

            // Fetch cities for the detected state
            await _fetchCities(matchingState);

            // Find matching city in the fetched cities list
            String? matchingCity = _cities.firstWhere(
              (c) =>
                  c.toLowerCase().contains(detectedCity.toLowerCase()) ||
                  detectedCity.toLowerCase().contains(c.toLowerCase()),
              orElse: () => '',
            );

            if (matchingCity.isNotEmpty) {
              setState(() {
                city = matchingCity;
                _citySearchController.text = matchingCity;
                _showCityDropdown = false; // Close city dropdown if open
              });
            }

            Models.showSuccessSnackBar(context,
                'Location detected: $matchingState${matchingCity.isNotEmpty ? ', $matchingCity' : ''}');
          } else {
            Models.showWarningSnackBar(
                context, 'Could not match detected state: $detectedState');
          }
        } else {
          Models.showWarningSnackBar(
              context, 'Could not detect state and city from your location');
        }
      } else {
        Models.showWarningSnackBar(
            context, 'Could not fetch address from coordinates');
      }
    } catch (e) {
      Models.showErrorSnackBar(
          context, 'Error fetching location: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Dialog to ask user if they want to resend verification email
  Future<bool> _showResendVerificationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Email Not Verified'),
              content: Text(
                  'Your email address has not been verified. Would you like to resend the verification email?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Resend'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  // Method to handle successful login/authentication
  void _navigateToHomeScreen() {
    // Clear input fields after successful login
    _clearInputFields();

    // Navigate to appropriate home screen based on user type
    if (isTenant) {
      Navigator.pushReplacementNamed(context, 'TenantHomeScreen');
    } else {
      Navigator.pushReplacementNamed(context, 'OwnerHomeScreen');
    }
  }

  // Helper method to clear all input fields
  void _clearInputFields() {
    _mobileController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    _cityController.clear();
    _stateController.clear();

    // Clear dropdown values
    setState(() {
      city = null;
      state = null;
      _cities = [];
      gender = "Male"; // Reset to default
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final double hPadding = width * 0.05;
    final double vPadding = height * 0.03;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: height * 0.03),
                  _buildUserTypeSelector(),
                  SizedBox(height: height * 0.03),
                  _buildTabs(),
                  SizedBox(height: height * 0.03),

                  // Form content based on selection
                  if (isTenant && isLoginTab)
                    _buildTenantLoginForm()
                  else if (!isTenant && isLoginTab)
                    _buildOwnerLoginForm()
                  else if (isTenant && !isLoginTab)
                    _buildTenantSignupForm()
                  else
                    _buildOwnerSignupForm(),

                  SizedBox(height: height * 0.02),
                  _buildTermsText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget to build the header section
  Widget _buildHeader() {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome',
          style: TextStyle(
            fontSize: width * 0.08,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: height * 0.02),
        Text(
          'Sign in or create an account',
          style: TextStyle(
            fontSize: width * 0.04,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Widget to build the user type selector
  Widget _buildUserTypeSelector() {
    final double width = MediaQuery.of(context).size.width;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildUserTypeButton(
          context: context,
          label: "I'm a Tenant",
          isSelected: isTenant,
          onTap: () {
            setState(() {
              isTenant = true;
            });
          },
        ),
        SizedBox(width: width * 0.03),
        _buildUserTypeButton(
          context: context,
          label: "I'm an Owner",
          isSelected: !isTenant,
          onTap: () {
            setState(() {
              isTenant = false;
            });
          },
        ),
      ],
    );
  }

  // Widget to build the login/signup tabs
  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTab(
          label: "Login",
          isSelected: isLoginTab,
          onTap: () {
            setState(() {
              isLoginTab = true;
              _isGoogleSignUp = false; // Reset Google signup state
            });
            // Clear input fields when switching tabs
            _clearInputFields();
          },
        ),
        _buildTab(
          label: "Sign Up",
          isSelected: !isLoginTab,
          onTap: () {
            setState(() {
              isLoginTab = false;
              _isGoogleSignUp = false; // Reset Google signup state
            });
            // Clear input fields when switching tabs
            _clearInputFields();
          },
        ),
      ],
    );
  }

  // Widget to build the tenant login form
  Widget _buildTenantLoginForm() {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tenant Login',
          style: TextStyle(
            fontSize: width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        _buildTextField(
          controller: _emailController,
          hintText: 'Enter your email',
          icon: Icons.email_outlined,
          validator: (value) {
            if (value!.isEmpty) {
              return 'Please enter your email';
            } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _passwordController,
          hintText: 'Password',
          icon: Icons.password,
          isPassword: true,
          validator: (value) =>
              value!.isEmpty ? 'Please enter your password' : null,
        ),
        SizedBox(height: height * 0.01),
        _buildPrimaryButton(
          text: 'Login',
          onPressed: loginTenant,
          isLoading: isLoading,
        ),
        SizedBox(height: height * 0.02),
        _buildDivider(),
        SizedBox(height: height * 0.02),
        _buildSocialLoginButton(
          text: 'Continue with Google',
          icon: FontAwesomeIcons.google,
          onPressed: () {
            signInWithGoogleTenant();
          },
        ),
      ],
    );
  } // Widget to build the owner login form

  Widget _buildOwnerLoginForm() {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Owner Login',
          style: TextStyle(
            fontSize: width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 20),
        _buildTextField(
          controller: _emailController,
          hintText: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildTextField(
          controller: _passwordController,
          hintText: 'Password',
          icon: Icons.lock,
          isPassword: true,
        ),
        SizedBox(height: height * 0.01),
        _buildPrimaryButton(
          text: 'Login',
          onPressed: loginOwner,
          isLoading: isLoading,
        ),
        SizedBox(height: height * 0.02),
        _buildDivider(),
        SizedBox(height: height * 0.02),
        _buildSocialLoginButton(
          text: 'Continue with Google',
          icon: FontAwesomeIcons.google,
          onPressed: () {
            signInWithGoogleOwner();
          },
        ),
      ],
    );
  }

  // Widget to build the tenant signup form
  Widget _buildTenantSignupForm() {
    // Access width and height from MediaQuery
    final double width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tenant Sign Up',
          style: TextStyle(
            fontSize: width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter first name' : null,
                decoration: InputDecoration(
                  hintText: 'First Name',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppConfig.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF007AFF)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter last name' : null,
                decoration: InputDecoration(
                  hintText: 'Last Name',
                  prefixIcon: Icon(Icons.person_2_outlined,
                      color: AppConfig.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF007AFF)),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Gender selection
        Row(
          spacing: 5,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGenderButton(
              label: 'Male',
              icon: Icons.male,
              isSelected: gender == "Male",
              onTap: () {
                setState(() {
                  gender = "Male";
                  log(gender);
                });
              },
            ),
            _buildGenderButton(
              label: 'Female',
              icon: Icons.female,
              isSelected: gender == "Female",
              onTap: () {
                setState(() {
                  gender = "Female";
                  log(gender);
                });
              },
            ),
          ],
        ),
        SizedBox(height: 16),

        // Phone, Email, Password fields
        _buildTextField(
          controller: _mobileController,
          hintText: 'Enter your phone number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          controller: _emailController,
          hintText: 'Enter your email',
          icon: Icons.email_outlined,
          validator: (value) {
            if (value!.isEmpty) {
              return 'Please enter the Email';
            } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          keyboardType: TextInputType.emailAddress,
        ),
        // Password field - only show for non-Google users
        if (!isGoogleUser || !_isGoogleSignUp)
          _buildTextField(
            controller: _passwordController,
            hintText: 'Password',
            icon: Icons.password,
            isPassword: true,
            validator: (value) =>
                value!.isEmpty ? 'Please enter your password' : null,
          ),

        // Signup button
        _buildPrimaryButton(
          text: 'Sign Up',
          onPressed: registerTenant,
          isLoading: isLoading,
        ),
      ],
    );
  }

  // Widget to build the owner signup form
  Widget _buildOwnerSignupForm() {
    final width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Owner Sign Up',
          style: TextStyle(
            fontSize: width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 20),

        // Full Name field
        _buildTextField(
          controller: _fullNameController,
          hintText: 'Full Name',
          icon: Icons.person,
        ),

        // Email field
        _buildTextField(
          controller: _emailController,
          hintText: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),

        // Phone Number field
        _buildTextField(
          controller: _mobileController,
          hintText: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),

        // Password field - only show for non-Google users
        if (!isGoogleUser || !_isGoogleSignUp)
          _buildTextField(
            controller: _passwordController,
            hintText: 'Password',
            icon: Icons.lock,
            isPassword: true,
            validator: (value) =>
                value!.isEmpty ? 'Please enter your password' : null,
          ),

        // State Custom Searchable Dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // State input field
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // State input with search functionality
                    TextFormField(
                      controller: _stateSearchController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        labelStyle: TextStyle(
                          fontSize: width * 0.045,
                          color: AppConfig.primaryColor,
                        ),
                        prefixIcon: Icon(Icons.map, color: Color(0xFF007AFF)),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_stateSearchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _stateSearchController.clear();
                                    _showStateDropdown = false;
                                  });
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _showStateDropdown
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: Color(0xFF007AFF),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showStateDropdown = !_showStateDropdown;
                                  if (_showStateDropdown) {
                                    _showCityDropdown = false;
                                    _filteredStates = _states;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _showStateDropdown = true;
                          _showCityDropdown = false;
                          _filteredStates = _states;
                        });
                      },
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            state = null;
                          });
                        }
                      },
                      validator: (value) {
                        if (state == null) {
                          return 'Please select a state';
                        }
                        return null;
                      },
                    ),

                    // State dropdown list
                    if (_showStateDropdown)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxHeight: 200,
                        ),
                        child: _filteredStates.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Center(
                                  child: Text(
                                    "No states found",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredStates.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(_filteredStates[index]),
                                    onTap: () {
                                      setState(() {
                                        state = _filteredStates[index];
                                        _stateSearchController.text = state!;
                                        _showStateDropdown = false;
                                        city = null;
                                        _citySearchController.clear();
                                        _cities = [];
                                      });
                                      _fetchCities(state!);
                                    },
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // City Dropdown with Location Button
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              // City searchable dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // City input with search functionality
                          TextFormField(
                            controller: _citySearchController,
                            decoration: InputDecoration(
                              labelText: 'City',
                              labelStyle: TextStyle(
                                fontSize: width * 0.045,
                                color: Color(0xFF007AFF),
                              ),
                              prefixIcon: Icon(Icons.location_city,
                                  color: Color(0xFF007AFF)),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_citySearchController.text.isNotEmpty)
                                    IconButton(
                                      icon:
                                          Icon(Icons.clear, color: Colors.grey),
                                      onPressed: () {
                                        setState(() {
                                          _citySearchController.clear();
                                          _showCityDropdown = false;
                                          city = null;
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _showCityDropdown
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: AppConfig.primaryColor,
                                    ),
                                    onPressed: () {
                                      if (_cities.isEmpty) {
                                        Models.showWarningSnackBar(context,
                                            'Please select a state first');
                                        return;
                                      }
                                      setState(() {
                                        _showCityDropdown = !_showCityDropdown;
                                        if (_showCityDropdown) {
                                          _showStateDropdown = false;
                                          _filteredCities = _cities;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                            ),
                            enabled: _cities.isNotEmpty,
                            onTap: () {
                              if (_cities.isEmpty) {
                                Models.showWarningSnackBar(
                                    context, 'Please select a state first');
                                return;
                              }
                              setState(() {
                                _showCityDropdown = true;
                                _showStateDropdown = false;
                                _filteredCities = _cities;
                              });
                            },
                            onChanged: (value) {
                              if (value.isEmpty) {
                                setState(() {
                                  city = null;
                                });
                              }
                            },
                            validator: (value) {
                              if (state != null && city == null) {
                                return 'Please select a city';
                              }
                              return null;
                            },
                          ),

                          // City dropdown list
                          if (_showCityDropdown)
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: _filteredCities.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Center(
                                        child: Text(
                                          "No cities found",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _filteredCities.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          dense: true,
                                          title: Text(_filteredCities[index]),
                                          onTap: () {
                                            setState(() {
                                              city = _filteredCities[index];
                                              _citySearchController.text =
                                                  city!;
                                              _showCityDropdown = false;
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // Location button - enhanced with animation
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _getCurrentLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isLoading ? Colors.grey[400] : Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF007AFF).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 22,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sign Up button
        _buildPrimaryButton(
          text: 'Sign Up',
          onPressed: registerOwner,
          isLoading: isLoading,
        ),
      ],
    );
  }

  // Widget to build the gender selection button
  Widget _buildGenderButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Container(
      width: width * 0.44,
      height: height * 0.06,
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF007AFF) : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.white : Color(0xFF007AFF),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Color(0xFF007AFF),
            ),
            SizedBox(width: width * 0.02),
            Text(
              label,
              style: TextStyle(
                fontSize: width * 0.04,
                color: isSelected ? Colors.white : Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget to build terms and conditions text
  Widget _buildTermsText() {
    final double width = MediaQuery.of(context).size.width;

    return Center(
      child: Text(
        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: width * 0.035,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildUserTypeButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width * 0.4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: width * 0.035),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF007AFF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.transparent : Color(0xFF007AFF),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Color(0xFF007AFF),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final double width = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width / 3,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: width * 0.05,
                color: isSelected ? Color(0xFF007AFF) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 5),
            if (isSelected)
              Container(
                height: 2,
                width: width / 3,
                color: Color(0xFF007AFF),
              ),
          ],
        ),
      ),
    );
  }

  // Google Sign-In for Tenant
  Future<void> signInWithGoogleTenant() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = await Api.signInWithGoogle();

      if (user != null) {
        log("Google Sign-In successful for user: ${user.email}");

        // Check if email is verified (Google accounts are always verified)
        if (user.emailVerified) {
          // Check if user exists as tenant in Firestore
          Map<String, dynamic>? tenantData =
              await Api.getUserDetailsByEmail(user.email!);

          if (tenantData != null) {
            log("Existing tenant data found for Google user");
            Models.showSuccessSnackBar(context, 'Welcome back!');
            // Ensure we're in tenant mode for navigation
            setState(() {
              isTenant = true;
            });
            _navigateToHomeScreen(); // Will navigate to TenantHomeScreen
          } else {
            // Check if exists as owner
            Map<String, dynamic>? ownerData =
                await Api.getOwnerDetailsByEmail(user.email!);
            if (ownerData != null) {
              log("User exists as owner, allowing tenant registration too");
              Models.showMsgSnackBar(context,
                  'You have an owner account. You can also register as a tenant to access both features.');
              setState(() {
                isLoginTab = false; // Switch to signup tab
                isTenant = true; // Ensure tenant mode
                _isGoogleSignUp = true; // Mark as Google signup
                _emailController.text = user.email!; // Pre-fill email
                // Pre-fill name if available
                if (user.displayName != null && user.displayName!.isNotEmpty) {
                  List<String> nameParts = user.displayName!.split(' ');
                  if (nameParts.isNotEmpty) {
                    _firstNameController.text = nameParts.first;
                    if (nameParts.length > 1) {
                      _lastNameController.text = nameParts.skip(1).join(' ');
                    }
                  }
                }
              });
            } else {
              // New Google user - show message and pre-fill form for tenant registration
              Models.showMsgSnackBar(
                  context, 'Welcome! Please complete your tenant profile.');
              setState(() {
                isLoginTab = false; // Switch to signup tab
                isTenant = true; // Ensure tenant mode
                _isGoogleSignUp = true; // Mark as Google signup
                _emailController.text = user.email!; // Pre-fill email
                // Pre-fill name if available
                if (user.displayName != null && user.displayName!.isNotEmpty) {
                  List<String> nameParts = user.displayName!.split(' ');
                  if (nameParts.isNotEmpty) {
                    _firstNameController.text = nameParts.first;
                    if (nameParts.length > 1) {
                      _lastNameController.text = nameParts.skip(1).join(' ');
                    }
                  }
                }
              });
            }
          }
        } else {
          Models.showErrorSnackBar(context, 'Email verification required');
        }
      } else {
        Models.showMsgSnackBar(context, 'Google Sign-In cancelled');
      }

      setState(() {
        isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
      });

      String errorMessage = 'Google Sign-In failed';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage =
            'An account already exists with this email. Please sign in with your email and password first.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      Models.showErrorSnackBar(context, errorMessage);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      log("Google Sign-In error: ${e.toString()}");
      Models.showErrorSnackBar(
          context, 'Google Sign-In failed: ${e.toString()}');
    }
  }

  // Google Sign-In for Owner
  Future<void> signInWithGoogleOwner() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = await Api.signInWithGoogle();

      if (user != null) {
        log("Google Sign-In successful for owner: ${user.email}");

        // Check if email is verified (Google accounts are always verified)
        if (user.emailVerified) {
          // Check if user exists as owner in Firestore
          Map<String, dynamic>? ownerData =
              await Api.getOwnerDetailsByEmail(user.email!);

          if (ownerData != null) {
            log("Existing owner data found for Google user");
            Models.showSuccessSnackBar(context, 'Welcome back!');
            // Ensure we're in owner mode for navigation
            setState(() {
              isTenant = false;
            });
            _navigateToHomeScreen(); // Will navigate to OwnerHomeScreen
          } else {
            // Check if exists as tenant
            Map<String, dynamic>? tenantData =
                await Api.getUserDetailsByEmail(user.email!);
            if (tenantData != null) {
              log("User exists as tenant, allowing owner registration too");
              Models.showMsgSnackBar(context,
                  'You have a tenant account. You can also register as an owner to access both features.');
              setState(() {
                isTenant = false; // Switch to owner mode
                isLoginTab = false; // Switch to signup tab
                _isGoogleSignUp = true; // Mark as Google signup
                _emailController.text = user.email!; // Pre-fill email
                // Pre-fill name if available
                if (user.displayName != null && user.displayName!.isNotEmpty) {
                  _fullNameController.text = user.displayName!;
                }
              });
            } else {
              // New Google user - show message and pre-fill form for owner registration
              Models.showMsgSnackBar(
                  context, 'Welcome! Please complete your owner profile.');
              setState(() {
                isTenant = false; // Switch to owner mode
                isLoginTab = false; // Switch to signup tab
                _isGoogleSignUp = true; // Mark as Google signup
                _emailController.text = user.email!; // Pre-fill email
                // Pre-fill name if available
                if (user.displayName != null && user.displayName!.isNotEmpty) {
                  _fullNameController.text = user.displayName!;
                }
              });
            }
          }
        } else {
          Models.showErrorSnackBar(context, 'Email verification required');
        }
      } else {
        Models.showMsgSnackBar(context, 'Google Sign-In cancelled');
      }

      setState(() {
        isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
      });

      String errorMessage = 'Google Sign-In failed';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage =
            'An account already exists with this email. Please sign in with your email and password first.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      Models.showErrorSnackBar(context, errorMessage);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      log("Google Sign-In error: ${e.toString()}");
      Models.showErrorSnackBar(
          context, 'Google Sign-In failed: ${e.toString()}');
    }
  }
}
