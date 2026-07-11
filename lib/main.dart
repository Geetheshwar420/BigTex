import 'package:flutter/material.dart';

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
  static const String _initialText = 'Type here...';

  final TextEditingController _controller = TextEditingController(text: _initialText);
  final FocusNode _focusNode = FocusNode();

  double _fontSize = 100.0;

  @override
  void initState() {
    super.initState();
    _recalculateFontSize(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _recalculateFontSize(String text) {
    final double size = 100.0 - 1.5 * text.length;
    setState(() {
      _fontSize = size < 20.0 ? 20.0 : size;
    });
  }

  void _unfocusKeyboard() {
    _focusNode.unfocus();
  }

  void _handleFullScreenTap() {
    _focusNode.requestFocus();
    if (_controller.text.toLowerCase() == _initialText.toLowerCase()) {
      _controller.clear();
      _recalculateFontSize('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    final TextStyle textStyle = TextStyle(
      fontSize: _fontSize,
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
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: textStyle,
                onChanged: (v) => _recalculateFontSize(v),
              ),
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
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: textStyle,
                      onChanged: (v) => _recalculateFontSize(v),
                    ),
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
