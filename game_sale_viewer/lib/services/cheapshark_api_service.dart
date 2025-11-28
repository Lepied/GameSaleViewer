import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_deal.dart';
import '../models/game_detail.dart';
import '../models/store.dart';

/// CheapShark API와 통신하는 서비스 클래스
class CheapSharkApiService {
  static const String baseUrl = 'https://www.cheapshark.com/api/1.0';

  /// 딜 목록 조회
  /// 
  /// **필터 파라미터:**
  /// [storeID] - 특정 스토어 ID로 필터링 (예: "1"=Steam, "25"=Epic)
  /// [upperPrice] - 최대 가격 제한 (USD 기준, 예: 15.0)
  /// [lowerPrice] - 최소 가격 제한 (USD 기준, 예: 0.0)
  /// [metacritic] - 최소 메타크리틱 점수 (0-100, 예: 90)
  /// [steamRating] - 최소 Steam 평점 (0-100, 예: 80)
  /// [title] - 게임 타이틀 검색어
  /// [exact] - 정확한 타이틀 매칭 여부 (0 또는 1)
  /// [AAA] - AAA 게임만 표시 (0 또는 1)
  /// [steamworks] - Steamworks 게임만 표시 (0 또는 1)
  /// [onSale] - 할인 중인 게임만 표시 (0 또는 1)
  /// [output] - 출력 형식 (기본: json, rss도 가능)
  /// 
  /// **페이징 & 정렬:**
  /// [pageSize] - 페이지당 항목 수 (기본값: 60, 최대 60)
  /// [pageNumber] - 페이지 번호 (기본값: 0)
  /// [sortBy] - 정렬 기준:
  ///   - 'Deal Rating' (기본): CheapShark 딜 평점순
  ///   - 'Title': 제목 알파벳순
  ///   - 'Savings': 할인율 높은순
  ///   - 'Price': 가격 낮은순
  ///   - 'Metacritic': 메타크리틱 점수 높은순
  ///   - 'Reviews': 리뷰 점수 높은순
  ///   - 'Release': 출시일 최신순
  ///   - 'Store': 스토어 ID순
  ///   - 'recent': 최근 추가순
  Future<List<GameDeal>> getDeals({
    String? storeID,
    double? upperPrice,
    double? lowerPrice,
    int? metacritic,
    int? steamRating,
    String? title,
    int? exact,
    int? AAA,
    int? steamworks,
    int? onSale,
    int pageSize = 60,
    int pageNumber = 0,
    String sortBy = 'Deal Rating',
  }) async {
    try {
      final queryParams = <String, String>{
        'pageSize': pageSize.toString(),
        'pageNumber': pageNumber.toString(),
        'sortBy': sortBy,
      };

      if (storeID != null) {
        queryParams['storeID'] = storeID;
      }

      if (upperPrice != null) {
        queryParams['upperPrice'] = upperPrice.toString();
      }

      if (lowerPrice != null) {
        queryParams['lowerPrice'] = lowerPrice.toString();
      }

      if (metacritic != null) {
        queryParams['metacritic'] = metacritic.toString();
      }

      if (steamRating != null) {
        queryParams['steamRating'] = steamRating.toString();
      }

      if (title != null) {
        queryParams['title'] = title;
      }

      if (exact != null) {
        queryParams['exact'] = exact.toString();
      }

      if (AAA != null) {
        queryParams['AAA'] = AAA.toString();
      }

      if (steamworks != null) {
        queryParams['steamworks'] = steamworks.toString();
      }

      if (onSale != null) {
        queryParams['onSale'] = onSale.toString();
      }

      final uri = Uri.parse('$baseUrl/deals').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => GameDeal.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load deals: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching deals: $e');
      rethrow;
    }
  }

