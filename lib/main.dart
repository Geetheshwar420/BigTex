import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

const MethodChannel _rotationChannel = MethodChannel('big_text/rotation');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Request all orientations so the app may rotate freely.
  // Note: the system-wide orientation lock may still prevent rotation on some devices.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
  static const double _defaultFontSize = 70.0;
  static const double _minFontSize = 30.0;
  static const double _maxFontSize = 200.0;
  static const String _initialText = 'Type here...';

  final TextEditingController _controller = TextEditingController(text: _initialText);
  final FocusNode _focusNode = FocusNode();

  double _fontSize = _defaultFontSize;
  double _baseFontSize = _defaultFontSize;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTap() {
    _focusNode.requestFocus();
    if (_controller.text.toLowerCase() == _initialText.toLowerCase()) {
      _controller.clear();
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseFontSize = _fontSize;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final double nextSize = (_baseFontSize * details.scale).clamp(_minFontSize, _maxFontSize);
    if (nextSize != _fontSize) {
      setState(() {
        _fontSize = nextSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontSize: _fontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF333333),
      letterSpacing: -5.0,
      height: 0.8,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                      textAlign: TextAlign.left,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: textStyle,
                    ),
                  ),
                  // Done button positioned above the keyboard, bottom-right
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    right: 16,
                    bottom: keyboardInset + 12,
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      bottom: true,
                      child: GestureDetector(
                        onTap: () {
                          _focusNode.unfocus();
                        },
                        child: Material(
                          elevation: 2,
                          color: Colors.white,
                          shape: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Rotation helper button above keyboard, bottom-left
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    left: 16,
                    bottom: keyboardInset + 12,
                    child: SafeArea(
                      top: false,
                      left: true,
                      right: false,
                      bottom: true,
                      child: GestureDetector(
                        onTap: _showRotationHelp,
                        child: Material(
                          elevation: 2,
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Icon(
                              Icons.rotate_right,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showRotationHelp() async {
    // Show instructions; on Android, offer to open display settings.
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rotation Help'),
          content: Text(Platform.isAndroid
              ? 'If your screen does not rotate, please enable Auto-rotate in system Settings.\n\nTap "Open Settings" to jump to Display settings.'
              : 'If your screen does not rotate, please disable the Rotation Lock from Control Center (tap the lock with a circular arrow).'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (Platform.isAndroid)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await _rotationChannel.invokeMethod<bool>('openAutoRotateSettings');
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open settings')));
                  }
                },
                child: const Text('Open Settings'),
              ),
          ],
        );
      },
    );
  }
}
