// ===================================================================
// KONUŞMA LİSTESİ SAYFASI (conversations_list_page.dart)
// ===================================================================
// Kullanıcının tüm mesajlaşmalarını listeler.
// Son mesaj ve okunmamış sayısı gösterilir.
// ===================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/models.dart';
import 'chat_page.dart';

class ConversationsListPage extends StatefulWidget {
  final int currentUserId;
  final String currentUserName;

  const ConversationsListPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  List<ConversationPreview> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conversations =
          await ApiClient.getConversations(widget.currentUserId);
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', 'tr').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Future<void> _showNewConversationDialog(BuildContext context) async {
    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final api = ApiClient();
    List<AppUser> allUsers = [];
    List<AppUser> filteredUsers = [];
    String searchQuery = '';

    try {
      // Tüm kullanıcıları al (hem bakıcı hem yakın)
      final caregivers = await api.getCaregivers();
      final relatives = await api.getRelatives();
      allUsers = [...caregivers, ...relatives]
        .where((u) => u.id != widget.currentUserId)
        .toList();
      filteredUsers = List.from(allUsers);
      
      // Debug için
      print('Toplam kullanıcı sayısı: ${allUsers.length}');
      print('Bakıcı sayısı: ${caregivers.length}');
      print('Hasta yakını sayısı: ${relatives.length}');
    } catch (e) {
      // Loading kapat
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcılar yüklenemedi: $e')),
        );
      }
      return;
    }

    // Loading kapat
    if (context.mounted) Navigator.pop(context);

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yeni Konuşma Başlat'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Ara',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          searchQuery = query.toLowerCase();
                          filteredUsers = allUsers
                            .where((u) => u.fullName.toLowerCase().contains(searchQuery))
                            .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (allUsers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Sistemde başka kullanıcı bulunmuyor',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      SizedBox(
                        height: 300,
                        child: filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                                searchQuery.isEmpty
                                  ? 'Kullanıcı listesi yükleniyor...'
                                  : 'Eşleşen kullanıcı yok',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: user.role == 'hasta_bakici'
                                      ? const Color(0xFF4ECDC4)
                                      : const Color(0xFFFEDBD0),
                                    child: Text(
                                      user.fullName[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: Text(
                                    user.role == 'hasta_bakici' ? 'Bakıcı' : 'Hasta Yakını',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          currentUserId: widget.currentUserId,
                                          currentUserName: widget.currentUserName,
                                          otherUserId: user.id,
                                          otherUserName: user.fullName,
                                        ),
                                      ),
                                    ).then((_) => _loadConversations());
                                  },
                                );
                              },
                            ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Mesajlar',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF4ECDC4)),
            tooltip: 'Yeni Konuşma',
            onPressed: () => _showNewConversationDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Hata: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadConversations,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz mesajlaşma yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.builder(
                        itemCount: _conversations.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return _buildConversationCard(conversation);
                        },
                      ),
                    ),
    );
  }

  Widget _buildConversationCard(ConversationPreview conversation) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: conversation.otherUserRole == 'hasta_bakici'
              ? const Color(0xFF4ECDC4)
              : const Color(0xFF95E1D3),
          child: Text(
            conversation.otherUserName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.otherUserName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            Text(
              _formatTime(conversation.lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                conversation.lastMessage ?? 'Henüz mesaj yok',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: conversation.unreadCount > 0
                      ? const Color(0xFF2C3E50)
                      : Colors.grey[600],
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF95E1D3),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                currentUserId: widget.currentUserId,
                currentUserName: widget.currentUserName,
                otherUserId: conversation.otherUserId,
                otherUserName: conversation.otherUserName,
              ),
            ),
          );
          // Geri dönünce listeyi yenile
          _loadConversations();
        },
      ),
    );
  }
}
