import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cheapshark_api_service.dart';
import 'notification_service.dart';
import '../models/game_deal.dart';


const String taskName = 'gamePriceCheckTask';

// 백그라운드 콜백함수
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {

    try {
      // 1. 초기화 
      final notificationService = NotificationService();
      await notificationService.init();
      
      // 2. 찜한 게임 목록 가져오기 
      final prefs = await SharedPreferences.getInstance();
      final List<String> favoriteIds = prefs.getStringList('favorite_game_ids') ?? [];

      if (favoriteIds.isEmpty) {
        return Future.value(true);
      }

      // 3. 가격 확인 (CheapShark API)
      final apiService = CheapSharkApiService();
      // 여러 게임을 확인해야 하므로 반복문 사용
      for (String gameId in favoriteIds) {
        // 상세 정보 가져오기
        final detail = await apiService.getGameDetail(gameId);
        
        if (detail != null && detail.deals.isNotEmpty) {
          // 가장 싼 딜 찾기
          final bestDeal = detail.deals.reduce((a, b) => a.priceNum < b.priceNum ? a : b);
          
          // 조건
          if (bestDeal.savingsPercent >= 50) {
            await notificationService.showNotification(
              id: int.parse(gameId),
              title: '🔥 ${detail.title} 할인',
              body: '현재 ${bestDeal.savingsPercent.toStringAsFixed(0)}% 할인 중! 가격: \$${bestDeal.price}',
              payload: gameId,
            );
          }
        }
      }

    } catch (e) {
      return Future.value(false);
    }

    return Future.value(true);
  });
}

class BackgroundService {
  // 백그라운드 서비스 초기화
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, 
    );
  }

  // 주기적 작업 등록
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1", // 유니크 이름
      taskName,
      frequency: const Duration(minutes: 15), // 주기
      constraints: Constraints(
        networkType: NetworkType.connected, 
      ),
    );
  }
  
  // 찜 목록 동기화 
  static Future<void> syncFavorites(List<String> gameIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_game_ids', gameIds);
  }
}