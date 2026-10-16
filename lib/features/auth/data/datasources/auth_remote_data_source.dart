import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

class LoginResponse {
  const LoginResponse({required this.token, required this.user});

  final String token;
  final UserModel user;
}

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<LoginResponse> login(String username, String password) async {
    final data = await _api.post(
      'auth/login',
      data: {'username': username, 'password': password},
    ) as Map<String, dynamic>;
    return LoginResponse(
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<UserModel> me() async {
    final data = await _api.get('auth/me') as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> logout() => _api.post('auth/logout');
}
