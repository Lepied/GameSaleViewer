import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite.dart';
import '../services/supabase_service.dart';

/// 인증 및 찜 목록을 관리하는 Provider
class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  User? _currentUser;
  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  List<Favorite> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  AuthProvider() {
    _currentUser = _supabaseService.currentUser;
    _listenToAuthChanges();
    if (isLoggedIn) {
      loadFavorites();
    }
  }

  /// 인증 상태 변경 감지
  void _listenToAuthChanges() {
    _supabaseService.client.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      if (_currentUser != null) {
        loadFavorites();
      } else {
        _favorites = [];
      }
      notifyListeners();
    });
  }

  /// 회원가입
  Future<bool> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );
      
      _currentUser = response.user;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '회원가입에 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 로그인
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      _currentUser = response.user;
      await loadFavorites();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '로그인에 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
      _currentUser = null;
      _favorites = [];
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '로그아웃에 실패했습니다: $e';
      notifyListeners();
    }
  }

  /// 찜 목록 로드
  Future<void> loadFavorites() async {
    if (!isLoggedIn) return;

    try {
      _favorites = await _supabaseService.getFavorites();
      notifyListeners();
    } catch (e) {
      print('찜 목록 로드 실패: $e');
    }
  }

  /// 찜 목록에 추가
  Future<bool> addFavorite({
    required String gameId,
    required String gameTitle,
    required String thumbUrl,
  }) async {
    if (!isLoggedIn) {
      _error = '로그인이 필요합니다';
      notifyListeners();
      return false;
    }

    try {
      final favorite = Favorite(
        userId: _currentUser!.id,
        gameId: gameId,
        gameTitle: gameTitle,
        thumbUrl: thumbUrl,
      );

      await _supabaseService.addFavorite(favorite);
      await loadFavorites();
      return true;
    } catch (e) {
      _error = '찜하기에 실패했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 찜 목록에서 제거
  Future<bool> removeFavorite(String gameId) async {
    if (!isLoggedIn) return false;

    try {
      await _supabaseService.removeFavorite(gameId);
      await loadFavorites();
      return true;
    } catch (e) {
      _error = '찜 해제에 실패했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 특정 게임이 찜 목록에 있는지 확인
  bool isFavorite(String gameId) {
    return _favorites.any((fav) => fav.gameId == gameId);
  }

  /// 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
