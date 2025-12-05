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
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/lookup/v1').replace(
        queryParameters: {
          'key': apiKey,
          'appid': steamAppId,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['found'] == true && jsonData['game'] != null) {
          final gameId = jsonData['game']['id'];
          return gameId;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 게임 제목으로 ITAD 게임 ID 조회
  Future<String?> lookupGameByTitle(String title) async {
    if (apiKey.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/lookup/v1').replace(
        queryParameters: {
          'key': apiKey,
          'title': title,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['found'] == true && jsonData['game'] != null) {
          final gameId = jsonData['game']['id'];
          return gameId;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 가격 히스토리 조회 (최근 6개월)
  Future<List<PriceHistory>> getPriceHistory(String gameId) async {
    if (apiKey.isEmpty) {
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

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final history = jsonData.map((e) => PriceHistory.fromJson(e)).toList();
        return history;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 역대 최저가 조회
  Future<HistoricalLow?> getHistoricalLow(String gameId) async {
    if (apiKey.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse('$baseUrl/games/historylow/v1').replace(
        queryParameters: {
          'key': apiKey,
          'country': 'US',
        },
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode([gameId]),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        if (jsonData.isNotEmpty && jsonData[0]['low'] != null) {
          final lowData = jsonData[0]['low'];
          final histLow = HistoricalLow.fromJson(lowData);
          return histLow;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 현재 가격 정보 조회 (할인 종료 시점 포함)
  Future<List<CurrentPrice>> getCurrentPrices(String gameId) async {
    if (apiKey.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('$baseUrl/games/prices/v2').replace(
        queryParameters: {
          'key': apiKey,
          'country': 'US',
        },
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode([gameId]),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        if (jsonData.isNotEmpty) {
          final firstItem = jsonData[0];
          if (firstItem is Map && firstItem['deals'] != null) {
            final List<dynamic> dealsData = firstItem['deals'];
            
            final prices = <CurrentPrice>[];
            for (var dealData in dealsData) {
              try {
                prices.add(CurrentPrice.fromJson(dealData));
              } catch (e) {
                // 개별 deal 파싱 실패 시 건너뜀
              }
            }
            
            return prices;
          }
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
}
