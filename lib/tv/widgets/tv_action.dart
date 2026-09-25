import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class TvAction extends StatefulWidget {
  const TvAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.padding = const EdgeInsets.all(8),
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;
  final EdgeInsets padding;

  @override
  State<TvAction> createState() => _TvActionState();
}

class _TvActionState extends State<TvAction> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: widget.autofocus,
    onFocusChange: (value) {
      setState(() => focused = value);
      if (value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 200),
              alignment: 0.2,
            );
          }
        });
      }
    },
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        widget.onPressed();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: focused ? const Color(0xFF315E4A) : const Color(0xFF20272C),
          border: Border.all(
            color: focused ? const Color(0xFF8DE0A9) : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: widget.child,
      ),
    ),
  );
}
