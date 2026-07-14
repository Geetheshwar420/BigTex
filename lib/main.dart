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

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  final Map<int, Offset> _activePointers = <int, Offset>{};

  bool _isCenteredLayout = false;
  double _fontWeightValue = 700.0;
  double _pinchScale = 1.0;
  double _basePinchScale = 1.0;
  double _pinchStartDistance = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double _fontSizeForText(String text) {
    if (text.isEmpty) {
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

  void _toggleTextLayout() {
    setState(() {
      _isCenteredLayout = !_isCenteredLayout;
    });
  }

  FontWeight _fontWeightFromValue(double value) {
    final int roundedValue = ((value / 100.0).round() * 100).clamp(100, 900);
    switch (roundedValue) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
      default:
        return FontWeight.w900;
    }
  }

  double _distanceBetween(Offset first, Offset second) {
    return (first - second).distance;
  }

  void _startPinchIfNeeded() {
    if (_activePointers.length < 2) {
      return;
    }

    final Iterator<Offset> iterator = _activePointers.values.iterator;
    final Offset first = iterator.moveNext() ? iterator.current : Offset.zero;
    final Offset second = iterator.moveNext() ? iterator.current : Offset.zero;
    _pinchStartDistance = _distanceBetween(first, second);
    _basePinchScale = _pinchScale;
  }

  void _updatePinchScale() {
    if (_activePointers.length < 2 || _pinchStartDistance <= 0.0) {
      return;
    }

    final Iterator<Offset> iterator = _activePointers.values.iterator;
    final Offset first = iterator.moveNext() ? iterator.current : Offset.zero;
    final Offset second = iterator.moveNext() ? iterator.current : Offset.zero;
    final double currentDistance = _distanceBetween(first, second);
    if (currentDistance <= 0.0) {
      return;
    }

    setState(() {
      _pinchScale = math.max(0.5, math.min(_basePinchScale * (currentDistance / _pinchStartDistance), 3.0));
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      _startPinchIfNeeded();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) {
      return;
    }

    _activePointers[event.pointer] = event.localPosition;
    _updatePinchScale();
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchStartDistance = 0.0;
    }
  }

  void _handleTapToClear() {
    _focusNode.requestFocus();
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

  Widget _buildSharedTextField(TextStyle textStyle, {required bool isLandscape}) {
    final bool centeredLayout = _isCenteredLayout;
    final AlignmentGeometry alignment = centeredLayout ? Alignment.center : Alignment.topLeft;
    final EdgeInsetsGeometry padding = centeredLayout
        ? const EdgeInsets.all(32.0)
        : const EdgeInsets.fromLTRB(28.0, 28.0, 28.0, 28.0);
    final TextAlign textAlign = centeredLayout ? TextAlign.center : TextAlign.left;
    final TextAlignVertical textAlignVertical = centeredLayout ? TextAlignVertical.center : TextAlignVertical.top;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _toggleTextLayout,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
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
              textAlign: textAlign,
              textAlignVertical: textAlignVertical,
              onTap: isLandscape ? null : _handleTapToClear,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: _qText,
                hintStyle: TextStyle(
                  color: Color(0x40333333),
                  fontWeight: FontWeight.bold,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
              style: textStyle,
              onChanged: _handleTextChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoldnessSlider() {
    return RotatedBox(
      quarterTurns: 3,
      child: Slider(
        value: _fontWeightValue,
        min: 100.0,
        max: 900.0,
        divisions: 8,
        onChanged: (double value) {
          setState(() {
            _fontWeightValue = value;
          });
        },
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
      fontWeight: _fontWeightFromValue(_fontWeightValue),
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
            child: _buildSharedTextField(textStyle, isLandscape: true),
          ),
        ),
      );
    }

    if (!keyboardVisible) {
      // Full-Screen Mode (Keyboard Closed)
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _buildSharedTextField(textStyle, isLandscape: false),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: _buildSharedTextField(textStyle, isLandscape: false),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  SizedBox(
                    width: 44.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18.0),
                      child: _buildBoldnessSlider(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
