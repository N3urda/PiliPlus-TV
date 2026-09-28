import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Route scopes remember their last focused child. Only choose an initial item
/// when the navigator has no focused leaf; never replace a restored selection.
class TvNavigationObserver extends NavigatorObserver {
  void _ensureFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus is FocusScopeNode) focus.nextFocus();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _ensureFocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _ensureFocus();
}

/// A visible focus outline also covers existing buttons, dialogs and settings,
/// so they remain usable without individually replacing every mobile widget.
class TvNavigation extends StatefulWidget {
  const TvNavigation({super.key, required this.child});
  final Widget child;

  @override
  State<TvNavigation> createState() => _TvNavigationState();
}

class _TvNavigationState extends State<TvNavigation> {
  final _key = GlobalKey();
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final node = FocusManager.instance.primaryFocus;
      if (node is FocusScopeNode) {
        // The navigator may transfer focus after didPush's first frame. Fill
        // only an empty scope, preserving the last focused leaf on return.
        node.nextFocus();
        if (_rect != null) setState(() => _rect = null);
        return;
      }
      final context = node?.context;
      if (context != null && node is! FocusScopeNode) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
      if (!mounted || node != FocusManager.instance.primaryFocus) return;
      final target = context?.findRenderObject();
      final root = _key.currentContext?.findRenderObject();
      Rect? rect;
      if (node is! FocusScopeNode &&
          target is RenderBox &&
          root is RenderBox &&
          target.attached &&
          target.hasSize &&
          root.hasSize) {
        final candidate =
            target.localToGlobal(Offset.zero, ancestor: root) & target.size;
        if (candidate.width > 0 &&
            candidate.height > 0 &&
            candidate.width * candidate.height <
                root.size.width * root.size.height * .8) {
          rect = candidate;
        }
      }
      setState(() => _rect = rect);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    },
    child: Stack(
      key: _key,
      fit: StackFit.expand,
      children: [
        FocusTraversalGroup(child: widget.child),
        if (_rect case final rect?)
          Positioned.fromRect(
            rect: rect.inflate(2),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD166), width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
