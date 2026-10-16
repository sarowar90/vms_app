import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/json_utils.dart';
import '../domain/settings_repository.dart';

class SettingsRemoteDataSource {
  const SettingsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<CompanySettings> get() async => _fromJson(await _api.get('settings') as Map<String, dynamic>);

  Future<CompanySettings> save(CompanySettings s) async => _fromJson(
    await _api.put(
          'settings',
          data: {
            'company_name': s.companyName,
            'company_name_bn': s.companyNameBn ?? '',
            'company_address': s.address ?? '',
            'company_phone': s.phone ?? '',
            'badge_footer': s.badgeFooter ?? '',
            'require_approval': s.requireApproval ? '1' : '0',
            'default_language': s.defaultLanguage,
          },
        )
        as Map<String, dynamic>,
  );

  /// `SettingsController::logo()` accepts a data URI in `image` as well as a file upload.
  Future<String?> uploadLogo(String dataUri) async {
    final d = await _api.post('settings/logo', data: {'image': dataUri}) as Map<String, dynamic>;
    return AppConfig.resolveUrl(parseString(d['company_logo_url']));
  }

  static CompanySettings _fromJson(Map<String, dynamic> j) => CompanySettings(
    companyName: j['company_name']?.toString() ?? '',
    companyNameBn: parseString(j['company_name_bn']),
    address: parseString(j['company_address']),
    phone: parseString(j['company_phone']),
    badgeFooter: parseString(j['badge_footer']),
    // Default on, like `Helpers::setting('require_approval', '1')`.
    requireApproval: (j['require_approval']?.toString() ?? '1') == '1',
    defaultLanguage: j['default_language']?.toString() == 'bn' ? 'bn' : 'en',
    logoUrl: AppConfig.resolveUrl(parseString(j['company_logo_url'])),
    companyCode: parseString(j['company_code']),
  );
}

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._remote);

  final SettingsRemoteDataSource _remote;

  @override
  Future<Result<CompanySettings>> get() => guard(_remote.get);

  @override
  Future<Result<CompanySettings>> save(CompanySettings settings) => guard(() => _remote.save(settings));

  @override
  Future<Result<String?>> uploadLogo(String dataUri) => guard(() => _remote.uploadLogo(dataUri));
}
