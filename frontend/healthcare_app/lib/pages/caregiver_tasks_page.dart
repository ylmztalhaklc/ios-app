import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../main.dart';
import 'notifications_page.dart';
import 'conversations_list_page.dart';
import 'login_page.dart';
import 'caregiver_statistics_page.dart';

class CaregiverTasksPage extends ConsumerStatefulWidget {
  const CaregiverTasksPage({super.key});

  @override
  ConsumerState<CaregiverTasksPage> createState() =>
      _CaregiverTasksPageState();
}

class _CaregiverTasksPageState extends ConsumerState<CaregiverTasksPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<DateTime, List<TaskInstance>> _tasksByDate = {};
  List<TaskInstance> _allTasks = [];
  List<TaskTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final tasks = await api.getAssignedTasks(user.id);
      
      // Tüm template'leri yükle
      Set<int> templateIds = tasks.map((t) => t.templateId).toSet();
      List<TaskTemplate> templates = [];
      for (int templateId in templateIds) {
        try {
          final template = await api.getTaskTemplate(templateId);
          templates.add(template);
        } catch (e) {
          print('Template yüklenemedi: $templateId');
        }
      }
      
      setState(() {
        _allTasks = tasks;
        _templates = templates;
        _tasksByDate = _groupTasksByDate(tasks);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'hafif':
        return Colors.green;
      case 'orta':
        return Colors.orange;
      case 'ciddi':
        return Colors.red;
      default:
        return const Color(0xFFFF6B6B);
    }
  }

  String _getSeverityText(String? severity) {
    switch (severity) {
      case 'hafif':
        return 'HAFİF SORUN';
      case 'orta':
        return 'ORTA SORUN';
      case 'ciddi':
        return '⚠️ CİDDİ SORUN';
      default:
        return 'SORUN';
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
            Icon(Icons.medical_services, color: const Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text(
              'Görevlerim',
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
            tooltip: 'İstatistiklerim',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CaregiverStatisticsPage(),
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

                // Seçili güne ait görevler
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
                              Icon(Icons.task_alt,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Bu gün için görev yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
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
    );
  }

  Widget _buildTaskCard(TaskInstance task) {
    final timeStr = DateFormat('HH:mm').format(task.scheduledFor);
    final statusColor = _statusColor(task.status, severity: task.problemSeverity);
    final statusIcon = _statusIcon(task.status);
    
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
                _buildStatusChip(task.status, severity: task.problemSeverity),
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
                        Icon(Icons.warning, color: _getSeverityColor(task.problemSeverity), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: _getSeverityColor(task.problemSeverity),
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '${_getSeverityText(task.problemSeverity)}: ',
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
                    // Resolution note göster (ciddi sorunlar için özel)
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
            const SizedBox(height: 12),
            // Ciddi sorunlar için hiçbir buton gösterme (etkileşime kapalı)
            if (task.problemSeverity == 'ciddi' && task.status == 'problem') ...[
              // Ciddi sorun bildirildiyse butonlar gösterilmez
              const SizedBox.shrink(),
            ] else if (task.status == 'problem') ...[
              // Ciddi olmayan sorunlar için Sorun Çözüldü butonu göster
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  'Sorun Çözüldü',
                  Icons.check_circle,
                  const Color(0xFF95E1D3),
                  true,
                  () => _showResolveProblemDialog(task),
                ),
              ),
            ] else if (task.status != 'problem' && task.status != 'resolved') ...[
              // Normal durum - tüm butonlar
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Başladım',
                      Icons.play_arrow,
                      const Color(0xFF4ECDC4),
                      task.status == 'pending',
                      () => _updateStatus(task, 'in_progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      'Tamamlandı',
                      Icons.check,
                      const Color(0xFF95E1D3),
                      task.status == 'in_progress',
                      () => _updateStatus(task, 'done'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      'Sorun Var',
                      Icons.error_outline,
                      const Color(0xFFFF6B6B),
                      task.status != 'done' && task.status != 'resolved',
                      () => _showProblemDialog(task),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, {String? severity}) {
    String label;
    switch (status) {
      case 'done':
        label = 'Tamamlandı';
        break;
      case 'resolved':
        label = 'Çözüldü';
        break;
      case 'problem':
        label = 'Sorunlu';
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

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    bool enabled,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey[300],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(TaskInstance task, String newStatus) async {
    // Eğer done durumuna geçiliyorsa fotoğraf seçme dialog'u göster
    if (newStatus == 'done') {
      final photoPath = await _showPhotoDialog();
      if (photoPath != null) {
        await _updateStatusWithPhoto(task, newStatus, photoPath);
      }
      return;
    }
    
    try {
      final user = ref.read(currentUserProvider)!;
      final api = ref.read(apiClientProvider);
      await api.updateTaskStatus(
        taskId: task.id,
        userId: user.id,
        status: newStatus,
      );
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görev durumu güncellendi'),
            backgroundColor: const Color(0xFF95E1D3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<String?> _showPhotoDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📸 Görev Tamamlandı'),
        content: const Text(
          'Görevin tamamlandığını fotoğrafla belgelemek ister misiniz?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Fotoğrafsız Tamamla'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1920,
                maxHeight: 1080,
                imageQuality: 85,
              );
              if (image != null && context.mounted) {
                Navigator.pop(context, image.path);
              }
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Fotoğraf Seç'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatusWithPhoto(
    TaskInstance task,
    String newStatus,
    String photoPath,
  ) async {
    try {
      final user = ref.read(currentUserProvider)!;
      final api = ref.read(apiClientProvider);
      
      // Önce durumu güncelle
      await api.updateTaskStatus(
        taskId: task.id,
        userId: user.id,
        status: newStatus,
      );
      
      // Eğer fotoğraf seçildiyse yükle
      if (photoPath.isNotEmpty) {
        await ApiClient.uploadTaskPhoto(
          taskId: task.id,
          filePath: photoPath,
        );
      }
      
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(photoPath.isNotEmpty 
              ? '✅ Görev tamamlandı ve fotoğraf yüklendi' 
              : '✅ Görev tamamlandı'),
            backgroundColor: const Color(0xFF95E1D3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _showProblemDialog(TaskInstance task) async {
    final controller = TextEditingController();
    String? selectedSeverity;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sorun Bildir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Sorun açıklaması *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sorun Derecesi:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Hafif'),
                      selected: selectedSeverity == 'hafif',
                      onSelected: (selected) {
                        setState(() => selectedSeverity = selected ? 'hafif' : null);
                      },
                      selectedColor: Colors.green.shade200,
                    ),
                    ChoiceChip(
                      label: const Text('Orta'),
                      selected: selectedSeverity == 'orta',
                      onSelected: (selected) {
                        setState(() => selectedSeverity = selected ? 'orta' : null);
                      },
                      selectedColor: Colors.orange.shade200,
                    ),
                    ChoiceChip(
                      label: const Text('Ciddi'),
                      selected: selectedSeverity == 'ciddi',
                      onSelected: (selected) {
                        setState(() => selectedSeverity = selected ? 'ciddi' : null);
                      },
                      selectedColor: Colors.red.shade300,
                    ),
                  ],
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
              onPressed: () {
                if (controller.text.isEmpty || selectedSeverity == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'message': controller.text,
                  'severity': selectedSeverity!,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
              ),
              child: const Text('Bildir'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final user = ref.read(currentUserProvider)!;
        final api = ref.read(apiClientProvider);
        await api.updateTaskStatus(
          taskId: task.id,
          userId: user.id,
          status: 'problem',
          problemMessage: result['message'],
          problemSeverity: result['severity'],
        );
        _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sorun bildirildi'),
              backgroundColor: Color(0xFFFF6B6B),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _showResolveProblemDialog(TaskInstance task) async {
    final controller = TextEditingController();
    
    // Ciddi sorunlar için otomatik metin
    if (task.problemSeverity == 'ciddi') {
      controller.text = 'Bakanlığa haber verildi. Gerekli müdahale başlatıldı.';
    }
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sorun Çözüldü'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.problemSeverity == 'ciddi') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ciddi sorun: Bakanlığa bildirim otomatik oluşturuldu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: task.problemSeverity == 'ciddi' 
                      ? 'Ek Notlar (opsiyonel)' 
                      : 'Nasıl çözüldü? *',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: task.problemSeverity != 'ciddi',
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
            onPressed: () {
              if (task.problemSeverity != 'ciddi' && controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen çözüm açıklaması girin')),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF95E1D3),
            ),
            child: const Text('Çözüldü Olarak İşaretle'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final user = ref.read(currentUserProvider)!;
        final api = ref.read(apiClientProvider);
        await api.updateTaskStatus(
          taskId: task.id,
          userId: user.id,
          status: 'resolved',
          resolutionNote: result,
        );
        _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sorun çözüldü olarak işaretlendi'),
              backgroundColor: Color(0xFF95E1D3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }
}
