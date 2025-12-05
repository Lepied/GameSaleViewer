import 'dart:convert';
import 'package:http/http.dart' as http;

/// Steam Store lightweight helper using public store endpoints (no API key required)
class SteamService {
  static const _storeSearchUrl = 'https://store.steampowered.com/api/storesearch/';
  static const _appDetailsUrl = 'https://store.steampowered.com/api/appdetails';

  /// Search the Steam store for [term]. Returns list of items with `id` and `name`.
  /// [locale] examples: 'koreana', 'english'
  Future<List<Map<String, dynamic>>> searchStore(String term, {int size = 10, int start = 0, String locale = 'koreana'}) async {
    try {
      final params = {
        'term': term,
        'l': locale,
        'cc': 'us',
        'size': size.toString(),
      };
      // some storesearch endpoints accept a 'start' or 'offset' param; include if provided
      if (start > 0) params['start'] = start.toString();
      final uri = Uri.parse(_storeSearchUrl).replace(queryParameters: params);

      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((e) => {
        'id': e['id'],
        'name': e['name'],
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get app details for an app id. Returns map containing `name` (localized) if available.
  Future<Map<String, dynamic>?> getAppDetails(int appId, {String locale = 'english'}) async {
    try {
      final uri = Uri.parse(_appDetailsUrl).replace(queryParameters: {
        'appids': appId.toString(),
        'l': locale,
      });
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final entry = data[appId.toString()] as Map<String, dynamic>?;
      if (entry == null) return null;
      if (entry['success'] == true) {
        final d = entry['data'] as Map<String, dynamic>;
        return {'name': d['name']};
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
