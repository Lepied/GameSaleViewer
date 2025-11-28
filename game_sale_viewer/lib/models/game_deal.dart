/// CheapShark API의 Deal 정보를 담는 모델
class GameDeal {
  final String dealID;
  final String gameID;
  final String title;
  final String storeID;
  final String salePrice;
  final String normalPrice;
  final String savings;
  final String metacriticScore;
  final String steamRatingPercent;
  final String steamRatingCount;
  final String thumb;
  final bool isOnSale;
  final int dealRating;

  GameDeal({
    required this.dealID,
    required this.gameID,
    required this.title,
    required this.storeID,
    required this.salePrice,
    required this.normalPrice,
    required this.savings,
    required this.metacriticScore,
    required this.steamRatingPercent,
    required this.steamRatingCount,
    required this.thumb,
    required this.isOnSale,
    required this.dealRating,
  });

  /// JSON에서 객체로 변환
  factory GameDeal.fromJson(Map<String, dynamic> json) {
    return GameDeal(
      dealID: json['dealID'] ?? json['cheapestDealID'] ??'',
      gameID: json['gameID'] ?? '',
      title: json['title'] ?? json['external'] ?? '',
      storeID: json['storeID'] ?? '',
      salePrice: json['salePrice'] ?? json['cheapest'] ?? '0.00',
      normalPrice: json['normalPrice'] ?? json['cheapest'] ?? '0.00',
      savings: json['savings'] ?? '0',
      metacriticScore: json['metacriticScore'] ?? '0',
      steamRatingPercent: json['steamRatingPercent'] ?? '0',
      steamRatingCount: json['steamRatingCount'] ?? '0',
      thumb: json['thumb'] ?? '',
      isOnSale: json['isOnSale'] == '1' || json['isOnSale'] == true,
      dealRating: int.tryParse(json['dealRating']?.toString() ?? '0') ?? 0,
    );
  }

  /// 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'dealID': dealID,
      'gameID': gameID,
      'title': title,
      'storeID': storeID,
      'salePrice': salePrice,
      'normalPrice': normalPrice,
      'savings': savings,
      'metacriticScore': metacriticScore,
      'steamRatingPercent': steamRatingPercent,
      'steamRatingCount': steamRatingCount,
      'thumb': thumb,
      'isOnSale': isOnSale,
      'dealRating': dealRating,
    };
  }

  /// 할인율을 숫자로 반환
  double get savingsPercent => double.tryParse(savings) ?? 0.0;

  /// 판매가를 숫자로 반환
  double get salePriceNum => double.tryParse(salePrice) ?? 0.0;

  /// 정상가를 숫자로 반환
  double get normalPriceNum => double.tryParse(normalPrice) ?? 0.0;

  /// 메타크리틱 점수를 숫자로 반환
  int get metacriticScoreNum => int.tryParse(metacriticScore) ?? 0;

  /// Deal Rating 계산 (할인율 + 메타크리틱 점수 기반)
  String get dealRatingText {
    if (savingsPercent >= 75 && metacriticScoreNum >= 80) {
      return 'Super Deal';
    } else if (savingsPercent >= 50 && metacriticScoreNum >= 70) {
      return 'Good Deal';
    } else if (savingsPercent >= 30) {
      return 'Fair Deal';
    } else {
      return 'Wait';
    }
  }

  /// Deal Rating 색상
  String get dealRatingColor {
    if (savingsPercent >= 75 && metacriticScoreNum >= 80) {
      return '#4CAF50'; // Green
    } else if (savingsPercent >= 50 && metacriticScoreNum >= 70) {
      return '#2196F3'; // Blue
    } else if (savingsPercent >= 30) {
      return '#FF9800'; // Orange
    } else {
      return '#F44336'; // Red
    }
  }
}
