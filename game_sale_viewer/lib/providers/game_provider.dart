import 'package:flutter/foundation.dart';
import '../models/game_deal.dart';
import '../models/store.dart';
import '../services/cheapshark_api_service.dart';

/// 게임 딜 데이터를 관리하는 Provider
class GameProvider extends ChangeNotifier {
  final CheapSharkApiService _apiService = CheapSharkApiService();

  List<GameDeal> _allDeals = [];
  List<GameDeal> _specialDeals = [];
  List<GameDeal> _highRatedDeals = [];
  List<GameDeal> _searchResults = [];
  List<GameDeal> _filteredDeals = [];
  
  bool _isLoading = false;
  String? _error;
  String? _selectedStoreId;

  List<GameDeal> get allDeals => _allDeals;
  List<GameDeal> get specialDeals => _specialDeals;
  List<GameDeal> get highRatedDeals => _highRatedDeals;
  List<GameDeal> get searchResults => _searchResults;
  List<GameDeal> get filteredDeals => _filteredDeals;
  List<GameDeal> get displayDeals => 
      _selectedStoreId != null ? _filteredDeals : _allDeals;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedStoreId => _selectedStoreId;

  /// 초기 데이터 로드
  Future<void> loadInitialData() async {
    // 먼저 스토어 목록 로드
    await _loadStores();
    
    // 그 다음 게임 데이터 로드
    await Future.wait([
      loadDeals(),
      loadSpecialDeals(),
      loadHighRatedDeals(),
    ]);
  }
  
  /// 스토어 목록 로드 및 매핑 초기화
  Future<void> _loadStores() async {
    try {
      final stores = await _apiService.getStores();
      StoreIds.initializeStoreMap(stores);
    } catch (e) {
      print('스토어 목록 로드 실패: $e');
      // 실패해도 기본 매핑으로 계속 진행
    }
  }

  /// 모든 딜 로드 (같은 타이틀은 최저가만 표시)
  Future<void> loadDeals({int pageSize = 200}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allDeals = await _apiService.getDeals(pageSize: pageSize);
      
      // 타이틀별로 그룹화하고 최저가만 선택
      final Map<String, GameDeal> bestDealsByTitle = {};
      
      for (var deal in allDeals) {
        final title = deal.title.toLowerCase().trim();
        
        if (!bestDealsByTitle.containsKey(title)) {
          bestDealsByTitle[title] = deal;
        } else {
          final existingDeal = bestDealsByTitle[title]!;
          
          // 가격이 더 낮은 것 선택
          if (deal.salePriceNum < existingDeal.salePriceNum) {
            bestDealsByTitle[title] = deal;
          }
        }
      }
      
      _allDeals = bestDealsByTitle.values.toList();
      _error = null;
    } catch (e) {
      _error = '딜을 불러오는데 실패했습니다: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 오늘의 특가 로드
  Future<void> loadSpecialDeals() async {
    try {
      _specialDeals = await _apiService.getTodaySpecialDeals();
      notifyListeners();
    } catch (e) {
      print('특가를 불러오는데 실패했습니다: $e');
    }
  }

  /// 메타스코어 90+ 할인 게임 로드
  Future<void> loadHighRatedDeals() async {
    try {
      // API에서 직접 메타스코어 90+ 할인 게임만 가져오기
      final highRated = await _apiService.getDeals(
        metacritic: 90,
        onSale: 1,
        pageSize: 100,
        sortBy: 'Metacritic',
      );
      
      // 타이틀별로 그룹화하고 메타스코어가 높은 것 우선 선택
      final Map<String, GameDeal> bestDealsByTitle = {};
      
      for (var deal in highRated) {
        final title = deal.title.toLowerCase().trim();
        
        if (!bestDealsByTitle.containsKey(title)) {
          bestDealsByTitle[title] = deal;
        } else {
          final existingDeal = bestDealsByTitle[title]!;
          final existingScore = int.tryParse(existingDeal.metacriticScore) ?? 0;
          final currentScore = int.tryParse(deal.metacriticScore) ?? 0;
          
          // 메타스코어가 더 높으면 교체, 같으면 가격이 낮은 것 선택
          if (currentScore > existingScore) {
            bestDealsByTitle[title] = deal;
          } else if (currentScore == existingScore && 
                     deal.salePriceNum < existingDeal.salePriceNum) {
            bestDealsByTitle[title] = deal;
          }
        }
      }
      
      _highRatedDeals = bestDealsByTitle.values.toList();
      print('메타스코어 90+ 게임 로드 완료: ${_highRatedDeals.length}개');
      notifyListeners();
    } catch (e) {
      print('메타스코어 90+ 게임을 불러오는데 실패했습니다: $e');
    }
  }

  /// 게임 검색
  Future<void> searchGames(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _apiService.searchGames(query);
      _error = null;
    } catch (e) {
      _error = '검색에 실패했습니다: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 스토어별 필터링 (같은 타이틀은 최저가만 표시)
  Future<void> filterByStore(String? storeId) async {
    _selectedStoreId = storeId;
    
    if (storeId == null) {
      _filteredDeals = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final storeDeals = await _apiService.getStoreDeals(storeId);
      
      // 타이틀별로 그룹화하고 최저가만 선택
      final Map<String, GameDeal> bestDealsByTitle = {};
      
      for (var deal in storeDeals) {
        final title = deal.title.toLowerCase().trim();
        
        if (!bestDealsByTitle.containsKey(title)) {
          bestDealsByTitle[title] = deal;
        } else {
          final existingDeal = bestDealsByTitle[title]!;
          
          // 가격이 더 낮은 것 선택
          if (deal.salePriceNum < existingDeal.salePriceNum) {
            bestDealsByTitle[title] = deal;
          }
        }
      }
      
      _filteredDeals = bestDealsByTitle.values.toList();
      _error = null;
    } catch (e) {
      _error = '필터링에 실패했습니다: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 필터 초기화
  void clearFilter() {
    _selectedStoreId = null;
    _filteredDeals = [];
    notifyListeners();
  }

  /// 검색 결과 초기화
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
