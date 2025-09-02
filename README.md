# HousingHub

<p align="center">
  <img src="assets/images/Logo.png" alt="HousingHub Logo" width="200"/>
</p>

## 📱 Project Overview

HousingHub is a mobile application that connects tenants searching for PG accommodations with property owners who want to list their properties. The app focuses on easy property discovery, seamless booking management, and direct tenant-owner communication.

## ⚙️ Tech Stack

- **Frontend**: Flutter (cross-platform, Android-first)
- **Backend & Database**: Firebase
  - Firestore (NoSQL Database)
  - Firebase Authentication (Email/Password and Google Sign-in)
  - Firebase Storage (for property images)
- **Payment Integration**: Razorpay (for booking payments)

## 🗂️ Database Schema

### Firestore Collections Structure

- **Owners Collection**
  - Document ID = owner's email
  - Fields: fullName, mobileNumber, city, state, createdAt, uid

- **Tenants Collection**
  - Document ID = tenant's email
  - Fields: firstName, lastName, mobileNumber, gender, createdAt, uid

- **Properties Collection**
  - Path: Properties/{ownerEmail}/Available/{propertyId}
  - Path: Properties/{ownerEmail}/Unavailable/{propertyId}
  - Fields:
    - id (propertyId)
    - title
    - price
    - address, city, state, pincode
    - propertyType (Apartment, House, Villa, PG/Hostel, etc.)
    - description
    - roomType (1BHK, 2BHK, etc.)
    - amenities (WiFi, Parking, Laundry, AC, etc.)
    - images (URLs from Cloudinary)
    - video (optional)
    - isAvailable (true/false)
    - maleAllowed, femaleAllowed (gender restrictions)
    - bedrooms, bathrooms, squareFootage
    - createdAt, updatedAt

## 🔑 App Features

### Owner Module
- **Authentication**
  - Login & Signup with Email/Password
  - Google Sign-in integration
- **Property Management**
  - Add new properties with details and images
  - Edit existing property information
  - Delete properties
  - Toggle property availability status
  - View property listings (All/Available/Unavailable)
- **Profile Management**
  - Update personal details

### Tenant Module
- **Authentication**
  - Login & Signup with Email/Password
  - Google Sign-in integration
- **Property Discovery**
  - Browse available properties
  - View detailed property information
  - Filter properties by various criteria
- **Property Booking**
  - Request property booking
  - View booking status
- **Profile Management**
  - Update personal details

## 🎨 UI Components

- **Color Scheme**
  - Primary: Defined in AppConfig
  - Success: Green for available properties
  - Danger: Red for unavailable properties

- **Screens**
  - Login & Signup
  - Property listings
  - Property details
  - Add/Edit property
  - User profile

## 📱 Screenshots

*(Coming soon)*

## 🚀 Installation & Setup

1. **Clone the repository**
   ```
   git clone https://github.com/harsh308050/HousingHub.git
   ```

2. **Install dependencies**
   ```
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Add Android & iOS apps to your Firebase project
   - Download and add google-services.json to android/app/
   - Download and add GoogleService-Info.plist to ios/Runner/

4. **Cloudinary Setup**
   - Create a Cloudinary account for image storage
   - Update the Cloudinary credentials in the API.dart file

5. **Run the app**
   ```
   flutter run
   ```

## 🔮 Future Enhancements

- Implement in-app messaging between tenants and owners
- Add Google Maps integration for property locations
- Implement push notifications for booking updates
- Add advanced filtering options
- Add payment integration for secure transactions
- Implement document verification for property owners

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Contributors

- Harsh (Developer)

---

*HousingHub - Find your perfect accommodation*