  /// 오늘의 특가 조회 (할인율 75% 이상, 메타크리틱 80점 이상)
  /// 같은 타이틀은 가장 높은 할인율과 낮은 가격인 것 하나만 반환
  Future<List<GameDeal>> getTodaySpecialDeals() async {
    try {
      final allDeals = await getDeals(pageSize: 100, sortBy: 'Savings');
      
      // 슈퍼 딜만 필터링
      final superDeals = allDeals.where((deal) {
        return deal.savingsPercent >= 75 && deal.metacriticScoreNum >= 80;
      }).toList();
      
      // 타이틀별로 그룹화하고 최고의 딜만 선택
      final Map<String, GameDeal> bestDealsByTitle = {};
      
      for (var deal in superDeals) {
        final title = deal.title.toLowerCase().trim();
        
        if (!bestDealsByTitle.containsKey(title)) {
          bestDealsByTitle[title] = deal;
        } else {
          final existingDeal = bestDealsByTitle[title]!;
          
          // 할인율이 더 높거나, 할인율이 같으면 가격이 더 낮은 것 선택
          if (deal.savingsPercent > existingDeal.savingsPercent ||
              (deal.savingsPercent == existingDeal.savingsPercent &&
                  deal.salePriceNum < existingDeal.salePriceNum)) {
            bestDealsByTitle[title] = deal;
          }
        }
      }
      
      return bestDealsByTitle.values.toList();
    } catch (e) {
      print('Error fetching today special deals: $e');
      return [];
    }
  }

  /// 게임 검색
  /// 
  /// [title] - 검색할 게임 타이틀
  Future<List<GameDeal>> searchGames(String title) async {
    try {
      final uri = Uri.parse('$baseUrl/games').replace(
        queryParameters: {
          'title': title,
          'limit': '60',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => GameDeal.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search games: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching games: $e');
      rethrow;
    }
  }

  /// 게임 상세 정보 조회
  /// 
  /// [gameID] - 조회할 게임 ID
  Future<GameDetail?> getGameDetail(String gameID) async {
    try {
      final uri = Uri.parse('$baseUrl/games').replace(
        queryParameters: {'id': gameID},
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return GameDetail.fromJson(jsonData);
      } else {
        throw Exception('Failed to load game detail: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching game detail: $e');
      return null;
    }
  }

  /// 게임 ID로 Steam 평점 정보 조회
  /// Deal 목록에서 해당 게임을 찾아 Steam 평점 반환
  Future<Map<String, String>?> getSteamRating(String gameID) async {
    try {
      // 게임 상세 정보에서 title을 가져와서 검색
      final detail = await getGameDetail(gameID);
      if (detail == null) return null;
      
      // title로 검색하여 Steam 평점 정보 가져오기
      final searchResults = await getDeals(
        title: detail.title,
        exact: 1,
        pageSize: 1,
      );
      
      if (searchResults.isNotEmpty) {
        final deal = searchResults.first;
        return {
          'steamRatingPercent': deal.steamRatingPercent,
          'steamRatingCount': deal.steamRatingCount,
        };
      }
      
      return null;
    } catch (e) {
      print('Error fetching Steam rating: $e');
      return null;
    }
  }

  /// 스토어 목록 조회
  Future<List<Store>> getStores() async {
    try {
      final uri = Uri.parse('$baseUrl/stores');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Store.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load stores: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stores: $e');
      rethrow;
    }
  }

  /// 특정 스토어의 딜 조회
  Future<List<GameDeal>> getStoreDeals(String storeID) async {
    return getDeals(storeID: storeID, pageSize: 60);
  }

  /// 가격 히스토리 조회를 위한 게임 정보
  /// 실제 가격 히스토리는 게임 상세 정보에 포함됨
  Future<Map<String, dynamic>?> getPriceHistory(String gameID) async {
    try {
      final detail = await getGameDetail(gameID);
      if (detail != null) {
        // 모든 딜에서 가격 정보 추출
        final priceData = detail.deals.map((deal) {
          return {
            'storeID': deal.storeID,
            'price': deal.priceNum,
            'retailPrice': deal.retailPriceNum,
            'savings': deal.savingsPercent,
          };
        }).toList();

        return {
          'gameID': gameID,
          'title': detail.title,
          'prices': priceData,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching price history: $e');
      return null;
    }
  }
}
