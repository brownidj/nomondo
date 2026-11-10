import 'dart:async';

import 'package:flutter/material.dart';

/// Contact details support explicit mouse hover as well as touch long-press.
class ContactTooltip extends StatefulWidget {
  const ContactTooltip({
    super.key,
    required this.message,
    required this.child,
    this.tooltipKey,
  });

  final String message;
  final Widget child;
  final GlobalKey<TooltipState>? tooltipKey;

  @override
  State<ContactTooltip> createState() => _ContactTooltipState();
}

class _ContactTooltipState extends State<ContactTooltip> {
  final _localKey = GlobalKey<TooltipState>();
  Timer? _hoverTimer;

  void _scheduleHover() {
    if (_hoverTimer != null) return;
    _hoverTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        (widget.tooltipKey ?? _localKey).currentState?.ensureTooltipVisible();
      }
    });
  }

  void _cancelHover() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  @override
  void dispose() {
    _cancelHover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    key: widget.tooltipKey ?? _localKey,
    message: widget.message,
    triggerMode: TooltipTriggerMode.longPress,
    waitDuration: const Duration(milliseconds: 300),
    exitDuration: const Duration(milliseconds: 200),
    showDuration: const Duration(seconds: 10),
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF202824),
      borderRadius: BorderRadius.circular(6),
    ),
    textStyle: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Colors.white, fontSize: 14, height: 1.4),
    child: MouseRegion(
      onEnter: (_) => _scheduleHover(),
      onHover: (_) => _scheduleHover(),
      onExit: (_) => _cancelHover(),
      child: widget.child,
    ),
  );
}
