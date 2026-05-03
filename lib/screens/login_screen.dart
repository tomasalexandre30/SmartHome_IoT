import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureCode = true;

  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _adminCtrl    = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _adminCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    _animCtrl.reverse().then((_) {
      setState(() => _isLogin = !_isLogin);
      _animCtrl.forward();
    });
    _formKey.currentState?.reset();
    _emailCtrl.clear();
    _passCtrl.clear();
    _nameCtrl.clear();
    _adminCtrl.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthService>();

    final error = _isLogin
        ? await auth.login(_emailCtrl.text, _passCtrl.text)
        : await auth.register(
      _emailCtrl.text,
      _passCtrl.text,
      _nameCtrl.text,
      _adminCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // ── Logo ──────────────────────────────────────────────
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: AppTheme.accent,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Título ─────────────────────────────────────────────
                  Text(
                    'SmartSpace',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin ? 'Bem-vindo de volta' : 'Cria a tua conta',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Toggle Login / Registo ─────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        _TabButton(
                          label: 'Entrar',
                          active: _isLogin,
                          onTap: () { if (!_isLogin) _toggle(); },
                        ),
                        _TabButton(
                          label: 'Registar',
                          active: !_isLogin,
                          onTap: () { if (_isLogin) _toggle(); },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Formulário ─────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [

                        // Nome (só registo)
                        if (!_isLogin) ...[
                          _Field(
                            controller: _nameCtrl,
                            label: 'Nome',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Insere o teu nome' : null,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email
                        _Field(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Insere o teu email';
                            if (!v.contains('@')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        _Field(
                          controller: _passCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePass,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Insere a tua password';
                            if (!_isLogin && v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),

                        // Código admin (só registo)
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          _Field(
                            controller: _adminCtrl,
                            label: 'Código de administrador (opcional)',
                            icon: Icons.vpn_key_outlined,
                            obscure: _obscureCode,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCode
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureCode = !_obscureCode),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppTheme.textMuted, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Deixa em branco para conta de utilizador',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Botão principal ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.accent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : Text(
                        _isLogin ? 'Entrar' : 'Criar conta',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer ─────────────────────────────────────────────
                  Text(
                    'Sistemas de IoT e Móveis 2025/26',
                    style: TextStyle(
                      color: AppTheme.textDisabled,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'NOVA School of Science & Technology',
                    style: TextStyle(
                      color: AppTheme.textDisabled,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab Button ─────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textMuted,
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Campo de texto reutilizável ────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}