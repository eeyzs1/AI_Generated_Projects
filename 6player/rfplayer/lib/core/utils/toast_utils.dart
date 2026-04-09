import 'package:flutter/material.dart';

class ToastUtils {
  ToastUtils._();

  static OverlayEntry? _currentEntry;
  static bool _isShowing = false;

  static void showToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    if (_isShowing && _currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _isShowing = false;
    }

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        onDismissed: () {
          _isShowing = false;
        },
      ),
    );

    _currentEntry = overlayEntry;
    _isShowing = true;
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      if (_currentEntry == overlayEntry) {
        try {
          overlayEntry.remove();
          _isShowing = false;
          _currentEntry = null;
        } catch (_) {
          _isShowing = false;
        }
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _ToastWidget({required this.message, required this.onDismissed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.onDismissed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
