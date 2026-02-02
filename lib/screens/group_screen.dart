import 'package:flutter/material.dart';
import '../widgets/group_manager.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grup Yönetimi')),
      body: const Center(
        child: GroupManagerDialog(),
      ),
    );
  }
}
