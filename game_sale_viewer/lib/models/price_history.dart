/// IsThereAnyDeal API의 가격 히스토리 모델
class PriceHistory {
  final DateTime timestamp;
  final Shop shop;
  final DealInfo deal;

  PriceHistory({
    required this.timestamp,
    required this.shop,
    required this.deal,
  });

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    return PriceHistory(
      timestamp: DateTime.parse(json['timestamp']),
      shop: Shop.fromJson(json['shop']),
      deal: DealInfo.fromJson(json['deal']),
    );
  }
}

class Shop {
  final int id;
  final String name;

  Shop({
    required this.id,
    required this.name,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }
}

class DealInfo {
  final PriceInfo price;
  final PriceInfo regular;
  final double cut;

  DealInfo({
    required this.price,
    required this.regular,
    required this.cut,
  });

  factory DealInfo.fromJson(Map<String, dynamic> json) {
    return DealInfo(
      price: PriceInfo.fromJson(json['price']),
      regular: PriceInfo.fromJson(json['regular']),
      cut: (json['cut'] as num).toDouble(),
    );
  }
}

class PriceInfo {
  final double amount;
  final String currency;

  PriceInfo({
    required this.amount,
    required this.currency,
  });

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] ?? 'USD',
    );
  }
}

/// 역대 최저가 정보
class HistoricalLow {
  final PriceInfo price;
  final DateTime date;
  final Shop shop;

  HistoricalLow({
    required this.price,
    required this.date,
    required this.shop,
  });

  factory HistoricalLow.fromJson(Map<String, dynamic> json) {
    return HistoricalLow(
      price: PriceInfo.fromJson(json['price']),
      date: DateTime.parse(json['timestamp']),
      shop: Shop.fromJson(json['shop']),
    );
  }
}

/// IsThereAnyDeal 게임 조회 결과
class ITADGame {
  final String id;
  final String slug;
  final String title;

  ITADGame({
    required this.id,
    required this.slug,
    required this.title,
  });

  factory ITADGame.fromJson(Map<String, dynamic> json) {
    return ITADGame(
      id: json['id'] ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
    );
  }
}

/// 현재 가격 정보 (할인 종료 시점 포함)
class CurrentPrice {
  final PriceInfo price;
  final PriceInfo regular;
  final double cut;
  final Shop shop;
  final DateTime? expiry; // 할인 종료 시점 (nullable)
  final String url;

  CurrentPrice({
    required this.price,
    required this.regular,
    required this.cut,
    required this.shop,
    this.expiry,
    required this.url,
  });

  factory CurrentPrice.fromJson(Map<String, dynamic> json) {
    // prices/v2 API는 최상위 레벨에 바로 필드들이 있음
    return CurrentPrice(
      price: json['price'] != null 
          ? PriceInfo.fromJson(json['price'])
          : PriceInfo(amount: 0, currency: 'USD'),
      regular: json['regular'] != null
          ? PriceInfo.fromJson(json['regular'])
          : PriceInfo(amount: 0, currency: 'USD'),
      cut: json['cut'] != null ? (json['cut'] as num).toDouble() : 0.0,
      shop: json['shop'] != null 
          ? Shop.fromJson(json['shop'])
          : Shop(id: 0, name: 'Unknown'),
      expiry: json['expiry'] != null 
          ? DateTime.parse(json['expiry'])
          : null,
      url: json['url'] ?? '',
    );
  }

  bool get isOnSale => cut > 0;
  bool get hasExpiry => expiry != null;
}
