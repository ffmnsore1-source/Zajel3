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
final ValueNotifier<bool> activityVisibilityNotifier = ValueNotifier<bool>(true);

String _normalizeUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

DateTime? _activityDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

bool _isActivityOnline(Map<String, dynamic> profile) {
  if (profile['showActivity'] == false || profile['isOnline'] != true) return false;
  final lastSeen = _activityDate(profile['lastSeen']);
  if (lastSeen == null) return false;
  return DateTime.now().difference(lastSeen).inSeconds <= 75;
}

String _activityLabel(Map<String, dynamic> profile) {
  if (profile['showActivity'] == false) return 'آخر ظهور غير متاح';
  if (_isActivityOnline(profile)) return 'متصل الآن';
  final lastSeen = _activityDate(profile['lastSeen']);
  if (lastSeen == null) return 'غير متصل';
  final difference = DateTime.now().difference(lastSeen);
  if (difference.inSeconds < 60) return 'آخر ظهور قبل قليل';
  if (difference.inMinutes < 60) return 'آخر ظهور منذ ${difference.inMinutes} د';
  if (difference.inHours < 24) return 'آخر ظهور منذ ${difference.inHours} س';
  return 'آخر ظهور ${lastSeen.day}/${lastSeen.month}';
}

String _chatTime(dynamic value) {
  DateTime? date;
  if (value is Timestamp) date = value.toDate();
  if (value is DateTime) date = value;
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${hour.toString()}:${date.minute.toString().padLeft(2, '0')}';
  }
  return '${date.day}/${date.month}';
}

