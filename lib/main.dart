import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const ZajelRealApp());
}

class ZajelRealApp extends StatelessWidget {
  const ZajelRealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'زاجل الحقيقي',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0C15),
      ),
      home: const RealChatScreen(),
    );
  }
}

class RealChatScreen extends StatefulWidget {
  const RealChatScreen({super.key});

  @override
  State<RealChatScreen> createState() => _RealChatScreenState();
}

class _RealChatScreenState extends State<RealChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  
  // أدوات التسجيل والصور
  final ImagePicker _picker = ImagePicker();
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  
  bool _isRecording = false;
  bool _isLocked = false;
  double _dragY = 0.0;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // إرسال رسالة نصية
  void _sendTextMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'type': 'text', 'content': _controller.text});
    });
    _controller.clear();
  }

  // التقاط واختيار صورة حقيقية وإرسالها
  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _messages.add({'type': 'image', 'content': image.path});
      });
    }
  }

  // بدء التسجيل الصوتي الحقيقي
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // تحديد مسار مؤقت لحفظ التسجيل
        // (في التطبيق الفعلي يفضل استخدام path_provider للحصول على مجلد المؤقتات)
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: '', // سيقوم النظام بتوليد مسار تلقائي أو يمكن تحديد مسار محدد
        );
        setState(() {
          _isRecording = true;
          _isLocked = false;
          _dragY = 0.0;
        });
      }
    } catch (e) {
      debugPrint('خطأ في بدء التسجيل: $e');
    }
  }

  // تحديث حالة السحب للقفل
  void _updateRecording(DragUpdateDetails details) {
    if (!_isRecording) return;
    setState(() {
      _dragY += details.delta.dy;
      if (_dragY < -40) {
        _isLocked = true;
      }
    });
  }

  // إنهاء التسجيل وإرساله
  Future<void> _endRecording() async {
    if (!_isRecording) return;
    if (_isLocked) return; // لو مقفول لا يرسل تلقائياً بل يبقى بانتظار الإرسال اليدوي
    
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragY = 0.0;
      if (path != null) {
        _recordedFilePath = path;
        _messages.add({'type': 'voice', 'content': path});
      }
    });
  }

  // إلغاء التسجيل وحذفه
  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragY = 0.0;
    });
  }

  // تشغيل الصوت المسجل
  Future<void> _playVoice(String path) async {
    if (path.isNotEmpty) {
      Source urlSource = DeviceFileSource(path);
      await _audioPlayer.play(urlSource);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تجربة زاجل الحقيقية (صور وصوت)')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A1E85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: msg['type'] == 'image'
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(msg['content']),
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          )
                        : msg['type'] == 'voice'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                                    onPressed: () => _playVoice(msg['content']),
                                  ),
                                  const Text('رسالة صوتية مسجلة 🎤', style: TextStyle(color: Colors.white)),
                                ],
                              )
                            : Text(msg['content'], style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // القفل العائم على الجانب الأيمن
                if (_isRecording)
                  Positioned(
                    right: 16,
                    top: _isLocked ? -60 : -45 + (_dragY.clamp(-45.0, 0.0)),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isLocked ? Colors.red : const Color(0xFF221A30),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        border: Border.all(color: _isLocked ? Colors.white : Colors.blue, width: 2),
                      ),
                      child: Icon(
                        _isLocked ? Icons.lock : Icons.lock_open,
                        color: _isLocked ? Colors.white : Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // زر إرفاق الصور (معرض أو كاميرا)
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blueAccent),
                        onPressed: () => _pickAndSendImage(ImageSource.gallery),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            filled: true,
                            fillColor: const Color(0xFF161022),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendTextMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // زر التسجيل الصوتي الحقيقي بالسحب
                      GestureDetector(
                        onPanStart: (_) => _startRecording(),
                        onPanUpdate: (details) => _updateRecording(details),
                        onPanEnd: (_) => _endRecording(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isLocked ? Colors.red : Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 20),
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
    );
  }
}
