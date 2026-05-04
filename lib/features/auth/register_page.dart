import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    authProvider.clearError();

    final success = await authProvider.registerWithEmail(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
                child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : AppColors.darkGreen).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: DirectionalIcon(isBack: true, size: 18, color: isDark ? Colors.white : AppColors.darkGreen),
              ),
            ),
          ),
        ),
        body: Consumer<AppAuthProvider>(
          builder: (context, authProvider, _) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إنشاء حساب جديد',
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'انضم إلينا في رحلة التطوير الروحي اليومية',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Error message
                      if (authProvider.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _buildTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        hint: 'محمود محمد',
                        icon: Icons.person_outline,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'يرجى إدخال الاسم';
                          if (value.trim().length < 2) return 'الاسم قصير جداً';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'example@mail.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                          if (!value.contains('@') || !value.contains('.')) return 'بريد إلكتروني غير صالح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        hint: '********',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscure: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'يرجى إدخال كلمة المرور';
                          if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'تأكيد كلمة المرور',
                        hint: '********',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscure: _obscureConfirm,
                        onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'يرجى تأكيد كلمة المرور';
                          if (value != _passwordController.text) return 'كلمة المرور غير متطابقة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkGreen,
                            disabledBackgroundColor: AppColors.darkGreen.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: authProvider.isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'إنشاء الحساب',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'لديك حساب بالفعل؟ سجل الدخول',
                            style: GoogleFonts.cairo(
                              color: AppColors.midGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscure = true,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          keyboardType: keyboardType,
          textDirection: textDirection,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: AppColors.midGreen),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey[500],
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.paleGreen),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.paleGreen),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.darkGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}
