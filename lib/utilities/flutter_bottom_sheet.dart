import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

bool _isBottomSheetOpen = false;

Future<void> showCustomBottomSheet(
  BuildContext context,
  Widget content, {
  Color? backgroundColor,
  bool useScrollView = true,
}) async {
  if (_isBottomSheetOpen) return;
  _isBottomSheetOpen = true;

  final size = MediaQuery.sizeOf(context);
  final colorScheme = Theme.of(context).colorScheme;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) {
      final child = Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width * 0.92,
                maxHeight: size.height * 0.65,
              ),
              child: useScrollView
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: content,
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: content,
                    ),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      );

      if (backgroundColor != null) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: child,
          ),
        );
      }
      return child;
    },
  );

  _isBottomSheetOpen = false;
}

void closeCurrentBottomSheet() {
  if (_isBottomSheetOpen) {
    try {
      final context = NavigationManager.parentNavigatorKey.currentContext;
      if (context != null) {
        Navigator.pop(context);
      }
    } catch (_) {}
    _isBottomSheetOpen = false;
  }
}
