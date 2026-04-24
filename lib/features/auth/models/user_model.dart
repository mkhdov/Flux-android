class UserModel {
  final String id;
  final String firstname;
  final String lastname;
  final String email;
  final String birthday;
  final String avatarUrl;

  const UserModel({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.birthday,
    required this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstname'] as String? ?? '';
    final lastName = json['lastname'] as String? ?? '';
    return UserModel(
      id: json['id'] as String? ?? '',
      firstname: firstName,
      lastname: lastName,
      email: json['email'] as String? ?? '',
      birthday: json['birthday'] as String? ?? '',
      avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent('$firstName $lastName')}&background=4E54C8&color=fff',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstname': firstname,
    'lastname': lastname,
    'email': email,
    'birthday': birthday,
    'avatarUrl': avatarUrl,
  };

  String get fullName => '$firstname $lastname';
  
  String get initials {
    final f = firstname.isNotEmpty ? firstname[0].toUpperCase() : '';
    final l = lastname.isNotEmpty ? lastname[0].toUpperCase() : '';
    return '$f$l';
  }
}
