import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/game_deal_card.dart';

/// 게임 검색 화면 (하단바에서 접근)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  bool _isSearching = false;
  String _sortOption = 'relevance';

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = 200.0; // 픽셀
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - threshold) {
      final gp = Provider.of<GameProvider>(context, listen: false);
      gp.loadMoreSearchResults();
    }
  }

  void _performSearch(GameProvider gameProvider) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    gameProvider.searchGames(query, sort: _sortOption).then((_) {
      setState(() {
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gameProvider = Provider.of<GameProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '게임 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          gameProvider.clearSearch();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
              ),
              onSubmitted: (_) => _performSearch(gameProvider),
            ),
          ),
          // 정렬 옵션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('정렬:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortOption,
                  items: const [
                    DropdownMenuItem(value: 'relevance', child: Text('정확도순')),
                    DropdownMenuItem(value: 'popularity', child: Text('인기순')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sortOption = v;
                    });
                    // 이미 텍스트가 있으면 다시 검색
                    if (_searchController.text.trim().isNotEmpty) {
                      _performSearch(gameProvider);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(gameProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(GameProvider gameProvider) {
    if (_isSearching || gameProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gameProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              gameProvider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(gameProvider),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (gameProvider.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? '게임 이름을 검색해보세요'
                  : '검색 결과가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final results = gameProvider.searchResults;
    final isLoadingMore = gameProvider.isLoadingMore;
    return ListView.builder(
      controller: _scrollController,
      itemCount: results.length + (isLoadingMore ? 1 : 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return GameDealCard(
          deal: results[index],
        );
      },
    );
  }
}
