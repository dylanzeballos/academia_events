class UserFcmTokenModel {
  final String? id;
  final String userId;
  final String fcmToken;
  final String deviceType;

  UserFcmTokenModel({
    this.id,
    required this.userId,
    required this.fcmToken,
    this.deviceType = 'android',
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'fcm_token': fcmToken,
    'device_type': deviceType,
    'updated_at': DateTime.now().toIso8601String(),
  };
}