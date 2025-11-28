import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/game_detail.dart';
import '../models/store.dart';
import '../models/price_history.dart';
import '../services/cheapshark_api_service.dart';
import '../services/itad_api_service.dart';
import '../providers/auth_provider.dart';
import 'dart:math';

/// 게임 상세 정보 화면
class GameDetailScreen extends StatefulWidget {
  final String gameId;

  const GameDetailScreen({
    super.key,
    required this.gameId,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final CheapSharkApiService _apiService = CheapSharkApiService();
  final ITADApiService _itadService = ITADApiService();
  
  GameDetail? _gameDetail;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _steamRatingData;
  
  // ITAD 데이터
  String? _itadGameId;
  List<PriceHistory>? _priceHistory;
  HistoricalLow? _historicalLow;
  List<CurrentPrice>? _currentPrices;
  bool _loadingITADData = false;

  @override
  void initState() {
    super.initState();
    _loadGameDetail();
  }

  Future<void> _loadGameDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _apiService.getGameDetail(widget.gameId);
      setState(() {
        _gameDetail = detail;
        _isLoading = false;
      });

      // 스팀 게임인 경우 스팀 평점 정보 로드
      if (detail != null && detail.steamAppID.isNotEmpty) {
        _loadSteamRating(detail.steamAppID);
        _loadITADData(detail.steamAppID, detail.title);
      }
    } catch (e) {
      setState(() {
        _error = '게임 정보를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadITADData(String steamAppId, String title) async {
    print('🔄 ITAD 데이터 로딩 시작...');
    print('Steam AppID: $steamAppId');
    print('게임 제목: $title');
    
    setState(() {
      _loadingITADData = true;
    });

    try {
      // Steam AppID로 ITAD 게임 조회
      print('🔍 AppID로 게임 조회 중...');
      String? itadId = await _itadService.lookupGameByAppId(steamAppId);
      
      if (itadId != null && itadId.isNotEmpty) {
        print('✅ AppID로 게임 찾음: $itadId');
      } else {
        print('❌ AppID로 게임 못찾음, 제목으로 시도...');
        // AppID로 실패하면 제목으로 시도
        itadId = await _itadService.lookupGameByTitle(title);
        
        if (itadId != null && itadId.isNotEmpty) {
          print('✅ 제목으로 게임 찾음: $itadId');
        } else {
          print('❌ 제목으로도 게임 못찾음');
        }
      }

      if (itadId != null && itadId.isNotEmpty && mounted) {
        print('📊 가격 히스토리 & 역대 최저가 & 현재 가격 로딩 중...');
        
        // 가격 히스토리, 역대 최저가, 현재 가격 동시 로드
        final results = await Future.wait([
          _itadService.getPriceHistory(itadId),
          _itadService.getHistoricalLow(itadId),
          _itadService.getCurrentPrices(itadId),
        ]);

        final priceHistory = results[0] as List<PriceHistory>;
        final historicalLow = results[1] as HistoricalLow?;
        final currentPrices = results[2] as List<CurrentPrice>;
        
        print('📈 가격 히스토리 개수: ${priceHistory.length}');
        print('🏆 역대 최저가: ${historicalLow != null ? "\$${historicalLow.price.amount}" : "없음"}');
        print('💰 현재 가격 정보: ${currentPrices.length}개');

        if (mounted) {
          setState(() {
            _itadGameId = itadId;
            _priceHistory = priceHistory;
            _historicalLow = historicalLow;
            _currentPrices = currentPrices;
            _loadingITADData = false;
          });
          
          print('✅ ITAD 데이터 로딩 완료!');
        }
      } else {
        print('⚠️ ITAD 게임 ID를 찾을 수 없음');
        if (mounted) {
          setState(() {
            _loadingITADData = false;
          });
        }
      }
    } catch (e) {
      print('❌ ITAD 데이터 로딩 에러: $e');
      if (mounted) {
        setState(() {
          _loadingITADData = false;
        });
      }
    }
  }

  Future<void> _loadSteamRating(String steamAppID) async {
    try {
      final steamData = await _apiService.getSteamRating(widget.gameId);
      
      if (steamData != null && mounted) {
        setState(() {
          _steamRatingData = steamData;
        });
      }
    } catch (e) {
      print('Error loading Steam rating: $e');
      // 스팀 평점 로드 실패시에도 다른 정보는 표시
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isFavorite = _gameDetail != null 
        ? authProvider.isFavorite(widget.gameId) 
        : false;

    return Scaffold(
      body: _buildBody(context, authProvider, isFavorite),
    );
  }

  Widget _buildBody(BuildContext context, AuthProvider authProvider, bool isFavorite) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _gameDetail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? '게임 정보를 찾을 수 없습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGameDetail,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final bestDeal = _getBestDeal();
    final valueScore = _calculateValueScore();

    return CustomScrollView(
      slivers: [
        // 상단 이미지 + 뒤로가기/찜 버튼
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: _gameDetail!.thumb,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, size: 64),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.white,
              ),
              onPressed: () async {
                if (!authProvider.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인이 필요합니다')),
                  );
                  return;
                }

                if (isFavorite) {
                  await authProvider.removeFavorite(widget.gameId);
                } else {
                  await authProvider.addFavorite(
                    gameId: widget.gameId,
                    gameTitle: _gameDetail!.title,
                    thumbUrl: _gameDetail!.thumb,
                  );
                }
              },
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목과 메타크리틱
                Text(
                  _gameDetail!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildMetacriticBadge(),
                
                const SizedBox(height: 24),

                // 현재 최저가 섹션
                _buildBestPriceCard(bestDeal),
                
                const SizedBox(height: 24),

                // 가격 대비 가치 분석
                _buildValueAnalysisCard(valueScore),
                
                const SizedBox(height: 24),

                // 가격 추이 그래프 (6개월)
                if (_priceHistory != null && _priceHistory!.isNotEmpty) ...[
                  _buildPriceHistoryChart(),
                  const SizedBox(height: 24),
                ],

                // 스팀 평점 (스팀 게임인 경우만 표시)
                if (_gameDetail!.steamAppID.isNotEmpty) ...[
                  _buildSteamRatingCard(),
                  const SizedBox(height: 24),
                ],

                // 판매 중인 스토어
                _buildStoreListSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 헬퍼 함수들
  Deal? _getBestDeal() {
    if (_gameDetail == null || _gameDetail!.deals.isEmpty) return null;
    return _gameDetail!.deals.reduce((a, b) => a.priceNum < b.priceNum ? a : b);
  }

  double _calculateValueScore() {
    if (_gameDetail == null || _gameDetail!.deals.isEmpty) return 5.0;
    
    // 할인율과 가격 기반으로 가치 점수 계산
    final bestDeal = _getBestDeal();
    if (bestDeal == null) return 5.0;
    
    double totalScore = 0.0;
    
    // 1. 할인율 점수 (최대 3점)
    final savingsScore = (bestDeal.savingsPercent / 100) * 3;
    totalScore += savingsScore;
    
    // 2. 역대 최저가와 비교 (최대 4점) - ITAD 데이터 있을 때만
    if (_historicalLow != null) {
      final currentPrice = bestDeal.priceNum;
      final historicalPrice = _historicalLow!.price.amount;
      
      if (currentPrice <= historicalPrice) {
        // 역대 최저가 또는 그보다 낮으면 만점
        totalScore += 4.0;
      } else {
        // 역대 최저가보다 비싸면 차이에 따라 점수 감소
        final priceDiff = currentPrice - historicalPrice;
        final diffPercent = (priceDiff / historicalPrice) * 100;
        
        if (diffPercent <= 10) {
          totalScore += 3.5; // 10% 이내 차이
        } else if (diffPercent <= 20) {
          totalScore += 3.0; // 20% 이내 차이
        } else if (diffPercent <= 50) {
          totalScore += 2.0; // 50% 이내 차이
        } else {
          totalScore += 1.0; // 50% 이상 차이
        }
      }
    } else {
      // ITAD 데이터 없으면 가격으로만 판단 (최대 2점)
      if (bestDeal.priceNum < 10) {
        totalScore += 2.0;
      } else if (bestDeal.priceNum < 20) {
        totalScore += 1.5;
      } else if (bestDeal.priceNum < 40) {
        totalScore += 1.0;
      } else {
        totalScore += 0.5;
      }
    }
    
    // 3. 여러 스토어에서 판매 중이면 가산점 (최대 2점)
    final availabilityScore = min(_gameDetail!.deals.length / 5.0, 2.0);
    totalScore += availabilityScore;
    
    // 4. 가격 히스토리 트렌드 (최대 1점) - 최근 6개월 중 가장 낮은 가격인지
    if (_priceHistory != null && _priceHistory!.isNotEmpty) {
      final recentLowPrice = _priceHistory!.map((h) => h.deal.price.amount).reduce(min);
      if (bestDeal.priceNum <= recentLowPrice) {
        totalScore += 1.0; // 최근 최저가
      } else {
        totalScore += 0.5; // 최근 최저가는 아님
      }
    }
    
    return min(totalScore, 10.0);
  }

  // UI 빌더 함수들
  Widget _buildMetacriticBadge() {
    // GameDetail의 deals에는 메타크리틱 정보가 없으므로
    // 할인율로 배지 표시
    final bestDeal = _getBestDeal();
    if (bestDeal == null) return const SizedBox();

    return Row(
      children: [
        if (bestDeal.savingsPercent > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.orange.shade600],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '-${bestDeal.savingsPercent.toStringAsFixed(0)}% 할인',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBestPriceCard(Deal? bestDeal) {
    if (bestDeal == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('가격 정보가 없습니다'),
        ),
      );
    }

    final storeName = StoreIds.getStoreName(bestDeal.storeID);

    return Card(
      color: Colors.purple.shade700,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 최저가',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${bestDeal.price}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                if (bestDeal.savingsPercent > 0) ...[
                  Text(
                    '\$${bestDeal.retailPrice}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '-${bestDeal.savingsPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openStorePage(bestDeal.dealID),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shopping_cart),
                label: Text(
                  '$storeName에서 구매',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueAnalysisCard(double valueScore) {
    final scoreInt = valueScore.round();
    final bestDeal = _getBestDeal();
    
    String qualityText;
    Color qualityColor;
    
    if (valueScore >= 9.0) {
      qualityText = '역대급 딜!';
      qualityColor = Colors.purple;
    } else if (valueScore >= 7.5) {
      qualityText = '훌륭한 가격';
      qualityColor = Colors.green;
    } else if (valueScore >= 6.0) {
      qualityText = '괜찮은 딜';
      qualityColor = Colors.lightGreen;
    } else if (valueScore >= 4.0) {
      qualityText = '보통 수준';
      qualityColor = Colors.orange;
    } else {
      qualityText = '더 기다려보세요';
      qualityColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '💰 가격 대비 가치 분석',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(10, (index) {
                return Expanded(
                  child: Container(
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index < scoreInt
                          ? qualityColor
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$scoreInt/10',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: qualityColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    qualityText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // 역대 최저가 비교 섹션
            if (_historicalLow != null && bestDeal != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '역대 최저가 비교',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildHistoricalLowComparison(bestDeal),
            ],
            
            const SizedBox(height: 12),
            Text(
              _historicalLow != null 
                  ? '역대 최저가, 할인율, 가격 추이 기반 평가'
                  : '할인율과 가격 기반 평가',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalLowComparison(Deal currentDeal) {
    if (_historicalLow == null) return const SizedBox();
    
    final currentPrice = currentDeal.priceNum;
    final historicalPrice = _historicalLow!.price.amount;
    final isHistoricalLow = currentPrice <= historicalPrice;
    final priceDiff = currentPrice - historicalPrice;
    final diffPercent = historicalPrice > 0 
        ? ((priceDiff / historicalPrice) * 100).abs() 
        : 0.0;
    
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final historicalDate = dateFormat.format(_historicalLow!.date);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHistoricalLow 
            ? Colors.green.shade900.withOpacity(0.3) 
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: isHistoricalLow 
            ? Border.all(color: Colors.green.shade600, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 가격',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '\$${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                isHistoricalLow 
                    ? Icons.star 
                    : (priceDiff > 0 ? Icons.arrow_upward : Icons.check),
                color: isHistoricalLow 
                    ? Colors.amber 
                    : (priceDiff > 0 ? Colors.red : Colors.green),
                size: 32,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '역대 최저가',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '\$${historicalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isHistoricalLow) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    '🎉 역대 최저가 달성!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (priceDiff > 0) ...[
            Text(
              '역대 최저가보다 \$${priceDiff.toStringAsFixed(2)} (${diffPercent.toStringAsFixed(0)}%) 높습니다',
              style: TextStyle(
                color: diffPercent <= 10 
                    ? Colors.lightGreen 
                    : (diffPercent <= 20 ? Colors.orange : Colors.red),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '역대 최저가 기록: $historicalDate',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          
          // 할인 종료 시점 표시
          if (_currentPrices != null && _currentPrices!.isNotEmpty)
            _buildDealExpiryInfo(),
        ],
      ),
    );
  }

  Widget _buildDealExpiryInfo() {
    if (_currentPrices == null || _currentPrices!.isEmpty) {
      return const SizedBox();
    }

    // 할인 중이고 종료 시점이 있는 딜 찾기
    final dealsWithExpiry = _currentPrices!
        .where((price) => price.isOnSale && price.hasExpiry)
        .toList();

    // 할인 종료 시점이 없는 경우
    if (dealsWithExpiry.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.grey[500], size: 18),
              const SizedBox(width: 6),
              Text(
                '할인 종료',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '현재 최저가 할인 종료일은 미정입니다',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    // 가장 빨리 끝나는 딜 찾기
    dealsWithExpiry.sort((a, b) => a.expiry!.compareTo(b.expiry!));
    final nearestExpiry = dealsWithExpiry.first;
    
    final now = DateTime.now();
    final timeLeft = nearestExpiry.expiry!.difference(now);
    final daysLeft = timeLeft.inDays;
    final hoursLeft = timeLeft.inHours % 24;
    
    String timeLeftText;
    Color timeColor;
    
    if (daysLeft > 7) {
      timeLeftText = '${daysLeft}일 후 종료';
      timeColor = Colors.blue;
    } else if (daysLeft > 2) {
      timeLeftText = '${daysLeft}일 후 종료';
      timeColor = Colors.orange;
    } else if (daysLeft > 0) {
      timeLeftText = '${daysLeft}일 ${hoursLeft}시간 후 종료';
      timeColor = Colors.red;
    } else if (hoursLeft > 0) {
      timeLeftText = '${hoursLeft}시간 후 종료';
      timeColor = Colors.red;
    } else {
      timeLeftText = '곧 종료';
      timeColor = Colors.red;
    }
    
    final dateFormat = DateFormat('MM월 dd일 HH:mm');
    final expiryDateText = dateFormat.format(nearestExpiry.expiry!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule, color: timeColor, size: 18),
            const SizedBox(width: 6),
            Text(
              '할인 종료',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              timeLeftText,
              style: TextStyle(
                color: timeColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              expiryDateText,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
        if (nearestExpiry.shop.name.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${nearestExpiry.shop.name} 기준',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStoreListSection() {
    // 유명 스토어 목록
    final majorStores = [
      StoreIds.steam,
      StoreIds.epicGames,
      StoreIds.gog,
      StoreIds.humbleStore,
      StoreIds.greenManGaming,
      StoreIds.fanatical,
    ];

    // 딜 필터링 및 정렬
    final filteredDeals = _gameDetail!.deals.where((deal) {
      final storeName = StoreIds.getStoreName(deal.storeID);
      final isMajorStore = majorStores.contains(deal.storeID);
      final hasDiscount = deal.savingsPercent > 0;
      
      // 유명 스토어는 항상 표시, 마이너 스토어는 할인 있을 때만
      if (isMajorStore) return true;
      if (storeName == 'Unknown Store') return hasDiscount; // UnknownStore는 할인 있을 때만
      return hasDiscount; // 기타 마이너 스토어는 할인 있을 때만
    }).toList();

    // 정렬: 알려진 스토어 우선 > 가격순
    filteredDeals.sort((a, b) {
      final aStoreName = StoreIds.getStoreName(a.storeID);
      final bStoreName = StoreIds.getStoreName(b.storeID);
      final aIsUnknown = aStoreName == 'Unknown Store';
      final bIsUnknown = bStoreName == 'Unknown Store';
      
      // Unknown Store는 하단으로
      if (aIsUnknown && !bIsUnknown) return 1;
      if (!aIsUnknown && bIsUnknown) return -1;
      
      // 나머지는 가격순
      return a.priceNum.compareTo(b.priceNum);
    });

    if (filteredDeals.isEmpty) {
      return const SizedBox(); // 표시할 딜이 없으면 섹션 숨김
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.store, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '🏪 판매 중인 스토어',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...filteredDeals.map((deal) => _buildStoreItem(deal)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreItem(Deal deal) {
    final storeName = StoreIds.getStoreName(deal.storeID);
    final isBestPrice = deal == _getBestDeal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBestPrice ? Colors.green.shade900.withOpacity(0.3) : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: isBestPrice
            ? Border.all(color: Colors.green.shade600, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isBestPrice) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '✨ 최저가',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\$${deal.price}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (deal.savingsPercent > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '-${deal.savingsPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openStorePage(deal.dealID),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('구매'),
          ),
        ],
      ),
    );
  }

  Widget _buildSteamRatingCard() {
    if (_steamRatingData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.videogame_asset, color: Colors.blue.shade400, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Steam 평점 정보 로딩 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ratingPercent = int.tryParse(_steamRatingData!['steamRatingPercent'] ?? '0') ?? 0;
    final ratingCount = _steamRatingData!['steamRatingCount'] ?? '0';
    
    // 평점이 없는 경우
    if (ratingPercent == 0 || ratingCount == '0') {
      return const SizedBox();
    }

    // 평점에 따른 색상 및 텍스트
    Color ratingColor;
    String ratingText;
    IconData ratingIcon;
    
    if (ratingPercent >= 95) {
      ratingColor = Colors.purple;
      ratingText = '압도적으로 긍정적';
      ratingIcon = Icons.sentiment_very_satisfied;
    } else if (ratingPercent >= 85) {
      ratingColor = Colors.blue;
      ratingText = '매우 긍정적';
      ratingIcon = Icons.sentiment_satisfied;
    } else if (ratingPercent >= 80) {
      ratingColor = Colors.lightBlue;
      ratingText = '긍정적';
      ratingIcon = Icons.thumb_up;
    } else if (ratingPercent >= 70) {
      ratingColor = Colors.lightGreen;
      ratingText = '대체로 긍정적';
      ratingIcon = Icons.thumb_up_outlined;
    } else if (ratingPercent >= 40) {
      ratingColor = Colors.orange;
      ratingText = '복합적';
      ratingIcon = Icons.thumbs_up_down;
    } else if (ratingPercent >= 20) {
      ratingColor = Colors.deepOrange;
      ratingText = '대체로 부정적';
      ratingIcon = Icons.thumb_down_outlined;
    } else {
      ratingColor = Colors.red;
      ratingText = '매우 부정적';
      ratingIcon = Icons.sentiment_dissatisfied;
    }

    // 리뷰 수 포맷팅
    final reviewCount = int.tryParse(ratingCount) ?? 0;
    String formattedCount;
    if (reviewCount >= 1000000) {
      formattedCount = '${(reviewCount / 1000000).toStringAsFixed(1)}M';
    } else if (reviewCount >= 1000) {
      formattedCount = '${(reviewCount / 1000).toStringAsFixed(1)}K';
    } else {
      formattedCount = reviewCount.toString();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videogame_asset, color: Colors.blue.shade400, size: 32),
                const SizedBox(width: 12),
                const Text(
                  '🎮 Steam 평가',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(ratingIcon, color: ratingColor, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ratingColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              ratingText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$ratingPercent% 긍정적 ($formattedCount개의 평가)',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 평점 바
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratingPercent / 100,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(ratingColor),
                minHeight: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceHistoryChart() {
    if (_priceHistory == null || _priceHistory!.isEmpty) {
      return const SizedBox();
    }

    // 가격 히스토리 데이터를 날짜순으로 정렬
    final sortedHistory = List<PriceHistory>.from(_priceHistory!)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 주간 데이터로 그룹화 (캔들스틱)
    final weeklyData = <Map<String, dynamic>>[];
    DateTime? currentWeekStart;
    List<double> weekPrices = [];
    DateTime? weekFirstDate;
    
    for (var history in sortedHistory) {
      final weekStart = history.timestamp.subtract(
        Duration(days: history.timestamp.weekday - 1)
      );
      final weekKey = DateTime(weekStart.year, weekStart.month, weekStart.day);
      
      if (currentWeekStart == null || weekKey != currentWeekStart) {
        // 이전 주 데이터 저장
        if (weekPrices.isNotEmpty) {
          weeklyData.add({
            'date': weekFirstDate!,
            'low': weekPrices.reduce(min),
            'high': weekPrices.reduce(max),
            'open': weekPrices.first,
            'close': weekPrices.last,
          });
        }
        
        // 새로운 주 시작
        currentWeekStart = weekKey;
        weekPrices = [history.deal.price.amount];
        weekFirstDate = history.timestamp;
      } else {
        weekPrices.add(history.deal.price.amount);
      }
    }
    
    // 마지막 주 데이터 추가
    if (weekPrices.isNotEmpty && weekFirstDate != null) {
      weeklyData.add({
        'date': weekFirstDate,
        'low': weekPrices.reduce(min),
        'high': weekPrices.reduce(max),
        'open': weekPrices.first,
        'close': weekPrices.last,
      });
    }

    // 데이터 없으면 차트 표시 안함
    if (weeklyData.isEmpty) {
      return const SizedBox();
    }

    // 전체 가격 범위 계산
    double minPrice = double.infinity;
    double maxPrice = 0;
    
    for (var data in weeklyData) {
      final low = (data['low'] as num).toDouble();
      final high = (data['high'] as num).toDouble();
      if (low < minPrice) minPrice = low;
      if (high > maxPrice) maxPrice = high;
    }

    // Y축 범위 설정 (약간의 여유 추가)
    final yMin = max(0.0, minPrice - 5);
    final yMax = maxPrice + 5;

    // 평균가 계산
    final avgPrice = weeklyData.map((d) => ((d['high'] as num).toDouble() + (d['low'] as num).toDouble()) / 2)
        .reduce((a, b) => a + b) / weeklyData.length;

    // 꺾은선 그래프용 데이터 포인트 (주간 평균가)
    final spots = weeklyData.asMap().entries.map((entry) {
      final data = entry.value;
      final avgWeekPrice = ((data['high'] as num).toDouble() + (data['low'] as num).toDouble()) / 2;
      return FlSpot(entry.key.toDouble(), avgWeekPrice);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '📈 6개월 가격 추이 (주간)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '← 좌우로 스와이프하여 기간 탐색 • 탭하여 상세 정보 (${weeklyData.length}주)',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: weeklyData.length * 50.0,
                  child: LineChart(
                    LineChartData(
                      minY: yMin,
                      maxY: yMax,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blue.shade400,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: Colors.blue.shade600,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400.withOpacity(0.3),
                                Colors.blue.shade400.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= weeklyData.length) {
                            return const Text('');
                          }
                          
                          final date = weeklyData[index]['date'] as DateTime;
                          final dateFormat = DateFormat('MM/dd');
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dateFormat.format(date),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (yMax - yMin) / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade800,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade700),
                      bottom: BorderSide(color: Colors.grey.shade700),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= weeklyData.length) {
                            return null;
                          }
                          
                          final data = weeklyData[index];
                          final date = data['date'] as DateTime;
                          final dateFormat = DateFormat('MM월 dd일');
                          
                          return LineTooltipItem(
                            '${dateFormat.format(date)}\n'
                            '최고: \$${data['high'].toStringAsFixed(2)}\n'
                            '최저: \$${data['low'].toStringAsFixed(2)}\n'
                            '평균: \$${spot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                ),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPriceStatItem(
                  '최저가',
                  '\$${minPrice.toStringAsFixed(2)}',
                  Colors.green,
                ),
                _buildPriceStatItem(
                  '최고가',
                  '\$${maxPrice.toStringAsFixed(2)}',
                  Colors.red,
                ),
                _buildPriceStatItem(
                  '평균가',
                  '\$${avgPrice.toStringAsFixed(2)}',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '* 각 점은 주간 평균 가격을 나타냅니다. 터치하여 상세 정보를 확인하세요.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _openStorePage(String dealID) async {
    try {
      final url = Uri.parse('https://www.cheapshark.com/redirect?dealID=$dealID');
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('페이지를 열 수 없습니다: $e')),
        );
      }
    }
  }
}
