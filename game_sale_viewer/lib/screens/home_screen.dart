import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/game_provider.dart';
import '../widgets/game_deal_card.dart';
import '../widgets/store_filter.dart';
import 'game_detail_screen.dart';

/// 홈 화면 (하단바에서 접근)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameProvider>(context, listen: false).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);

    return RefreshIndicator(
        onRefresh: () => gameProvider.loadInitialData(),
        child: CustomScrollView(
          slivers: [
            // 오늘의 특가 배너 섹션
            if (gameProvider.specialDeals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '오늘의 특가',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '75% 이상 할인',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SpecialDealsBanner(deals: gameProvider.specialDeals),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 메타스코어 90+ 섹션
            if (gameProvider.highRatedDeals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '메타스코어 90+ 할인',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '최고 평점 게임',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: gameProvider.highRatedDeals.take(10).length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 180,
                        margin: const EdgeInsets.only(right: 12),
                        child: GameDealCard(
                          deal: gameProvider.highRatedDeals[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // 스토어별 게임 섹션 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Text(
                      '스토어별 게임',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 스토어 필터
            SliverToBoxAdapter(
              child: StoreFilter(
                selectedStoreId: gameProvider.selectedStoreId,
                onStoreSelected: (storeId) {
                  if (storeId == null) {
                    gameProvider.clearFilter();
                  } else {
                    gameProvider.filterByStore(storeId);
                  }
                },
              ),
            ),

            // 로딩 상태
            if (gameProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            // 에러 상태
            else if (gameProvider.error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        gameProvider.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => gameProvider.loadInitialData(),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              )
            // 딜 목록
            else if (gameProvider.displayDeals.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('딜이 없습니다'),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return GameDealCard(
                      deal: gameProvider.displayDeals[index],
                    );
                  },
                  childCount: gameProvider.displayDeals.length,
                ),
              ),
          ],
        ),
    );
  }
}

/// 특가 배너 위젯 (PageView with indicator)
class _SpecialDealsBanner extends StatefulWidget {
  final List deals;

  const _SpecialDealsBanner({required this.deals});

  @override
  State<_SpecialDealsBanner> createState() => _SpecialDealsBannerState();
}

class _SpecialDealsBannerState extends State<_SpecialDealsBanner> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.deals.length,
            itemBuilder: (context, index) {
              final deal = widget.deals[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: _BannerCard(deal: deal),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // 인디케이터 점
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.deals.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? const Color(0xFF66c0f4)
                    : Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 배너 카드 위젯
class _BannerCard extends StatelessWidget {
  final dynamic deal;

  const _BannerCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(gameId: deal.gameID),
          ),
        );
      },
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1E1E1E),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 배경 이미지
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: deal.thumb,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.darken,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[850],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[850],
                    child: const Icon(Icons.broken_image, size: 50),
                  ),
                ),
              ),
              // 단색 오버레이 (그라데이션 제거)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              // 내용
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 할인율 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C6B22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '-${deal.savings.split('.')[0]}%',
                        style: const TextStyle(
                          color: const Color(0xFFB8E712),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 게임 제목
                    Text(
                      deal.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 가격
                    Row(
                      children: [
                        if (deal.normalPrice != deal.salePrice) ...[
                          Text(
                            '\$${double.parse(deal.normalPrice).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '\$${double.parse(deal.salePrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB8E712)
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
