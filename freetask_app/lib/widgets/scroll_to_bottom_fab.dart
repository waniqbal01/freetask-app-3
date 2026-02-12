import 'package:flutter/material.dart';

class ScrollToBottomFAB extends StatefulWidget {
  const ScrollToBottomFAB({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<ScrollToBottomFAB> createState() => _ScrollToBottomFABState();
}

class _ScrollToBottomFABState extends State<ScrollToBottomFAB> {
  bool _showFAB = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!widget.scrollController.hasClients) return;

    final offset = widget.scrollController.offset;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final shouldShow = offset < maxScroll - 200;

    if (shouldShow != _showFAB) {
      setState(() => _showFAB = shouldShow);
    }
  }

  void _scrollToBottom() {
    widget.scrollController.animateTo(
      widget.scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showFAB) return const SizedBox.shrink();

    return FloatingActionButton.small(
      onPressed: _scrollToBottom,
      backgroundColor: const Color(0xFF2196F3),
      child: const Icon(Icons.arrow_downward, color: Colors.white),
    );
  }
}
