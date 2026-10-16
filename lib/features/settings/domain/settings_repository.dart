import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';

/// Company settings (web: Setup → Settings).
class CompanySettings {
  const CompanySettings({
    required this.companyName,
    this.companyNameBn,
    this.address,
    this.phone,
    this.badgeFooter,
    this.requireApproval = true,
    this.defaultLanguage = 'en',
    this.logoUrl,
    this.companyCode,
  });

  final String companyName;
  final String? companyNameBn;
  final String? address;
  final String? phone;

  /// Footer text on the visitor pass.
  final String? badgeFooter;

  /// When off, all pre-registrations are approved automatically.
  final bool requireApproval;

  /// `en` or `bn`.
  final String defaultLanguage;
  final String? logoUrl;
  final String? companyCode;
}

abstract interface class SettingsRepository {
  Future<Result<CompanySettings>> get();

  Future<Result<CompanySettings>> save(CompanySettings settings);

  /// [dataUri] is `data:image/jpeg;base64,...` (PNG/JPG, max 2 MB). Returns the new logo URL.
  Future<Result<String?>> uploadLogo(String dataUri);
}

class GetSettings implements UseCase<CompanySettings, NoParams> {
  const GetSettings(this._repo);

  final SettingsRepository _repo;

  @override
  Future<Result<CompanySettings>> call(NoParams params) => _repo.get();
}

class SaveSettings implements UseCase<CompanySettings, CompanySettings> {
  const SaveSettings(this._repo);

  final SettingsRepository _repo;

  @override
  Future<Result<CompanySettings>> call(CompanySettings s) => _repo.save(s);
}

class UploadLogo implements UseCase<String?, String> {
  const UploadLogo(this._repo);

  final SettingsRepository _repo;

  @override
  Future<Result<String?>> call(String dataUri) => _repo.uploadLogo(dataUri);
}
