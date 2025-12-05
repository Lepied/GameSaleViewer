import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // 초기화 함수
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. 타임존 초기화 
    tz.initializeTimeZones();

    // 2. 안드로이드 초기화 설정
    // 'ic_launcher'는 android/app/src/main/res/mipmap 폴더에 있는 기본 아이콘 
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. 통합 설정 객체 생성
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // 5. 플러그인 초기화
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림을 눌렀을 때 실행될 로직
        if (response.payload != null) {
          print('알림 클릭됨! Payload: ${response.payload}');
          // 페이지 이동 로직 처리넣기
        }
      },
    );

    _isInitialized = true;
  }

  // 알림 띄우기 함수
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'game_deal_channel_id', // 채널 ID
      '게임 할인 알림', // 채널 이름
      channelDescription: '찜한 게임의 할인 정보를 알려줍니다.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS 알림 설정
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    // 실제 알림 표시
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload, 
    );

    // 로컬 저장소에 알림 항목 추가
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'saved_notifications';
      final existing = prefs.getStringList(key) ?? <String>[];

      final Map<String, dynamic> item = {
        'id': id.toString(),
        'title': title,
        'body': body,
        'payload': payload,
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
        'read': false,
      };

      existing.insert(0, json.encode(item)); // 최신순으로 앞에 추가
      await prefs.setStringList(key, existing);
    } catch (e) {
      print('⚠️ 로컬 알림 저장 실패: $e');
    }
  }
}