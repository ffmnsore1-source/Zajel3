import 'package:flutter/material.dart';

void main() {
  runApp(const ZajelApp());
}

class ZajelApp extends StatelessWidget {
  const ZajelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'زاجل - Zajel',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
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

  void _login() {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم الهاتف')),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C15),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: Color(0xFF221A30),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🕊️', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'زاجل | Zajel',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEADBFF),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'التواصل الأسرع والأكثر أماناً',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: const TextStyle(color: Color(0xFFC79FFF)),
                    filled: true,
                    fillColor: const Color(0xFF191324),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F35B4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _login,
                    child: const Text(
                      'دخول',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161022),
        title: const Text('المحادثات | زاجل', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFFC79FFF), child: Text('أ')),
            title: Text('أحمد علي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('أهلاً بك في تطبيق زاجل 🕊', style: TextStyle(color: Colors.grey)),
            trailing: Text('10:30 ص', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
