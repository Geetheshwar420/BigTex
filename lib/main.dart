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

enum AppInitState {
  loading,
  error,
  requiresAcceptance,
  accepted,
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

  // App Initialization state
  AppInitState _initState = AppInitState.loading;
  String? _initErrorMessage;

  static const String _privacyPolicyContent = '''
BigTex Privacy Policy
Last updated: August 5, 2026

1. DATA COLLECTION & PROCESSING
BigTex is built as an offline-first, local text banner and graphic utility application. We do NOT collect, harvest, transmit, or store any personal data, accounts, email addresses, or phone numbers on any remote servers.

2. LOCAL DEVICE STORAGE & USER CONTENT
• Text Input: Text created or typed within BigTex remains strictly in device memory and is never uploaded to any remote database.
• Exported Graphics & Images: When you export or share a banner graphic, the resulting image is temporarily saved to your local device directory using your device's native sharing capabilities.
• App Preferences: Your visual theme preferences (e.g., Dark Mode, colors, font choices, terms acceptance) are saved locally on your device via secure system storage.

3. DEVICE PERMISSIONS
BigTex may request basic system permissions solely to perform user-requested actions:
• Storage / Photo Library: Required only when saving or exporting custom text graphics to your device's gallery or file system.

4. THIRD-PARTY SERVICES
BigTex operates locally and does not integrate external advertising networks or invasive user analytics software.

5. CHILDREN'S PRIVACY
Because BigTex does not collect any personal data, our application is safe for users of all ages, including children under 13.

6. CONTACT US
If you have any questions regarding this Privacy Policy or BigTex's privacy practices, please contact us at:
Email: nareshkumark331@gmail.com
''';

  static const String _termsContent = '''
BigTex Terms & Conditions
Last updated: August 5, 2026

1. AGREEMENT TO TERMS
By accessing or using the BigTex mobile application ("Service"), you agree to be bound by these Terms. If you disagree with any part of the terms, then you may not access the Service.

2. INTELLECTUAL PROPERTY
The Service and its original content, features, and functionality are and will remain the exclusive property of BigTex Team and its licensors. The Service is protected by copyright, trademark, and other laws.

3. PROHIBITED USES
You agree not to use the Service:
• In any way that violates any applicable national or international law or regulation.
• To transmit, or procure the sending of, any advertising or promotional material without our prior written consent.
• To impersonate or attempt to impersonate the Company, a Company employee, another user, or any other person or entity.

4. LIMITATION OF LIABILITY
In no event shall BigTex Team, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your access to or use of or inability to access or use the Service.

5. DISCLAIMER
Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind.

6. GOVERNING LAW
These Terms shall be governed and construed in accordance with applicable laws, without regard to conflict of law provisions.

7. CONTACT US
If you have any questions about these Terms, please contact us at:
Email: nareshkumark331@gmail.com
''';

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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _initState = AppInitState.loading;
      _initErrorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAccepted = prefs.getBool('has_accepted_terms') ?? false;

      if (!mounted) return;

      setState(() {
        if (hasAccepted) {
          _initState = AppInitState.accepted;
        } else {
          _initState = AppInitState.requiresAcceptance;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initState = AppInitState.error;
        _initErrorMessage = e.toString();
      });
    }
  }

  Future<void> _acceptTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_accepted_terms', true);
      if (!mounted) return;
      setState(() {
        _initState = AppInitState.accepted;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save acceptance: $e. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showDocumentViewer(String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  content,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.6),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 20),
            Text(
              'Initializing BigTex...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Initialization Error',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _initErrorMessage ?? 'Failed to load user preferences.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeApp,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptanceScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0x1F38BDF8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to BigTex',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please review and acknowledge our Terms of Service & Privacy Policy before using the application.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Document Action Buttons
                  OutlinedButton.icon(
                    onPressed: () => _showDocumentViewer('Privacy Policy', _privacyPolicyContent),
                    icon: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF38BDF8)),
                    label: const Text('Read Privacy Policy', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDocumentViewer('Terms of Service', _termsContent),
                    icon: const Icon(Icons.description_outlined, color: Color(0xFF38BDF8)),
                    label: const Text('Read Terms of Service', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'By tapping "I Agree & Continue", you confirm that you have read and agree to the Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _acceptTerms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'I Agree & Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build Dispatcher ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_initState) {
      case AppInitState.loading:
        return _buildLoadingScreen();
      case AppInitState.error:
        return _buildErrorScreen();
      case AppInitState.requiresAcceptance:
        return _buildAcceptanceScreen();
      case AppInitState.accepted:
        return _buildMainEditorScaffold(context);
    }
  }

  Widget _buildMainEditorScaffold(BuildContext context) {
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
