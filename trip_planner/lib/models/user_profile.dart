// lib/models/user_profile.dart

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String bio;
  final String phone;

  // 新增：性別、國家
  final String gender;   // e.g. "Male", "Female", "Other", or empty
  final String country;  // e.g. "Taiwan", "USA", etc.

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.bio,
    required this.phone,
    required this.gender,
    required this.country,
  });

  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) {
    return UserProfile(
      uid         : uid,
      displayName : json['displayName'] as String? ?? '',
      email       : json['email'] as String? ?? '',
      photoURL    : json['photoURL'] as String? ?? '',
      bio         : json['bio'] as String? ?? '',
      phone       : json['phone'] as String? ?? '',
      gender      : json['gender'] as String? ?? '',   // 取不到就空字串
      country     : json['country'] as String? ?? '',  // 取不到就空字串
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email'      : email,
        'photoURL'   : photoURL,
        'bio'        : bio,
        'phone'      : phone,
        'gender'     : gender,
        'country'    : country,
      };
}
