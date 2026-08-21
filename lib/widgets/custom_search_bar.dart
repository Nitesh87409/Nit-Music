import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  const CustomSearchBar({
    super.key,
    required this.onSubmitted,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    this.onChanged,
    this.loadingProgressNotifier,
  });
  final Function(String) onSubmitted;
  final ValueNotifier<bool>? loadingProgressNotifier;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final Function(String)? onChanged;

  @override
  _CustomSearchBarState createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 46, // Reduced height
        decoration: BoxDecoration(
          color: colorScheme.surface, // Solid color instead of glassmorphism
          borderRadius: BorderRadius.circular(12), // Less rounded corners like image
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SearchBar(
            constraints: const BoxConstraints(minHeight: 46, maxHeight: 46),
            elevation: WidgetStateProperty.all(0),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            side: WidgetStateProperty.all(BorderSide.none),
            overlayColor: WidgetStateProperty.all(
              colorScheme.primary.withValues(alpha: 0.08),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16),
            ),
            hintText: widget.labelText,
            hintStyle: WidgetStateProperty.all(
              TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            textStyle: WidgetStateProperty.all(
              TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            leading: Icon(
              FluentIcons.search_24_regular,
              color: colorScheme.onSurface,
              size: 22,
            ),
            onSubmitted: (String value) {
              widget.onSubmitted(value);
              widget.focusNode.unfocus();
            },
            onChanged: widget.onChanged != null
                ? (value) async {
                    widget.onChanged!(value);
                    setState(() {});
                  }
                : null,
            textInputAction: TextInputAction.search,
            controller: widget.controller,
            focusNode: widget.focusNode,
            trailing: [
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    FluentIcons.dismiss_24_regular,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                    setState(() {});
                  },
                )
              else
                IconButton(
                  icon: Icon(
                    FluentIcons.mic_24_regular,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: () {
                    // Voice search placeholder
                  },
                ),
              if (widget.loadingProgressNotifier != null)
                ValueListenableBuilder<bool>(
                  valueListenable: widget.loadingProgressNotifier!,
                  builder: (_, value, __) {
                    if (value) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
