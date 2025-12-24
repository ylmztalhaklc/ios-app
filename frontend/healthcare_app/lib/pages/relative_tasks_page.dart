import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../main.dart';
import 'notifications_page.dart';
import 'conversations_list_page.dart';
import 'login_page.dart';
import 'relative_statistics_page.dart';

class RelativeTasksPage extends ConsumerStatefulWidget {
  const RelativeTasksPage({super.key});

  @override
  ConsumerState<RelativeTasksPage> createState() =>
      _RelativeTasksPageState();
}

class _RelativeTasksPageState extends ConsumerState<RelativeTasksPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<DateTime, List<TaskInstance>> _tasksByDate = {};
  List<TaskInstance> _allTasks = [];
  List<TaskTemplate> _templates = [];
  List<AppUser> _caregivers = [];
  bool _isLoading = true;
  
  // Gösterilen ciddi sorun ID'lerini sakla (tekrar gösterilmesin)
  final Set<int> _shownCriticalProblems = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final tasks = await api.getCreatedTasks(user.id);
      final templates = await api.getTaskTemplates(user.id);
      final caregivers = await api.getCaregivers();

      print('Yüklenen görev sayısı: ${tasks.length}');
      print('Yüklenen şablon sayısı: ${templates.length}');
      print('Yüklenen bakıcı sayısı: ${caregivers.length}');

      setState(() {
        _allTasks = tasks;
        _tasksByDate = _groupTasksByDate(tasks);
        _templates = templates;
        _caregivers = caregivers;
        _isLoading = false;
      });
      
      // Ciddi sorun kontrolü
      _checkCriticalProblems(tasks);
      
      if (caregivers.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sistemde hiç bakıcı yok. Lütfen önce bakıcı ekleyin.'),
            backgroundColor: Color(0xFFFF6B6B),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Veri yükleme hatası: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri yüklenirken hata: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Map<DateTime, List<TaskInstance>> _groupTasksByDate(
      List<TaskInstance> tasks) {
    Map<DateTime, List<TaskInstance>> grouped = {};
    for (var task in tasks) {
      final date = DateTime(
        task.scheduledFor.year,
        task.scheduledFor.month,
        task.scheduledFor.day,
      );
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(task);
    }
    return grouped;
  }

  void _checkCriticalProblems(List<TaskInstance> tasks) async {
    // SharedPreferences'tan daha önce gösterilen ciddi sorunları yükle
    final prefs = await SharedPreferences.getInstance();
    final shownIds = prefs.getStringList('shown_critical_problems') ?? [];
    final shownIdsSet = shownIds.map((id) => int.parse(id)).toSet();
    
    // Ciddi sorunlu görevleri bul (sadece daha önce gösterilmemişler)
    final criticalProblems = tasks.where((task) =>
      task.problemSeverity == 'ciddi' && 
      (task.status == 'problem' || task.status == 'resolved') &&
      !shownIdsSet.contains(task.id)
    ).toList();

    if (criticalProblems.isEmpty) return;

    // En son ciddi sorunu göster
    final latestCritical = criticalProblems.reduce((a, b) =>
      a.createdAt.isAfter(b.createdAt) ? a : b
    );

    // Bu sorunun ID'sini kalıcı olarak kaydet
    shownIdsSet.add(latestCritical.id);
    await prefs.setStringList(
      'shown_critical_problems',
      shownIdsSet.map((id) => id.toString()).toList()
    );

    // Dialog göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.red, width: 3),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning, color: Colors.red, size: 32),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '⚠️ CİDDİ SORUN',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestCritical.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (latestCritical.problemMessage != null)
                        Text(
                          latestCritical.problemMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(latestCritical.scheduledFor)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bu ciddi sorun Bakanlığa bildirilmiştir. Gerekli aksiyonlar alınmaktadır.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Anladım',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4ECDC4),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  List<TaskInstance> _getTasksForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final tasks = _tasksByDate[normalizedDay] ?? [];
    
    // Özel sıralama: yapılmamış -> sorunlu (ciddi/orta/hafif) -> çözülen (ciddi/orta/hafif) -> tamamlanan
    tasks.sort((a, b) {
      // Yapılmamış görevler (pending, in_progress) en üstte
      final aActive = (a.status == 'pending' || a.status == 'in_progress');
      final bActive = (b.status == 'pending' || b.status == 'in_progress');
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      
      // Sorunlu görevler yapılmamışlardan sonra
      if (a.status == 'problem' && b.status != 'problem') return -1;
      if (a.status != 'problem' && b.status == 'problem') return 1;
      
      // Her iki görev de sorunlu ise derece sırasına göre: ciddi -> orta -> hafif
      if (a.status == 'problem' && b.status == 'problem') {
        final severityOrder = {'ciddi': 0, 'orta': 1, 'hafif': 2};
        final aOrder = severityOrder[a.problemSeverity] ?? 3;
        final bOrder = severityOrder[b.problemSeverity] ?? 3;
        return aOrder.compareTo(bOrder);
      }
      
      // Çözülen görevler arasında derece sırasına göre: ciddi -> orta -> hafif
      if (a.status == 'resolved' && b.status == 'resolved') {
        final severityOrder = {'ciddi': 0, 'orta': 1, 'hafif': 2};
        final aOrder = severityOrder[a.problemSeverity] ?? 3;
        final bOrder = severityOrder[b.problemSeverity] ?? 3;
        return aOrder.compareTo(bOrder);
      }
      
      // Çözülen görevler done'dan önce
      if (a.status == 'resolved' && b.status == 'done') return -1;
      if (a.status == 'done' && b.status == 'resolved') return 1;
      
      return 0;
    });
    return tasks;
  }

  Color _statusColor(String status, {String? severity}) {
    // Ciddi sorunlar çözülse bile kırmızı kalır
    if (status == 'resolved' && severity == 'ciddi') {
      return const Color(0xFFFF6B6B);
    }
    
    switch (status) {
      case 'done':
      case 'resolved':
        return const Color(0xFF95E1D3);
      case 'problem':
        return const Color(0xFFFF6B6B);
      case 'pending':
        return const Color(0xFFFEDBD0);
      case 'in_progress':
        return const Color(0xFF4ECDC4);
      default:
        return Colors.grey.shade200;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'done':
      case 'resolved':
        return Icons.check_circle;
      case 'problem':
        return Icons.error;
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_circle;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    final selectedDayTasks = _selectedDay != null
        ? _getTasksForDay(_selectedDay!)
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.favorite, color: const Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(
              'Görev Yönetimi',
              style: TextStyle(
                color: const Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          FutureBuilder<List<ConversationPreview>>(
            future: ApiClient.getConversations(user.id),
            builder: (context, snapshot) {
              final conversations = snapshot.data ?? [];
              final unreadCount = conversations.fold<int>(
                0, (sum, conv) => sum + conv.unreadCount);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message, color: Color(0xFF4ECDC4)),
                    tooltip: 'Mesajlaşma',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationsListPage(
                            currentUserId: user.id,
                            currentUserName: user.fullName,
                          ),
                        ),
                      );
                      setState(() {}); // Refresh badge
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          FutureBuilder<List<NotificationModel>>(
            future: ref.read(apiClientProvider).getNotifications(user.id),
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              final unread = notifs.where((n) => !n.isRead).length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications,
                        color: Color(0xFF2C3E50)),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics, color: Color(0xFF4ECDC4)),
            tooltip: 'İstatistikler',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RelativeStatisticsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
            tooltip: 'Çıkış Yap',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Takvim widget
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getTasksForDay,
                    calendarFormat: _calendarFormat,
                    availableCalendarFormats: const {
                      CalendarFormat.week: 'Hafta',
                      CalendarFormat.month: 'Ay',
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      cellMargin: const EdgeInsets.all(4),
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFF4ECDC4),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: const Color(0xFF95E1D3).withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                      ),
                      markerSize: 6,
                      markersMaxCount: 1,
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                      rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                      titleTextStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                      formatButtonTextStyle: TextStyle(fontSize: 12),
                    ),
                    daysOfWeekHeight: 30,
                    rowHeight: 40,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),

                // Seçili güne ait görevler başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: const Color(0xFF4ECDC4)),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDay != null
                            ? DateFormat('dd MMMM yyyy', 'tr')
                                .format(_selectedDay!)
                            : 'Tarih seçin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${selectedDayTasks.length} görev',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Görev listesi
                Expanded(
                  child: selectedDayTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Bu gün için görev yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateTaskDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Yeni Görev Oluştur'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4ECDC4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: selectedDayTasks.length,
                          itemBuilder: (context, index) {
                            final task = selectedDayTasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTaskDialog(),
        backgroundColor: const Color(0xFF4ECDC4),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Görev'),
      ),
    );
  }

  Widget _buildTaskCard(TaskInstance task) {
    final timeStr = DateFormat('HH:mm').format(task.scheduledFor);
    final statusColor = _statusColor(task.status, severity: task.problemSeverity);
    final statusIcon = _statusIcon(task.status);
    final caregiver = _caregivers.firstWhere(
      (c) => c.id == task.assignedToId,
      orElse: () => AppUser(
        id: 0,
        fullName: 'Bilinmeyen',
        email: '',
        role: '',
        isActive: false,
      ),
    );
    
    // Template bilgisini bul
    final template = _templates.firstWhere(
      (t) => t.id == task.templateId,
      orElse: () => TaskTemplate(
        id: task.templateId,
        title: 'Bilinmeyen Görev',
        description: null,
        defaultTime: null,
        createdById: 0,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: template.taskType == 'medication' ? const Color(0xFFFF6B9D) : statusColor,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (template.taskType == 'medication' 
                        ? const Color(0xFFFF6B9D) 
                        : statusColor).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    template.taskType == 'medication' ? Icons.medication : statusIcon,
                    color: template.taskType == 'medication' ? const Color(0xFFFF6B9D) : statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (template.taskType == 'medication')
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B9D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '💊 İlaç',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.medical_services, size: 16, color: Color(0xFFFF6B9D)),
                          ],
                        ),
                      if (template.taskType == 'medication')
                        const SizedBox(height: 4),
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            caregiver.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(task.status, task.problemSeverity),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[  
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Tamamlama fotoğrafını göster
            if (task.completionPhotoUrl != null && task.completionPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF95E1D3), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    'http://127.0.0.1:8000${task.completionPhotoUrl}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.photo_camera, size: 14, color: Color(0xFF95E1D3)),
                  const SizedBox(width: 4),
                  Text(
                    'Tamamlama fotoğrafı',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? null : () => _showEditTaskDialog(task, template),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Düzenle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? Colors.grey : const Color(0xFF4ECDC4),
                      side: BorderSide(color: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? Colors.grey : const Color(0xFF4ECDC4)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? null : () => _deleteTask(task),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? Colors.grey : const Color(0xFFFF6B6B),
                      side: BorderSide(color: (task.status == 'done' || task.status == 'problem' || task.status == 'resolved') ? Colors.grey : const Color(0xFFFF6B6B)),
                    ),
                  ),
                ),
              ],
            ),
            // Tamamlanmış görevler için değerlendirme bölümü
            if (task.status == 'done') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4ECDC4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFB347), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Bakıcı Değerlendirmesi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (task.rating == null) ...[
                      const Text(
                        'Bu görev henüz değerlendirilmedi',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showRatingDialog(task),
                        icon: const Icon(Icons.star_rate, size: 18),
                        label: const Text('Değerlendir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB347),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < task.rating! ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFB347),
                            size: 20,
                          );
                        }),
                      ),
                      if (task.reviewNote != null && task.reviewNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          task.reviewNote!,
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            // Ciddi sorun otomatik olarak Bakanlığa haber verilir, ek buton gerekli değil
            if (task.problemMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: task.problemSeverity == 'ciddi' 
                                    ? 'CİDDİ SORUN: '
                                    : task.problemSeverity == 'orta'
                                      ? 'ORTA SORUN: '
                                      : task.problemSeverity == 'hafif'
                                        ? 'HAFİF SORUN: '
                                        : 'SORUN: ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: task.problemMessage),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.resolutionNote != null && task.resolutionNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.phone_in_talk, color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          const Icon(Icons.phone, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.resolutionNote!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String? severity) {
    String label;
    switch (status) {
      case 'done':
        label = 'Tamamlandı';
        break;
      case 'resolved':
        label = 'Çözüldü';
        break;
      case 'problem':
        if (severity == 'ciddi') {
          label = 'Sorunlu - CİDDİ';
        } else if (severity == 'orta') {
          label = 'Sorunlu - Orta';
        } else if (severity == 'hafif') {
          label = 'Sorunlu - Hafif';
        } else {
          label = 'Sorunlu';
        }
        break;
      case 'in_progress':
        label = 'Devam Ediyor';
        break;
      default:
        label = 'Bekliyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status, severity: severity),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    if (_caregivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sistemde bakıcı bulunmuyor')),
      );
      return;
    }

    int? selectedCaregiverId = _caregivers.first.id;
    DateTime selectedDate = _selectedDay ?? DateTime.now(); // Takvimde seçili tarih
    TimeOfDay selectedTime = TimeOfDay.now();
    String taskTitle = ''; // Görev başlığı
    String taskDescription = ''; // Görev açıklaması
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Görev Oluştur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bakıcı seçimi
                DropdownButtonFormField<int>(
                  value: selectedCaregiverId,
                  decoration: const InputDecoration(
                    labelText: 'Bakıcı Seç *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _caregivers.map((caregiver) {
                    return DropdownMenuItem(
                      value: caregiver.id,
                      child: Text(caregiver.fullName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedCaregiverId = val);
                  },
                ),
                const SizedBox(height: 16),
                
                // Görev başlığı
                TextField(
                  controller: titleController,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Görev Başlığı *',
                    border: OutlineInputBorder(),
                    hintText: 'İlaç verme, Yemek hazırlama, vb.',
                    prefixIcon: Icon(Icons.title),
                  ),
                  onChanged: (val) {
                    taskTitle = val;
                  },
                ),
                const SizedBox(height: 16),
                
                // Görev açıklaması
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Görev Açıklaması',
                    border: OutlineInputBorder(),
                    hintText: 'Detaylı açıklama (opsiyonel)',
                    prefixIcon: Icon(Icons.description),
                  ),
                  onChanged: (val) {
                    taskDescription = val;
                  },
                ),
                const SizedBox(height: 16),
                
                // Tarih (takvimden seçili - sadece gösterim)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4ECDC4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF4ECDC4)),
                      const SizedBox(width: 12),
                      Text(
                        'Tarih: ${DateFormat('dd MMMM yyyy', 'tr').format(selectedDate)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Saat seçimi
                ListTile(
                  title: Text(
                    'Saat: ${selectedTime.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: const Icon(Icons.access_time, color: Color(0xFF4ECDC4)),
                  trailing: const Icon(Icons.edit),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF4ECDC4)),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validasyonlar
                if (selectedCaregiverId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bakıcı seçmelisiniz')),
                  );
                  return;
                }
                
                if (taskDescription.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Görev açıklaması girmelisiniz')),
                  );
                  return;
                }

                final scheduledFor = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                // Geçmiş tarih kontrolü
                final now = DateTime.now();
                if (scheduledFor.isBefore(now)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Geçmiş tarihe görev atanamaz'),
                      backgroundColor: Color(0xFFFF6B6B),
                    ),
                  );
                  return;
                }

                try {
                  final user = ref.read(currentUserProvider)!;
                  final api = ref.read(apiClientProvider);
                  
                  // Görev için şablon oluştur (her görev için dummy template)
                  final template = await api.createTaskTemplate(
                    title: taskTitle.trim(),
                    description: null,
                    createdById: user.id,
                  );
                  
                  // Görev örneği oluştur - kendi başlık ve açıklaması ile
                  await api.createTaskInstance(
                    templateId: template.id,
                    title: taskTitle.trim(),
                    description: taskDescription.trim().isNotEmpty ? taskDescription.trim() : null,
                    createdById: user.id,
                    assignedToId: selectedCaregiverId!,
                    scheduledFor: scheduledFor,
                  );

                  Navigator.pop(context);
                  _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Görev başarıyla oluşturuldu'),
                        backgroundColor: Color(0xFF95E1D3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Color(0xFFFF6B6B),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
              ),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(TaskInstance task, TaskTemplate template) async {
    String taskDescription = template.description ?? template.title;
    DateTime selectedDate = task.scheduledFor;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(task.scheduledFor);
    final descriptionController = TextEditingController(text: taskDescription);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Görevi Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Görev açıklaması
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Görev Açıklaması *',
                    border: OutlineInputBorder(),
                    hintText: 'İlaç verme, yemek hazırlama, temizlik vb.',
                    prefixIcon: Icon(Icons.description),
                  ),
                  onChanged: (val) {
                    taskDescription = val;
                  },
                ),
                const SizedBox(height: 16),
                
                // Tarih
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4ECDC4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF4ECDC4)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tarih: ${DateFormat('dd MMMM yyyy', 'tr').format(selectedDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Saat seçimi
                ListTile(
                  title: Text(
                    'Saat: ${selectedTime.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: const Icon(Icons.access_time, color: Color(0xFF4ECDC4)),
                  trailing: const Icon(Icons.edit),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF4ECDC4)),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (taskDescription.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Görev açıklaması girmelisiniz')),
                  );
                  return;
                }

                final scheduledFor = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                // Geçmiş tarih kontrolü
                final now = DateTime.now();
                if (scheduledFor.isBefore(now)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Geçmiş tarihe görev atanamaz'),
                      backgroundColor: Color(0xFFFF6B6B),
                    ),
                  );
                  return;
                }

                try {
                  final user = ref.read(currentUserProvider)!;
                  final api = ref.read(apiClientProvider);
                  
                  // Şablonu güncelle
                  await api.updateTaskTemplate(
                    templateId: template.id,
                    title: taskDescription.trim().length > 50 
                        ? taskDescription.trim().substring(0, 50) 
                        : taskDescription.trim(),
                    description: taskDescription.trim(),
                  );
                  
                  // Görev zamanını güncelle
                  await api.updateTaskTime(
                    taskId: task.id,
                    newTime: scheduledFor.toIso8601String(),
                  );

                  Navigator.pop(context);
                  _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Görev güncellendi'),
                        backgroundColor: Color(0xFF95E1D3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Color(0xFFFF6B6B),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
              ),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask(TaskInstance task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: const Text('Bu görevi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = ref.read(currentUserProvider)!;
        final api = ref.read(apiClientProvider);
        await api.deleteTask(task.id, user.id);
        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görev silindi'),
              backgroundColor: Color(0xFF95E1D3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }

  Future<void> _showRatingDialog(TaskInstance task) async {
    int selectedRating = 5;
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFB347)),
              SizedBox(width: 8),
              Text('Bakıcıyı Değerlendirin'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görev: ${task.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Puan:'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          selectedRating = index + 1;
                        });
                      },
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFB347),
                        size: 40,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Değerlendirme Notu (opsiyonel)',
                    border: OutlineInputBorder(),
                    hintText: 'Bakıcının performansı hakkında notunuz...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
              ),
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final user = ref.read(currentUserProvider)!;
        await ApiClient.rateTask(
          taskId: task.id,
          userId: user.id,
          rating: selectedRating,
          reviewNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⭐ Değerlendirme kaydedildi'),
              backgroundColor: Color(0xFFFFB347),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }

  // _notifyAuthority fonksiyonu artık gerekli değil - otomatik yapılıyor
}
