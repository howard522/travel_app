// lib/models/user_profile.dart
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String bio;
  final String phone;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.bio,
    required this.phone,
  });

  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) {
    return UserProfile(
      uid         : uid,
      displayName : json['displayName'] as String? ?? '',
      email       : json['email'] as String? ?? '',
      photoURL    : json['photoURL'] as String? ?? '',
      bio         : json['bio'] as String? ?? '',
      phone       : json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email'      : email,
        'photoURL'   : photoURL,
        'bio'        : bio,
        'phone'      : phone,
      };
}
