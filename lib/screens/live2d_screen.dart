import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Live2D virtual avatar screen.
/// Loads the Hiyori Live2D model via WebView and exposes
/// mouth-sync / speaking / tap-reaction bridge methods.
class Live2DScreen extends StatefulWidget {
  const Live2DScreen({super.key});

  @override
  State<Live2DScreen> createState() => Live2DScreenState();
}

class Live2DScreenState extends State<Live2DScreen> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1A1A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() => _ready = true);
            // Let the model finish loading before first interaction
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) _pingReady();
            });
          },
        ),
      )
      ..loadFlutterAsset('assets/live2d/index.html');
  }

  Future<void> _pingReady() async {
    try {
      final result = await _controller
          .runJavaScriptReturningResult('window.__live2dReady ? 1 : 0');
      if (result.toString().contains('1')) {
        if (mounted) setState(() => _ready = true);
      }
    } catch (_) {}
  }

  /// Drive mouth opening 0~1 (voice amplitude).
  Future<void> setMouth(double v) async {
    if (!_ready) return;
    try {
      await _controller.runJavaScript('Live2D_setMouth($v);');
    } catch (_) {}
  }

  /// Toggle speaking state (nodding animation).
  Future<void> setSpeaking(bool b) async {
    if (!_ready) return;
    try {
      await _controller.runJavaScript('Live2D_setSpeaking($b);');
    } catch (_) {}
  }

  /// Trigger tap reaction.
  Future<void> react() async {
    if (!_ready) return;
    try {
      await _controller.runJavaScript('Live2D_react();');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('虚拟形象'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_ready)
            const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
