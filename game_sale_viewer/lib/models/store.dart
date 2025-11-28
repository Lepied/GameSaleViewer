/// CheapShark API의 스토어 정보를 담는 모델
class Store {
  final String storeID;
  final String storeName;
  final bool isActive;
  final String imageUrl;

  Store({
    required this.storeID,
    required this.storeName,
    required this.isActive,
    required this.imageUrl,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeID: json['storeID']?.toString() ?? '',
      storeName: json['storeName'] ?? '',
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      imageUrl: json['images']?['logo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeID': storeID,
      'storeName': storeName,
      'isActive': isActive,
      'imageUrl': imageUrl,
    };
  }
}

/// 주요 스토어 ID 상수
class StoreIds {
  static const String steam = '1';
  static const String gamersGate = '2';
  static const String greenManGaming = '3';
  static const String gog = '7';
  static const String origin = '8';
  static const String humbleStore = '11';
  static const String uplay = '13';
  static const String fanatical = '15';
  static const String epicGames = '25';

  /// API에서 가져온 스토어 매핑 캐시
  static Map<String, String> _storeNameCache = {};
  
  /// 스토어 목록 로드 여부
  static bool _isLoaded = false;

  /// 스토어 맵 초기화 (API에서 가져온 데이터로)
  static void initializeStoreMap(List<Store> stores) {
    _storeNameCache.clear();
    for (var store in stores) {
      _storeNameCache[store.storeID] = store.storeName;
    }
    _isLoaded = true;
    print('스토어 맵 초기화 완료: ${_storeNameCache.length}개 스토어');
  }

  /// 스토어 ID를 이름으로 매핑
  static String getStoreName(String storeID) {
    // 캐시에서 먼저 확인
    if (_storeNameCache.containsKey(storeID)) {
      return _storeNameCache[storeID]!;
    }
    
    // 캐시에 없으면 기본 매핑 사용 (호환성)
    switch (storeID) {
      case steam:
        return 'Steam';
      case gamersGate:
        return 'GamersGate';
      case greenManGaming:
        return 'Green Man Gaming';
      case gog:
        return 'GOG';
      case origin:
        return 'Origin';
      case humbleStore:
        return 'Humble Store';
      case uplay:
        return 'Uplay';
      case fanatical:
        return 'Fanatical';
      case epicGames:
        return 'Epic Games';
      default:
        return 'Unknown Store';
    }
  }
  
  /// 스토어 로드 완료 여부
  static bool get isLoaded => _isLoaded;
}
