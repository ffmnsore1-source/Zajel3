          cat << 'EOF' > lib/main.dart
          import 'package:flutter/material.dart';
          import 'package:image_picker/image_picker.dart';

          void main() {
            runApp(const ZajelApp());
          }

          Route<T> _smoothRoute<T>(Widget page) {
            return PageRouteBuilder<T>(
              pageBuilder: (context, animation, secondaryAnimation) => page,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.08, 0.0);
                const end = Offset.zero;
                const curve = Curves.fastOutSlowIn;
                var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
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
                      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0C15) : Colors.white,
                      useMaterial3: true,
                    ),
                    home: const LoginScreen(),
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
            final _phoneController = TextEditingController();

            void _sendCode() {
              Navigator.push(
                context,
                _smoothRoute(OtpVerificationScreen(phoneNumber: _phoneController.text)),
              );
            }

            @override
            Widget build(BuildContext context) {
              return ValueListenableBuilder<bool>(
                valueListenable: themeNotifier,
                builder: (context, isDark, child) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0F0C15) : Colors.white,
                    body: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF221A30) : Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.purpleAccent.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                                      blurRadius: 25,
                                      offset: const Offset(0, 8),
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
                                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 48),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF191324) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? Colors.deepPurple.withOpacity(0.3) : Colors.blue.shade200),
                                ),
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87, letterSpacing: 1),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    labelText: 'رقم الهاتف',
                                    labelStyle: TextStyle(color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700, fontSize: 14),
                                    hintText: '+964 770 000 0000',
                                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    prefixIcon: Icon(Icons.phone_iphone_rounded, color: isDark ? const Color(0xFFC79FFF) : Colors.blue.shade700, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: isDark ? const LinearGradient(colors: [Color(0xFF6F35B4), Color(0xFF4A1E85)]) : null,
                                  color: isDark ? null : Colors.blue,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? Colors.purple : Colors.blue).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: _sendCode,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'إرسال رمز التحقق',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
            const OtpVerificationScreen({super.key, required this.phoneNumber});

            @override
            State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
          }

          class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
            final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());

            void _verifyAndProceed() {
              Navigator.pushAndRemoveUntil(
                context,
                _smoothRoute(const ChatListScreen()),
                (route) => false,
              );
            }

            @override
            Widget build(BuildContext context) {
              return ValueListenableBuilder<bool>(
                valueListenable: themeNotifier,
                builder: (context, isDark, child) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0F0C15) : Colors.white,
                    appBar: AppBar(
                      backgroundColor: isDark ? const Color(0xFF161022) : Colors.blue.shade50,
                      title: Text('رمز التحقق', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
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
                          Text(
                            'أدخل رمز التحقق المرسل',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFEADBFF) : Colors.blue.shade900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إلى الرقم: ${widget.phoneNumber.isEmpty ? "رقمك الشخصي" : widget.phoneNumber}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                          const SizedBox(height: 36),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return Container(
                                width: 45,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF191324) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? Colors.deepPurple.shade700 : Colors.blue, width: 1.5),
                                ),
                                child: TextField(
                                  controller: _controllers[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
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
                              gradient: isDark ? const LinearGradient(colors: [Color(0xFF6F35B4), Color(0xFF4A1E85)]) : null,
                              color: isDark ? null : Colors.blue,
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _verifyAndProceed,
                              child: const Text('تأكيد والانتقال', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

          class ChatListScreen extends StatelessWidget {
            const ChatListScreen({super.key});

            @override
            Widget build(BuildContext context) {
              return ValueListenableBuilder<bool>(
                valueListenable: themeNotifier,
                builder: (context, isDark, child) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0F0C15) : Colors.white,
                    appBar: AppBar(
                      backgroundColor: isDark ? const Color(0xFF161022) : Colors.blue.shade50,
                      elevation: 0,
                      title: Text('المحادثات | Zajel', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF8A49DF) : Colors.blue,
                            child: const Text('أ', style: TextStyle(color: Colors.white)),
                          ),
                          title: Text('أحمد علي', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                          subtitle: Text('أهلاً بك في تطبيق زاجل 🕊', style: TextStyle(color: Colors.grey.shade500)),
                          onTap: () {
                            Navigator.push(context, _smoothRoute(const ChatScreen(userName: 'أحمد علي')));
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          }

          class ChatScreen extends StatefulWidget {
            final String userName;
            const ChatScreen({super.key, required this.userName});

            @override
            State<ChatScreen> createState() => _ChatScreenState();
          }

          class _ChatScreenState extends State<ChatScreen> {
            final _textController = TextEditingController();
            final List<Map<String, dynamic>> _messages = [];
            final ImagePicker _picker = ImagePicker();

            @override
            void initState() {
              super.initState();
              _messages.add({
                'type': 'text',
                'content': 'أهلاً بك! معك ${widget.userName} 🕊',
                'time': '8:28 م',
                'isMe': 'false'
              });
            }

            @override
            void dispose() {
              _textController.dispose();
              super.dispose();
            }

            void _sendMessage() {
              if (_textController.text.trim().isEmpty) return;
              setState(() {
                _messages.add({
                  'type': 'text',
                  'content': _textController.text,
                  'time': '8:29 م',
                  'isMe': 'true'
                });
              });
              _textController.clear();
            }

            Future<void> _pickImage(ImageSource source) async {
              try {
                final XFile? image = await _picker.pickImage(source: source);
                if (image != null) {
                  setState(() {
                    _messages.add({
                      'type': 'text',
                      'content': '📷 صورة مرسلة (${image.name})',
                      'time': '8:30 م',
                      'isMe': 'true'
                    });
                  });
                }
              } catch (e) {
                // تجنب أي خطأ غير متوقع
              }
            }

            void _sendVoiceNote() {
              setState(() {
                _messages.add({
                  'type': 'text',
                  'content': '🎤 تسجيل صوتي مرسل',
                  'time': '8:31 م',
                  'isMe': 'true'
                });
              });
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
                            _buildAttachmentItem(
                              icon: Icons.image_rounded,
                              color: isDark ? const Color(0xFF9E5DF8) : Colors.blue,
                              title: 'معرض',
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                            _buildAttachmentItem(
                              icon: Icons.camera_alt_rounded,
                              color: Colors.blueAccent,
                              title: 'الكاميرا',
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              );
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

            @override
            Widget build(BuildContext context) {
              return ValueListenableBuilder<bool>(
                valueListenable: themeNotifier,
                builder: (context, isDark, child) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0F0C15) : Colors.white,
                    appBar: AppBar(
                      backgroundColor: isDark ? const Color(0xFF161022) : Colors.blue.shade50,
                      elevation: 0,
                      title: Text(widget.userName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
                    ),
                    body: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['isMe'] == 'true';
                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isMe ? (isDark ? const Color(0xFF4A1E85) : Colors.blue) : (isDark ? const Color(0xFF1E172B) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(msg['content']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.attach_file_rounded, color: isDark ? const Color(0xFFC79FFF) : Colors.blue),
                                  onPressed: () => _showAttachmentMenu(isDark),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'اكتب رسالتك...',
                                      hintStyle: TextStyle(color: Colors.grey.shade500),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.blue),
                                  onPressed: _sendMessage,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.mic_rounded, color: Colors.purpleAccent),
                                  onPressed: _sendVoiceNote,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          }
          EOF
