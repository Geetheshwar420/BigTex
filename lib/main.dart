import 'package:flutter/material.dart';
import 'dart:math' as math;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BigTextApp());
}

class BigTextApp extends StatelessWidget {
  const BigTextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const BigTextHomePage(),
    );
  }
}

class BigTextHomePage extends StatefulWidget {
  const BigTextHomePage({super.key});

  @override
  State<BigTextHomePage> createState() => _BigTextHomePageState();
}

class _BigTextHomePageState extends State<BigTextHomePage> {
  static const String _qText = 'Type here...';

  final TextEditingController _controller = TextEditingController(text: _qText);
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double _fontSizeForText(String text) {
    if (text.isEmpty || text == _qText) {
      return 100.0;
    }
    final double size = 100.0 - 1.5 * text.length;
    return math.max(20.0, size);
  }

  void _handleTextChanged(String text) {
    setState(() {
      // Rebuild so the style recomputes from the current controller text.
    });
  }

  void _handleTapToClear() {
    // Evaluates case-insensitively.
    if (_controller.text.toLowerCase() == _qText.toLowerCase()) {
      _controller.clear();
      // Force a UI rebuild so the font size updates immediately.
      _handleTextChanged('');
    }
  }

  void _unfocusKeyboard() {
    _focusNode.unfocus();
  }

  void _handleFullScreenTap() {
    _focusNode.requestFocus();
    _handleTapToClear(); // Clears text if they tap the outer edges.
  }

  Widget _buildSharedTextField(TextStyle textStyle) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      onTap: _handleTapToClear,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: textStyle,
      onChanged: _handleTextChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double fontSize = _fontSizeForText(_controller.text);

    final TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF333333),
      letterSpacing: -2.0,
      height: 1.0,
    );

    if (!keyboardVisible) {
      // Full-Screen Mode (Keyboard Closed)
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleFullScreenTap,
            child: SizedBox.expand(
              child: _buildSharedTextField(textStyle),
            ),
          ),
        ),
      );
    }

    // Editing Mode (Keyboard Open)
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _unfocusKeyboard,
                  ),
                  ElevatedButton(
                    onPressed: _unfocusKeyboard,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: _buildSharedTextField(textStyle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
