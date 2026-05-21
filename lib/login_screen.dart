import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaccine/app_colors.dart';
import 'package:vaccine/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isPasswordObscured = true;
  bool isLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;

  Future<void> _handleAuth() async {
    // Validation cho form đăng ký
    if (!isLogin) {
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _selectedDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng điền đầy đủ tất cả thông tin.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    setState(() { isLoading = true; });

    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
        
        if (res.user != null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': res.user!.id,
            'full_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'date_of_birth': _selectedDob!.toIso8601String().substring(0, 10),
          });
        }
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Đã có lỗi xảy ra.';
        if (e.message.contains('Invalid login credentials')) {
          errorMessage = 'Email hoặc mật khẩu không chính xác.';
        } else if (e.message.contains('rate_limit') || e.message.contains('rate limit') || e.message.contains('over_email_send_rate_limit')) {
          errorMessage = 'Hệ thống gửi email đang bị quá tải (Rate Limit). Vui lòng tắt "Confirm Email" trong Supabase hoặc thử lại sau.';
        } else if (e.message.contains('User already registered')) {
          errorMessage = 'Email này đã được đăng ký.';
        } else {
          errorMessage = e.message;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blurry circles
          Positioned(
            top: -100,
            right: -100,
            child: _buildBlurryCircle(AppColors.primary.withOpacity(0.05), 400),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _buildBlurryCircle(AppColors.secondary.withOpacity(0.05), 350),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // Header
                      const SizedBox(height: 24),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryContainer.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.vaccines,
                          color: AppColors.onPrimary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'VaxCare',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: -0.02 * 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLogin ? 'Bảo vệ sức khỏe cộng đồng' : 'Bắt đầu hành trình chăm sóc sức khỏe',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.white.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryContainer.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Tab Switcher
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => isLogin = true),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isLogin ? Colors.white : Colors.transparent,
                                              borderRadius: BorderRadius.circular(40),
                                              boxShadow: isLogin
                                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                                  : null,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Đăng nhập',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isLogin ? AppColors.primary : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => isLogin = false),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: !isLogin ? Colors.white : Colors.transparent,
                                              borderRadius: BorderRadius.circular(40),
                                              boxShadow: !isLogin
                                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                                  : null,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Đăng ký',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: !isLogin ? AppColors.primary : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Inputs
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  child: !isLogin
                                      ? Column(
                                          children: [
                                            _buildInputLabel('Họ và tên'),
                                            const SizedBox(height: 8),
                                            _buildTextField(
                                              controller: _nameController,
                                              icon: Icons.person_outline,
                                              hintText: 'Nguyễn Văn A',
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                
                                _buildInputLabel('Email'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _emailController,
                                  icon: Icons.mail_outline,
                                  hintText: 'example@email.com',
                                ),
                                const SizedBox(height: 16),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  child: !isLogin
                                      ? Column(
                                          children: [
                                            _buildInputLabel('Số điện thoại'),
                                            const SizedBox(height: 8),
                                            _buildTextField(
                                              controller: _phoneController,
                                              icon: Icons.phone_outlined,
                                              hintText: '09xxxxxxxx',
                                              keyboardType: TextInputType.phone,
                                            ),
                                            const SizedBox(height: 16),
                                            _buildInputLabel('Ngày sinh'),
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: _pickDob,
                                              child: AbsorbPointer(
                                                child: _buildTextField(
                                                  controller: _dobController,
                                                  icon: Icons.cake_outlined,
                                                  hintText: 'DD/MM/YYYY',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                
                                _buildInputLabel('Mật khẩu'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _passwordController,
                                  icon: Icons.lock_outline,
                                  hintText: '••••••••',
                                  obscureText: isPasswordObscured,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      isPasswordObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: AppColors.outline,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isPasswordObscured = !isPasswordObscured;
                                      });
                                    },
                                  ),
                                ),
                                
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  child: isLogin
                                      ? Container(
                                          alignment: Alignment.centerRight,
                                          margin: const EdgeInsets.only(top: 8),
                                          child: TextButton(
                                            onPressed: () {},
                                            child: const Text(
                                              'Quên mật khẩu?',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox(height: 16),
                                ),

                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: isLoading ? null : _handleAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    minimumSize: const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isLogin ? 'Đăng nhập' : 'Tạo tài khoản',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward, size: 18),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      // Footer
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(text: 'Bằng cách tiếp tục, bạn đồng ý với '),
                              TextSpan(
                                text: 'Điều khoản & Chính sách',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' của VaxCare.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurryCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String hintText,
    TextEditingController? controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.outlineVariant, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.outline, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}