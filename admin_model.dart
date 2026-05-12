class AdminModel {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String email;
  final String secretKey;
  final int createdAt;

  AdminModel({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
    required this.secretKey,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'fullName': fullName,
      'email': email,
      'secretKey': secretKey,
      'createdAt': createdAt,
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      secretKey: map['secretKey'] as String? ?? '',
      createdAt: map['createdAt'] as int,
    );
  }

  AdminModel copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? secretKey,
    int? createdAt,
  }) {
    return AdminModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      secretKey: secretKey ?? this.secretKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
