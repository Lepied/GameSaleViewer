import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite.dart';

/// Supabase 서비스 클래스
/// 인증 및 데이터베이스 관리를 담당
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Supabase 클라이언트 반환
  SupabaseClient get client => _client;

  /// 현재 로그인한 사용자 반환
  User? get currentUser => _client.auth.currentUser;

  /// 로그인 상태 확인
  bool get isLoggedIn => currentUser != null;

  /// 이메일/비밀번호로 회원가입
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      // 프로필 생성
      if (response.user != null) {
        await _client.from('profiles').insert({
          'id': response.user!.id,
          'username': username ?? email.split('@')[0],
        });
      }

      return response;
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  /// 찜 목록 조회
  Future<List<Favorite>> getFavorites() async {
    try {
      if (!isLoggedIn) {
        throw Exception('User not logged in');
      }

      final response = await _client
          .from('favorites')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Favorite.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      rethrow;
    }
  }

  /// 찜 목록에 게임 추가
  Future<void> addFavorite(Favorite favorite) async {
    try {
      if (!isLoggedIn) {
        throw Exception('User not logged in');
      }

      await _client.from('favorites').insert(favorite.toInsertJson());
    } catch (e) {
      print('Error adding favorite: $e');
      rethrow;
    }
  }

  /// 찜 목록에서 게임 제거
  Future<void> removeFavorite(String gameId) async {
    try {
      if (!isLoggedIn) {
        throw Exception('User not logged in');
      }

      await _client
          .from('favorites')
          .delete()
          .eq('user_id', currentUser!.id)
          .eq('game_id', gameId);
    } catch (e) {
      print('Error removing favorite: $e');
      rethrow;
    }
  }

  /// 특정 게임이 찜 목록에 있는지 확인
  Future<bool> isFavorite(String gameId) async {
    try {
      if (!isLoggedIn) {
        return false;
      }

      final response = await _client
          .from('favorites')
          .select()
          .eq('user_id', currentUser!.id)
          .eq('game_id', gameId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking favorite: $e');
      return false;
    }
  }

  /// 사용자 프로필 조회
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!isLoggedIn) {
        return null;
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// 사용자 프로필 업데이트
  Future<void> updateUserProfile({
    required String username,
  }) async {
    try {
      if (!isLoggedIn) {
        throw Exception('User not logged in');
      }

      await _client.from('profiles').update({
        'username': username,
      }).eq('id', currentUser!.id);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
}
