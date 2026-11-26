import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

enum AuthMode { login, signup, forgot }

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _field = TextEditingController();
  AuthMode _mode = AuthMode.login;
  int? _year;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _field.dispose();
    super.dispose();
  }

  void _switch(AuthMode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
      });

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_mode == AuthMode.login) {
        await AuthService.signIn(_email.text, _password.text);
      } else if (_mode == AuthMode.signup) {
        await AuthService.register(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          fieldOfStudy: _field.text.trim().isEmpty ? null : _field.text.trim(),
          yearOfStudy: _year,
        );
      } else {
        await AuthService.sendPasswordReset(_email.text);
        _info = 'If an account exists for that email, a reset link is on its way.';
      }
    } catch (e) {
      _error = friendlyError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final title = switch (_mode) {
      AuthMode.login => 'Welcome back \u{1F44B}',
      AuthMode.signup => 'Your campus starts here.',
      AuthMode.forgot => 'Let\u2019s get you back in.',
    };
    final cta = switch (_mode) {
      AuthMode.login => 'Log in',
      AuthMode.signup => 'Create account',
      AuthMode.forgot => 'Send reset link',
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(9)),
                        child: const Text('c',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                      const SizedBox(width: 9),
                      Text('campusconnect', style: Txt.brandLarge(context)),
                    ]),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(children: [
                        Image.asset('assets/images/campus-community.jpg',
                            height: 170, width: double.infinity, fit: BoxFit.cover),
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xCC2B1F6E), Color(0x00000000)]),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 16,
                          bottom: 14,
                          child: Text('Big ideas start\nwith a connection.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    Text(title, style: Txt.h1(context)),
                    const SizedBox(height: 16),
                    if (_mode == AuthMode.signup) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Full name', hintText: 'Your name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'University email', hintText: 'you@university.edu'),
                      validator: (v) => (v == null || !v.contains('@') || v.trim().length < 5)
                          ? 'Enter a valid email.'
                          : null,
                    ),
                    if (_mode != AuthMode.forgot) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        autofillHints: [_mode == AuthMode.login ? AutofillHints.password : AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: _mode == AuthMode.login ? 'Password' : 'At least 12 characters',
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your password.';
                          if (_mode == AuthMode.signup && v.length < 12) return 'Use at least 12 characters.';
                          return null;
                        },
                      ),
                    ],
                    if (_mode == AuthMode.signup) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _field,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Field of study (optional)', hintText: 'e.g. Computer Science'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _year,
                        decoration: const InputDecoration(labelText: 'Year of study (optional)'),
                        items: [for (var y = 1; y <= 8; y++) DropdownMenuItem(value: y, child: Text('Year $y'))],
                        onChanged: (v) => setState(() => _year = v),
                      ),
                    ],
                    if (_mode == AuthMode.login)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => _switch(AuthMode.forgot), child: const Text('Forgot password?')),
                      ),
                    const SizedBox(height: 12),
                    if (_error != null) ErrorNote(_error!),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_info!, style: TextStyle(color: p.success, fontSize: 13)),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('$cta \u2192'),
                    ),
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_mode == AuthMode.login ? 'New to campus?' : 'Already a member?',
                          style: Txt.caption(context)),
                      TextButton(
                        onPressed: () => _switch(_mode == AuthMode.login ? AuthMode.signup : AuthMode.login),
                        child: Text(_mode == AuthMode.login ? 'Create an account' : 'Log in'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
