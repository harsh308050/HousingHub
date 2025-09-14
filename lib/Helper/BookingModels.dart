import 'package:cloud_firestore/cloud_firestore.dart';

/// Booking Status Enum
enum BookingStatus {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected'),
  completed('Completed');

  const BookingStatus(this.displayName);
  final String displayName;

  static BookingStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'accepted':
      case 'approved': // Support legacy 'approved' status
        return BookingStatus.accepted;
      case 'rejected':
        return BookingStatus.rejected;
      case 'completed':
        return BookingStatus.completed;
      default:
        return BookingStatus.pending;
    }
  }

  String toFirestore() {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.completed:
        return 'Completed';
    }
  }
}

// Payment Status Enum
enum PaymentStatus {
  pending('Pending'),
  paid('Paid'),
  failed('Failed'),
  refunded('Refunded'),
  refundPending('RefundPending');

  const PaymentStatus(this.displayName);
  final String displayName;

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'refundpending':
        return PaymentStatus.refundPending;
      default:
        return PaymentStatus.pending;
    }
  }

  String toFirestore() {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.refundPending:
        return 'RefundPending';
    }
  }
}

// Payment Information Model
class PaymentInfo {
  final String? transactionId;
  final double amount;
  final PaymentStatus status;
  final String? refundId;
  final String? refundStatus;
  final DateTime? paymentDate;
  final DateTime? refundDate;
  final String currency;
  final String paymentMethod;

  PaymentInfo({
    this.transactionId,
    required this.amount,
    required this.status,
    this.refundId,
    this.refundStatus,
    this.paymentDate,
    this.refundDate,
    this.currency = 'INR',
    this.paymentMethod = 'Razorpay',
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'status': status.toFirestore(),
      'refundId': refundId,
      'refundStatus': refundStatus,
      'paymentDate':
          paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'refundDate': refundDate != null ? Timestamp.fromDate(refundDate!) : null,
      'currency': currency,
      'paymentMethod': paymentMethod,
    };
  }

  factory PaymentInfo.fromMap(Map<String, dynamic> map) {
    return PaymentInfo(
      transactionId: map['transactionId']?.toString(),
      amount: (map['amount'] ?? 0).toDouble(),
      status: PaymentStatus.fromString(map['status'] ?? 'pending'),
      refundId: map['refundId']?.toString(),
      refundStatus: map['refundStatus']?.toString(),
      paymentDate: map['paymentDate'] != null
          ? (map['paymentDate'] as Timestamp).toDate()
          : null,
      refundDate: map['refundDate'] != null
          ? (map['refundDate'] as Timestamp).toDate()
          : null,
      currency: map['currency']?.toString() ?? 'INR',
      paymentMethod: map['paymentMethod']?.toString() ?? 'Razorpay',
    );
  }
}

// Tenant Data Model
class TenantData {
  final String tenantEmail;
  final String firstName;
  final String lastName;
  final String mobileNumber;
  final String gender;
  final String? profilePhotoUrl;

  TenantData({
    required this.tenantEmail,
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.gender,
    this.profilePhotoUrl,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'tenantEmail': tenantEmail,
      'firstName': firstName,
      'lastName': lastName,
      'mobileNumber': mobileNumber,
      'gender': gender,
      'profilePhotoUrl': profilePhotoUrl,
      'fullName': fullName,
    };
  }

  factory TenantData.fromMap(Map<String, dynamic> map) {
    return TenantData(
      tenantEmail: map['tenantEmail']?.toString() ?? '',
      firstName: map['firstName']?.toString() ?? '',
      lastName: map['lastName']?.toString() ?? '',
      mobileNumber: map['mobileNumber']?.toString() ?? '',
      gender: map['gender']?.toString() ?? '',
      profilePhotoUrl: map['profilePhotoUrl']?.toString(),
    );
  }
}

// Property Data Model for Booking
class BookingPropertyData {
  final String propertyId;
  final String title;
  final String address;
  final String city;
  final String state;
  final String propertyType;
  final String roomType;
  final double rent;
  final double deposit;
  final List<String> amenities;
  final List<String> images;
  final String ownerEmail;
  final String? ownerName;
  final bool maleAllowed;
  final bool femaleAllowed;

