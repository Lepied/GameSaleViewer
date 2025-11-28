/// CheapShark API의 게임 상세 정보를 담는 모델
class GameDetail {
  final String gameID;
  final String title;
  final String steamAppID;
  final String thumb;
  final CheaperStores cheaperStores;
  final List<Deal> deals;

  GameDetail({
    required this.gameID,
    required this.title,
    required this.steamAppID,
    required this.thumb,
    required this.cheaperStores,
    required this.deals,
  });

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    return GameDetail(
      gameID: json['gameID'] ?? '',
      title: json['info']?['title'] ?? '',
      steamAppID: json['info']?['steamAppID'] ?? '',
      thumb: json['info']?['thumb'] ?? '',
      cheaperStores: CheaperStores.fromJson(
        json['cheaperStores'] ?? [],
      ),
      deals: (json['deals'] as List<dynamic>?)
              ?.map((e) => Deal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CheaperStores {
  final List<String> stores;

  CheaperStores({required this.stores});

  factory CheaperStores.fromJson(List<dynamic> json) {
    return CheaperStores(
      stores: json.map((e) => e.toString()).toList(),
    );
  }
}

class Deal {
  final String storeID;
  final String dealID;
  final String price;
  final String retailPrice;
  final String savings;

  Deal({
    required this.storeID,
    required this.dealID,
    required this.price,
    required this.retailPrice,
    required this.savings,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      storeID: json['storeID']?.toString() ?? '',
      dealID: json['dealID']?.toString() ?? '',
      price: json['price']?.toString() ?? '0.00',
      retailPrice: json['retailPrice']?.toString() ?? '0.00',
      savings: json['savings']?.toString() ?? '0',
    );
  }

  double get savingsPercent => double.tryParse(savings) ?? 0.0;
  double get priceNum => double.tryParse(price) ?? 0.0;
  double get retailPriceNum => double.tryParse(retailPrice) ?? 0.0;
}
