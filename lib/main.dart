import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _BigTextHomePageState extends State<BigTextHomePage> with SingleTickerProviderStateMixin {
  static const String _hintText = 'Type here...';

  // Core controllers & keys
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _repaintKey = GlobalKey();

  // Pinch-to-zoom state
  final Map<int, Offset> _activePointers = <int, Offset>{};
  double _pinchScale = 1.0;
  double _basePinchScale = 1.0;
  double _pinchStartDistance = 0.0;

  // Controls state
  double _sliderScale = 1.0;
  bool _isMenuOpen = false;
  late AnimationController _menuIconController;
  bool _showColorPicker = false;
  bool _showPopularSentences = false;
  bool _isDarkMode = false;
  TextAlign _textAlign = TextAlign.left;
  Offset _textOffset = Offset.zero;
  Size _lastFullScreenSize = Size.zero;

  // Font cycling (in hamburger menu)
  int _fontIndex = 0;
  static const List<String> _fontNames = [
    'Atkinson Hyperlegible',
    'Roboto',
    'Merriweather',
    'Pacifico',
    'Oswald',
  ];

  // Color palette for the toolbar color picker row
  int _selectedColorIndex = 0;
  static const List<Color> _colorPalette = [
    Colors.white,
    Color(0xFF999999),
    Color(0xFF333333),
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
  ];

  // Color presets for hamburger menu
  String _selectedColorPreset = 'Default';

  // Popular sentences
  final List<String> _popularSentences = [
    "Hello World!",
    "Flutter is awesome.",
    "Keep calm and code on.",
    "You got this!",
    "Dream big.",
    "Stay creative.",
    "Make it happen.",
    "Less is more.",
  ];

  @override
  void initState() {
    super.initState();
    _menuIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAccepted = prefs.getBool('has_accepted_terms') ?? false;
    if (!hasAccepted && mounted) {
      _showAcknowledgementDialog();
    }
  }

  Future<void> _showAcknowledgementDialog() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF38BDF8), size: 28),
            SizedBox(width: 10),
            Text(
              'Welcome to BigTex',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before using BigTex, please acknowledge our Terms of Service & Privacy Policy.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% Offline & Private: No personal data or text input is ever collected or sent to remote servers.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.image_outlined, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local Storage: Exported banner graphics are saved locally on your device.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_accepted_terms', true);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text(
                'I Agree & Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _menuIconController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Pinch-to-Zoom ─────────────────────────────────────────

  double _distanceBetween(Offset a, Offset b) => (a - b).distance;

  void _startPinchIfNeeded() {
    if (_activePointers.length < 2) return;
    final iter = _activePointers.values.iterator;
    final first = iter.moveNext() ? iter.current : Offset.zero;
    final second = iter.moveNext() ? iter.current : Offset.zero;
    _pinchStartDistance = _distanceBetween(first, second);
    _basePinchScale = _pinchScale;
  }

  void _updatePinchScale() {
    if (_activePointers.length < 2 || _pinchStartDistance <= 0.0) return;
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;

    final iter = _activePointers.values.iterator;
    final first = iter.moveNext() ? iter.current : Offset.zero;
    final second = iter.moveNext() ? iter.current : Offset.zero;
    final currentDist = _distanceBetween(first, second);
    if (currentDist <= 0.0) return;

    setState(() {
      _pinchScale = (_basePinchScale * (currentDist / _pinchStartDistance)).clamp(0.5, 3.0);
    });
  }

  void _handlePointerDown(PointerDownEvent e) {
    _activePointers[e.pointer] = e.localPosition;
    if (_activePointers.length == 2) _startPinchIfNeeded();
  }

  void _handlePointerMove(PointerMoveEvent e) {
    if (!_activePointers.containsKey(e.pointer)) return;
    _activePointers[e.pointer] = e.localPosition;

    if (_activePointers.length == 1) {
      if (MediaQuery.of(context).viewInsets.bottom == 0) {
        _lastFullScreenSize = MediaQuery.of(context).size;
        setState(() {
          _textOffset += e.delta;
        });
      }
    } else {
      _updatePinchScale();
    }
  }

  void _handlePointerEnd(PointerEvent e) {
    _activePointers.remove(e.pointer);
    if (_activePointers.length < 2) _pinchStartDistance = 0.0;
  }

  // ─── Actions ────────────────────────────────────────────────

  void _unfocusKeyboard() {
    _focusNode.unfocus();
    _menuIconController.reverse();
    setState(() {
      _isMenuOpen = false;
      _showColorPicker = false;
      _showPopularSentences = false;
    });
  }

  void _handleTapToFocus() {
    _focusNode.requestFocus();
    if (_controller.text.isEmpty) {
      _controller.selection = const TextSelection.collapsed(offset: 0);
    }
  }

  void _cycleAlignment() {
    setState(() {
      if (_textAlign == TextAlign.left) {
        _textAlign = TextAlign.center;
      } else if (_textAlign == TextAlign.center) {
        _textAlign = TextAlign.right;
      } else {
        _textAlign = TextAlign.left;
      }
    });
  }

  IconData _alignmentIcon() {
    switch (_textAlign) {
      case TextAlign.center:
        return Icons.format_align_center;
      case TextAlign.right:
        return Icons.format_align_right;
      default:
        return Icons.format_align_left;
    }
  }

  bool _isLandscape(BuildContext ctx) =>
      MediaQuery.of(ctx).orientation == Orientation.landscape;

  Future<void> _promptPortraitMode() async {
    if (!mounted) return;
    final shouldRotate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rotate to portrait?'),
            content: const Text('Text editing is available in portrait mode.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rotate'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRotate || !mounted) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  // ─── Image Export ───────────────────────────────────────────

  Future<void> _exportImage() async {
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture image bytes.');

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/bigtex_export.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with BigTex',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ─── Responsive Font Size ───────────────────────────────────

  double _responsiveFontSize(double containerWidth) {
    final base = containerWidth * 0.24;
    final size = base * _sliderScale * _pinchScale;
    return math.max(8.0, size);
  }

  double _responsiveFontSizeLandscape(double containerWidth) {
    final base = containerWidth * 0.12;
    final size = base * _sliderScale * _pinchScale;
    return math.max(8.0, size);
  }

  double _responsiveFontSizeEditing(double containerWidth) {
    final base = containerWidth * 0.12;
    final size = base * _sliderScale * _pinchScale;
    return math.max(8.0, size);
  }

  // ─── Text Color Logic ──────────────────────────────────────

  Color _resolveTextColor({required bool keyboardVisible}) {
    if (_selectedColorIndex == 0) { // Default color behavior
      if (_isDarkMode) {
        return const Color(0xFF999999);
      } else {
        return const Color(0xFF333333);
      }
    }
    return _colorPalette[_selectedColorIndex];
  }

  // ─── Text Style Builder ─────────────────────────────────────

  TextStyle _buildTextStyle(double fontSize, {required bool keyboardVisible}) {
    final color = _resolveTextColor(keyboardVisible: keyboardVisible);
    final fontName = _fontNames[_fontIndex];

    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.roboto(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.0,
          height: 1.0,
        );
      case 'Merriweather':
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.0,
          height: 1.1,
        );
      case 'Pacifico':
        return GoogleFonts.pacifico(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: color,
          letterSpacing: 0.0,
          height: 1.1,
        );
      case 'Oswald':
        return GoogleFonts.oswald(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.0,
          height: 1.0,
        );
      default:
        return GoogleFonts.atkinsonHyperlegible(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.0,
          height: 1.0,
        );
    }
  }

  TextStyle _buildHintStyle(double fontSize) {
    final hintColor = _isDarkMode ? const Color(0x60FFFFFF) : const Color(0x40333333);
    return GoogleFonts.atkinsonHyperlegible(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: hintColor,
      letterSpacing: 0.0,
      height: 1.0,
    );
  }

  // ─── Shared TextField ───────────────────────────────────────

  Widget _buildTextField(TextStyle textStyle, double fontSize,
      {required bool isLandscape}) {
    Widget textField = TextField(
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
      textAlign: _textAlign,
      textAlignVertical: TextAlignVertical.top,
      onTap: isLandscape ? null : _handleTapToFocus,
      decoration: InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        hintText: _hintText,
        hintStyle: _buildHintStyle(fontSize),
      ),
      style: textStyle,
      onChanged: (_) => setState(() {}),
    );

    // Apply gradient shader if Rainbow or Shades preset is active
    if (_selectedColorPreset == 'Rainbow') {
      textField = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo, Colors.purple],
        ).createShader(bounds),
        child: textField,
      );
    } else if (_selectedColorPreset == 'Shades') {
      textField = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.black, Colors.grey, Colors.black87],
        ).createShader(bounds),
        child: textField,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Transform.translate(
          offset: _textOffset,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: textField,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Icon Toolbar (above Done button) ──────────────────────

  Widget _buildIconToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      color: const Color(0xFF1A1A1A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [

          // Color picker toggle
          _toolbarIcon(
            icon: Icons.color_lens,
            isActive: _showColorPicker,
            onTap: () => setState(() {
              _showColorPicker = !_showColorPicker;
              if (_showColorPicker) _showPopularSentences = false;
            }),
          ),
          // Popular sentences toggle
          _toolbarIcon(
            icon: Icons.star,
            isActive: _showPopularSentences,
            onTap: () => setState(() {
              _showPopularSentences = !_showPopularSentences;
              if (_showPopularSentences) _showColorPicker = false;
            }),
          ),
          // Dark mode toggle
          _toolbarIcon(
            icon: _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            isActive: _isDarkMode,
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          // Alignment cycle
          _toolbarIcon(
            icon: _alignmentIcon(),
            isActive: _textAlign != TextAlign.left,
            onTap: _cycleAlignment,
          ),
          // Export / share
          _toolbarIcon(
            icon: Icons.ios_share,
            isActive: false,
            onTap: _exportImage,
          ),
        ],
      ),
    );
  }

  Widget _toolbarIcon({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white70,
          size: 24,
        ),
      ),
    );
  }

  // ─── Color Picker Row ───────────────────────────────────────

  Widget _buildColorPickerRow() {
    return Container(
      height: 48,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _colorPalette.length,
        itemBuilder: (context, index) {
          final color = _colorPalette[index];
          final isSelected = index == _selectedColorIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedColorIndex = index;
              _selectedColorPreset = 'Default'; // reset gradient presets
            }),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Popular Sentences Row ──────────────────────────────────

  Widget _buildSentenceChips() {
    return Container(
      height: 44,
      color: const Color(0xFF1A1A1A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: _popularSentences.length,
        itemBuilder: (context, index) {
          final sentence = _popularSentences[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: ActionChip(
              label: Text(
                sentence,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: const Color(0xFF2A2A2A),
              side: BorderSide.none,
              onPressed: () {
                _controller.text = sentence;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  // ─── Vertical Slider (left edge) ───────────────────────────

  Widget _buildVerticalSlider() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 44,
      child: Center(
        child: RotatedBox(
          quarterTurns: -1,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: Colors.white24,
              inactiveTrackColor: Colors.white54,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              overlayColor: Colors.white12,
            ),
            child: Slider(
              value: _sliderScale,
              min: 0.5,
              max: 3.0,
              onChanged: (val) => setState(() => _sliderScale = val),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Hamburger Menu Panel ──────────────────────────────────

  Widget _buildMenuPanel() {
    return const SizedBox.shrink(); // Side panel removed per user request
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape = _isLandscape(context);
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bgColor = _isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    // ── Landscape Mode ──
    if (isLandscape) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fontSize = _responsiveFontSizeLandscape(constraints.maxWidth);
              final textStyle = _buildTextStyle(fontSize, keyboardVisible: false);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _promptPortraitMode,
                child: _buildTextField(textStyle, fontSize, isLandscape: true),
              );
            },
          ),
        ),
      );
    }

    // ── Full-Screen Mode (Keyboard Closed) ──
    if (!keyboardVisible) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lastFullScreenSize = constraints.biggest;
              final fontSize = _responsiveFontSize(constraints.maxWidth);
              final textStyle = _buildTextStyle(fontSize, keyboardVisible: false);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: _buildTextField(textStyle, fontSize, isLandscape: false),
              );
            },
          ),
        ),
      );
    }

    // ── Editing Mode (Keyboard Open) ──
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Close (left) + Hamburger menu (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _isMenuOpen ? Icons.check : Icons.menu,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      if (_isMenuOpen) {
                        _unfocusKeyboard();
                      } else {
                        setState(() {
                          _isMenuOpen = true;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            // 9:16 preview + vertical slider + optional hamburger panel
            Expanded(
              child: Stack(
                children: [
                  // 9:16 preview container
                  Center(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: ClipRect(
                        child: AspectRatio(
                          aspectRatio: (_lastFullScreenSize.width > 0 && _lastFullScreenSize.height > 0)
                              ? (_lastFullScreenSize.width / _lastFullScreenSize.height)
                              : (9 / 16),
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? const Color(0xFF000000)
                                    : const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: _lastFullScreenSize.width > 0
                                      ? _lastFullScreenSize.width
                                      : MediaQuery.of(context).size.width,
                                  height: _lastFullScreenSize.height > 0
                                      ? _lastFullScreenSize.height
                                      : MediaQuery.of(context).size.height,
                                  child: _buildTextField(
                                    _buildTextStyle(
                                      _responsiveFontSize(
                                        _lastFullScreenSize.width > 0
                                            ? _lastFullScreenSize.width
                                            : MediaQuery.of(context).size.width,
                                      ),
                                      keyboardVisible: true,
                                    ),
                                    _responsiveFontSize(
                                      _lastFullScreenSize.width > 0
                                          ? _lastFullScreenSize.width
                                          : MediaQuery.of(context).size.width,
                                    ),
                                    isLandscape: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Vertical slider on the left edge
                  _buildVerticalSlider(),

                  // Hamburger menu panel (slides from right)
                  // (Removed - tools are inline now)
                ],
              ),
            ),

            // Popular sentences row (when star is active)
            if (_showPopularSentences && _isMenuOpen) _buildSentenceChips(),

            // Color picker row (when color_lens is active)
            if (_showColorPicker && _isMenuOpen) _buildColorPickerRow(),

            // Icon toolbar (only visible when hamburger menu is toggled ON)
            if (_isMenuOpen) _buildIconToolbar(),

            // Done button at the bottom (only visible when hamburger menu is inactive)
            if (!_isMenuOpen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _unfocusKeyboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
