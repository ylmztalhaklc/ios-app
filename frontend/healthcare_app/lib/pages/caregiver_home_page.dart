// Bu dosya: Hasta Bakıcı için ana sayfa (dashboard).
// - Kullanıcı adını gösterir
// - Görevlerim sayfasına yönlendirme butonu
// - Bildirimler sayfasına yönlendirme butonu
// - Çıkış yapma butonu

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import 'caregiver_tasks_page.dart';
import 'notifications_page.dart';
import 'login_page.dart';
import 'conversations_list_page.dart';

class CaregiverHomePage extends ConsumerWidget {
  const CaregiverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hasta Bakıcı - ${user?.fullName ?? ""}'),
        actions: [
          // Çıkış butonu
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(currentUserProvider.notifier).state = null;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Görevlerim sayfasına git
            ElevatedButton(
              child: const Text('Görevlerim'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CaregiverTasksPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Bildirimler sayfasına git
            ElevatedButton(
              child: const Text('Bildirimler'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Mesajlar sayfasına git
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message),
                  SizedBox(width: 8),
                  Text('Mesajlar'),
                ],
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConversationsListPage(
                      currentUserId: user!.id,
                      currentUserName: user.fullName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
