import 'package:readright/utils/enums.dart';


/// Model class representing user data.
class UserModel {
  // This 'id' value will be updated with the FirestoreAuth UID 
  // upon user creation. No need to set it manually.
  final String? id;
  
  final String fullName;
  final String email;
  final UserRole role;
  final String local;
  final String institution;
  final String username;

  final bool isEmailVerified;
  final VerificationStatus verificationStatus;

  /// Constructor for UserModel.
  UserModel({
    String? id,
    required this.email,
    this.fullName = '',
    this.role = UserRole.student, // Default role is student, teacher will be assigned explicitly when they register for an account.
    this.local = 'en-US',
    this.institution = '',
    this.username = '',
    this.isEmailVerified = false,
    this.verificationStatus = VerificationStatus.unknown,
  }) : id = id ?? '';

  // Create a copy of the current UserModel with optional new values.
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    UserRole? role,
    String? local,
    String? institution,
    String? username,
    bool? isEmailVerified,
    VerificationStatus? verificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      local: local ?? this.local,
      institution: institution ?? this.institution,
      username: username ?? this.username,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  } 

  // Convert UserModel instance to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role.name,
      'local': local,
      'institution': institution,
      'username': username,
      'isEmailVerified': isEmailVerified,
      'verificationStatus': verificationStatus.name,
    };
  }

  // Create a UserModel instance from JSON data retrieved from Firestore.
  factory UserModel.fromJson(Map<String, dynamic> data) {
    return UserModel(
      id: (data['id'] as String?) ?? '',
      fullName: data.containsKey('fullName') ? data['fullName'] ?? '' : '',
      email: data.containsKey('email') ? data['email'] ?? '' : '',
      role: data.containsKey('role')
          ? ((data['role'] ?? UserRole.student.name) == UserRole.teacher.name)
              ? UserRole.teacher
              : UserRole.student
          : UserRole.student,
      local: data.containsKey('local') ? data['local'] ?? 'en-US' : 'en-US',
      institution: data.containsKey('institution') ? data['institution'] ?? '' : '',
      username: data.containsKey('username') ? data['username'] ?? '' : '',
      isEmailVerified: data.containsKey('isEmailVerified') ? data['isEmailVerified'] ?? false : false,
      verificationStatus: data.containsKey('verificationStatus')
          ? _mapVerificationStringToEnum(data['verificationStatus'])
          : VerificationStatus.unknown,
    );
  }

  // Utility to map a role String to the VerificationStatus enum
  static VerificationStatus _mapVerificationStringToEnum(String verification) {
    switch (verification) {
      case 'Pending':
        return VerificationStatus.pending;
      case 'Approved':
        return VerificationStatus.approved;
      case 'Rejected':
        return VerificationStatus.rejected;
      case 'Submitted':
        return VerificationStatus.submitted;
      case 'Under Review':
        return VerificationStatus.underReview;
      default:
        return VerificationStatus.unknown;
    }
  }
}
