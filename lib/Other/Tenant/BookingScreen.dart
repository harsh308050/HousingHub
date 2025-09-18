import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/BookingModels.dart';
import 'package:housinghub/Helper/PdfReceiptGenerator.dart';
import 'package:housinghub/Helper/LoadingStateManager.dart';
import 'package:housinghub/Helper/Models.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> propertyData;

  const BookingScreen({
    Key? key,
    required this.propertyData,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form controllers and data
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedCheckInDate;
  int? _selectedPeriodMonths; // selected booking duration in months

  // Tenant information
  Map<String, dynamic> _tenantData = {};
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedGender = 'Male';

  // Document selection
  List<Map<String, dynamic>> _availableDocuments = [];

  // Required documents for booking - all must be provided
  Map<String, Map<String, dynamic>?> _selectedDocuments = {
    'Proof of Identity': null,
    'Proof of Address': null,
    'PAN Card': null,
    'Passport Photo': null,
  };

  // Track uploaded files for each document type
  Map<String, File?> _uploadedFiles = {
    'Proof of Identity': null,
    'Proof of Address': null,
    'PAN Card': null,
    'Passport Photo': null,
  };

  // Payment
  late Razorpay _razorpay;
  bool _paymentCompleted = false;
  String? _paymentId;
  String? _paymentSignature;
  DateTime? _paymentCompletedAt;
  bool _isSubmitting = false;
  bool _isUnavailable = false;

  // Notes
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _initializeRazorpay();
    _loadTenantData();
    _loadTenantDocuments();
    _checkAvailability();
    _animationController.forward();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _loadTenantData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      try {
        final tenantDetails = await Api.getUserDetailsByEmail(user!.email!);
        if (tenantDetails != null && mounted) {
          setState(() {
            _tenantData = tenantDetails;
            _firstNameController.text = tenantDetails['firstName'] ?? '';
            _lastNameController.text = tenantDetails['lastName'] ?? '';
            _phoneController.text = tenantDetails['mobileNumber'] ?? '';
            _selectedGender = tenantDetails['gender'] ?? 'Male';

            // Ensure selected gender is allowed by the property
            final availableGenders = _getAvailableGenders();
            if (!availableGenders.contains(_selectedGender)) {
              _selectedGender =
                  availableGenders.isNotEmpty ? availableGenders.first : 'Male';
            }
          });
        }
      } catch (e) {
        print('Error loading tenant data: $e');
      }
    }
  }

  Future<void> _loadTenantDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      try {
        final documents = await Api.getTenantDocuments(user!.email!);
        if (mounted) {
          setState(() {
            _availableDocuments = documents;
          });
        }
      } catch (e) {
        print('Error loading documents: $e');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() {
      _paymentCompleted = true;
      _paymentId = response.paymentId;
      _paymentSignature = response.signature;
      _paymentCompletedAt = DateTime.now();
    });
    Models.showSuccessSnackBar(context, 'Payment successful!');

    // Automatically proceed to next step after successful payment
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextStep();
      }
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Models.showErrorSnackBar(context, 'Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Models.showInfoSnackBar(context, 'External Wallet: ${response.walletName}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _nextStep() {
    if (_isUnavailable) {
      Models.showWarningSnackBar(
          context, 'This property is no longer available for booking.');
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Property & Move-in Details
        return _selectedCheckInDate != null && _selectedPeriodMonths != null;
      case 1: // Tenant Information
        return _firstNameController.text.isNotEmpty &&
            _lastNameController.text.isNotEmpty &&
            _phoneController.text.isNotEmpty;
      case 2: // Document Selection
        if (!_areAllDocumentsSelected()) {
          Models.showWarningSnackBar(
              context, 'Please select all required documents to continue');
          return false;
        }
        return true;
      case 3: // Payment
        return _paymentCompleted;
      case 4: // Review
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitBooking() async {
    if (_isUnavailable) {
      Models.showWarningSnackBar(
          context, 'This property is no longer available for booking.');
      return;
    }
    await LoadingStateManager.runWithLoader<Map<String, dynamic>?>(
      context: context,
      loadingState: (loading) {
        if (mounted) {
          setState(() => _isSubmitting = loading);
        }
      },
      operation: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == null) {
          throw Exception('User not authenticated');
        }

        // Final availability check just before creating booking
        try {
          final ownerEmail = widget.propertyData['ownerEmail']?.toString();
          final propertyId = widget.propertyData['id']?.toString();
          if (ownerEmail != null &&
              ownerEmail.isNotEmpty &&
              propertyId != null &&
              propertyId.isNotEmpty) {
            final data = await Api.getPropertyById(ownerEmail, propertyId,
                checkUnavailable: true);
            if (data == null || data['isAvailable'] != true) {
              throw Exception('Property is unavailable');
            }
          }
        } catch (e) {
          throw Exception('Property is unavailable');
        }

        // Prepare booking data
        final propertyData =
            BookingPropertyData.fromPropertyData(widget.propertyData);
        final tenantData = TenantData(
          tenantEmail: user!.email!,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          mobileNumber: _phoneController.text,
          gender: _selectedGender,
          profilePhotoUrl: _tenantData['profilePhotoUrl'],
        );

        // Prepare all required documents
        Map<String, dynamic> allDocuments = {};
        for (String docType in _selectedDocuments.keys) {
          final doc = _selectedDocuments[docType];
          if (doc != null) {
            if (doc['isUploaded'] == true && doc['tempFile'] != null) {
              // Upload to cloud storage
              final url = await Api.uploadImageToCloudinary(
                doc['tempFile'] as File,
                'tenant_documents/${user.email!.replaceAll('@', '_')}',
              );

              allDocuments[docType] = {
                'documentId': DateTime.now().millisecondsSinceEpoch.toString(),
                'documentType': docType,
                'documentUrl': url,
                'documentName': docType,
                'uploadedAt': DateTime.now().toIso8601String(),
              };
            } else {
              // Use existing document
              allDocuments[docType] = doc;
            }
          }
        }

        // Extract owner email and resolve owner details from Owners collection
        final String ownerEmail = widget.propertyData['ownerEmail'] ?? '';
        String resolvedOwnerName = '';
        String resolvedOwnerMobile = '';

        try {
          if (ownerEmail.isNotEmpty) {
            final ownerDoc = await Api.getOwnerDetailsByEmail(ownerEmail);
            if (ownerDoc != null) {
              resolvedOwnerName = (ownerDoc['fullName'] ??
                      ownerDoc['displayName'] ??
                      ownerDoc['name'] ??
                      '')
                  .toString()
                  .trim();
              resolvedOwnerMobile =
                  (ownerDoc['mobileNumber'] ?? ownerDoc['phone'] ?? '')
                      .toString()
                      .trim();
            }
          }
        } catch (e) {
          // If lookup fails, continue with fallbacks below
          debugPrint('Owner details lookup failed: $e');
        }

        // Fallbacks: try property payload then email prefix
        if (resolvedOwnerName.isEmpty) {
          final propOwnerName = (widget.propertyData['fullName'] ??
                  widget.propertyData['ownerName'] ??
                  '')
              .toString()
              .trim();
          if (propOwnerName.isNotEmpty) {
            resolvedOwnerName = propOwnerName;
          } else if (ownerEmail.isNotEmpty) {
            resolvedOwnerName = ownerEmail.split('@').first;
          }
        }
        if (resolvedOwnerMobile.isEmpty) {
          resolvedOwnerMobile = (widget.propertyData['ownerPhone'] ??
                      widget.propertyData['ownerMobileNumber'] ??
                      widget.propertyData['ownerContact'])
                  ?.toString() ??
              '';
        }

        // Create booking
        final bookingId = await Api.createBooking(
          tenantEmail: user.email!,
          ownerEmail: ownerEmail,
          propertyId: widget.propertyData['id'] ?? '',
          propertyData: propertyData.toMap(),
          tenantData: tenantData.toMap(),
          idProof: allDocuments, // Use all documents
          checkInDate: _selectedCheckInDate!,
          bookingPeriodMonths: _selectedPeriodMonths ?? 1,
          amount: propertyData.totalAmount,
          ownerName: resolvedOwnerName.isNotEmpty ? resolvedOwnerName : null,
          ownerMobileNumber:
              resolvedOwnerMobile.isNotEmpty ? resolvedOwnerMobile : null,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          paymentId: _paymentId,
          paymentSignature: _paymentSignature,
          paymentCompletedAt: _paymentCompletedAt,
          paymentStatus: _paymentCompleted ? 'Completed' : 'Pending',
        );

        // Generate and upload PDF receipt if payment was completed
        String? receiptUrl;
        if (_paymentCompleted && _paymentId != null) {
          try {
            final rentAmount = _parsePrice(widget.propertyData['price']);
            final depositAmount = _parsePrice(
                widget.propertyData['securityDeposit'] ??
                    widget.propertyData['deposit']);
            final ownerName = resolvedOwnerName;

            receiptUrl = await PdfReceiptGenerator.generateAndUploadReceipt(
              bookingId: bookingId,
              tenantData: tenantData.toMap(),
              propertyData: propertyData.toMap(),
              ownerData: {
                'ownerName': ownerName,
                'mobileNumber': resolvedOwnerMobile,
                'email': ownerEmail,
              },
              paymentData: {
                'paymentId': _paymentId,
                'paymentSignature': _paymentSignature,
                'status': 'Captured',
                'paymentMethod': 'Razorpay',
                'currency': 'INR',
              },
              checkInDate: _selectedCheckInDate!,
              checkoutDate: (() {
                final ci = _selectedCheckInDate!;
                final months = _selectedPeriodMonths ?? 1;
                final nm = ci.month + months;
                final ny = ci.year + ((nm - 1) ~/ 12);
                final nmon = ((nm - 1) % 12) + 1;
                final lastDay = DateTime(ny, nmon + 1, 0).day;
                final nd = ci.day.clamp(1, lastDay);
                return DateTime(ny, nmon, nd);
              })(),
              bookingPeriodMonths: _selectedPeriodMonths ?? 1,
              paymentDate: _paymentCompletedAt!,
              rentAmount: rentAmount,
              depositAmount: depositAmount,
              notes:
                  _notesController.text.isEmpty ? null : _notesController.text,
            );

            // Update booking with receipt URL
            await Api.updateBookingWithReceiptUrl(
              bookingId: bookingId,
              tenantEmail: user.email!,
              ownerEmail: ownerEmail,
              receiptUrl: receiptUrl,
              ownerName:
                  resolvedOwnerName.isNotEmpty ? resolvedOwnerName : null,
              ownerMobileNumber:
                  resolvedOwnerMobile.isNotEmpty ? resolvedOwnerMobile : null,
            );
          } catch (e) {
            // Don't fail the booking if receipt generation fails
            debugPrint('Error generating PDF receipt: $e');
          }
        }

        return {
          'receiptUrl': receiptUrl,
        };
      },
      onSuccess: (result) {
        final String? receiptUrl = result?['receiptUrl'] as String?;
        Models.showSuccessSnackBar(
            context,
            _paymentCompleted && receiptUrl != null && receiptUrl.isNotEmpty
                ? 'Booking submitted successfully with receipt!'
                : 'Booking request submitted successfully!');
        Navigator.of(context).pop(true);
      },
      onError: (e) {
        Models.showErrorSnackBar(context, 'Error submitting booking: $e');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Book Property',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPropertyDetailsStep(),
                      _buildTenantInfoStep(),
                      _buildDocumentStep(),
                      _buildPaymentStep(),
                      _buildReviewStep(),
                    ],
                  ),
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : isActive
                            ? AppConfig.primaryColor
                            : Colors.grey[300],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.grey[300],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPropertyDetailsStep() {
    final rent = _parsePrice(widget.propertyData['price']);
    final deposit = _parsePrice(widget.propertyData['securityDeposit']);
    final minMonths =
        _minBookingMonths(widget.propertyData['minimumBookingPeriod']);
    final options = _allowedPeriodOptions(minMonths);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Property & Move-in Details',
              'Review property details and select your move-in date'),
          const SizedBox(height: 20),

          // Property Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      widget.propertyData['images']?.isNotEmpty == true
                          ? widget.propertyData['images'][0]
                          : 'https://via.placeholder.com/400x200',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.propertyData['title'] ?? 'Property',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.propertyData['address'] ?? 'Address',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPriceInfo(
                              'Monthly Rent', '₹${rent.toStringAsFixed(0)}'),
                          _buildPriceInfo('Security Deposit',
                              '₹${deposit.toStringAsFixed(0)}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Minimum Booking Period
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                color: AppConfig.primaryColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Minimum Booking Period: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              widget.propertyData['minimumBookingPeriod'] ??
                                  'Not specified',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Move-in Date Selection
          Text(
            'Select Move-in Date',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCheckInDate != null
                      ? AppConfig.primaryColor
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _selectedCheckInDate != null
                        ? AppConfig.primaryColor
                        : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _selectedCheckInDate != null
                        ? DateFormat('MMM dd, yyyy')
                            .format(_selectedCheckInDate!)
                        : 'Select move-in date',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedCheckInDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Booking period selection
          Text(
            'Select Booking Period',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPeriodMonths != null
                    ? AppConfig.primaryColor
                    : Colors.grey[300]!,
              ),
            ),
            child: DropdownButton<int>(
              value: _selectedPeriodMonths,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Select period (months)'),
              items: options
                  .map((m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text('$m month${m > 1 ? 's' : ''}'),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedPeriodMonths = val);
              },
            ),
          ),
          if (_selectedCheckInDate != null && _selectedPeriodMonths != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.event_available,
                      size: 18, color: AppConfig.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Checkout Date: ${DateFormat('MMM dd, yyyy').format(_computeCheckoutDate(_selectedCheckInDate!, _selectedPeriodMonths!))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
                'Your Information', 'Verify and update your personal details'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Text(
              'Gender',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _getAvailableGenders().map((gender) {
                final isSelected = _selectedGender == gender;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedGender = gender),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppConfig.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppConfig.primaryColor
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        gender,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Required Documents',
              'All documents are required for booking completion'),
          const SizedBox(height: 20),

          Text(
            'Please provide all the following documents:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),

          // Build document requirement cards for each required document
          ..._selectedDocuments.keys.map((docType) {
            return _buildDocumentRequirementCard(docType);
          }).toList(),

          const SizedBox(height: 20),

          // Show completion status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _areAllDocumentsSelected()
                  ? Colors.green[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _areAllDocumentsSelected()
                    ? Colors.green[300]!
                    : Colors.orange[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _areAllDocumentsSelected()
                      ? Icons.check_circle
                      : Icons.report_gmailerrorred_outlined,
                  color: _areAllDocumentsSelected()
                      ? Colors.green[600]
                      : Colors.orange[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _areAllDocumentsSelected()
                        ? 'All required documents are ready!'
                        : 'Please select all required documents to continue.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _areAllDocumentsSelected()
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRequirementCard(String docType) {
    final selectedDoc = _selectedDocuments[docType];
    final isCompleted = selectedDoc != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.report_gmailerrorred_outlined,
                color: isCompleted ? Colors.green[600] : Colors.orange[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  docType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.green[700] : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                      selectedDoc['isUploaded'] == true
                          ? Icons.upload_file
                          : Icons.description,
                      size: 16,
                      color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDoc['name'] ??
                              selectedDoc['documentType'] ??
                              'Document',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectedDoc['isUploaded'] == true)
                          Text(
                            'Newly uploaded',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _changeDocument(docType),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppConfig.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDocumentForType(docType),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppConfig.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Select Document',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _uploadDocumentForType(docType),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Upload New',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _areAllDocumentsSelected() {
    return _selectedDocuments.values.every((doc) => doc != null);
  }

  void _selectDocumentForType(String docType) {
    final availableDocsForType = _availableDocuments.where((doc) {
      final docTypeFromDoc = doc['documentType'] ?? doc['name'] ?? '';
      return _isDocumentTypeMatch(docTypeFromDoc, docType);
    }).toList();

    if (availableDocsForType.isNotEmpty) {
      _showDocumentSelectionDialog(docType, availableDocsForType);
    } else {
      _showUploadDocumentDialog(docType);
    }
  }

  void _changeDocument(String docType) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change $docType',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how you want to provide this document:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectDocumentForType(docType);
                  },
                  icon: Icon(Icons.folder, color: Colors.white),
                  label: Text('Select from Existing Documents',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadDocumentForType(docType);
                  },
                  icon: Icon(Icons.camera_alt, color: Colors.white),
                  label: Text('Upload New Document',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isDocumentTypeMatch(String docTypeFromDoc, String requiredType) {
    final doc = docTypeFromDoc.toLowerCase();
    final required = requiredType.toLowerCase();

    switch (required) {
      case 'proof of identity':
        // Exclude any passport-size photograph entries
        final isPhoto = (doc.contains('photo') || doc.contains('photograph')) &&
            doc.contains('passport');
        if (isPhoto) return false;
        return doc.contains('aadhaar') ||
            doc.contains('passport') ||
            doc.contains('voter') ||
            doc.contains('driver') ||
            doc.contains('identity');
      case 'proof of address':
        return doc.contains('address') ||
            doc.contains('utility') ||
            doc.contains('bank') ||
            doc.contains('rental');
      case 'pan card':
        return doc.contains('pan');
      case 'passport photo':
        return doc.contains('passport') && doc.contains('photo') ||
            doc.contains('photograph');
      default:
        return false;
    }
  }

  void _uploadDocumentForType(String docType) async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upload $docType',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, ImageSource.camera),
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    label: Text('Take Photo',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, ImageSource.gallery),
                    icon: Icon(Icons.photo_library, color: Colors.white),
                    label: Text('Choose from Gallery',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _uploadedFiles[docType] = File(image.path);
            // Create a temporary document object for uploaded file
            _selectedDocuments[docType] = {
              'documentId': 'temp_${DateTime.now().millisecondsSinceEpoch}',
              'documentType': docType,
              'name': '$docType - Uploaded',
              'isUploaded': true,
              'tempFile': File(image.path),
            };
          });

          Models.showSuccessSnackBar(
              context, '$docType uploaded successfully!');
        }
      }
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error uploading document: $e');
    }
  }

  void _showDocumentSelectionDialog(
      String docType, List<Map<String, dynamic>> availableDocs) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select $docType',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...availableDocs
                  .map((doc) => ListTile(
                        leading: Icon(Icons.description),
                        title: Text(
                            doc['name'] ?? doc['documentType'] ?? 'Document'),
                        subtitle:
                            doc['option'] != null ? Text(doc['option']) : null,
                        onTap: () {
                          setState(() {
                            _selectedDocuments[docType] = doc;
                          });
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showUploadDocumentDialog(docType);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                  ),
                  child: Text('Upload New Document',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUploadDocumentDialog(String docType) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload $docType',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please upload this document from your tenant profile first, then return to complete booking. or Select the Upload New Document Button to upload now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentStep() {
    final rent = _parsePrice(widget.propertyData['price']);
    final deposit = _parsePrice(widget.propertyData['securityDeposit']);
    final total = rent + deposit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle(
              'Payment', 'Pay security deposit and first month rent'),
          const SizedBox(height: 20),

          // Payment breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Breakdown',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaymentRow('Monthly Rent', rent),
                const SizedBox(height: 8),
                _buildPaymentRow('Security Deposit', deposit),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (!_paymentCompleted)
            ElevatedButton(
              onPressed: () {
                if (_isUnavailable) {
                  Models.showWarningSnackBar(context,
                      'This property is no longer available for booking.');
                  return;
                }
                _makePayment(total);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Pay Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[600],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Successful',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[600],
                          ),
                        ),
                        if (_paymentId != null)
                          Text(
                            'Payment ID: $_paymentId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final rent = _parsePrice(widget.propertyData['price']);
    final deposit = _parsePrice(widget.propertyData['securityDeposit']);
    final checkout = (_selectedCheckInDate != null &&
            _selectedPeriodMonths != null)
        ? _computeCheckoutDate(_selectedCheckInDate!, _selectedPeriodMonths!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Review & Submit',
              'Review your booking details before submitting'),
          const SizedBox(height: 20),

          // Property summary
          _buildReviewCard(
            'Property Details',
            [
              _buildReviewItem('Property', widget.propertyData['title'] ?? ''),
              _buildReviewItem('Address', widget.propertyData['address'] ?? ''),
              _buildReviewItem('Type',
                  '${widget.propertyData['roomType'] ?? ''} ${widget.propertyData['propertyType'] ?? ''}'),
              _buildReviewItem('Monthly Rent', '₹${rent.toStringAsFixed(0)}'),
              _buildReviewItem(
                  'Security Deposit', '₹${deposit.toStringAsFixed(0)}'),
            ],
          ),

          const SizedBox(height: 16),

          // Tenant summary
          _buildReviewCard(
            'Your Details',
            [
              _buildReviewItem('Name',
                  '${_firstNameController.text} ${_lastNameController.text}'),
              _buildReviewItem('Phone', _phoneController.text),
              _buildReviewItem('Gender', _selectedGender),
              _buildReviewItem(
                  'Move-in Date',
                  _selectedCheckInDate != null
                      ? DateFormat('MMM dd, yyyy').format(_selectedCheckInDate!)
                      : ''),
              if (_selectedPeriodMonths != null)
                _buildReviewItem('Period',
                    '${_selectedPeriodMonths} month${(_selectedPeriodMonths ?? 1) > 1 ? 's' : ''}'),
              if (checkout != null)
                _buildReviewItem('Checkout Date',
                    DateFormat('MMM dd, yyyy').format(checkout)),
            ],
          ),

          const SizedBox(height: 16),

          // Document summary
          _buildReviewCard(
            'Required Documents',
            [
              for (String docType in _selectedDocuments.keys)
                _buildReviewItem(
                  docType,
                  _selectedDocuments[docType] != null
                      ? (_selectedDocuments[docType]!['isUploaded'] == true
                          ? 'Newly Uploaded'
                          : 'Existing Document')
                      : 'Not Selected',
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment summary
          _buildReviewCard(
            'Payment',
            [
              _buildReviewItem(
                  'Amount Paid', '₹${(rent + deposit).toStringAsFixed(0)}'),
              _buildReviewItem('Payment Status',
                  _paymentCompleted ? 'Completed' : 'Pending'),
              if (_paymentId != null)
                _buildReviewItem('Payment ID', _paymentId!),
              if (_paymentCompletedAt != null)
                _buildReviewItem(
                    'Payment Time',
                    DateFormat('MMM dd, yyyy HH:mm')
                        .format(_paymentCompletedAt!)),
              _buildReviewItem('Payment Method', 'Razorpay'),
            ],
          ),

          const SizedBox(height: 16),

          // Notes
          Text(
            'Additional Notes (Optional)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any special requests or notes for the owner...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppConfig.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConfig.primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _currentStep == 3 // Payment step
                ? Container() // Hide Next button during payment step
                : ElevatedButton(
                    onPressed: _currentStep == _totalSteps - 1
                        ? _submitBooking
                        : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep == _totalSteps - 1
                          ? 'Submit Booking'
                          : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Helper widgets and methods
  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  Widget _buildPaymentRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppConfig.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedCheckInDate) {
      setState(() {
        _selectedCheckInDate = picked;
      });
    }
  }

  void _makePayment(double amount) {
    if (_isUnavailable) {
      Models.showWarningSnackBar(
          context, 'This property is no longer available for booking.');
      return;
    }
    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag', // Replace with your Razorpay key
      'amount': (amount * 100).toInt(), // Razorpay accepts amount in paisa
      'name': 'HousingHub',
      'description': 'Property Booking Payment',
      'prefill': {
        'contact': _phoneController.text,
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'theme': {
        'color': AppConfig.primaryColor,
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      Models.showErrorSnackBar(context, 'Error opening payment gateway');
    }
  }

  List<String> _getAvailableGenders() {
    final bool maleAllowed = widget.propertyData['maleAllowed'] ?? false;
    final bool femaleAllowed = widget.propertyData['femaleAllowed'] ?? false;

    List<String> availableGenders = [];

    if (maleAllowed) {
      availableGenders.add('Male');
    }
    if (femaleAllowed) {
      availableGenders.add('Female');
    }

    // If no specific gender is allowed, show all options as fallback
    if (availableGenders.isEmpty) {
      return ['Male', 'Female', 'Other'];
    }

    return availableGenders;
  }

  Future<void> _checkAvailability() async {
    try {
      final ownerEmail = widget.propertyData['ownerEmail']?.toString();
      final propertyId = widget.propertyData['id']?.toString();
      if (ownerEmail == null ||
          ownerEmail.isEmpty ||
          propertyId == null ||
          propertyId.isEmpty) return;

      // Respect inline data if explicitly unavailable
      if (widget.propertyData['isAvailable'] == false ||
          widget.propertyData['available'] == false) {
        if (!mounted) return;
        setState(() => _isUnavailable = true);
        return;
      }

      final data = await Api.getPropertyById(ownerEmail, propertyId,
          checkUnavailable: true);
      if (!mounted) return;
      setState(() {
        _isUnavailable = (data == null || data['isAvailable'] != true);
      });
    } catch (e) {
      // Ignore errors, default to available
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  // Helpers for booking period
  int _minBookingMonths(dynamic raw) {
    if (raw == null) return 1;
    final s = raw.toString().toLowerCase().trim();
    final match = RegExp(r'(\d+)').firstMatch(s);
    if (match != null) {
      final v = int.tryParse(match.group(1)!);
      if (v != null && v > 0) return v;
    }
    if (s.contains('year')) return 12;
    if (s.contains('month')) return 1;
    return 1;
  }

  List<int> _allowedPeriodOptions(int minMonths) {
    final base = [1, 3, 6, 12];
    return base.where((m) => m >= minMonths).toList();
  }

  DateTime _computeCheckoutDate(DateTime checkIn, int months) {
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
}
