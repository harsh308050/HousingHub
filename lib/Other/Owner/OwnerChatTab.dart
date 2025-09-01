import 'package:flutter/material.dart';

class OwnerChatTab extends StatefulWidget {
  const OwnerChatTab({super.key});

  @override
  State<OwnerChatTab> createState() => _OwnerChatTabState();
}

class _OwnerChatTabState extends State<OwnerChatTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text("Owner Chat Tab"),
        ),
      ),
    );
  }
}
