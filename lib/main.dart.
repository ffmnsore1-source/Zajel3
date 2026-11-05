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
  final signedInUser = FirebaseAuth.instance.currentUser;
  if (signedInUser != null) {
    try {
      await _ensureZajelUserProfile(signedInUser);
    } catch (_) {
      // The app still opens; Firestore operations will show their own errors.
    }
  }

  runApp(const ZajelApp());
}

Future<void> _ensureZajelUserProfile(User user) async {
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(user.uid);
  await db.runTransaction((transaction) async {
    final userSnapshot = await transaction.get(userRef);
    final existing = userSnapshot.data() ?? <String, dynamic>{};
    var username = (existing['username'] as String?)?.toLowerCase().trim();
    if (username == null || !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      username = _usernameFromEmail(user.email);
    }
    var usernameRef = db.collection('usernames').doc(username);
    final usernameSnapshot = await transaction.get(usernameRef);
    if (usernameSnapshot.exists && usernameSnapshot.data()?['uid'] != user.uid) {
      username = 'user_${user.uid.substring(0, user.uid.length < 10 ? user.uid.length : 10)}';
      usernameRef = db.collection('usernames').doc(username);
    }
    transaction.set(userRef, {
      'uid': user.uid,
      'email': user.email,
      'username': username,
      'fullName': (existing['fullName'] as String?) ??
          (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'مستخدم زاجل'),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!userSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(usernameRef, {
      'uid': user.uid,
      'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(db.collection('publicProfiles').doc(user.uid), {
      'uid': user.uid,
      'username': username,
      'fullName': (existing['fullName'] as String?) ??
          (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'مستخدم زاجل'),
      'status': (existing['status'] as String?) ?? 'متاح للتواصل الفوري 🕊',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
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

String _usernameFromEmail(String? email) {
  final local = (email ?? 'user').split('@').first.toLowerCase();
  final cleaned = local.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  final normalized = cleaned.length < 3 ? 'user_$cleaned' : cleaned;
  return normalized.length > 20 ? normalized.substring(0, 20) : normalized;
}

String _privateConversationId(String firstUid, String secondUid) {
  final ids = [firstUid, secondUid]..sort();
  return 'private_${ids[0]}_${ids[1]}';
}

String _formatChatTime(dynamic value) {
  DateTime? date;
  if (value is Timestamp) date = value.toDate().toLocal();
  if (value is DateTime) date = value.toLocal();
  if (date == null) return 'الآن';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'م' : 'ص'}';
}

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
    await _ensureZajelUserProfile(user);
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
      await _saveUserProfile(result.user);
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
                          _createAccount ? 'لديك حساب؟ سجّل الدخول' : 'إنشاء حساب',
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
  State<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends State<OtpVerificationScreen> {
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
        } catch (_) {
          // Keep the authenticated session even if Firestore is not configured yet.
        }
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
        SnackBar(
          content: Text('رمز التحقق غير صحيح أو انتهت صلاحيته: ${error.message ?? error.code}'),
        ),
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
          backgroundColor: isDark
              ? const Color(0xFF0F0C15)
              : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF161022) : Colors.white,
            title: Text(
              'رمز التحقق',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'أدخل رمز التحقق المرسل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFEADBFF)
                        : Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'إلى الرقم: ${widget.phoneNumber.isEmpty ? "رقمك الشخصي" : widget.phoneNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161022)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF8A49DF).withOpacity(0.5)
                              : Colors.blue.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.2 : 0.03,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
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
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF8A49DF),
                              Color(0xFF5A22A6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade800,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDark
                                    ? const Color(0xFF8A49DF)
                                    : Colors.blue)
                                .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _verifyingCode ? null : _verifyAndProceed,
                    child: Text(
                      _verifyingCode ? 'جارٍ التحقق...' : 'تأكيد والانتقال',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
  String _profileStatus = 'متاح للتواصل الفوري 🕊';
  String _fullName = 'مستخدم زاجل';
  String _username = '';
  String _email = '';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    _email = user.email ?? '';
    _username = 'user_${user.uid.substring(0, user.uid.length < 6 ? user.uid.length : 6)}';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (data != null) {
        _fullName = (data['fullName'] as String?) ?? _fullName;
        _username = (data['username'] as String?) ?? _username;
        _profileStatus = (data['status'] as String?) ?? _profileStatus;
        _email = user.email ?? (data['email'] as String?) ?? _email;
      }
    } catch (_) {
      // Keep the profile screen usable if profile data is not available.
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  Future<void> _saveProfileField(String key, String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), {
        key: value,
        'uid': user.uid,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (key == 'fullName' || key == 'status') {
        batch.set(db.collection('publicProfiles').doc(user.uid), {
          key: value,
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر حفظ التعديل: $error')),
        );
      }
    }
  }

  Future<void> _editTextField({
    required String title,
    required String currentValue,
    required String fieldKey,
    required ValueChanged<String> onUpdated,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final isDark = themeNotifier.value;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تعديل $title',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'أدخل $title',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFFC79FFF) : Colors.blue),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF8A49DF) : Colors.blue, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    if (fieldKey == 'username') {
      await _changeUsername(result.trim());
      return;
    }
    onUpdated(result.trim());
    await _saveProfileField(fieldKey, result.trim());
  }

  Future<void> _changeUsername(String input) async {
    final user = FirebaseAuth.instance.currentUser;
    final username = input.replaceFirst(RegExp(r'^@'), '').trim().toLowerCase();
    if (user == null) return;
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم المستخدم يجب أن يكون 3 إلى 20 حرفاً إنجليزياً أو رقماً أو _.')),
      );
      return;
    }
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final newRef = db.collection('usernames').doc(username);
    try {
      await db.runTransaction((transaction) async {
        final newSnapshot = await transaction.get(newRef);
        if (newSnapshot.exists && newSnapshot.data()?['uid'] != user.uid) {
          throw StateError('اسم المستخدم مستخدم بالفعل.');
        }
        final oldSnapshot = await transaction.get(userRef);
        final oldName = oldSnapshot.data()?['username'] as String?;
        transaction.set(newRef, {
          'uid': user.uid,
          'username': username,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userRef, {
          'uid': user.uid,
          'username': username,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(db.collection('publicProfiles').doc(user.uid), {
          'uid': user.uid,
          'username': username,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (oldName != null && oldName != username) {
          final oldRef = db.collection('usernames').doc(oldName);
          transaction.delete(oldRef);
        }
      });
      if (!mounted) return;
      setState(() => _username = username);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث اسم المستخدم بنجاح.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError ? error.message : 'تعذّر تحديث اسم المستخدم: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'حدث خطأ.')));
    }
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email);
    final isDark = themeNotifier.value;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تعديل البريد الإلكتروني', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: const InputDecoration(hintText: 'name@example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.contains('@')) Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result == _email) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Firebase Auth 7 uses verification before changing the email address.
      await user.verifyBeforeUpdateEmail(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أرسلنا رابط التحقق إلى البريد الجديد. سيتغير البريد بعد تأكيد الرابط.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'requires-recent-login'
          ? 'لأمان الحساب، سجّل الدخول من جديد ثم حاول تغيير البريد.'
          : 'تعذّر تحديث البريد: ${error.message ?? error.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _editProfileImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161022),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          body: _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: Text(_profileStatus, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700, fontWeight: FontWeight.w600))),
                          IconButton(
                            tooltip: 'تعديل الحالة الشخصية',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? const Color(0xFFC79FFF) : Colors.blue),
                            onPressed: () => _editTextField(title: 'الحالة الشخصية', currentValue: _profileStatus, fieldKey: 'status', onUpdated: (value) => setState(() => _profileStatus = value)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            _buildModernProfileCard(isDark: isDark, icon: Icons.person_outline_rounded, title: 'الاسم الكامل', value: _fullName, onEdit: () => _editTextField(title: 'الاسم الكامل', currentValue: _fullName, fieldKey: 'fullName', onUpdated: (value) => setState(() => _fullName = value))),
                            const SizedBox(height: 12),
                            _buildModernProfileCard(isDark: isDark, icon: Icons.alternate_email_rounded, title: 'اسم المستخدم', value: _username, onEdit: () => _editTextField(title: 'اسم المستخدم', currentValue: _username, fieldKey: 'username', onUpdated: (value) => setState(() => _username = value))),
                            const SizedBox(height: 12),
                            _buildModernProfileCard(isDark: isDark, icon: Icons.email_outlined, title: 'البريد الإلكتروني', value: _email.isEmpty ? 'غير مضاف' : _email, onEdit: _editEmail),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF221A30) : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDark ? const Color(0xFFEADBFF) : Colors.blue, size: 20),
          ),
          title: Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          subtitle: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          trailing: IconButton(
            tooltip: 'تعديل $title',
            icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? const Color(0xFFC79FFF) : Colors.blue),
            onPressed: onEdit,
          ),
        ),
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
          backgroundColor: isDark
              ? const Color(0xFF0F0C15)
              : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF161022) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'الإعدادات',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات المظهر',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFC79FFF)
                        : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161022)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.blue.shade100,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          isDark ? 0.2 : 0.03,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(
                            isDark
                                ? Icons.nights_stay_rounded
                                : Icons.wb_sunny_rounded,
                            color: isDark
                                ? Colors.amberAccent
                                : Colors.orange,
                          ),
                          title: Text(
                            isDark
                                ? 'الوضع الداكن'
                                : 'الوضع الفاتح',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'تغيير سمة التطبيق بالكامل',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          value: isDark,
                          activeColor:
                              const Color(0xFF8A49DF),
                          onChanged: (val) {
                            themeNotifier.toggleTheme(val);
                          },
                        ),
                      ],
                    ),
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
  State<ChatListScreen> createState() =>
      _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<Map<String, dynamic>> _chats = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSubscription;
  bool _loadingChats = true;
  String? _chatLoadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _listenToConversations();
  }

  void _listenToConversations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _loadingChats = false;
      return;
    }
    _conversationsSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) async {
      final items = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final members = List<String>.from(data['members'] ?? const <String>[]);
        final otherMembers = members.where((id) => id != user.uid).toList();
        if (otherMembers.isEmpty) continue;
        final partnerUid = otherMembers.first;
        final participants = Map<String, dynamic>.from(data['participants'] ?? const {});
        var partner = Map<String, dynamic>.from(participants[partnerUid] ?? const {});
        if (partner.isEmpty) {
          try {
            final profile = await FirebaseFirestore.instance.collection('publicProfiles').doc(partnerUid).get();
            partner = profile.data() ?? <String, dynamic>{};
          } catch (_) {}
        }
        final title = (partner['fullName'] as String?)?.trim().isNotEmpty == true
            ? (partner['fullName'] as String).trim()
            : (partner['username'] as String?) ?? 'مستخدم زاجل';
        items.add({
          'name': title,
          'username': partner['username'] ?? '',
          'lastMessage': data['lastMessage'] ?? 'ابدأ محادثة جديدة',
          'time': _formatChatTime(data['updatedAt']),
          'unread': 0,
          'isOnline': false,
          'avatarColor': const Color(0xFF8A49DF),
          'chatId': doc.id,
          'partnerUid': partnerUid,
          'updatedAt': data['updatedAt'],
        });
      }
      items.sort((a, b) {
        final aa = a['updatedAt'];
        final bb = b['updatedAt'];
        final ad = aa is Timestamp ? aa.millisecondsSinceEpoch : 0;
        final bd = bb is Timestamp ? bb.millisecondsSinceEpoch : 0;
        return bd.compareTo(ad);
      });
      if (!mounted) return;
      setState(() {
        _chats
          ..clear()
          ..addAll(items);
        _loadingChats = false;
        _chatLoadError = null;
      });
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _loadingChats = false;
        _chatLoadError = 'تعذّر تحميل المحادثات من Firestore: $error';
      });
    });
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAndOpenUser(String rawUsername, BuildContext dialogContext) async {
    final username = rawUsername.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم مستخدم صحيحاً مثل @ahmed_123')),
      );
      return;
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    try {
      final index = await FirebaseFirestore.instance.collection('usernames').doc(username).get();
      if (!index.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم نعثر على مستخدم بهذا الاسم.')));
        return;
      }
      final partnerUid = index.data()?['uid'] as String?;
      if (partnerUid == null || partnerUid.isEmpty) throw StateError('بيانات اسم المستخدم غير مكتملة.');
      if (partnerUid == current.uid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك بدء محادثة مع حسابك.')));
        return;
      }
      final db = FirebaseFirestore.instance;
      final partnerSnapshot = await db.collection('publicProfiles').doc(partnerUid).get();
      if (!partnerSnapshot.exists) throw StateError('ملف هذا المستخدم غير موجود.');
      final partner = partnerSnapshot.data() ?? <String, dynamic>{};
      final currentSnapshot = await db.collection('publicProfiles').doc(current.uid).get();
      final mine = currentSnapshot.data() ?? <String, dynamic>{};
      final chatId = _privateConversationId(current.uid, partnerUid);
      final members = [current.uid, partnerUid]..sort();
      final conversationRef = db.collection('conversations').doc(chatId);
      await db.runTransaction((transaction) async {
        final existing = await transaction.get(conversationRef);
        if (existing.exists) {
          final existingMembers = List<String>.from(existing.data()?['members'] ?? const <String>[]);
          if (existingMembers.toSet().length != 2 || !existingMembers.toSet().containsAll(members)) {
            throw StateError('تعارض في بيانات المحادثة.');
          }
          transaction.update(conversationRef, {'updatedAt': FieldValue.serverTimestamp()});
        } else {
          transaction.set(conversationRef, {
            'members': members,
            'type': 'private',
            'participants': {
              current.uid: {
                'uid': current.uid,
                'username': mine['username'] ?? _usernameFromEmail(current.email),
                'fullName': mine['fullName'] ?? current.displayName ?? 'مستخدم زاجل',
              },
              partnerUid: {
                'uid': partnerUid,
                'username': partner['username'] ?? username,
                'fullName': partner['fullName'] ?? 'مستخدم زاجل',
              },
            },
            'lastMessage': 'ابدأ محادثة جديدة',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      final title = (partner['fullName'] as String?)?.trim().isNotEmpty == true
          ? (partner['fullName'] as String).trim()
          : '@${partner['username'] ?? username}';
      Navigator.push(context, _smoothRoute(ChatScreen(
        userName: title,
        chatId: chatId,
        partnerUid: partnerUid,
      )));
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError ? error.message : 'تعذّر بدء المحادثة: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'حدث خطأ.')));
    }
  }

  void _showAddConversationDialog(bool isDark) {
    final controller = TextEditingController();
    bool searching = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161022) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إضافة محادثة', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: '@username',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              helperText: 'ابحث باسم المستخدم الفريد',
            ),
            onSubmitted: (_) async {
              if (searching) return;
              setDialogState(() => searching = true);
              await _searchAndOpenUser(controller.text, dialogContext);
              if (dialogContext.mounted) setDialogState(() => searching = false);
            },
          ),
          actions: [
            TextButton(onPressed: searching ? null : () { controller.dispose(); Navigator.pop(dialogContext); }, child: const Text('إلغاء')),
            FilledButton.icon(
              onPressed: searching ? null : () async {
                setDialogState(() => searching = true);
                await _searchAndOpenUser(controller.text, dialogContext);
                if (dialogContext.mounted) setDialogState(() => searching = false);
              },
              icon: searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded),
              label: const Text('بحث'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showLogoutDialog(
    BuildContext context,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF161022)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  Colors.red.withOpacity(0.15),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF8A49DF)
                            : Colors.blue,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        _smoothRoute(
                          const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'خروج',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
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
      final name =
          chat['name'].toString().toLowerCase();
      final message =
          chat['lastMessage'].toString().toLowerCase();

      return name.contains(_searchQuery) ||
          message.contains(_searchQuery);
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F0C15)
              : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF161022) : Colors.white,
            elevation: 0,
            title: Text(
              'المحادثات | Zajel',
              style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.blue.shade50,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  color: isDark
                      ? const Color(0xFF161022)
                      : Colors.white,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'profile') {
                      Navigator.push(
                        context,
                        _smoothRoute(
                          const ProfileScreen(),
                        ),
                      );
                    } else if (value == 'settings') {
                      Navigator.push(
                        context,
                        _smoothRoute(
                          const SettingsScreen(),
                        ),
                      );
                    } else if (value == 'logout') {
                      _showLogoutDialog(
                        context,
                        isDark,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: isDark
                                ? const Color(0xFFEADBFF)
                                : Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'الملف الشخصي',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: isDark
                                ? const Color(0xFFEADBFF)
                                : Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'الإعدادات',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton:
              FloatingActionButton(
            backgroundColor: isDark
                ? const Color(0xFF8A49DF)
                : Colors.blue,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            tooltip: 'إضافة محادثة',
            onPressed: () => _showAddConversationDialog(isDark),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          body: Stack(
            children: [
              if (!isDark)
                Positioned.fill(
                  child: CustomPaint(
                    painter: BirdPatternPainter(),
                  ),
                ),
              Column(
                children: [
                  if (_loadingChats)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_chatLoadError != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_chatLoadError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  Container(
                    color: isDark
                        ? const Color(0xFF161022)
                        : Colors.white,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 14,
                    ),
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF221A30)
                            : const Color(0xFFF1F5F9),
                        borderRadius:
                            BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? Colors.white
                                  .withOpacity(0.04)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: isDark
                                ? Colors.white70
                                : Colors.blue.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller:
                                  _searchController,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 13,
                              ),
                              decoration:
                                  InputDecoration(
                                hintText:
                                    'البحث السريع...',
                                hintStyle: TextStyle(
                                  color:
                                      Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () =>
                                  _searchController
                                      .clear(),
                              child: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 85,
                            child: ListView(
                              scrollDirection:
                                  Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: [
                                _buildStoryAvatar(
                                  'قصتك',
                                  '🕊',
                                  isDark
                                      ? const Color(
                                          0xFF8A49DF)
                                      : Colors.blue,
                                  isAdd: true,
                                  isDark: isDark,
                                ),
                                _buildStoryAvatar(
                                  'أحمد',
                                  '👨',
                                  isDark
                                      ? const Color(
                                          0xFF9E5DF8)
                                      : Colors.blueAccent,
                                  isDark: isDark,
                                ),
                                _buildStoryAvatar(
                                  'زاجل',
                                  '🕊',
                                  isDark
                                      ? const Color(
                                          0xFF8A49DF)
                                      : Colors.indigo,
                                  isDark: isDark,
                                ),
                                _buildStoryAvatar(
                                  'سارة',
                                  '👩',
                                  isDark
                                      ? const Color(
                                          0xFFC79FFF)
                                      : Colors.blue,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            child: Text(
                              'الرسائل الأخيرة',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Colors.grey.shade500,
                              ),
                            ),
                          ),
                          filteredChats.isEmpty
                              ? const Padding(
                                  padding:
                                      EdgeInsets.all(30.0),
                                  child: Center(
                                    child: Text(
                                      'لا توجد نتائج مطابقة',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      filteredChats.length,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  itemBuilder:
                                      (context, index) {
                                    final chat =
                                        filteredChats[index];

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      decoration:
                                          BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF161022)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius
                                                .circular(16),
                                        border:
                                            Border.all(
                                          color: isDark
                                              ? Colors
                                                  .transparent
                                              : Colors
                                                  .grey
                                                  .shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors
                                                .black
                                                .withOpacity(
                                              isDark
                                                  ? 0.15
                                                  : 0.02,
                                            ),
                                            blurRadius: 6,
                                            offset:
                                                const Offset(
                                              0,
                                              2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              _smoothRoute(
                                                ChatScreen(
                                                  userName: chat['name'],
                                                  chatId: chat['chatId'],
                                                  partnerUid: chat['partnerUid'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Stack(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 24,
                                                      backgroundColor:
                                                          (chat['avatarColor']
                                                                  as Color)
                                                              .withOpacity(
                                                        0.2,
                                                      ),
                                                      child: Text(
                                                        chat['name']
                                                            [0],
                                                        style:
                                                            TextStyle(
                                                          color: chat[
                                                              'avatarColor'],
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (chat[
                                                        'isOnline'])
                                                      Positioned(
                                                        bottom: 1,
                                                        right: 1,
                                                        child:
                                                            Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .greenAccent,
                                                            shape: BoxShape
                                                                .circle,
                                                            border:
                                                                Border.all(
                                                              color: isDark
                                                                  ? const Color(
                                                                      0xFF161022)
                                                                  : Colors
                                                                      .white,
                                                              width: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        chat['name'],
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors
                                                                  .black87,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 3),
                                                      Text(
                                                        chat['lastMessage'],
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          color: chat[
                                                                      'unread'] >
                                                                  0
                                                              ? (isDark
                                                                  ? Colors
                                                                      .white
                                                                  : Colors
                                                                      .blue
                                                                      .shade900)
                                                              : Colors.grey
                                                                  .shade500,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .end,
                                                  children: [
                                                    Text(
                                                      chat['time'],
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: chat[
                                                                    'unread'] >
                                                                0
                                                            ? (isDark
                                                                ? const Color(
                                                                    0xFFEADBFF)
                                                                : Colors
                                                                    .blue)
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 4,
                                                    ),
                                                    if (chat[
                                                            'unread'] >
                                                        0)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF8A49DF)
                                                              : Colors
                                                                  .blue,
                                                          shape: BoxShape
                                                              .circle,
                                                        ),
                                                        child: Text(
                                                          '${chat['unread']}',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .white,
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
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

  Widget _buildStoryAvatar(
    String name,
    String emoji,
    Color color, {
    bool isAdd = false,
    required bool isDark,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      color.withOpacity(0.2),
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              if (isAdd)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: isDark
                        ? const Color(0xFF8A49DF)
                        : Colors.blue,
                    child: const Icon(
                      Icons.add,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? Colors.white70
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class BirdPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final List<Offset> birdPositions = [
      Offset(size.width * 0.15, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.22),
      Offset(size.width * 0.35, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.65),
      Offset(size.width * 0.20, size.height * 0.82),
      Offset(size.width * 0.60, size.height * 0.90),
    ];

    for (var pos in birdPositions) {
      final path = Path();

      path.moveTo(
        pos.dx - 12,
        pos.dy,
      );

      path.quadraticBezierTo(
        pos.dx - 6,
        pos.dy - 8,
        pos.dx,
        pos.dy,
      );

      path.quadraticBezierTo(
        pos.dx + 6,
        pos.dy - 8,
        pos.dx + 12,
        pos.dy,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class ChatScreen extends StatefulWidget {
  final String userName;
  final String chatId;
  final String partnerUid;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.chatId,
    required this.partnerUid,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final ValueNotifier<bool> _isTypingNotifier = ValueNotifier<bool>(false);
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSubscription;
  bool _isRecordingActive = false;
  bool _isLocked = false;
  bool _sending = false;
  double _currentDragY = 0.0;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => _isTypingNotifier.value = _textController.text.trim().isNotEmpty);
    _listenToMessages();
  }

  void _listenToMessages() {
    _messagesSubscription = FirebaseFirestore.instance
        .collection('conversations').doc(widget.chatId)
        .collection('messages').orderBy('createdAt')
        .snapshots().listen((snapshot) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        return <String, dynamic>{
          'id': doc.id,
          'type': data['type'] ?? 'text',
          'content': data['text'] ?? '',
          'time': _formatChatTime(createdAt),
          'isMe': data['senderId'] == uid ? 'true' : 'false',
          'senderId': data['senderId'],
        };
      }).toList();
      if (mounted) setState(() { _messages..clear()..addAll(items); });
    }, onError: (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تحميل الرسائل: $error')));
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _recordingTimer?.cancel();
    _textController.dispose();
    _isTypingNotifier.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      final db = FirebaseFirestore.instance;
      final conversationRef = db.collection('conversations').doc(widget.chatId);
      await conversationRef.collection('messages').add({
        'senderId': user.uid,
        'text': text,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await conversationRef.update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _textController.clear();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إرسال الرسالة: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachmentMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark
          ? const Color(0xFF161022)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'إرفاق ملف أو محتوى',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFEADBFF)
                      : Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentItem(
                    icon: Icons.image_rounded,
                    color: isDark
                        ? const Color(0xFF9E5DF8)
                        : Colors.blue,
                    title: 'صورة',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('طلب إرفاق صورة (رفع الصور غير مفعّل بعد)');
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.blueAccent,
                    title: 'الكاميرا',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('طلب إرفاق صورة من الكاميرا (غير مفعّل بعد)');
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.person_rounded,
                    color: Colors.orangeAccent,
                    title: 'جهة اتصال',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('جهة اتصال (مشاركة الجهات غير مفعّلة بعد)');
                    },
                  ),
                  _buildAttachmentItem(
                    icon:
                        Icons.insert_drive_file_rounded,
                    color: Colors.blueAccent,
                    title: 'مستند',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('مستند (رفع الملفات غير مفعّل بعد)');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTextMsg(String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(widget.chatId).collection('messages').add({
        'senderId': user.uid,
        'text': content,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('conversations').doc(widget.chatId).update({
        'lastMessage': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إرسال المحتوى: $error')));
    }
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                color.withOpacity(0.15),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
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

    _recordingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || !_isRecordingActive) {
          return;
        }

        setState(() {
          _recordingDuration +=
              const Duration(seconds: 1);
        });
      },
    );
  }

  void _updateRecording(
    LongPressMoveUpdateDetails details,
  ) {
    if (!_isRecordingActive || _isLocked) {
      return;
    }

    final double dragY =
        details.offsetFromOrigin.dy;

    setState(() {
      _currentDragY = dragY;

      if (_currentDragY < -55) {
        _isLocked = true;
      }
    });
  }

  void _endRecording() {
    if (!_isRecordingActive) {
      return;
    }

    if (_isLocked) {
      return;
    }

    _finishAndSendRecording();
  }

  void _finishAndSendRecording() {
    if (!_isRecordingActive) {
      return;
    }

    _recordingTimer?.cancel();

    setState(() {
      _isRecordingActive = false;
      _isLocked = false;
      _currentDragY = 0.0;

      _recordingDuration = Duration.zero;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('إرسال الرسائل الصوتية إلى Firestore غير مفعّل في هذه النسخة بعد.')),
    );
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

  String _formatRecordingDuration(
    Duration duration,
  ) {
    final minutes =
        duration.inMinutes.remainder(60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        duration.inSeconds.remainder(60)
            .toString()
            .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Widget _buildVoiceMessage(
    Map<String, dynamic> msg,
    bool isDark,
  ) {
    final String duration =
        msg['duration'] ?? '00:00';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.45),
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.30),
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.45),
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.25),
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.45),
                        borderRadius:
                            BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                duration,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F0C15)
              : const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize:
                const Size.fromHeight(60),
            child: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF161022)
                  : Colors.white,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.blue.shade50,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                    size: 16,
                  ),
                  onPressed: () =>
                      Navigator.pop(context),
                ),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark
                        ? const Color(0xFF221A30)
                        : Colors.blue.shade100,
                    child: Text(
                      widget.userName[0],
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFEADBFF)
                            : Colors.blue,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'متصل الآن',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.blue.shade50,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.videocam_rounded,
                      color: isDark
                          ? const Color(0xFFC79FFF)
                          : Colors.blue,
                      size: 18,
                    ),
                    onPressed: () {},
                    constraints:
                        const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.blue.shade50,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.phone_rounded,
                      color: isDark
                          ? const Color(0xFFC79FFF)
                          : Colors.blue,
                      size: 18,
                    ),
                    onPressed: () {},
                    constraints:
                        const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              if (!isDark)
                Positioned.fill(
                  child: CustomPaint(
                    painter: BirdPatternPainter(),
                  ),
                ),
              Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder:
                          (context, index) {
                        final msg =
                            _messages[index];

                        final isMe =
                            msg['isMe'] == 'true';

                        final type =
                            msg['type'];

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(
                              vertical: 5,
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints:
                                BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context)
                                          .size
                                          .width *
                                      0.78,
                            ),
                            decoration:
                                BoxDecoration(
                              gradient: isMe
                                  ? (isDark
                                      ? const LinearGradient(
                                          colors: [
                                            Color(
                                                0xFF8A49DF),
                                            Color(
                                                0xFF5A22A6),
                                          ],
                                          begin:
                                              Alignment.topLeft,
                                          end:
                                              Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.blue
                                                .shade600,
                                            Colors.blue
                                                .shade800,
                                          ],
                                          begin:
                                              Alignment.topLeft,
                                          end:
                                              Alignment.bottomRight,
                                        ))
                                  : null,
                              color: isMe
                                  ? null
                                  : (isDark
                                      ? const Color(
                                          0xFF1E172B)
                                      : Colors.white),
                              borderRadius:
                                  BorderRadius.only(
                                topLeft:
                                    const Radius.circular(
                                        18),
                                topRight:
                                    const Radius.circular(
                                        18),
                                bottomLeft:
                                    Radius.circular(
                                  isMe ? 18 : 4,
                                ),
                                bottomRight:
                                    Radius.circular(
                                  isMe ? 4 : 18,
                                ),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white
                                            .withOpacity(
                                            0.04,
                                          )
                                        : Colors.grey
                                            .shade200),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(
                                    0.04,
                                  ),
                                  blurRadius: 4,
                                  offset:
                                      const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: type == 'voice'
                                ? _buildVoiceMessage(
                                    msg,
                                    isDark,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .end,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          msg['content']!,
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors
                                                    .white
                                                : (isDark
                                                    ? Colors
                                                        .white
                                                    : Colors
                                                        .black87),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg['time']!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors
                                                      .white70
                                                  : Colors
                                                      .grey,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 4,
                                          ),
                                          Icon(
                                            Icons
                                                .done_all_rounded,
                                            color: isMe
                                                ? (isDark
                                                    ? const Color(
                                                        0xFFC79FFF)
                                                    : Colors
                                                        .white70)
                                                : Colors
                                                    .blue,
                                            size: 12,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
                            top: _isLocked
                                ? -62
                                : -45 +
                                    (_currentDragY
                                        .clamp(
                                      -55.0,
                                      0.0,
                                    )),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(
                                milliseconds: 120,
                              ),
                              padding:
                                  const EdgeInsets.all(
                                10,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: _isLocked
                                    ? Colors.red.shade700
                                    : (isDark
                                        ? const Color(
                                            0xFF221A30)
                                        : Colors.white),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(
                                      0.2,
                                    ),
                                    blurRadius: 8,
                                    offset:
                                        const Offset(
                                      0,
                                      -2,
                                    ),
                                  ),
                                ],
                                border: Border.all(
                                  color: _isLocked
                                      ? Colors.white
                                      : (isDark
                                          ? const Color(
                                              0xFF8A49DF)
                                          : Colors.blue),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                _isLocked
                                    ? Icons.lock_rounded
                                    : Icons
                                        .keyboard_arrow_up_rounded,
                                color: _isLocked
                                    ? Colors.white
                                    : (isDark
                                        ? const Color(
                                            0xFFC79FFF)
                                        : Colors.blue),
                                size: 20,
                              ),
                            ),
                          ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF161022)
                                  : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(
                                      28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white
                                        .withOpacity(0.08)
                                    : Colors
                                        .grey
                                        .shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(
                                    isDark
                                        ? 0.2
                                        : 0.05,
                                  ),
                                  blurRadius: 10,
                                  offset:
                                      const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _isRecordingActive
                                ? _buildRecordingBar(
                                    isDark,
                                  )
                                : _buildMessageBar(
                                    isDark,
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildRecordingBar(bool isDark) {
    return Container(
      height: 44,
      padding:
          const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _isLocked
            ? Colors.red.shade700
            : (isDark
                ? const Color(0xFF6D56E8)
                : Colors.blue),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade700,
                size: 17,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _isLocked
                ? Icons.lock_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            _formatRecordingDuration(
              _recordingDuration,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: List.generate(
                12,
                (index) {
                  return AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 180),
                    width: 3,
                    height:
                        5.0 +
                        ((index % 4) * 4.0),
                    margin:
                        const EdgeInsets.symmetric(
                      horizontal: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withOpacity(
                        0.75,
                      ),
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isLocked)
            GestureDetector(
              onTap: _finishAndSendRecording,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: isDark
                      ? const Color(0xFF6D56E8)
                      : Colors.blue,
                  size: 17,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBar(bool isDark) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(),
            icon: CustomPaint(
              size: const Size(22, 22),
              painter:
                  StickerIconPainter(
                isDark: isDark,
              ),
            ),
            onPressed: () {},
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            child: TextField(
              controller: _textController,
              style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
                fontSize: 14,
              ),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'الرسالة',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(),
            icon: Icon(
              Icons.attach_file_rounded,
              color: isDark
                  ? const Color(0xFFC79FFF)
                  : Colors.blue,
              size: 22,
            ),
            onPressed: () =>
                _showAttachmentMenu(isDark),
          ),
        ),
        const SizedBox(width: 4),
        ValueListenableBuilder<bool>(
          valueListenable:
              _isTypingNotifier,
          builder:
              (context, isTyping, child) {
            return AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 250),
              child: isTyping
                  ? GestureDetector(
                      key: const ValueKey(
                        'sendBtn',
                      ),
                      onTap: _sendMessage,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration:
                            BoxDecoration(
                          color: isDark
                              ? const Color(
                                  0xFF8A49DF)
                              : Colors
                                  .blue
                                  .shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.25,
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey(
                        'micBtn',
                      ),

                      onLongPressStart:
                          (_) {
                        _startRecording();
                      },

                      onLongPressMoveUpdate:
                          (details) {
                        _updateRecording(
                          details,
                        );
                      },

                      onLongPressEnd:
                          (_) {
                        _endRecording();
                      },

                      child: Container(
                        width: 44,
                        height: 44,
                        decoration:
                            BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(
                                  0xFF8A49DF)
                              : Colors
                                  .blue
                                  .shade600,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class StickerIconPainter
    extends CustomPainter {
  final bool isDark;

  StickerIconPainter({
    required this.isDark,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = isDark
          ? const Color(0xFFC79FFF)
          : Colors.blue.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          2.0,
          2.0,
          size.width - 4,
          size.height - 4,
        ),
        const Radius.circular(5),
      ),
    );

    canvas.drawPath(
      path,
      paint,
    );

    final fillDot = Paint()
      ..color = isDark
          ? const Color(0xFFC79FFF)
          : Colors.blue.shade700
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        size.width * 0.38,
        size.height * 0.38,
      ),
      1.5,
      fillDot,
    );

    canvas.drawCircle(
      Offset(
        size.width * 0.62,
        size.height * 0.38,
      ),
      1.5,
      fillDot,
    );

    final smilePath = Path();

    smilePath.moveTo(
      size.width * 0.35,
      size.height * 0.52,
    );

    smilePath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.66,
      size.width * 0.65,
      size.height * 0.52,
    );

    canvas.drawPath(
      smilePath,
      paint,
    );

    final foldPath = Path();

    foldPath.moveTo(
      size.width - 2.0,
      size.height * 0.54,
    );

    foldPath.quadraticBezierTo(
      size.width * 0.72,
      size.height * 0.58,
      size.width * 0.58,
      size.height - 2.0,
    );

    canvas.drawPath(
      foldPath,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}
