import 'package:flutter/foundation.dart';
import '../models/game_deal.dart';
import '../models/store.dart';
import '../services/cheapshark_api_service.dart';
import '../services/steam_service.dart';

/// 게임 딜 데이터를 관리하는 Provider
class GameProvider extends ChangeNotifier {
  final CheapSharkApiService _apiService = CheapSharkApiService();
  final SteamService _steamService = SteamService();
  // steam-based search candidate state
  List<String> _steamCandidateNames = [];
  int _steamCandidatePos = 0;
  int _steamCandidateBatch = 30; // how many steam candidates to fetch per batch
  bool _searchUsingSteam = false;

  List<GameDeal> _allDeals = [];
  List<GameDeal> _specialDeals = [];
  List<GameDeal> _highRatedDeals = [];
  List<GameDeal> _searchResults = [];
  String _searchQuery = '';
  String _searchSort = 'relevance';
  int _searchPage = 0;
  bool _searchHasMore = true;
  bool _isLoadingMore = false;
  List<GameDeal> _filteredDeals = [];

  bool _isLoading = false;
  String? _error;
  String? _selectedStoreId;

  List<GameDeal> get allDeals => _allDeals;
  List<GameDeal> get specialDeals => _specialDeals;
  List<GameDeal> get highRatedDeals => _highRatedDeals;
  List<GameDeal> get searchResults => _searchResults;
  bool get isLoadingMore => _isLoadingMore;
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
    await Future.wait([loadDeals(), loadSpecialDeals(), loadHighRatedDeals()]);
  }

  /// 스토어 목록 로드 및 매핑 초기화
  Future<void> _loadStores() async {
    try {
      final stores = await _apiService.getStores();
      StoreIds.initializeStoreMap(stores);
    } catch (e) {
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
      // 특가 로드 실패
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
      notifyListeners();
    } catch (e) {
      // 메타스코어 90+ 게임 로드 실패
    }
  }

  /// 게임 검색
  ///
  /// [sort] - 'popularity' (인기순: Deal Rating) 또는 'relevance' (정확도순: 기본 검색 우선)
  Future<void> searchGames(String query, {String sort = 'relevance'}) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      // 한글 포함 여부 검사 (간단한 한글 문자 범위)
      final hasHangul = RegExp(r'[\u3131-\u318E\uAC00-\uD7A3]').hasMatch(query);
      if (hasHangul) {
        _searchUsingSteam = true;
        _steamCandidateNames = [];
        _steamCandidatePos = 0;
        _searchQuery = query;

        // fetch initial steam candidate batch
        final steamItems = await _steamService.searchStore(query, size: _steamCandidateBatch, start: 0, locale: 'koreana');
        final names = <String>[];
        for (var item in steamItems) {
          final idRaw = item['id'];
          int? appId;
          if (idRaw is int) appId = idRaw;
          else if (idRaw is String) appId = int.tryParse(idRaw);
          if (appId == null) continue;
          final details = await _steamService.getAppDetails(appId, locale: 'english');
          final engName = details?['name'] as String?;
          if (engName != null && engName.isNotEmpty) names.add(engName);
        }
        _steamCandidateNames = names;

        // build initial results from steam candidate names up to pageSize
        final pageSize = 30;
        final Map<String, GameDeal> byTitle = {};
        while (_steamCandidatePos < _steamCandidateNames.length && byTitle.length < pageSize) {
          final engName = _steamCandidateNames[_steamCandidatePos++];
          final deals = await _apiService.getDeals(title: engName, pageSize: 10);
          if (deals.isNotEmpty) {
            deals.sort((a, b) => a.salePriceNum.compareTo(b.salePriceNum));
            final d = deals.first;
            final key = d.title.toLowerCase().trim();
            if (!byTitle.containsKey(key) || d.salePriceNum < byTitle[key]!.salePriceNum) {
              byTitle[key] = d;
            }
          }
        }

        _searchResults = byTitle.values.toList();
        _searchHasMore = true; // assume there may be more candidates
        _error = null;
        notifyListeners();
        return;
      }

      // 초기화
      _searchQuery = query;
      _searchSort = sort;
      _searchPage = 0;
      _searchHasMore = true;

      final pageSize = 30;
      final sortBy = sort == 'popularity' ? 'Deal Rating' : 'recent';

      final deals = await _apiService.getDeals(
        title: query,
        pageSize: pageSize,
        pageNumber: _searchPage,
        sortBy: sortBy,
      );

      // 타이틀별로 최저가만 남기기
      final Map<String, GameDeal> bestByTitle = {};
      for (var d in deals) {
        final key = d.title.toLowerCase().trim();
        if (!bestByTitle.containsKey(key) ||
            d.salePriceNum < bestByTitle[key]!.salePriceNum) {
          bestByTitle[key] = d;
        }
      }

      _searchResults = bestByTitle.values.toList();
      _searchHasMore = deals.length == pageSize;
      _error = null;
    } catch (e) {
      _error = '검색에 실패했습니다: $e';
    } finally {}
  }

  /// 검색 결과 추가 로드 (무한스크롤용)
  Future<void> loadMoreSearchResults() async {
    if (!_searchHasMore || _isLoadingMore || _searchQuery.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      // If using Steam flow, process next steam candidates
      if (_searchUsingSteam) {
        final Map<String, GameDeal> merged = {for (var d in _searchResults) d.title.toLowerCase().trim(): d};
        final pageSize = 30;
        // ensure we have candidates; if exhausted, fetch next batch from Steam
        if (_steamCandidatePos >= _steamCandidateNames.length) {
          final start = _steamCandidateNames.length;
          final steamItems = await _steamService.searchStore(_searchQuery, size: _steamCandidateBatch, start: start, locale: 'koreana');
          final names = <String>[];
          for (var item in steamItems) {
            final idRaw = item['id'];
            int? appId;
            if (idRaw is int) appId = idRaw;
            else if (idRaw is String) appId = int.tryParse(idRaw);
            if (appId == null) continue;
            final details = await _steamService.getAppDetails(appId, locale: 'english');
            final engName = details?['name'] as String?;
            if (engName != null && engName.isNotEmpty) names.add(engName);
          }
          if (names.isNotEmpty) {
            _steamCandidateNames.addAll(names);
          } else {
            // no more steam candidates
            _searchHasMore = false;
            _isLoadingMore = false;
            notifyListeners();
            return;
          }
        }

        // process next candidates until we append up to pageSize new items or run out
        while (_steamCandidatePos < _steamCandidateNames.length && merged.length < pageSize) {
          final engName = _steamCandidateNames[_steamCandidatePos++];
          final deals = await _apiService.getDeals(title: engName, pageSize: 10);
          if (deals.isNotEmpty) {
            deals.sort((a, b) => a.salePriceNum.compareTo(b.salePriceNum));
            final d = deals.first;
            final key = d.title.toLowerCase().trim();
            if (!merged.containsKey(key) || d.salePriceNum < merged[key]!.salePriceNum) {
              merged[key] = d;
            }
          }
        }

        _searchResults = merged.values.toList();
        _searchHasMore = _steamCandidatePos < _steamCandidateNames.length || _searchHasMore;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }

      _searchPage += 1;
      final pageSize = 30;
      final sortBy = _searchSort == 'popularity' ? 'Deal Rating' : 'recent';

      final deals = await _apiService.getDeals(
        title: _searchQuery,
        pageSize: pageSize,
        pageNumber: _searchPage,
        sortBy: sortBy,
      );

      // append while deduplicating by title and preferring lower price
      final Map<String, GameDeal> merged = {
        for (var d in _searchResults) d.title.toLowerCase().trim(): d,
      };
      for (var d in deals) {
        final key = d.title.toLowerCase().trim();
        if (!merged.containsKey(key) ||
            d.salePriceNum < merged[key]!.salePriceNum) {
          merged[key] = d;
        }
      }

      _searchResults = merged.values.toList();
      _searchHasMore = deals.length == pageSize;
    } catch (e) {
      // 검색 결과 추가 로드 실패
    } finally {
      _isLoadingMore = false;
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
