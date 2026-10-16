import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

const _green = Color(0xFF006A4E);
const _greenDeep = Color(0xFF0F2A22);

/// Sign-in (web: `login.php`): brand header on the web's green gradient,
/// sign-in card below.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(loginControllerProvider.notifier).submit(username: _username.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(loginControllerProvider);
    final theme = Theme.of(context);
    final headerHeight = MediaQuery.sizeOf(context).height * 0.42;

    // Light status-bar icons over the green header.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            // Curved gradient header (web: .login-page background).
            Container(
              height: headerHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_green, _greenDeep],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        const _Brand(),
                        const SizedBox(height: 28),
                        _card(theme, login),
                        const SizedBox(height: 20),
                        Text(
                          '© ${DateTime.now().year} VMS · Visitor Management System',
                          textAlign: .center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, AsyncValue<void> login) {
    final scheme = theme.colorScheme;
    InputDecoration deco(String label, IconData icon, {Widget? suffix}) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _green, width: 2),
      ),
    );

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Text('Welcome back', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: .w700)),
                const SizedBox(height: 4),
                Text('Sign in to manage visitors', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _username,
                  decoration: deco('Username', Icons.person_outline),
                  textInputAction: .next,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.username],
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  decoration: deco(
                    'Password',
                    Icons.lock_outline,
                    suffix: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: .done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                ),
                if (login.hasError) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(login.error.toString(), style: TextStyle(color: scheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: login.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: .w600),
                  ),
                  icon: login.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login),
                  label: Text(login.isLoading ? 'Signing in…' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App icon + name on the green header.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/icon/app_icon.png', width: 88, height: 88),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Visitor Management System',
          textAlign: .center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: .w700, letterSpacing: 0.2),
        ),
        const SizedBox(height: 4),
        Text(
          'Secure, simple visitor check-in',
          textAlign: .center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
        ),
      ],
    );
  }
}
