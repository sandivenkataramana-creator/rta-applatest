import 'package:flutter/material.dart';
import '../../core/widgets/page_header_banner.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeaderBanner(
              title: 'Support Center',
              subtitle: 'Government of Telangana Transport Department',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    child: ListTile(
                      title: Text(user['name']!),
                      subtitle: Text(user['role']!),
                      trailing: Chip(label: Text(user['status']!)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
