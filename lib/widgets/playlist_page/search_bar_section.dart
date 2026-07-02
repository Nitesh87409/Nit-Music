import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/custom_search_bar.dart';

class SearchBarSection extends StatefulWidget {
  const SearchBarSection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearchChanged,
    required this.labelText,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSearchChanged;
  final String labelText;

  @override
  State<SearchBarSection> createState() => _SearchBarSectionState();
}

class _SearchBarSectionState extends State<SearchBarSection> {
  @override
  Widget build(BuildContext context) {
    return CustomSearchBar(
      controller: widget.controller,
      focusNode: widget.focusNode,
      labelText: context.l10n!.search,
      onSubmitted: (_) {},
      onChanged: widget.onSearchChanged,
    );
  }
}