  BookingPropertyData({
    required this.propertyId,
    required this.title,
    required this.address,
    required this.city,
    required this.state,
    required this.propertyType,
    required this.roomType,
    required this.rent,
    required this.deposit,
    required this.amenities,
    required this.images,
    required this.ownerEmail,
    this.ownerName,
    required this.maleAllowed,
    required this.femaleAllowed,
  });

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'title': title,
      'address': address,
      'city': city,
      'state': state,
      'propertyType': propertyType,
      'roomType': roomType,
      'rent': rent,
      'deposit': deposit,
      'amenities': amenities,
      'images': images,
      'ownerEmail': ownerEmail,
      'ownerName': ownerName,
      'maleAllowed': maleAllowed,
      'femaleAllowed': femaleAllowed,
    };
  }

  factory BookingPropertyData.fromMap(Map<String, dynamic> map) {
    return BookingPropertyData(
      propertyId: map['propertyId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      propertyType: map['propertyType']?.toString() ?? '',
      roomType: map['roomType']?.toString() ?? '',
      rent: (map['rent'] ?? 0).toDouble(),
      deposit: (map['deposit'] ?? 0).toDouble(),
      amenities: List<String>.from(map['amenities'] ?? []),
      images: List<String>.from(map['images'] ?? []),
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      ownerName: map['ownerName']?.toString(),
      maleAllowed: map['maleAllowed'] ?? false,
      femaleAllowed: map['femaleAllowed'] ?? false,
    );
  }

  // Factory method to create from property data
  factory BookingPropertyData.fromPropertyData(
      Map<String, dynamic> propertyData) {
    return BookingPropertyData(
      propertyId: propertyData['id']?.toString() ?? '',
      title: propertyData['title']?.toString() ?? '',
      address: propertyData['address']?.toString() ?? '',
      city: propertyData['city']?.toString() ?? '',
      state: propertyData['state']?.toString() ?? '',
      propertyType: propertyData['propertyType']?.toString() ?? '',
      roomType: propertyData['roomType']?.toString() ?? '',
      rent: _parsePrice(propertyData['price']),
      deposit: _parsePrice(
          propertyData['securityDeposit'] ?? propertyData['deposit']),
      amenities: List<String>.from(propertyData['amenities'] ?? []),
      images: List<String>.from(propertyData['images'] ?? []),
      ownerEmail: propertyData['ownerEmail']?.toString() ?? '',
      ownerName: propertyData['ownerName']?.toString(),
      maleAllowed: propertyData['maleAllowed'] ?? false,
      femaleAllowed: propertyData['femaleAllowed'] ?? false,
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  // Calculate total amount (rent + deposit)
  double get totalAmount => rent + deposit;
}

// ID Proof Document Model
class IdProofDocument {
  final String documentId;
  final String documentType;
  final String documentUrl;
  final String documentName;
  final DateTime uploadedAt;

  IdProofDocument({
    required this.documentId,
    required this.documentType,
    required this.documentUrl,
    required this.documentName,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'documentType': documentType,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  factory IdProofDocument.fromMap(Map<String, dynamic> map) {
    return IdProofDocument(
      documentId: map['documentId']?.toString() ?? '',
      documentType: map['documentType']?.toString() ?? '',
      documentUrl: map['documentUrl']?.toString() ?? '',
      documentName: map['documentName']?.toString() ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// Main Booking Model
class Booking {
  final String bookingId;
  final String tenantEmail;
  final String ownerEmail;
  final String propertyId;
  final BookingPropertyData propertyData;
  final TenantData tenantData;
  final IdProofDocument idProof;
  final BookingStatus status;
  final PaymentInfo paymentInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final String? notes;
  final String? rejectionReason;

  Booking({
    required this.bookingId,
    required this.tenantEmail,
    required this.ownerEmail,
    required this.propertyId,
    required this.propertyData,
    required this.tenantData,
    required this.idProof,
    required this.status,
    required this.paymentInfo,
    required this.createdAt,
    required this.updatedAt,
    required this.checkInDate,
    this.checkOutDate,
    this.notes,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'tenantEmail': tenantEmail,
      'ownerEmail': ownerEmail,
      'propertyId': propertyId,
      'propertyData': propertyData.toMap(),
      'tenantData': tenantData.toMap(),
      'idProof': idProof.toMap(),
      'status': status.toFirestore(),
      'paymentInfo': paymentInfo.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'checkInDate': Timestamp.fromDate(checkInDate),
      'checkOutDate':
          checkOutDate != null ? Timestamp.fromDate(checkOutDate!) : null,
      'notes': notes,
      'rejectionReason': rejectionReason,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      bookingId: map['bookingId']?.toString() ?? '',
      tenantEmail: map['tenantEmail']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      propertyId: map['propertyId']?.toString() ?? '',
      propertyData: BookingPropertyData.fromMap(map['propertyData'] ?? {}),
      tenantData: TenantData.fromMap(map['tenantData'] ?? {}),
      idProof: IdProofDocument.fromMap(map['idProof'] ?? {}),
      status: BookingStatus.fromString(map['status'] ?? 'pending'),
      paymentInfo: PaymentInfo.fromMap(map['paymentInfo'] ?? {}),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      checkInDate: map['checkInDate'] != null
          ? (map['checkInDate'] as Timestamp).toDate()
          : DateTime.now(),
      checkOutDate: map['checkOutDate'] != null
          ? (map['checkOutDate'] as Timestamp).toDate()
          : null,
      notes: map['notes']?.toString(),
      rejectionReason: map['rejectionReason']?.toString(),
    );
  }

  // Helper methods
  bool get isPending => status == BookingStatus.pending;
  bool get isAccepted => status == BookingStatus.accepted;
  bool get isRejected => status == BookingStatus.rejected;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isActive => status == BookingStatus.accepted;

  double get totalAmount => propertyData.rent + propertyData.deposit;

  String get statusDisplayName => status.displayName;

  String get propertyTitle => propertyData.title;

  String get propertyAddress => '${propertyData.address}, ${propertyData.city}';

  String get tenantFullName => tenantData.fullName;

  // Create a copy with updated status
  Booking copyWith({
    BookingStatus? status,
    String? rejectionReason,
    DateTime? checkOutDate,
    String? notes,
    PaymentInfo? paymentInfo,
  }) {
    return Booking(
      bookingId: bookingId,
      tenantEmail: tenantEmail,
      ownerEmail: ownerEmail,
      propertyId: propertyId,
      propertyData: propertyData,
      tenantData: tenantData,
      idProof: idProof,
      status: status ?? this.status,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      checkInDate: checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

// Notification Model
class BookingNotification {
  final String notificationId;
  final String recipientEmail;
  final String type;
  final String message;
  final String bookingId;
  final DateTime createdAt;
  final bool isRead;

  BookingNotification({
    required this.notificationId,
    required this.recipientEmail,
    required this.type,
    required this.message,
    required this.bookingId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientEmail': recipientEmail,
      'type': type,
      'message': message,
      'bookingId': bookingId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory BookingNotification.fromMap(Map<String, dynamic> map) {
    return BookingNotification(
      notificationId: map['notificationId']?.toString() ?? '',
      recipientEmail: map['recipientEmail']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      bookingId: map['bookingId']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