Future<void> _ensureUserProfile(User? user) async {
  if (user == null) return;
  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(user.uid);
  await db.runTransaction((transaction) async {
    final profileSnapshot = await transaction.get(userRef);
    final existing = profileSnapshot.data() ?? <String, dynamic>{};
    String username = (existing['username'] as String?)?.trim() ?? '';
    if (username.isEmpty ||
        !RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(_normalizeUsername(username))) {
      username = 'user_${user.uid.substring(0, user.uid.length < 10 ? user.uid.length : 10)}';
    }
    username = _normalizeUsername(username);
    var usernameLower = _normalizeUsername(username);
    var usernameRef = db.collection('usernames').doc(usernameLower);
    var usernameSnapshot = await transaction.get(usernameRef);
    if (usernameSnapshot.exists && usernameSnapshot.data()?['uid'] != user.uid) {
      username = 'user_${user.uid.toLowerCase()}';
      usernameLower = _normalizeUsername(username);
      usernameRef = db.collection('usernames').doc(usernameLower);
      usernameSnapshot = await transaction.get(usernameRef);
      if (usernameSnapshot.exists && usernameSnapshot.data()?['uid'] != user.uid) {
        throw StateError('تعذر إنشاء اسم مستخدم فريد لهذا الحساب.');
      }
    }
    final fullName = (existing['fullName'] as String?) ??
        (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'مستخدم زاجل');
    final status = (existing['status'] as String?) ?? 'متاح للتواصل الفوري 🕊';
    final profile = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'username': username,
      'usernameLower': usernameLower,
      'fullName': fullName,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    transaction.set(userRef, profile, SetOptions(merge: true));
    transaction.set(usernameRef, {
      'uid': user.uid,
      'username': username,
      'usernameLower': usernameLower,
      'fullName': fullName,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

// Telegram Plus-inspired visual system (Day/Night palette values extracted from Plus 13.1.1.1).
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
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: isDark ? const Color(0xFF5CC1FF) : const Color(0xFF298ACF),
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: isDark ? const Color(0xFF232326) : Colors.white,
            ),
            scaffoldBackgroundColor: isDark ? const Color(0xFF181819) : Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
              foregroundColor: isDark ? Colors.white : const Color(0xFF333333),
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            dividerColor: isDark ? const Color(0xFF303033) : const Color(0xFFE6E6E6),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: isDark ? const Color(0xFF303033) : const Color(0xFF333333),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF4F4F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF298ACF), width: 1.2)),
            ),
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
    try {
      await _ensureUserProfile(user);
    } catch (error) {
      _message('تم تسجيل الدخول، لكن تعذّر تجهيز الملف الشخصي: $error');
    }
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
      final authenticatedUser = result.user;
      if (authenticatedUser == null) {
        throw StateError('تمت العملية دون إرجاع حساب مستخدم صالح.');
      }

      // لا نجعل فشل Firestore يمنع المستخدم من دخول التطبيق.
      // المصادقة تتم أولاً، ثم نجهّز الملف الشخصي بشكل مستقل.
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        _smoothRoute(const ChatListScreen()),
        (route) => false,
      );

      // تجهيز بيانات المستخدم بالخلفية حتى لا تبقى شاشة الدخول معلّقة.
      unawaited(
        _ensureUserProfile(authenticatedUser).catchError((Object error) {
          debugPrint('Zajel profile setup failed: $error');
        }),
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
        final primary = isDark ? const Color(0xFF229ED9) : Colors.blue.shade700;
        final panel = isDark ? const Color(0xFF232326) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF181819) : const Color(0xFFFFFFFF),
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
                          color: isDark ? const Color(0xFFDAF0FF) : Colors.blue.shade900,
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
                                ? const [Color(0xFF229ED9), Color(0xFF1C83B8)]
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
                          style: TextStyle(color: isDark ? const Color(0xFF5CC1FF) : Colors.blue.shade700, fontWeight: FontWeight.w600),
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
          await _ensureUserProfile(user);
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
              ? const Color(0xFF181819)
              : const Color(0xFFFFFFFF),
          appBar: AppBar(
            backgroundColor:
                isDark ? const Color(0xFF232326) : Colors.white,
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
                        ? const Color(0xFFDAF0FF)
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
                            ? const Color(0xFF232326)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF229ED9).withOpacity(0.5)
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
                              Color(0xFF229ED9),
                              Color(0xFF1C83B8),
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
                                    ? const Color(0xFF229ED9)
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

  Future<bool> _saveProfileField(String key, String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    try {
      if (key == 'username') {
        final username = _normalizeUsername(value);
        if (!RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(username)) {
          throw ArgumentError('اسم المستخدم يجب أن يكون 3 إلى 40 حرفاً إنجليزياً أو رقماً أو _');
        }
        await db.runTransaction((transaction) async {
          final profileSnapshot = await transaction.get(userRef);
          final profile = profileSnapshot.data() ?? <String, dynamic>{};
          final oldUsername = _normalizeUsername((profile['username'] as String?) ?? '');
          final newRef = db.collection('usernames').doc(username);
          final newSnapshot = await transaction.get(newRef);
          DocumentSnapshot<Map<String, dynamic>>? oldSnapshot;
          DocumentReference<Map<String, dynamic>>? oldRef;
          if (oldUsername.isNotEmpty && oldUsername != username) {
            oldRef = db.collection('usernames').doc(oldUsername);
            oldSnapshot = await transaction.get(oldRef);
          }
          if (newSnapshot.exists && newSnapshot.data()?['uid'] != user.uid) {
            throw StateError('اسم المستخدم مستخدم بالفعل. اختر اسماً آخر.');
          }
          final fullName = (profile['fullName'] as String?) ?? 'مستخدم زاجل';
          final status = (profile['status'] as String?) ?? 'متاح للتواصل الفوري 🕊';
          transaction.set(userRef, {
            'uid': user.uid, 'email': user.email,
            'username': username, 'usernameLower': username,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          transaction.set(newRef, {
            'uid': user.uid, 'username': username, 'usernameLower': username,
            'fullName': fullName, 'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          if (oldRef != null && oldSnapshot != null &&
              oldSnapshot.exists && oldSnapshot.data()?['uid'] == user.uid) {
            transaction.delete(oldRef);
          }
        });
      } else {
        await db.runTransaction((transaction) async {
          final profileSnapshot = await transaction.get(userRef);
          final profile = profileSnapshot.data() ?? <String, dynamic>{};
          final username = _normalizeUsername((profile['username'] as String?) ?? '');
          DocumentReference<Map<String, dynamic>>? usernameRef;
          DocumentSnapshot<Map<String, dynamic>>? usernameSnapshot;
          if (username.isNotEmpty) {
            usernameRef = db.collection('usernames').doc(username);
            usernameSnapshot = await transaction.get(usernameRef);
          }
          transaction.set(userRef, {
            key: value,
            'uid': user.uid,
            'email': user.email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          if (usernameRef != null && usernameSnapshot != null &&
              usernameSnapshot.exists && usernameSnapshot.data()?['uid'] == user.uid) {
            transaction.set(usernameRef, {
              key: value,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر حفظ التعديل: $error')),
        );
      }
      return false;
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
        backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
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
              borderSide: BorderSide(color: isDark ? const Color(0xFF5CC1FF) : Colors.blue),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF229ED9) : Colors.blue, width: 2),
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
    final saved = await _saveProfileField(fieldKey, result.trim());
    if (saved && mounted) onUpdated(result.trim());
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email);
    final isDark = themeNotifier.value;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
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
      backgroundColor: const Color(0xFF232326),
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
              const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDAF0FF))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionItem(icon: Icons.photo_library_rounded, color: const Color(0xFF5CC1FF), title: 'المعرض', onTap: () { Navigator.pop(context); setState(() => _profileStatus = 'صورة معرض جديدة'); }),
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
          backgroundColor: isDark ? const Color(0xFF181819) : const Color(0xFFFFFFFF),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
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
                                gradient: LinearGradient(colors: isDark ? [const Color(0xFF229ED9), const Color(0xFF5CC1FF)] : [Colors.blue.shade400, Colors.blue.shade700]),
                              ),
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
                                child: Icon(Icons.person, size: 68, color: isDark ? const Color(0xFFDAF0FF) : Colors.blue),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: GestureDetector(
                                onTap: _editProfileImage,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isDark ? const Color(0xFF229ED9) : Colors.blue,
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
                          Flexible(child: Text(_profileStatus, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF5CC1FF) : Colors.blue.shade700, fontWeight: FontWeight.w600))),
                          IconButton(
                            tooltip: 'تعديل الحالة الشخصية',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? const Color(0xFF5CC1FF) : Colors.blue),
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
                            _buildModernProfileCard(isDark: isDark, icon: Icons.alternate_email_rounded, title: 'اسم المستخدم', value: _username.startsWith('@') ? _username : '@$_username', onEdit: () => _editTextField(title: 'اسم المستخدم', currentValue: _username, fieldKey: 'username', onUpdated: (value) => setState(() => _username = value))),
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
        color: isDark ? const Color(0xFF232326) : Colors.white,
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
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1F) : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDark ? const Color(0xFFDAF0FF) : Colors.blue, size: 20),
          ),
          title: Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          subtitle: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          trailing: IconButton(
            tooltip: 'تعديل $title',
            icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? const Color(0xFF5CC1FF) : Colors.blue),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showActivity = true;
  bool _loadingActivity = true;
  bool _savingActivity = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadActivityPreference();
  }

  Future<void> _loadActivityPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingActivity = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      _username = _normalizeUsername((data['username'] as String?) ?? '');
      var show = data['showActivity'] != false;
      if (_username!.isNotEmpty) {
        final publicProfile = await FirebaseFirestore.instance.collection('usernames').doc(_username).get();
        final publicData = publicProfile.data();
        if (publicData != null && publicData.containsKey('showActivity')) {
          show = publicData['showActivity'] != false;
        }
      }
      activityVisibilityNotifier.value = show;
      if (mounted) setState(() { _showActivity = show; _loadingActivity = false; });
    } catch (error) {
      debugPrint('[ZAJEL_ACTIVITY] preference load failed: $error');
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  Future<void> _setActivityVisibility(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _savingActivity) return;
    setState(() { _savingActivity = true; _showActivity = value; });
    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);
      final userSnapshot = await userRef.get();
      final username = _normalizeUsername((userSnapshot.data()?['username'] as String?) ?? _username ?? '');
      final batch = db.batch();
      batch.set(userRef, {
        'showActivity': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (username.isNotEmpty) {
        batch.set(db.collection('usernames').doc(username), {
          'showActivity': value,
          if (!value) 'isOnline': false,
          if (!value) 'lastSeen': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      activityVisibilityNotifier.value = value;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'سيظهر نشاطك للآخرين' : 'تم إخفاء حالة نشاطك وآخر ظهورك')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _showActivity = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ إعداد الخصوصية: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingActivity = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final panelColor = isDark ? const Color(0xFF232326) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final accent = isDark ? const Color(0xFF5CC1FF) : Colors.blue.shade800;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF181819) : const Color(0xFFFFFFFF),
          appBar: AppBar(
            backgroundColor: panelColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('الإعدادات', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('إعدادات المظهر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.blue.shade100)),
                child: SwitchListTile(
                  secondary: Icon(isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded, color: isDark ? Colors.amberAccent : Colors.orange),
                  title: Text(isDark ? 'الوضع الداكن' : 'الوضع الفاتح', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('تغيير سمة التطبيق بالكامل', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  value: isDark,
                  activeColor: const Color(0xFF229ED9),
                  onChanged: (value) => themeNotifier.toggleTheme(value),
                ),
              ),
              const SizedBox(height: 28),
              Text('الخصوصية والنشاط', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.blue.shade100)),
                child: SwitchListTile(
                  secondary: Icon(Icons.visibility_outlined, color: accent),
                  title: Text('إظهار حالة النشاط وآخر ظهور', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    _loadingActivity ? 'جارٍ تحميل الإعداد...' : (_showActivity ? 'يمكن للآخرين معرفة متى تكون متصلاً وآخر ظهورك' : 'لن يتمكن الآخرون من رؤية اتصالك أو آخر ظهورك'),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  value: _showActivity,
                  onChanged: _loadingActivity || _savingActivity ? null : _setActivityVisibility,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('عند إخفاء النشاط، لن تظهر حالتك للآخرين، لكن ستبقى قادراً على رؤية حالة نشاطهم إذا سمحوا بذلك.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.5)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Temporary Firestore diagnostic: remembers the last conversation opened in this app session.
String? _zajelLastOpenedConversationId;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() =>
      _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchingUser = false;
  String _searchQuery = '';
  final List<String> _recentUserSearches = <String>[];
  List<Map<String, dynamic>> _chats = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _preferencesSubscription;
  // Live public profile listeners keep names in every chat row synchronized
  // without changing the conversations query or Firestore security rules.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _peerProfileSubscriptions = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _incomingDeliverySubscriptions = {};
  final Set<String> _deliveringMessageKeys = <String>{};
  final Map<String, Map<String, dynamic>> _chatPreferences = {};
  final Set<String> _selectedChatIds = <String>{};
  String _activeChatTab = 'all';
  bool _loadingChats = true;
  String? _chatError;
  Timer? _presenceTimer;
  String? _presenceUsername;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final firestore = FirebaseFirestore.instance;
      final projectId = firestore.app.options.projectId;
      final appId = firestore.app.options.appId;
      debugPrint('[ZAJEL_CHAT_DIAG] START projectId=$projectId appId=$appId databaseId=(default) appName=${firestore.app.name} uid=${user.uid}');
      unawaited(_ensureUserProfile(user).then((_) => _startPresenceHeartbeat(user)).catchError((error, stack) {
        debugPrint('[ZAJEL_CHAT_DIAG] ensureUserProfile/presence start failed: $error');
      }));
      // Personal Plus-style preferences are stored below this account only.
      // The shared conversations query and its memberIds filter stay unchanged.
      _preferencesSubscription = firestore
          .collection('users').doc(user.uid).collection('chatPreferences')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final next = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.docs) {
          next[doc.id] = doc.data();
        }
        setState(() {
          _chatPreferences
            ..clear()
            ..addAll(next);
        });
      }, onError: (Object error) {
        debugPrint('[ZAJEL_PREFS] load failed: $error');
      });
      _chatSubscription = firestore
          .collection('conversations')
          .where('memberIds', arrayContains: user.uid)
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint('[ZAJEL_CHAT_DIAG] QUERY_OK projectId=$projectId uid=${user.uid} count=${snapshot.docs.length} ids=${snapshot.docs.map((doc) => doc.id).join(',')}');
          _onChatsChanged(snapshot);
        },
        onError: (Object error, StackTrace stack) {
          final details = 'Firestore query failed\n'
              'projectId: $projectId\n'
              'appId: $appId\n'
              'uid: ${user.uid}\n'
              'path: conversations\n'
              'databaseId: (default)\n'
              'filter: memberIds arrayContains current UID\n'
              'queryLimit: none\n'
              'error: $error';
          debugPrint('[ZAJEL_CHAT_DIAG] QUERY_ERROR $details');
          debugPrint('[ZAJEL_CHAT_DIAG] STACK $stack');
          if (mounted) setState(() { _chatError = details; _loadingChats = false; });
        },
      );
    } else {
      debugPrint('[ZAJEL_CHAT_DIAG] NO_AUTH_USER');
      _loadingChats = false;
    }
  }

  Future<void> _startPresenceHeartbeat(User user) async {
    final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final profileData = profile.data() ?? const <String, dynamic>{};
    activityVisibilityNotifier.value = profileData['showActivity'] != false;
    _presenceUsername = _normalizeUsername((profileData['username'] as String?) ?? '');
    if (_presenceUsername == null || _presenceUsername!.isEmpty) return;
    await _writePresence(true);
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(_writePresence(true));
    });
  }

  Future<void> _writePresence(bool online) async {
    final username = _presenceUsername;
    if (username == null || username.isEmpty) return;
    try {
      final visible = activityVisibilityNotifier.value;
      await FirebaseFirestore.instance.collection('usernames').doc(username).set({
        'showActivity': visible,
        'isOnline': visible && online,
        if (visible) 'lastSeen': FieldValue.serverTimestamp(),
        if (!visible) 'lastSeen': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      // If the device loses internet, the last heartbeat becomes stale. Other
      // clients treat a heartbeat older than 75 seconds as offline.
      debugPrint('[ZAJEL_ACTIVITY] presence write failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_writePresence(true));
      _presenceTimer ??= Timer.periodic(const Duration(seconds: 25), (_) {
        unawaited(_writePresence(true));
      });
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _presenceTimer?.cancel();
      _presenceTimer = null;
      unawaited(_writePresence(false));
    }
  }

  Future<void> _runConversationReadDiagnostic() async {
    final conversationId = _zajelLastOpenedConversationId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (conversationId == null || conversationId.isEmpty || uid == null) {
      if (mounted) {
        setState(() {
          _chatError = '${_chatError ?? ''}\n\nتشخيص الوثيقة: افتح محادثة من البحث أولاً، ثم ارجع واضغط فحص قراءة الوثيقة.';
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingChats = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      final data = snapshot.data();
      final rawMembers = data?['memberIds'];
      final membersAreList = rawMembers is List;
      final containsCurrentUid = membersAreList && rawMembers.contains(uid);
      final report = 'تشخيص قراءة الوثيقة: نجح\n'
          'documentId: $conversationId\n'
          'exists: ${snapshot.exists}\n'
          'memberIds is List: $membersAreList\n'
          'contains current UID: $containsCurrentUid\n'
          'databaseId: (default)';
      debugPrint('[ZAJEL_CHAT_DIAG] DIRECT_GET_OK $report');
      if (mounted) setState(() { _chatError = report; _loadingChats = false; });
    } catch (error, stack) {
      final report = 'تشخيص قراءة الوثيقة: فشل\n'
          'documentId: $conversationId\n'
          'error: $error';
      debugPrint('[ZAJEL_CHAT_DIAG] DIRECT_GET_ERROR $report');
      debugPrint('[ZAJEL_CHAT_DIAG] DIRECT_GET_STACK $stack');
      if (mounted) setState(() { _chatError = report; _loadingChats = false; });
    }
  }

  Future<void> _runAllFirestoreDiagnostics() async {
    final conversationId = _zajelLastOpenedConversationId;
    final user = FirebaseAuth.instance.currentUser;
    if (conversationId == null || conversationId.isEmpty || user == null) {
      if (mounted) {
        setState(() {
          _chatError = 'فحص Firestore الشامل: افتح محادثة من البحث أولاً، ثم ارجع واضغط الفحص الشامل.';
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingChats = true);

    final db = FirebaseFirestore.instance;
    final uid = user.uid;
    final projectId = db.app.options.projectId;
    final appId = db.app.options.appId;
    final baseQuery = db.collection('conversations')
        .where('memberIds', arrayContains: uid);
    final report = StringBuffer()
      ..writeln('فحص Firestore الشامل – زاجل')
      ..writeln('projectId: $projectId')
      ..writeln('appId: $appId')
      ..writeln('databaseId: (default)')
      ..writeln('uid: $uid')
      ..writeln('known conversationId: $conversationId')
      ..writeln('ملاحظة: كل اختبار مستقل؛ فشل اختبار لا يوقف البقية.')
      ..writeln('');

    Future<void> runTest(String name, Future<void> Function() test) async {
      try {
        await test();
        report.writeln('[$name] PASS');
      } catch (error) {
        report.writeln('[$name] FAIL: $error');
      }
    }

    // 1) Direct document read: verifies get on a known conversation.
    await runTest('1 DIRECT GET', () async {
      final snap = await db.collection('conversations').doc(conversationId)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) throw StateError('الوثيقة غير موجودة على الخادم');
      final data = snap.data() ?? <String, dynamic>{};
      final members = data['memberIds'];
      report.writeln('  document exists: ${snap.exists}');
      report.writeln('  memberIds type: ${members.runtimeType}');
      report.writeln('  memberIds is List: ${members is List}');
      report.writeln('  contains current UID: ${members is List && members.contains(uid)}');
      report.writeln('  memberIds length: ${members is List ? members.length : 'not-list'}');
      report.writeln('  memberProfiles is Map: ${data['memberProfiles'] is Map}');
      if (members is! List || !members.contains(uid)) {
        throw StateError('الوثيقة لا تحتوي UID الحالي ضمن memberIds');
      }
    });

    // 2) A real LIST query narrowed to the already-readable document.
    await runTest('2 FILTERED LIST (ONE DOCUMENT)', () async {
      final result = await db.collection('conversations')
          .where(FieldPath.documentId, isEqualTo: conversationId)
          .where('memberIds', arrayContains: uid)
          .get(const GetOptions(source: Source.server));
      report.writeln('  returned count: ${result.docs.length}');
      report.writeln('  returned IDs: ${result.docs.map((d) => d.id).join(', ')}');
      if (result.docs.isEmpty) throw StateError('الاستعلام لم يرجع الوثيقة المحددة');
    });

    // 3) Same membership query with a small limit.
    await runTest('3 LIST LIMIT 1', () async {
      final result = await baseQuery.limit(1)
          .get(const GetOptions(source: Source.server));
      report.writeln('  returned count: ${result.docs.length}');
      report.writeln('  returned IDs: ${result.docs.map((d) => d.id).join(', ')}');
    });

    // 4) Same membership query with a larger limit.
    await runTest('4 LIST LIMIT 20', () async {
      final result = await baseQuery.limit(20)
          .get(const GetOptions(source: Source.server));
      report.writeln('  returned count: ${result.docs.length}');
      report.writeln('  returned IDs: ${result.docs.map((d) => d.id).join(', ')}');
    });

    // 5) Exact one-shot server query matching the app's live listener filter.
    await runTest('5 FULL LIST GET (EXACT FILTER)', () async {
      final result = await baseQuery.get(
        const GetOptions(source: Source.server),
      );
      report.writeln('  returned count: ${result.docs.length}');
      report.writeln('  returned IDs: ${result.docs.map((d) => d.id).join(', ')}');
      final invalid = result.docs.where((doc) {
        final members = doc.data()['memberIds'];
        return members is! List || !members.contains(uid);
      }).map((doc) => doc.id).toList();
      report.writeln('  unexpected membership documents: ${invalid.join(', ')}');
      if (invalid.isNotEmpty) {
        throw StateError('نتائج لا تحتوي UID كما هو متوقع: ${invalid.join(', ')}');
      }
    });

    // 6) The same filter as a live stream, separated from the original listener.
    await runTest('6 LIVE STREAM FIRST SNAPSHOT', () async {
      final snapshot = await baseQuery.snapshots().first
          .timeout(const Duration(seconds: 25));
      report.writeln('  first snapshot count: ${snapshot.docs.length}');
      report.writeln('  first snapshot IDs: ${snapshot.docs.map((d) => d.id).join(', ')}');
    });

    report
      ..writeln('')
      ..writeln('انتهى الفحص. أرسل التقرير كاملاً كما هو.')
      ..writeln('لم يتم تغيير قواعد Firestore أو حذف/تعديل أي وثيقة.');

    final output = report.toString();
    debugPrint('[ZAJEL_FIRESTORE_FULL_DIAGNOSTIC]\n$output');
    if (mounted) {
      setState(() {
        _chatError = output;
        _loadingChats = false;
      });
    }
  }

  void _onChatsChanged(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    debugPrint('[ZAJEL_CHAT_DIAG] PROCESS_SNAPSHOT uid=$uid docs=${snapshot.docs.length}');
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aDate = a.data()['updatedAt'];
        final bDate = b.data()['updatedAt'];
        final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
        final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });
    final chats = <Map<String, dynamic>>[];
    final activeUsernames = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final members = List<String>.from(data['memberIds'] ?? const []);
      final peerUid = members.firstWhere((id) => id != uid, orElse: () => '');
      if (peerUid.isEmpty) continue;
      final profiles = Map<String, dynamic>.from(data['memberProfiles'] ?? const {});
      final peer = Map<String, dynamic>.from(profiles[peerUid] ?? const {});
      final username = _normalizeUsername((peer['username'] as String?) ?? '');
      if (username.isNotEmpty) activeUsernames.add(username);
      chats.add({
        'conversationId': doc.id,
        'peerUid': peerUid,
        'name': (peer['fullName'] as String?)?.trim().isNotEmpty == true
            ? peer['fullName'] : (peer['username'] ?? 'مستخدم زاجل'),
        'username': username,
        'lastMessage': (data['lastMessage'] as String?)?.isNotEmpty == true
            ? data['lastMessage'] : 'ابدأ محادثة جديدة',
        'time': _chatTime(data['updatedAt']),
        'unread': 0,
        'isOnline': false,
        'avatarColor': const Color(0xFF229ED9),
      });
    }

    // Keep incoming messages acknowledged as delivered while the recipient
    // app is connected, even before they open the individual conversation.
    final activeConversationIds = chats
        .map((chat) => chat['conversationId'] as String)
        .toSet();
    for (final chat in chats) {
      final conversationId = chat['conversationId'] as String;
      if (_incomingDeliverySubscriptions.containsKey(conversationId)) continue;
      _incomingDeliverySubscriptions[conversationId] = FirebaseFirestore.instance
          .collection('conversations').doc(conversationId)
          .collection('messages').orderBy('createdAt').snapshots()
          .listen((messageSnapshot) {
        for (final messageDoc in messageSnapshot.docs) {
          final messageData = messageDoc.data();
          if (messageData['senderId'] == uid || messageData['deliveredAt'] != null) continue;
          final key = '$conversationId/${messageDoc.id}';
          if (!_deliveringMessageKeys.add(key)) continue;
          unawaited(messageDoc.reference.update({
            'deliveredAt': FieldValue.serverTimestamp(),
          }).catchError((Object error) {
            debugPrint('[ZAJEL_RECEIPTS] delivery acknowledgement failed: $error');
          }).whenComplete(() {
            _deliveringMessageKeys.remove(key);
          }));
        }
      }, onError: (Object error) {
        debugPrint('[ZAJEL_RECEIPTS] delivery stream failed conversation=$conversationId error=$error');
      });
    }
    final obsoleteConversationIds = _incomingDeliverySubscriptions.keys
        .where((id) => !activeConversationIds.contains(id)).toList();
    for (final id in obsoleteConversationIds) {
      _incomingDeliverySubscriptions.remove(id)?.cancel();
    }

    // Keep one live listener per peer username. The username document is
    // already updated by the profile editor, and is readable by signed-in
    // users under the existing Firestore rules.
    for (final username in activeUsernames) {
      if (_peerProfileSubscriptions.containsKey(username)) continue;
      _peerProfileSubscriptions[username] = FirebaseFirestore.instance
          .collection('usernames').doc(username).snapshots().listen(
        (profileSnapshot) {
          if (!mounted || !profileSnapshot.exists) return;
          final profile = profileSnapshot.data() ?? const <String, dynamic>{};
          final latestName = (profile['fullName'] as String?)?.trim() ?? '';
          if (latestName.isEmpty) return;
          setState(() {
            for (final chat in _chats) {
              if (chat['username'] == username) {
                chat['name'] = latestName;
                chat['isOnline'] = _isActivityOnline(profile);
                chat['lastSeen'] = profile['lastSeen'];
                chat['showActivity'] = profile['showActivity'] != false;
              }
            }
          });
        },
        onError: (Object error) {
          debugPrint('[ZAJEL_PEER_PROFILE] username=$username error=$error');
        },
      );
    }
    final obsoleteUsernames = _peerProfileSubscriptions.keys
        .where((username) => !activeUsernames.contains(username)).toList();
    for (final username in obsoleteUsernames) {
      _peerProfileSubscriptions.remove(username)?.cancel();
    }

    if (mounted) setState(() { _chats = chats; _loadingChats = false; _chatError = null; });
  }

  Future<void> _saveChatPreference(String conversationId, String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final current = <String, dynamic>{
      'archived': false,
      'pinned': false,
      'muted': false,
      'hidden': false,
      'markedUnread': false,
      ...Map<String, dynamic>.from(_chatPreferences[conversationId] ?? const {}),
    };
    current[key] = value;
    current['updatedAt'] = FieldValue.serverTimestamp();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .collection('chatPreferences').doc(conversationId)
          .set(current, SetOptions(merge: true));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حفظ إعداد المحادثة: $error')),
      );
    }
  }

  Future<void> _toggleChatPreference(String conversationId, String key) async {
    final oldValue = _chatPreferences[conversationId]?[key] == true;
    await _saveChatPreference(conversationId, key, !oldValue);
  }

  void _showChatActions(Map<String, dynamic> chat) {
    final id = chat['conversationId'] as String;
    final pref = _chatPreferences[id] ?? const <String, dynamic>{};
    final isDark = themeNotifier.value;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21182D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF5CC1FF).withOpacity(.22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(.5), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Text(chat['name']?.toString() ?? 'المحادثة', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _chatActionTile(sheetContext, Icons.push_pin_outlined, pref['pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت المحادثة', () => _toggleChatPreference(id, 'pinned')),
          _chatActionTile(sheetContext, Icons.volume_off_outlined, pref['muted'] == true ? 'إلغاء الكتم' : 'كتم المحادثة', () => _toggleChatPreference(id, 'muted')),
          _chatActionTile(sheetContext, Icons.archive_outlined, pref['archived'] == true ? 'إلغاء الأرشفة' : 'أرشفة المحادثة', () => _toggleChatPreference(id, 'archived')),
          _chatActionTile(sheetContext, Icons.mark_chat_unread_outlined, pref['markedUnread'] == true ? 'تحديد كمقروءة' : 'تحديد كغير مقروءة', () => _toggleChatPreference(id, 'markedUnread')),
          _chatActionTile(sheetContext, Icons.check_circle_outline, 'تحديد', () { setState(() => _selectedChatIds.add(id)); }),
        ]),
      ),
    );
  }

  Widget _chatActionTile(BuildContext sheetContext, IconData icon, String title, VoidCallback action) {
    final dark = themeNotifier.value;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF5CC1FF)),
      title: Text(title, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 14)),
      onTap: () { Navigator.pop(sheetContext); action(); },
    );
  }

  Future<void> _applyBulkPreference(String key, dynamic value) async {
    final ids = _selectedChatIds.toList();
    for (final id in ids) { await _saveChatPreference(id, key, value); }
    if (mounted) setState(() => _selectedChatIds.clear());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    unawaited(_writePresence(false));
    _chatSubscription?.cancel();
    _preferencesSubscription?.cancel();
    for (final subscription in _peerProfileSubscriptions.values) {
      subscription.cancel();
    }
    _peerProfileSubscriptions.clear();
    for (final subscription in _incomingDeliverySubscriptions.values) {
      subscription.cancel();
    }
    _incomingDeliverySubscriptions.clear();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _searchAndOpenUser(String rawUsername, {BuildContext? closeContext}) async {
    final handle = _normalizeUsername(rawUsername);
    if (!RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(handle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم مستخدم صحيحاً مثل @majed_1')),
      );
      return false;
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return false;
    setState(() => _searchingUser = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('usernames').doc(handle).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        throw StateError('لم نعثر على مستخدم بهذا الاسم.');
      }
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        throw StateError('بيانات اسم المستخدم غير مكتملة.');
      }
      if (uid == current.uid) {
        throw StateError('هذا اسم حسابك أنت.');
      }
      final conversationId = await _createConversation(data);
      if (!mounted) return false;
      _recentUserSearches.remove(handle);
      _recentUserSearches.insert(0, handle);
      if (_recentUserSearches.length > 8) _recentUserSearches.removeLast();
      _searchController.clear();
      if (closeContext != null && closeContext.mounted) {
        Navigator.pop(closeContext);
      }
      Navigator.push(context, _smoothRoute(ChatScreen(
        conversationId: conversationId,
        peerUid: uid,
        peerUsername: data['username'] ?? handle,
        userName: (data['fullName'] as String?)?.trim().isNotEmpty == true
            ? data['fullName']
            : '@${data['username'] ?? handle}',
      )));
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = error is StateError ? error.message : 'تعذّر بدء المحادثة: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'حدث خطأ غير متوقع.')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _searchingUser = false);
    }
  }

  Future<void> _showSearchInterface(bool isDark) async {
    final controller = TextEditingController();
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit(String value) async {
            if (busy || value.trim().isEmpty) return;
            setDialogState(() => busy = true);
            final opened = await _searchAndOpenUser(value, closeContext: dialogContext);
            if (dialogContext.mounted && !opened) setDialogState(() => busy = false);
          }

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF232326) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.of(dialogContext).size.height * .72,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF229ED9).withOpacity(.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.search_rounded, color: Color(0xFF229ED9)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('البحث', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 2),
                          Text('ابحث عن الأشخاص باستخدام اسم المستخدم', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                        ],
                      )),
                      IconButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54)),
                    ]),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !busy,
                      onChanged: (_) => setDialogState(() {}),
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.search,
                      onSubmitted: submit,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'اسم المستخدم مثل majed_1',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.text.isNotEmpty)
                              IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: busy ? null : () => setDialogState(() => controller.clear()),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            busy
                                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                                : IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: () => submit(controller.text)),
                          ],
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Icon(Icons.history_rounded, size: 18, color: isDark ? Colors.white60 : Colors.black54),
                      const SizedBox(width: 8),
                      Text('عمليات البحث الأخيرة', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const Spacer(),
                      if (_recentUserSearches.isNotEmpty)
                        TextButton(onPressed: () => setDialogState(() => _recentUserSearches.clear()), child: const Text('مسح')),
                    ]),
                    Flexible(
                      child: _recentUserSearches.isEmpty
                          ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('لا توجد عمليات بحث أخيرة', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45))))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _recentUserSearches.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                              itemBuilder: (context, index) {
                                final handle = _recentUserSearches[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(radius: 17, backgroundColor: const Color(0xFF229ED9).withOpacity(.16), child: const Icon(Icons.person_outline_rounded, color: Color(0xFF229ED9), size: 19)),
                                  title: Text('@$handle', textDirection: TextDirection.ltr, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                  trailing: Icon(Icons.north_west_rounded, size: 17, color: isDark ? Colors.white54 : Colors.black45),
                                  onTap: busy ? null : () { controller.text = handle; submit(handle); },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<String> _createConversation(Map<String, dynamic> peer) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw StateError('سجّل الدخول أولاً.');
    final peerUid = peer['uid'] as String?;
    if (peerUid == null || peerUid.isEmpty || peerUid == current.uid) {
      throw StateError('حساب المستخدم غير صالح.');
    }
    final members = [current.uid, peerUid]..sort();
    final conversationId = '${members[0]}__${members[1]}';
    await _ensureUserProfile(current);
    final db = FirebaseFirestore.instance;
    final conversationRef = db.collection('conversations').doc(conversationId);
    final ownSnapshot = await db.collection('users').doc(current.uid).get();
    final own = ownSnapshot.data() ?? <String, dynamic>{};
    final ownUsername = _normalizeUsername(
      (own['username'] as String?) ?? 'user_${current.uid.substring(0, 8)}',
    );
    final peerUsername = _normalizeUsername(
      (peer['username'] as String?) ?? (peer['usernameLower'] as String? ?? ''),
    );
    if (ownUsername.isEmpty || peerUsername.isEmpty) {
      throw StateError('بيانات اسم المستخدم غير مكتملة. حدّث ملفك الشخصي ثم أعد المحاولة.');
    }
    final currentProfile = {
      'username': ownUsername,
      'usernameLower': ownUsername,
      'fullName': (own['fullName'] as String?)?.trim().isNotEmpty == true
          ? own['fullName'] : 'مستخدم زاجل',
    };
    final peerProfile = {
      'username': peerUsername,
      'usernameLower': peerUsername,
      'fullName': (peer['fullName'] as String?)?.trim().isNotEmpty == true
          ? peer['fullName'] : 'مستخدم زاجل',
    };
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(conversationRef);
      if (!existing.exists) {
        transaction.set(conversationRef, {
          'memberIds': members,
          'memberProfiles': {current.uid: currentProfile, peerUid: peerProfile},
          'type': 'private',
          'createdBy': current.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastSenderId': '',
        });
      }
    });
    return conversationId;
  }

  void _showLogoutDialog(
    BuildContext context,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF232326)
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
                            ? const Color(0xFF229ED9)
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

  Widget _buildPlusDrawer(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'حساب زاجل';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'Z';
    final bg = isDark ? const Color(0xFF232326) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF333333);
    final muted = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF79817E);
    Widget entry(IconData icon, String label, VoidCallback action, {Color? color}) {
      return ListTile(
        dense: true,
        minLeadingWidth: 28,
        leading: Icon(icon, color: color ?? (isDark ? const Color(0xFFB7DFFF) : const Color(0xFF404E56)), size: 22),
        title: Text(label, style: TextStyle(color: color ?? fg, fontSize: 14, fontWeight: FontWeight.w500)),
        onTap: action,
      );
    }
    return Drawer(
      width: 310,
      backgroundColor: bg,
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF229ED9), Color(0xFF1C83B8)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 29, backgroundColor: Colors.white.withOpacity(.22), child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold))),
              const SizedBox(height: 13),
              Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('زاجل • تواصل أسرع', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
            entry(Icons.person_outline_rounded, 'الملف الشخصي', () { Navigator.pop(context); Navigator.push(context, _smoothRoute(const ProfileScreen())); }),
            entry(Icons.chat_bubble_outline_rounded, 'كل المحادثات', () { Navigator.pop(context); setState(() => _activeChatTab = 'all'); }),
            entry(Icons.archive_outlined, 'الأرشيف', () { Navigator.pop(context); setState(() => _activeChatTab = 'archive'); }),
            entry(Icons.push_pin_outlined, 'المفضلة والمثبتة', () { Navigator.pop(context); setState(() => _activeChatTab = 'favorites'); }),
            Divider(color: isDark ? const Color(0xFF303033) : const Color(0xFFE6E6E6), height: 14),
            entry(Icons.settings_outlined, 'الإعدادات', () { Navigator.pop(context); Navigator.push(context, _smoothRoute(const SettingsScreen())); }),
            entry(Icons.nightlight_round, isDark ? 'الوضع النهاري' : 'الوضع الليلي', () { Navigator.pop(context); themeNotifier.toggleTheme(!isDark); }),
            entry(Icons.logout_rounded, 'تسجيل الخروج', () { Navigator.pop(context); _showLogoutDialog(context, isDark); }, color: Colors.redAccent),
          ])),
          Divider(height: 1, color: isDark ? const Color(0xFF303033) : const Color(0xFFE6E6E6)),
          Padding(padding: const EdgeInsets.all(13), child: Text('Zajel • Plus-inspired interface', style: TextStyle(color: muted, fontSize: 10))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((chat) {
      final id = chat['conversationId'] as String;
      final pref = _chatPreferences[id] ?? const <String, dynamic>{};
      final archived = pref['archived'] == true;
      final hidden = pref['hidden'] == true;
      if (hidden || (_activeChatTab != 'archive' && archived) || (_activeChatTab == 'archive' && !archived)) return false;
      if (_activeChatTab == 'favorites' && pref['pinned'] != true) return false;
      if (_activeChatTab == 'unread' && pref['markedUnread'] != true) return false;
      if (_activeChatTab == 'groups') return false;
      final name = chat['name'].toString().toLowerCase();
      final message = chat['lastMessage'].toString().toLowerCase();
      return name.contains(_searchQuery) || message.contains(_searchQuery);
    }).toList()..sort((a, b) {
      final ap = _chatPreferences[a['conversationId']]?['pinned'] == true;
      final bp = _chatPreferences[b['conversationId']]?['pinned'] == true;
      if (ap != bp) return ap ? -1 : 1;
      return 0;
    });

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final background = isDark ? const Color(0xFF181819) : Colors.white;
        final surface = isDark ? const Color(0xFF232326) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF333333);
        final muted = isDark ? const Color(0xFF8A8A8A) : const Color(0xFF79817E);
        final accent = isDark ? const Color(0xFF5CC1FF) : const Color(0xFF298ACF);
        return Scaffold(
          backgroundColor: background,
          drawer: _buildPlusDrawer(isDark),
          appBar: AppBar(
            backgroundColor: surface,
            elevation: 0,
            titleSpacing: 0,
            leading: Builder(builder: (ctx) => IconButton(
              tooltip: 'القائمة الجانبية',
              icon: const Icon(Icons.menu_rounded, size: 25),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            )),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('زاجل', style: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.w700)),
              Text(_activeChatTab == 'archive' ? 'الأرشيف' : 'المحادثات', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w400)),
            ]),
            actions: [
              IconButton(tooltip: 'بحث', onPressed: () => _showSearchInterface(isDark), icon: Icon(Icons.search_rounded, color: isDark ? Colors.white : const Color(0xFF404E56))),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF404E56)),
                color: surface,
                onSelected: (value) {
                  if (value == 'profile') Navigator.push(context, _smoothRoute(const ProfileScreen()));
                  if (value == 'settings') Navigator.push(context, _smoothRoute(const SettingsScreen()));
                  if (value == 'theme') themeNotifier.toggleTheme(!isDark);
                  if (value == 'logout') _showLogoutDialog(context, isDark);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
                  PopupMenuItem(value: 'settings', child: Text('الإعدادات')),
                  PopupMenuItem(value: 'theme', child: Text('تبديل المظهر')),
                  PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF229ED9),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
            tooltip: 'محادثة جديدة',
            onPressed: () => _showSearchInterface(isDark),
            child: const Icon(Icons.edit_rounded, size: 23),
          ),
          body: Column(children: [
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: Material(
                color: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showSearchInterface(isDark),
                  child: SizedBox(height: 42, child: Row(children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: muted, size: 20),
                    const SizedBox(width: 9),
                    Expanded(child: Text('بحث عن أشخاص أو رسائل', style: TextStyle(color: muted, fontSize: 13))),
                    const SizedBox(width: 12),
                  ])),
                ),
              ),
            ),
            Container(
              height: 48,
              color: surface,
              child: Row(children: [
                _plusTab('all', 'الكل', Icons.chat_bubble_outline_rounded, accent, muted),
                _plusTab('unread', 'غير المقروءة', Icons.mark_chat_unread_outlined, accent, muted),
                _plusTab('favorites', 'المثبتة', Icons.push_pin_outlined, accent, muted),
                _plusTab('archive', 'الأرشيف', Icons.archive_outlined, accent, muted),
              ]),
            ),
            Divider(height: 1, thickness: .7, color: isDark ? const Color(0xFF303033) : const Color(0xFFE6E6E6)),
            if (_selectedChatIds.isNotEmpty)
              Container(
                color: surface,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  Text('${_selectedChatIds.length} محددة', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(tooltip: 'أرشفة', onPressed: () => _applyBulkPreference('archived', true), icon: Icon(Icons.archive_outlined, color: accent)),
                  IconButton(tooltip: 'كتم', onPressed: () => _applyBulkPreference('muted', true), icon: Icon(Icons.volume_off_outlined, color: accent)),
                  IconButton(tooltip: 'تثبيت', onPressed: () => _applyBulkPreference('pinned', true), icon: Icon(Icons.push_pin_outlined, color: accent)),
                  IconButton(tooltip: 'إلغاء', onPressed: () => setState(() => _selectedChatIds.clear()), icon: Icon(Icons.close, color: muted)),
                ]),
              ),
            Expanded(child: _loadingChats
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _chatError != null
                ? SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
                    const SizedBox(height: 18),
                    Icon(Icons.cloud_off_outlined, size: 42, color: Colors.redAccent.withOpacity(.85)),
                    const SizedBox(height: 12),
                    Text('تعذّر تحميل المحادثات', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_chatError!, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11, height: 1.5)),
                    const SizedBox(height: 14),
                    FilledButton.icon(onPressed: _loadingChats ? null : _runAllFirestoreDiagnostics, icon: const Icon(Icons.health_and_safety_outlined), label: const Text('تشغيل فحص Firestore الشامل')),
                    TextButton(onPressed: () => setState(() { _chatError = null; _loadingChats = true; }), child: const Text('إعادة المحاولة')),
                  ]))
                : filteredChats.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_activeChatTab == 'archive' ? Icons.archive_outlined : Icons.forum_outlined, size: 46, color: muted),
                      const SizedBox(height: 12),
                      Text(_activeChatTab == 'archive' ? 'الأرشيف فارغ' : 'لا توجد محادثات بعد', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text('ابدأ محادثة جديدة باستخدام زر الكتابة', style: TextStyle(color: muted, fontSize: 12)),
                    ])))
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 2, bottom: 88),
                      itemCount: filteredChats.length,
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 78, endIndent: 8, color: isDark ? const Color(0xFF303033) : const Color(0xFFE6E6E6)),
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];
                        final id = chat['conversationId'] as String;
                        final pref = _chatPreferences[id] ?? const <String, dynamic>{};
                        final name = chat['name']?.toString() ?? 'مستخدم زاجل';
                        final avatarColor = (chat['avatarColor'] as Color?) ?? accent;
                        final selected = _selectedChatIds.contains(id);
                        final markedUnread = pref['markedUnread'] == true;
                        return Material(
                          color: selected ? accent.withOpacity(.12) : background,
                          child: InkWell(
                            onLongPress: () => _showChatActions(chat),
                            onTap: () {
                              if (_selectedChatIds.isNotEmpty) {
                                setState(() { if (! _selectedChatIds.add(id)) _selectedChatIds.remove(id); });
                                return;
                              }
                              _zajelLastOpenedConversationId = id;
                              Navigator.push(context, _smoothRoute(ChatScreen(
                                conversationId: id,
                                peerUid: chat['peerUid'],
                                peerUsername: chat['username'],
                                userName: name,
                              )));
                            },
                            child: SizedBox(height: 76, child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                              child: Row(children: [
                                Stack(children: [
                                  CircleAvatar(radius: 27, backgroundColor: avatarColor.withOpacity(.18), child: selected ? Icon(Icons.check, color: accent, size: 25) : Text(name.isNotEmpty ? name.substring(0, 1) : 'ز', style: TextStyle(color: avatarColor, fontSize: 20, fontWeight: FontWeight.w600))),
                                  if (chat['isOnline'] == true) Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF4BC36A), shape: BoxShape.circle, border: Border.all(color: background, width: 2)))),
                                ]),
                                const SizedBox(width: 12),
                                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600))),
                                    if (pref['pinned'] == true) Padding(padding: const EdgeInsetsDirectional.only(start: 5), child: Icon(Icons.push_pin_rounded, size: 13, color: muted)),
                                    if (pref['muted'] == true) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.volume_off_rounded, size: 14, color: muted)),
                                  ]),
                                  const SizedBox(height: 5),
                                  Text(chat['lastMessage']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12.5)),
                                ])),
                                const SizedBox(width: 8),
                                SizedBox(width: 55, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(chat['time']?.toString() ?? '', style: TextStyle(color: markedUnread ? accent : muted, fontSize: 10.5)),
                                  const SizedBox(height: 7),
                                  if (markedUnread) Container(constraints: const BoxConstraints(minWidth: 19), height: 19, padding: const EdgeInsets.symmetric(horizontal: 5), alignment: Alignment.center, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 11)),
                                ])),
                              ]),
                            )),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _plusTab(String id, String label, IconData icon, Color accent, Color muted) {
    final selected = _activeChatTab == id;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _activeChatTab = id),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? accent : Colors.transparent, width: 2.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: selected ? accent : muted),
          const SizedBox(width: 5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? accent : muted, fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
        ]),
      ),
    ));
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
  final String conversationId;
  final String peerUid;
  final String peerUsername;
  final String userName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerUid,
    required this.peerUsername,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();

  final ValueNotifier<bool> _isTypingNotifier =
      ValueNotifier<bool>(false);

  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSubscription;
  bool _sendingMessage = false;
  final Set<String> _acknowledgingMessageIds = <String>{};

  bool _isRecordingActive = false;
  bool _isLocked = false;

  double _currentDragY = 0.0;

  Timer? _recordingTimer;

  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _zajelLastOpenedConversationId = widget.conversationId;
    debugPrint('[ZAJEL_CHAT_DIAG] OPEN_CONVERSATION documentId=${widget.conversationId} uid=${FirebaseAuth.instance.currentUser?.uid}');
    _textController.addListener(() {
      _isTypingNotifier.value = _textController.text.trim().isNotEmpty;
    });
    _messageSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final isMine = data['senderId'] == currentUid;
        final status = doc.metadata.hasPendingWrites
            ? 'pending'
            : (data['readAt'] != null
                ? 'read'
                : (data['deliveredAt'] != null ? 'delivered' : 'sent'));
        if (!isMine && currentUid != null && data['deliveredAt'] != null && data['readAt'] == null) {
          unawaited(_acknowledgeIncomingMessage(doc));
        }
        return <String, dynamic>{
          'id': doc.id,
          'type': data['type'] ?? 'text',
          'content': data['text'] ?? '',
          'time': _chatTime(createdAt),
          'isMe': isMine ? 'true' : 'false',
          'deliveryStatus': status,
        };
      }).toList();
      if (mounted) setState(() { _messages..clear()..addAll(messages); });
    }, onError: (Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحميل الرسائل. تحقق من صلاحيات Firestore.')),
        );
      }
    });
  }

  Future<void> _acknowledgeIncomingMessage(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    if (!_acknowledgingMessageIds.add(doc.id)) return;
    try {
      final data = doc.data();
      // ChatListScreen acknowledges delivery as soon as the recipient app
      // receives the message. The open conversation adds the read receipt.
      if (mounted && data['deliveredAt'] != null && data['readAt'] == null) {
        await doc.reference.update({'readAt': FieldValue.serverTimestamp()});
      }
    } catch (error) {
      debugPrint('[ZAJEL_RECEIPTS] incoming acknowledgement failed: $error');
    } finally {
      _acknowledgingMessageIds.remove(doc.id);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _recordingTimer?.cancel();
    _textController.dispose();
    _isTypingNotifier.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sendingMessage) return;
    if (text.length > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرسالة طويلة جداً. الحد الأقصى 4000 حرف.')),
      );
      return;
    }
    setState(() => _sendingMessage = true);
    try {
      final db = FirebaseFirestore.instance;
      final conversation = db.collection('conversations').doc(widget.conversationId);
      final message = conversation.collection('messages').doc();
      final batch = db.batch();
      batch.set(message, {
        'senderId': user.uid,
        'type': 'text',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(conversation, {
        'lastMessage': text.length > 180 ? '${text.substring(0, 180)}…' : text,
        'lastSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final commitFuture = batch.commit();
      _textController.clear();
      unawaited(commitFuture.catchError((Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تسليم الرسالة إلى الخادم: $error')),
          );
        }
      }));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم تُرسل الرسالة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  void _showAttachmentMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark
          ? const Color(0xFF232326)
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
                      ? const Color(0xFFDAF0FF)
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
                      _addTextMsg('');
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.blueAccent,
                    title: 'الكاميرا',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('');
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.person_rounded,
                    color: Colors.orangeAccent,
                    title: 'جهة اتصال',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('');
                    },
                  ),
                  _buildAttachmentItem(
                    icon:
                        Icons.insert_drive_file_rounded,
                    color: Colors.blueAccent,
                    title: 'مستند',
                    onTap: () {
                      Navigator.pop(context);
                      _addTextMsg('');
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

  void _addTextMsg(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('إرسال الصور والملفات سيُفعّل بعد إعداد خدمة التخزين. المراسلة النصية متاحة الآن.')),
    );
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
      const SnackBar(content: Text('الرسائل الصوتية غير مرتبطة بالتخزين بعد؛ أُوقف الإرسال الوهمي حتى لا تظهر رسالة غير حقيقية.')),
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
              ? const Color(0xFF0F0F10)
              : const Color(0xFFFFFFFF),
          appBar: PreferredSize(
            preferredSize:
                const Size.fromHeight(60),
            child: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF232326)
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
                        ? const Color(0xFF1E1E1F)
                        : Colors.blue.shade100,
                    child: Text(
                      widget.userName[0],
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFDAF0FF)
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
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('usernames').doc(_normalizeUsername(widget.peerUsername)).snapshots(),
                        builder: (context, snapshot) {
                          final profile = snapshot.data?.data() ?? const <String, dynamic>{};
                          final online = _isActivityOnline(profile);
                          return Text(
                            _activityLabel(profile),
                            style: TextStyle(color: online ? const Color(0xFF36C66B) : Colors.grey, fontSize: 10),
                          );
                        },
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
                          ? const Color(0xFF5CC1FF)
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
                          ? const Color(0xFF5CC1FF)
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
                                                0xFF229ED9),
                                            Color(
                                                0xFF1C83B8),
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
                                          if (isMe)
                                            Icon(
                                              msg['deliveryStatus'] == 'pending'
                                                  ? Icons.schedule_rounded
                                                  : (msg['deliveryStatus'] == 'sent'
                                                      ? Icons.done_rounded
                                                      : Icons.done_all_rounded),
                                              color: msg['deliveryStatus'] == 'read'
                                                  ? const Color(0xFF66D9FF)
                                                  : Colors.white70,
                                              size: 13,
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
                                            0xFF1E1E1F)
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
                                              0xFF229ED9)
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
                                            0xFF5CC1FF)
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
                                      0xFF232326)
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
                  ? const Color(0xFF5CC1FF)
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
                                  0xFF229ED9)
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
                                  0xFF229ED9)
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
          ? const Color(0xFF5CC1FF)
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
          ? const Color(0xFF5CC1FF)
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
