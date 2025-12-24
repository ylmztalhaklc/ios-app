// Bu dosya: Bildirimler sayfası (hem Hasta Yakını hem Bakıcı için ortak).
// - Kullanıcının tüm bildirimlerini listeler
// - Okunmamış bildirimler mavi ikon ile gösterilir
// - Sayfa açıldığında tüm bildirimler otomatik okundu işaretlenir
// - Tarih formatı: dd.MM.yyyy HH:mm

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../main.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  late Future<List<NotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    final api = ref.read(apiClientProvider);
    final user = ref.read(currentUserProvider);

    if (user != null) {
      // Bildirimleri getir
      _future = api.getNotifications(user.id);
      // Sayfa açıldığında tüm bildirimleri okundu olarak işaretle
      api.markAllNotificationsRead(user.id);
    } else {
      _future = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tarih formatı
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      // Bildirimleri FutureBuilder ile asenkron olarak yükle
      body: FutureBuilder<List<NotificationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final notifs = snapshot.data ?? [];
          if (notifs.isEmpty) {
            return const Center(child: Text('Bildirim yok'));
          }

          // Bildirim listesi
          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final n = notifs[index];
              final isUnread = !n.isRead;

              return ListTile(
                // Okunmamış ise aktif ikon, okunmuş ise pasif ikon
                leading: Icon(
                  isUnread
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: isUnread ? Colors.blue : Colors.grey,
                ),
                title: Text(n.message),
                subtitle: Text(df.format(n.createdAt)),
                onTap: () {
                  // Tıklama işlevi - şu an boş (gelecekte detay sayfası eklenebilir)
                },
              );
            },
          );
        },
      ),
    );
  }
}
