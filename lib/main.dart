import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCRtY0MNjFnU4kAPE67YE8EkAjm4CCoQXg',
      appId: '1:816514499753:android:ed378f3d2dfe16dc7195b8',
      messagingSenderId: '816514499753',
      projectId: 'zajel-messages',
      storageBucket: 'zajel-messages.firebasestorage.app',
    ),
  );

  runApp(const ZajelApp());
}

Route<T> _smoothRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.08, 0.0);
      const end = Offset.zero;
      const curve = Curves.fastOutSlowIn;

      var slideTween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      var fadeTween = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(
        CurveTween(
          curve: const Interval(
            0.0,
            0.7,
            curve: Curves.easeOut,
          ),
        ),
      );

      return FadeTransition(
        opacity: animation.drive(fadeTween),
        child: SlideTransition(
          position: animation.drive(slideTween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

class ThemeNotifier extends ValueNotifier<bool> {
  ThemeNotifier() : super(true);

  void toggleTheme(bool isDark) {
    value = isDark;
  }
}

final themeNotifier = ThemeNotifier();

class ZajelApp extends StatelessWidget {
  const ZajelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'زاجل - Zajel',
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
            scaffoldBackgroundColor: isDark
                ? const Color(0xFF0F0C15)
                : const Color(0xFFF8FAFC),
            useMaterial3: true,
          ),
          home: FirebaseAuth.instance.currentUser == null
              ? const LoginScreen()
              : const ChatListScreen(),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _createAccount = false;
  bool _showPassword = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveUserProfile(User? user) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'uid': user.uid,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _message('اكتب بريد إلكتروني صحيح.');
      return;
    }
    if (password.length < 6) {
      _message('كلمة المرور لازم تكون 6 أحرف أو أكثر.');
      return;
    }

    setState(() => _busy = true);
    try {
      UserCredential result;
      if (_createAccount) {
        result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        result = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      unawaited(_saveUserProfile(result.user));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        _smoothRoute(const ChatListScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      final String message;
      switch (error.code) {
        case 'email-already-in-use':
          message = 'هذا البريد مسجّل مسبقاً. جرّب تسجيل الدخول.';
          break;
        case 'invalid-email':
          message = 'صيغة البريد الإلكتروني غير صحيحة.';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة؛ استخدم 6 أحرف على الأقل.';
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
          break;
        case 'operation-not-allowed':
          message = 'فعّل خيار Email/Password من Firebase Authentication.';
          break;
        case 'network-request-failed':
          message = 'تحقّق من اتصال الإنترنت وحاول مرة ثانية.';
          break;
        default:
          message = 'تعذّر إكمال العملية: ${error.message ?? error.code}';
      }
      _message(message);
    } catch (error) {
      _message('حدث خطأ غير متوقع: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _message('اكتب بريدك الإلكتروني أولاً لاستعادة كلمة المرور.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _message('إذا كان البريد مسجلاً، ستصلك رسالة لاستعادة كلمة المرور.');
    } on FirebaseAuthException catch (error) {
      _message('تعذّر إرسال رسالة الاستعادة: ${error.message ?? error.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final primary = isDark ? const Color(0xFF8A49DF) : Colors.blue.shade700;
        final panel = isDark ? const Color(0xFF161022) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E172B) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Text('🕊️', style: TextStyle(fontSize: 48)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'زاجل | Zajel',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFEADBFF) : Colors.blue.shade900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'التواصل الأسرع والأكثر أماناً',
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 34),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primary.withOpacity(0.25)),
                        ),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'البريد الإلكتروني',
                            labelStyle: TextStyle(color: primary, fontSize: 14),
                            hintText: 'name@example.com',
                            prefixIcon: Icon(Icons.email_outlined, color: primary, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primary.withOpacity(0.25)),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _submit(),
                          style: TextStyle(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'كلمة المرور',
                            labelStyle: TextStyle(color: primary, fontSize: 14),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: primary, size: 20),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: primary),
                            ),
                          ),
                        ),
                      ),
                      if (!_createAccount)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: Text('نسيت كلمة المرور؟', style: TextStyle(color: primary)),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF8A49DF), Color(0xFF5A22A6)]
                                : [Colors.blue.shade600, Colors.blue.shade800],
                          ),
                          boxShadow: [BoxShadow(color: primary.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_busy) ...[
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                _busy ? 'يرجى الانتظار...' : (_createAccount ? 'إنشاء حساب جديد' : 'تسجيل الدخول'),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _createAccount = !_createAccount),
                        child: Text(
                          _createAccount ? 'لديك حساب؟ سجّل الدخول' : 'ما عندك حساب؟ أنشئ حساباً مجانياً',
                          style: TextStyle(color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  bool _verifyingCode = false;

  Future<void> _verifyAndProceed() async {
    final smsCode = _controllers.map((controller) => controller.text).join();
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق المكوّن من 6 أرقام')),
      );
      return;
    }

    setState(() => _verifyingCode = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'uid': user.uid,
              'phoneNumber': user.phoneNumber ?? widget.phoneNumber,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        _smoothRoute(const ChatListScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رمز التحقق غير صحيح: ${error.message ?? error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحقق: $error')),
      );
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
            title: Text('رمز التحقق', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('أدخل رمز التحقق المرسل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFEADBFF) : Colors.blue.shade900)),
                const SizedBox(height: 8),
                Text('إلى الرقم: ${widget.phoneNumber}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161022) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF8A49DF).withOpacity(0.5) : Colors.blue.shade300, width: 1.5),
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) FocusScope.of(context).nextFocus();
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isDark ? const LinearGradient(colors: [Color(0xFF8A49DF), Color(0xFF5A22A6)]) : LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800]),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: _verifyingCode ? null : _verifyAndProceed,
                    child: Text(_verifyingCode ? 'جارٍ التحقق...' : 'تأكيد والانتقال', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _profileStatus = 'صورة احترافية نشطة';

  void _editProfileImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161022),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 18),
              const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEADBFF))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionItem(icon: Icons.photo_library_rounded, color: const Color(0xFFC79FFF), title: 'المعرض', onTap: () { Navigator.pop(context); setState(() => _profileStatus = 'صورة معرض جديدة'); }),
                  _buildOptionItem(icon: Icons.camera_alt_rounded, color: Colors.blueAccent, title: 'الكاميرا', onTap: () { Navigator.pop(context); setState(() => _profileStatus = 'صورة كاميرا جديدة'); }),
                  _buildOptionItem(icon: Icons.delete_outline_rounded, color: Colors.redAccent, title: 'حذف', onTap: () { Navigator.pop(context); setState(() => _profileStatus = 'افتراضي'); }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('الملف الشخصي', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 28),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: isDark ? [const Color(0xFF8A49DF), const Color(0xFFC79FFF)] : [Colors.blue.shade400, Colors.blue.shade700]),
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
                          child: Icon(Icons.person, size: 68, color: isDark ? const Color(0xFFEADBFF) : Colors.blue),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: GestureDetector(
                          onTap: _editProfileImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark ? const Color(0xFF8A49DF) : Colors.blue,
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(_profileStatus, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildModernProfileCard(isDark: isDark, icon: Icons.person_outline_rounded, title: 'الاسم الكامل', value: 'مستخدم زاجل', onEdit: () {}),
                      const SizedBox(height: 12),
                      _buildModernProfileCard(isDark: isDark, icon: Icons.phone_android_rounded, title: 'رقم الهاتف', value: '+964 770 000 0000', onEdit: () {}),
                      const SizedBox(height: 12),
                      _buildModernProfileCard(isDark: isDark, icon: Icons.info_outline_rounded, title: 'الحالة الشخصية', value: 'متاح للتواصل الفوري 🕊', onEdit: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernProfileCard({required bool isDark, required IconData icon, required String title, required String value, required VoidCallback onEdit}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161022) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.blue.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF221A30) : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: isDark ? const Color(0xFFEADBFF) : Colors.blue, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        subtitle: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        trailing: IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? const Color(0xFFC79FFF) : Colors.blue), onPressed: onEdit),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('الإعدادات', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إعدادات المظهر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade800)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161022) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.blue.shade100),
                  ),
                  child: SwitchListTile(
                    secondary: Icon(isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded, color: isDark ? Colors.amberAccent : Colors.orange),
                    title: Text(isDark ? 'الوضع الداكن' : 'الوضع الفاتح', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('تغيير سمة التطبيق بالكامل', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    value: isDark,
                    activeColor: const Color(0xFF8A49DF),
                    onChanged: (val) => themeNotifier.toggleTheme(val),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'أحمد علي',
      'lastMessage': 'أهلاً بك! كيف حالك اليوم؟',
      'time': '10:30 ص',
      'unread': 2,
      'isOnline': true,
      'avatarColor': const Color(0xFFC79FFF),
    },
    {
      'name': 'فريق زاجل',
      'lastMessage': 'مرحباً بك في تطبيق زاجل 🕊',
      'time': 'أمس',
      'unread': 0,
      'isOnline': true,
      'avatarColor': const Color(0xFF8A49DF),
    },
    {
      'name': 'سارة محمود',
      'lastMessage': 'تم إرسال الملف المطلوب 👍',
      'time': '08:15 ص',
      'unread': 0,
      'isOnline': false,
      'avatarColor': const Color(0xFF9E5DF8),
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 28, backgroundColor: Colors.red.withOpacity(0.15), child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 26)),
            const SizedBox(height: 16),
            Text('تسجيل الخروج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: TextStyle(color: isDark ? Colors.white : Colors.black87)))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () { Navigator.pop(context); Navigator.pushReplacement(context, _smoothRoute(const LoginScreen())); }, child: const Text('خروج', style: TextStyle(color: Colors.white)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((chat) {
      final name = chat['name'].toString().toLowerCase();
      final message = chat['lastMessage'].toString().toLowerCase();
      return name.contains(_searchQuery) || message.contains(_searchQuery);
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
            elevation: 0,
            title: Text('المحادثات | Zajel', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              PopupMenuButton<String>(
                color: isDark ? const Color(0xFF161022) : Colors.white,
                icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : Colors.black87),
                onSelected: (value) {
                  if (value == 'profile') Navigator.push(context, _smoothRoute(const ProfileScreen()));
                  else if (value == 'settings') Navigator.push(context, _smoothRoute(const SettingsScreen()));
                  else if (value == 'logout') _showLogoutDialog(context, isDark);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
                  const PopupMenuItem(value: 'settings', child: Text('الإعدادات')),
                  const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              if (!isDark) Positioned.fill(child: CustomPaint(painter: BirdPatternPainter())),
              Column(
                children: [
                  Container(
                    color: isDark ? const Color(0xFF161022) : Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF221A30) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(22)),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.blue.shade700, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _searchController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: const InputDecoration(hintText: 'البحث السريع...', border: InputBorder.none, isDense: true))),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredChats.length,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF161022) : Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            onTap: () => Navigator.push(context, _smoothRoute(ChatScreen(userName: chat['name']))),
                            leading: CircleAvatar(backgroundColor: (chat['avatarColor'] as Color).withOpacity(0.2), child: Text(chat['name'][0], style: TextStyle(color: chat['avatarColor']))),
                            title: Text(chat['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text(chat['lastMessage'], maxLines: 1, style: TextStyle(color: Colors.grey.shade500)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class BirdPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withOpacity(0.04)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final List<Offset> birdPositions = [
      Offset(size.width * 0.15, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.22),
      Offset(size.width * 0.35, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.65),
    ];
    for (var pos in birdPositions) {
      final path = Path();
      path.moveTo(pos.dx - 12, pos.dy);
      path.quadraticBezierTo(pos.dx - 6, pos.dy - 8, pos.dx, pos.dy);
      path.quadraticBezierTo(pos.dx + 6, pos.dy - 8, pos.dx + 12, pos.dy);
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChatScreen extends StatefulWidget {
  final String userName;
  const ChatScreen({super.key, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final ValueNotifier<bool> _isTypingNotifier = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> _messages = [];

  bool _isRecordingActive = false;
  bool _isLocked = false;
  double _currentDragY = 0.0;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      _isTypingNotifier.value = _textController.text.trim().isNotEmpty;
    });
    _messages.add({
      'type': 'text',
      'content': 'أهلاً بك! معك ${widget.userName} 🕊',
      'time': '8:28 م',
      'isMe': 'false',
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _textController.dispose();
    _isTypingNotifier.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'type': 'text', 'content': _textController.text, 'time': '8:29 م', 'isMe': 'true'});
    });
    _textController.clear();
  }

  void _showAttachmentMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text('إرفاق ملف أو محتوى', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFEADBFF) : Colors.blue.shade900)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentItem(icon: Icons.image_rounded, color: Colors.blue, title: 'صورة', onTap: () { Navigator.pop(context); _addTextMsg('📷 صورة مرسلة'); }),
                  _buildAttachmentItem(icon: Icons.camera_alt_rounded, color: Colors.blueAccent, title: 'الكاميرا', onTap: () { Navigator.pop(context); _addTextMsg('📸 لقطة كاميرا'); }),
                  _buildAttachmentItem(icon: Icons.person_rounded, color: Colors.orangeAccent, title: 'جهة اتصال', onTap: () { Navigator.pop(context); _addTextMsg('👤 جهة اتصال'); }),
                  _buildAttachmentItem(icon: Icons.insert_drive_file_rounded, color: Colors.blueAccent, title: 'مستند', onTap: () { Navigator.pop(context); _addTextMsg('📄 ملف مستند'); }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _addTextMsg(String content) {
    setState(() {
      _messages.add({'type': 'text', 'content': content, 'time': '8:30 م', 'isMe': 'true'});
    });
  }

  Widget _buildAttachmentItem({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }

  void _startRecording() {
    if (_isRecordingActive) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingActive = true;
      _isLocked = false;
      _currentDragY = 0.0;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecordingActive) return;
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
  }

  void _updateRecording(LongPressMoveUpdateDetails details) {
    if (!_isRecordingActive || _isLocked) return;
    setState(() {
      _currentDragY = details.offsetFromOrigin.dy;
      if (_currentDragY < -55) _isLocked = true;
    });
  }

  void _endRecording() {
    if (!_isRecordingActive || _isLocked) return;
    _finishAndSendRecording();
  }

  void _finishAndSendRecording() {
    if (!_isRecordingActive) return;
    _recordingTimer?.cancel();
    final duration = '${(_recordingDuration.inMinutes.remainder(60)).toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
    setState(() {
      _isRecordingActive = false;
      _isLocked = false;
      _currentDragY = 0.0;
      _messages.add({'type': 'voice', 'content': 'رسالة صوتية', 'duration': duration, 'time': '8:35 م', 'isMe': 'true'});
      _recordingDuration = Duration.zero;
    });
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingActive = false;
      _isLocked = false;
      _currentDragY = 0.0;
      _recordingDuration = Duration.zero;
    });
  }

  Widget _buildVoiceMessage(Map<String, dynamic> msg, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 8),
        Text(msg['duration'] ?? '00:00', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C15) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
            leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context)),
            title: Text(widget.userName, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['isMe'] == 'true';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF8A49DF) : (isDark ? const Color(0xFF1E172B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: msg['type'] == 'voice' ? _buildVoiceMessage(msg, isDark) : Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_isRecordingActive)
                      Positioned(
                        right: 16,
                        top: _isLocked ? -62 : -45 + (_currentDragY.clamp(-55.0, 0.0)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isLocked ? Colors.red.shade700 : (isDark ? const Color(0xFF221A30) : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(color: _isLocked ? Colors.white : const Color(0xFF8A49DF), width: 1.5),
                          ),
                          child: Icon(_isLocked ? Icons.lock_rounded : Icons.keyboard_arrow_up_rounded, color: _isLocked ? Colors.white : const Color(0xFFC79FFF), size: 20),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161022) : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                        ),
                        child: _isRecordingActive ? _buildRecordingBar(isDark) : _buildMessageBar(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingBar(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _isLocked ? Colors.red.shade700 : (isDark ? const Color(0xFF6D56E8) : Colors.blue),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 17),
            ),
          ),
          const SizedBox(width: 8),
          Icon(_isLocked ? Icons.lock_rounded : Icons.mic_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(
            '${(_recordingDuration.inMinutes.remainder(60)).toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(12, (index) {
                return Container(
                  width: 3,
                  height: 5.0 + ((index % 4) * 4.0),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
          ),
          if (_isLocked)
            GestureDetector(
              onTap: _finishAndSendRecording,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.send_rounded, color: isDark ? const Color(0xFF6D56E8) : Colors.blue, size: 17),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBar(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: CustomPaint(size: const Size(22, 22), painter: StickerIconPainter(isDark: isDark)),
            onPressed: () {},
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _textController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'الرسالة',
                hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.attach_file_rounded, color: isDark ? const Color(0xFFC79FFF) : Colors.blue, size: 22),
            onPressed: () => _showAttachmentMenu(isDark),
          ),
        ),
        const SizedBox(width: 4),
        ValueListenableBuilder<bool>(
          valueListenable: _isTypingNotifier,
          builder: (context, isTyping, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isTyping
                  ? GestureDetector(
                      key: const ValueKey('sendBtn'),
                      onTap: _sendMessage,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF8A49DF) : Colors.blue.shade600, shape: BoxShape.circle),
                        child: Center(
                          child: Transform.rotate(angle: -0.25, child: const Icon(Icons.send_rounded, color: Colors.white, size: 19)),
                        ),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('micBtn'),
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressMoveUpdate: (details) => _updateRecording(details),
                      onLongPressEnd: (_) => _endRecording(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF8A49DF) : Colors.blue.shade600),
                        child: const Center(child: Icon(Icons.mic_rounded, color: Colors.white, size: 19)),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class StickerIconPainter extends CustomPainter {
  final bool isDark;
  StickerIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2.0, 2.0, size.width - 4, size.height - 4), const Radius.circular(5)));
    canvas.drawPath(path, paint);

    final fillDot = Paint()
      ..color = isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.38), 1.5, fillDot);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.38), 1.5, fillDot);

    final smilePath = Path();
    smilePath.moveTo(size.width * 0.35, size.height * 0.52);
    smilePath.quadraticBezierTo(size.width * 0.5, size.height * 0.66, size.width * 0.65, size.height * 0.52);
    canvas.drawPath(smilePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
