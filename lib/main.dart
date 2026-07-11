import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey _textFieldKey = GlobalKey();

  double _pinchScale = 1.0;
  double _basePinchScale = 1.0;

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

  void _handleScaleStart(ScaleStartDetails details) {
    _basePinchScale = _pinchScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _pinchScale = math.max(0.5, math.min(_basePinchScale * details.scale, 3.0));
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

  bool _isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  Future<void> _promptPortraitMode() async {
    if (!mounted) {
      return;
    }

    final bool shouldRotate = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Rotate to portrait?'),
              content: const Text('Text editing is available in portrait mode. Switch now to edit.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Rotate'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRotate || !mounted) {
      return;
    }

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _unfocusKeyboard() {
    _focusNode.unfocus();
  }

  void _handleFullScreenTap(bool isLandscape) {
    if (isLandscape) {
      return;
    }
    _focusNode.requestFocus();
    _handleTapToClear(); // Clears text if they tap the outer edges.
  }

  Widget _buildSharedTextField(TextStyle textStyle, {required bool isLandscape}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: isLandscape ? null : _handleScaleUpdate,
      child: TextField(
        key: _textFieldKey,
        controller: _controller,
        focusNode: _focusNode,
        canRequestFocus: !isLandscape,
        readOnly: isLandscape,
        showCursor: !isLandscape,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        onTap: isLandscape ? null : _handleTapToClear,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: textStyle,
        onChanged: _handleTextChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = _isLandscape(context);
    final bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double fontSize = _fontSizeForText(_controller.text) * _pinchScale;

    final TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF333333),
      letterSpacing: -2.0,
      height: 1.0,
    );

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _promptPortraitMode,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _controller.text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!keyboardVisible) {
      // Full-Screen Mode (Keyboard Closed)
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleFullScreenTap(false),
            child: SizedBox.expand(
              child: _buildSharedTextField(textStyle, isLandscape: false),
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
                    child: _buildSharedTextField(textStyle, isLandscape: false),
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
