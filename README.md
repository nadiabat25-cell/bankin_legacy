# 🏦 Secure Banking Digital Legacy Management System

A Flutter-based mobile application for managing digital banking credentials and ensuring secure inheritance through encrypted storage and automated beneficiary access.

## 📱 Features

- **Secure Credential Vault**: AES-256 encrypted storage for banking credentials
- **Dead Man's Switch**: Automatic beneficiary access after 3 days of inactivity
- **Emergency Access**: Designated beneficiaries can access inherited assets
- **Multi-Factor Authentication**: Secure login with PIN verification
- **Admin Dashboard**: Manage users and verify death notifications
- **Audit Trails**: Complete logging of all system activities

## 🔧 Technology Stack

- **Framework**: Flutter 3.10.0
- **Database**: SQLite (local storage)
- **Encryption**: AES-256 CBC mode
- **State Management**: Provider
- **Platform**: Android & iOS

## 📦 Installation

### Prerequisites

- Flutter SDK 3.10.0 or higher
- Android Studio / VS Code
- Android device or emulator (API 21+)

### Setup Steps

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/secure_legacy_app.git
cd secure_legacy_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## 🔐 Default Credentials

### Admin Account
- **Username**: `admin`
- **Password**: `admin123`

### User Accounts
Register new accounts through the app interface.

## 📚 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user_model.dart
│   ├── admin_model.dart
│   ├── bank_asset_model.dart
│   └── emergency_contact_model.dart
├── services/                 # Business logic
│   ├── database_service.dart
│   ├── auth_service.dart
│   ├── aes_encryption_service.dart
│   ├── legacy_service.dart
│   └── theme_service.dart
├── screens/                  # UI screens
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── user_home_screen.dart
│   ├── admin_home_screen.dart
│   └── emergency_login_screen.dart
└── widgets/                  # Reusable components
    └── custom_textfield.dart
```

## 🎯 Key Functionalities

### For Account Holders
- Register and secure account with encryption
- Store banking credentials with AES-256 encryption
- Designate emergency contacts/beneficiaries
- Configure dead man's switch timing
- View activity logs

### For Beneficiaries
- Emergency login with IC number and PIN
- Access inherited banking credentials
- View special instructions from deceased

### For Administrators
- Monitor inactive users
- Verify death notifications
- Grant emergency access
- View system-wide activity logs
- Manage user accounts

## 🔒 Security Features

- **AES-256 Encryption**: Military-grade encryption for all credentials
- **SHA-256 Hashing**: Secure password storage
- **Multi-Factor Authentication**: Username + Password + PIN
- **Local Storage**: Data never leaves the device
- **Audit Logging**: Immutable activity records
- **Dead Man's Switch**: Automated access control

## 📖 User Guide

### Registering New Account
1. Open app and tap "Register"
2. Fill in all required information
3. Create strong password and 6-digit PIN
4. Submit registration

### Adding Bank Assets
1. Login to user dashboard
2. Navigate to "Bank Assets"
3. Tap "Add New Asset"
4. Enter encrypted credentials
5. Save securely

### Adding Emergency Contacts
1. Go to "Emergency Contacts"
2. Tap "Add Beneficiary"
3. Enter beneficiary details (Full Name, IC Number)
4. Set inheritance percentage
5. Save contact

### Emergency Access (for Beneficiaries)
1. Tap "Emergency Access" on login screen
2. Enter your Full Name (as registered)
3. Enter your IC Number (12 digits)
4. Enter PIN (last 6 digits of IC)
5. Access inherited credentials

## 🛠️ Development

### Running Tests
```bash
flutter test
```

### Building APK
```bash
flutter build apk --release
```

### Building iOS
```bash
flutter build ios --release
```
