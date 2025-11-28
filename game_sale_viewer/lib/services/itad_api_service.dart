import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/price_history.dart';

/// IsThereAnyDeal API 서비스
class ITADApiService {
  static const String baseUrl = 'https://api.isthereanydeal.com';
  final String apiKey;

  ITADApiService() : apiKey = dotenv.env['ITAD_API_KEY'] ?? '';

  /// Steam AppID로 ITAD 게임 ID 조회
  Future<String?> lookupGameByAppId(String steamAppId) async {
    if (apiKey.isEmpty) {
      print('❌ ITAD API key가 설정되지 않음');
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/lookup/v1').replace(
        queryParameters: {
          'key': apiKey,
          'appid': steamAppId,
        },
      );

      print('🔗 [AppID] API 호출: $uri');
      final response = await http.get(uri);
      print('📥 [AppID] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📦 [AppID] 응답 데이터: $jsonData');
        
        if (jsonData['found'] == true && jsonData['game'] != null) {
          final gameId = jsonData['game']['id'];
          print('✅ [AppID] 게임 ID 찾음: $gameId');
          return gameId;
        } else {
          print('⚠️ [AppID] found=${jsonData['found']}, game=${jsonData['game']}');
        }
      } else {
        print('❌ [AppID] API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      print('❌ [AppID] 에러: $e');
      return null;
    }
  }

  /// 게임 제목으로 ITAD 게임 ID 조회
  Future<String?> lookupGameByTitle(String title) async {
    if (apiKey.isEmpty) {
      print('❌ ITAD API key가 설정되지 않음');
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/lookup/v1').replace(
        queryParameters: {
          'key': apiKey,
          'title': title,
        },
      );

      print('🔗 [Title] API 호출: $uri');
      final response = await http.get(uri);
      print('📥 [Title] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📦 [Title] 응답 데이터: $jsonData');
        
        if (jsonData['found'] == true && jsonData['game'] != null) {
          final gameId = jsonData['game']['id'];
          print('✅ [Title] 게임 ID 찾음: $gameId');
          return gameId;
        } else {
          print('⚠️ [Title] found=${jsonData['found']}, game=${jsonData['game']}');
        }
      } else {
        print('❌ [Title] API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      print('❌ [Title] 에러: $e');
      return null;
    }
  }

  /// 가격 히스토리 조회 (최근 6개월)
  Future<List<PriceHistory>> getPriceHistory(String gameId) async {
    if (apiKey.isEmpty) {
      print('❌ ITAD API key가 설정되지 않음');
      return [];
    }

    try {
      // 6개월 전 날짜 계산
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      // ISO 8601 포맷, 밀리초 제거 (예: 2025-05-28T00:00:00Z)
      final isoString = sixMonthsAgo.toUtc().toIso8601String();
      final sinceDate = isoString.contains('.') 
          ? isoString.substring(0, isoString.indexOf('.')) + 'Z'
          : isoString;
      
      final uri = Uri.parse('$baseUrl/games/history/v2').replace(
        queryParameters: {
          'key': apiKey,
          'id': gameId,
          'since': sinceDate,
          'country': 'US',
        },
      );

      print('🔗 [History] API 호출: $uri');
      final response = await http.get(uri);
      print('📥 [History] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('📊 [History] 데이터 개수: ${jsonData.length}');
        
        final history = jsonData.map((e) => PriceHistory.fromJson(e)).toList();
        print('✅ [History] 파싱 완료: ${history.length}개');
        return history;
      } else {
        print('❌ [History] API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return [];
    } catch (e) {
      print('❌ [History] 에러: $e');
      return [];
    }
  }

  /// 역대 최저가 조회
  Future<HistoricalLow?> getHistoricalLow(String gameId) async {
    if (apiKey.isEmpty) {
      print('❌ ITAD API key가 설정되지 않음');
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/historylow/v1').replace(
        queryParameters: {
          'key': apiKey,
          'country': 'US',
        },
      );

      print('🔗 [HistLow] API 호출: $uri');
      print('📤 [HistLow] 요청 body: ${json.encode([gameId])}');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode([gameId]),
      );

      print('📥 [HistLow] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('📦 [HistLow] 응답 데이터: $jsonData');
        
        if (jsonData.isNotEmpty && jsonData[0]['low'] != null) {
          final lowData = jsonData[0]['low'];
          final histLow = HistoricalLow.fromJson(lowData);
          print('✅ [HistLow] 역대최저가: \$${histLow.price.amount}');
          return histLow;
        } else {
          print('⚠️ [HistLow] 데이터 없음');
        }
      } else {
        print('❌ [HistLow] API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      print('❌ [HistLow] 에러: $e');
      return null;
    }
  }

  /// 현재 가격 정보 조회 (할인 종료 시점 포함)
  Future<List<CurrentPrice>> getCurrentPrices(String gameId) async {
    if (apiKey.isEmpty) {
      print('❌ ITAD API key가 설정되지 않음');
      return [];
    }

    try {
      final uri = Uri.parse('$baseUrl/games/prices/v2').replace(
        queryParameters: {
          'key': apiKey,
          'country': 'US',
        },
      );

      print('🔗 [Prices] API 호출: $uri');
      print('📤 [Prices] 요청 body: ${json.encode([gameId])}');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode([gameId]),
      );

      print('📥 [Prices] 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('📦 [Prices] 응답 데이터 길이: ${jsonData.length}');
        
        if (jsonData.isNotEmpty) {
          print('📦 [Prices] 첫 번째 항목: ${jsonData[0]}');
          
          final firstItem = jsonData[0];
          if (firstItem is Map && firstItem['deals'] != null) {
            final List<dynamic> dealsData = firstItem['deals'];
            print('📦 [Prices] deals 개수: ${dealsData.length}');
            
            final prices = <CurrentPrice>[];
            for (var dealData in dealsData) {
              try {
                prices.add(CurrentPrice.fromJson(dealData));
              } catch (e) {
                print('⚠️ [Prices] 개별 deal 파싱 실패: $e');
                print('⚠️ [Prices] 문제된 데이터: $dealData');
              }
            }
            
            print('✅ [Prices] 가격 정보: ${prices.length}개');
            return prices;
          } else {
            print('⚠️ [Prices] deals 필드 없음 또는 null');
          }
        } else {
          print('⚠️ [Prices] 응답 데이터 비어있음');
        }
      } else {
        print('❌ [Prices] API 오류: ${response.statusCode} - ${response.body}');
      }
      
      return [];
    } catch (e) {
      print('❌ [Prices] 에러: $e');
      return [];
    }
  }
}
