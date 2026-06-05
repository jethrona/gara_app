class ProfileModel {
  final String id;
  final String phoneNumber;
  final String fullName;
  final bool isDoctor;
  final DateTime? createdAt;
  final String? avatarUrl;
  final int consultationFee;

  ProfileModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.isDoctor = false,
    this.createdAt,
    this.avatarUrl,
    this.consultationFee = 2000,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      phoneNumber: map['phone_number'] as String,
      fullName: map['full_name'] as String,
      isDoctor: map['is_doctor'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      avatarUrl: map['avatar_url'] as String?,
      consultationFee: map['consultation_fee'] as int? ?? 2000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'is_doctor': isDoctor,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (isDoctor) 'consultation_fee': consultationFee,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? phoneNumber,
    String? fullName,
    bool? isDoctor,
    DateTime? createdAt,
    String? avatarUrl,
    int? consultationFee,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      isDoctor: isDoctor ?? this.isDoctor,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      consultationFee: consultationFee ?? this.consultationFee,
    );
  }
}
