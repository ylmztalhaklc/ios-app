// Bu dosya: Backend API ile iletişim kuran tüm fonksiyonları içerir.
// - Kullanıcı kimlik doğrulama (login, register)
// - Görev yönetimi (oluşturma, güncelleme, silme, listeleme)
// - Bildirim işlemleri (getirme, okundu işaretleme)
// - HTTP istekleri ile JSON veri alışverişi

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  // Backend API'nin temel URL'i - localhost üzerinde port 8000
  static const String baseUrl = 'http://127.0.0.1:8000';

  // ---------- Kimlik Doğrulama (Authentication) ----------

  // Kullanıcı girişi - email ve şifre ile giriş yapar, AppUser nesnesi döner
  Future<AppUser> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return AppUser.fromJson(data['user']);
    } else {
      throw Exception('Giriş başarısız: ${res.body}');
    }
  }

  // Yeni kullanıcı kaydı - tam ad, email, şifre ve rol bilgisi ile kayıt oluşturur
  Future<void> register(
    String fullName,
    String email,
    String password,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Kayıt başarısız: ${res.body}');
    }
  }

  // ---------- Kullanıcı İşlemleri ----------

  // ID'ye göre kullanıcı bilgisi getirir
  Future<AppUser> getUser(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return AppUser.fromJson(data);
    } else {
      throw Exception('Kullanıcı alınamadı: ${res.body}');
    }
  }

  // ---------- Görev İşlemleri ----------

  // Bakıcıya atanmış görevleri getirir (opsiyonel durum filtresi ile)
  Future<List<TaskInstance>> getAssignedTasks(int userId,
      {String? status}) async {
    String urlStr = '$baseUrl/tasks/assigned/$userId';
    if (status != null) {
      urlStr += '?status=$status';
    }
    final url = Uri.parse(urlStr);
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => TaskInstance.fromJson(e)).toList();
    } else {
      throw Exception('Görevler alınamadı: ${res.body}');
    }
  }

  // Hasta yakınının oluşturduğu görevleri getirir
  Future<List<TaskInstance>> getCreatedTasks(int userId,
      {String? status}) async {
    String urlStr = '$baseUrl/tasks/created/$userId';
    if (status != null) {
      urlStr += '?status=$status';
    }
    final url = Uri.parse(urlStr);
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => TaskInstance.fromJson(e)).toList();
    } else {
      throw Exception('Görevler alınamadı (created): ${res.body}');
    }
  }

  // ---------- Görev Şablonu İşlemleri ----------

  // Yeni görev şablonu oluşturur (başlık, açıklama, oluşturan kişi)
  Future<TaskTemplate> createTaskTemplate({
    required String title,
    required String? description,
    required int createdById,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/templates');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'default_time': null,
        'created_by_id': createdById,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return TaskTemplate.fromJson(data);
    } else {
      throw Exception('Şablon oluşturulamadı: ${res.body}');
    }
  }

  // Kullanıcının tüm görev şablonlarını getirir
  Future<List<TaskTemplate>> getTaskTemplates(int userId) async {
    final url = Uri.parse('$baseUrl/tasks/templates/user/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => TaskTemplate.fromJson(e)).toList();
    } else {
      throw Exception('Şablonlar alınamadı: ${res.body}');
    }
  }

  // Görev şablonu detaylarını getirir
  Future<TaskTemplate> getTaskTemplate(int templateId) async {
    final url = Uri.parse('$baseUrl/tasks/templates/$templateId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return TaskTemplate.fromJson(data);
    } else {
      throw Exception('Şablon alınamadı: ${res.body}');
    }
  }

  // Mevcut görev şablonunu günceller
  Future<void> updateTaskTemplate({
    required int templateId,
    required String title,
    required String? description,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/templates/$templateId');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'default_time': null,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Şablon güncellenemedi: ${res.body}');
    }
  }

  // ---------- Görev Örnekleri (Task Instance) ----------

  // Yeni görev örneği oluşturur (şablondan, atanan kişiye, belirli zamanda)
  Future<void> createTaskInstance({
    required int templateId,
    required String title,
    String? description,
    required int createdById, // created_by_id
    required int assignedToId,
    required DateTime scheduledFor,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/instances');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'template_id': templateId,
        'title': title,
        'description': description,
        'created_by_id': createdById,
        'assigned_to_id': assignedToId,
        'scheduled_for': scheduledFor.toIso8601String(),
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Görev oluşturulamadı: ${res.body}');
    }
  }

  // Görevin zamanlamasını günceller
  Future<void> updateTaskTime({
    required int taskId,
    required String newTime,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/instances/$taskId');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduled_for': newTime,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Görev zamanı güncellenemedi: ${res.body}');
    }
  }

  // Görevi siler (kullanıcı ID'si ile yetkilendirme)
  Future<void> deleteTask(int taskId, int userId) async {
    final url =
        Uri.parse('$baseUrl/tasks/instances/$taskId?user_id=$userId');
    final res = await http.delete(url);

    if (res.statusCode != 200) {
      throw Exception('Görev silinemedi: ${res.body}');
    }
  }

  // Görevin durumunu günceller (pending, done, problem, resolved)
  // Problem durumunda opsiyonel mesaj ve severity eklenebilir
  Future<void> updateTaskStatus({
    required int taskId,
    required int userId,
    required String status,
    String? problemMessage,
    String? problemSeverity,
    String? resolutionNote,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/instances/status');
    final res = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'task_id': taskId,
        'user_id': userId,
        'status': status,
        'problem_message': problemMessage,
        'problem_severity': problemSeverity,
        'resolution_note': resolutionNote,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Görev durumu güncellenemedi: ${res.body}');
    }
  }

  // ---------- Bildirimler ----------

  // Kullanıcının tüm bildirimlerini getirir
  Future<List<NotificationModel>> getNotifications(int userId) async {
    final url = Uri.parse('$baseUrl/notifications/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    } else {
      throw Exception('Bildirimler alınamadı: ${res.body}');
    }
  }

  // Tek bir bildirimi okundu olarak işaretler
  Future<void> markNotificationRead(int notificationId) async {
    final url = Uri.parse('$baseUrl/notifications/$notificationId/read');
    final res = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Bildirim okundu işaretlenemedi: ${res.body}');
    }
  }

  // Kullanıcının tüm bildirimlerini okundu olarak işaretler
  Future<void> markAllNotificationsRead(int userId) async {
    final url = Uri.parse('$baseUrl/notifications/$userId/read_all');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Tüm bildirimler okundu işaretlenemedi: ${res.body}');
    }
  }

  // ---------- Bakıcı Listesi ----------

  // Sistemdeki tüm hasta bakıcılarının listesini getirir
  Future<List<AppUser>> getCaregivers() async {
    try {
      final url = Uri.parse('$baseUrl/users/caregivers');
      print('Bakıcı listesi çekiliyor: $url');
      final res = await http.get(url);
      print('Bakıcı listesi yanıtı: ${res.statusCode}');

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        print('Bakıcı sayısı: ${list.length}');
        return list.map((e) => AppUser.fromJson(e)).toList();
      } else {
        print('Bakıcı listesi hatası: ${res.body}');
        throw Exception('Bakıcı listesi alınamadı: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Bakıcı listesi exception: $e');
      rethrow;
    }
  }

  // Sistemdeki tüm hasta yakınlarının listesini getirir
  Future<List<AppUser>> getRelatives() async {
    try {
      final url = Uri.parse('$baseUrl/users/relatives');
      print('Hasta yakını listesi çekiliyor: $url');
      final res = await http.get(url);
      print('Hasta yakını listesi yanıtı: ${res.statusCode}');

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        print('Hasta yakını sayısı: ${list.length}');
        return list.map((e) => AppUser.fromJson(e)).toList();
      } else {
        print('Hasta yakını listesi hatası: ${res.body}');
        throw Exception('Hasta yakını listesi alınamadı: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Hasta yakını listesi exception: $e');
      rethrow;
    }
  }

  // ---------- Mesajlaşma İşlemleri ----------

  // Yeni mesaj gönderir
  static Future<Message> sendMessage({
    required int senderId,
    required int receiverId,
    String? content,
  }) async {
    final url = Uri.parse('$baseUrl/messages/send');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Message.fromJson(data);
    } else {
      throw Exception('Mesaj gönderilemedi: ${res.body}');
    }
  }

  // İki kullanıcı arasındaki konuşmayı getirir
  static Future<List<Message>> getConversation(
    int currentUserId,
    int otherUserId,
  ) async {
    final url = Uri.parse(
        '$baseUrl/messages/conversation/$otherUserId?current_user_id=$currentUserId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Message.fromJson(e)).toList();
    } else {
      throw Exception('Konuşma getirilemedi: ${res.body}');
    }
  }

  // Kullanıcının tüm konuşmalarını listeler
  static Future<List<ConversationPreview>> getConversations(
      int userId) async {
    final url = Uri.parse('$baseUrl/messages/conversations/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => ConversationPreview.fromJson(e)).toList();
    } else {
      throw Exception('Konuşma listesi alınamadı: ${res.body}');
    }
  }

  // Mesaj düzenler
  static Future<Message> updateMessage(
    int messageId,
    int currentUserId,
    String content,
  ) async {
    final url = Uri.parse(
        '$baseUrl/messages/$messageId?current_user_id=$currentUserId');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Message.fromJson(data);
    } else {
      throw Exception('Mesaj düzenlenemedi: ${res.body}');
    }
  }

  // Mesaj siler
  static Future<void> deleteMessage(int messageId, int currentUserId) async {
    final url = Uri.parse(
        '$baseUrl/messages/$messageId?current_user_id=$currentUserId');
    final res = await http.delete(url);

    if (res.statusCode != 200) {
      throw Exception('Mesaj silinemedi: ${res.body}');
    }
  }

  // Mesaja dosya eki yükler
  static Future<void> uploadAttachment({
    required int messageId,
    required int userId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse(
          '$baseUrl/messages/upload/$messageId').replace(
            queryParameters: {'current_user_id': userId.toString()}
          );
      print('Dosya yükleniyor: $url');

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print('Dosya yükleme yanıtı: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('Dosya yükleme hatası: ${response.body}');
        throw Exception('Dosya yüklenemedi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Dosya yükleme exception: $e');
      rethrow;
    }
  }

  // Mesaj ekini siler
  static Future<void> deleteAttachment(
      int attachmentId, int currentUserId) async {
    final url = Uri.parse(
        '$baseUrl/messages/attachment/$attachmentId?current_user_id=$currentUserId');
    final res = await http.delete(url);

    if (res.statusCode != 200) {
      throw Exception('Ek silinemedi: ${res.body}');
    }
  }

  // ---------- İstatistik İşlemleri ----------

  // Hasta yakını için genel istatistik özeti
  static Future<Map<String, dynamic>> getRelativeOverview(int userId) async {
    final url = Uri.parse('$baseUrl/statistics/relative/$userId/overview');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('İstatistik alınamadı: ${res.body}');
    }
  }

  // Bakıcı performans analizi
  static Future<List<dynamic>> getCaregiverPerformance(int userId) async {
    final url = Uri.parse('$baseUrl/statistics/relative/$userId/caregiver-performance');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Performans verileri alınamadı: ${res.body}');
    }
  }

  // Sorun trendleri analizi
  static Future<Map<String, dynamic>> getProblemTrends(int userId, {int days = 30}) async {
    final url = Uri.parse('$baseUrl/statistics/relative/$userId/problem-trends?days=$days');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Sorun trendleri alınamadı: ${res.body}');
    }
  }

  // Bakıcı için genel istatistik özeti
  static Future<Map<String, dynamic>> getCaregiverOverview(int userId) async {
    final url = Uri.parse('$baseUrl/statistics/caregiver/$userId/overview');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('İstatistik alınamadı: ${res.body}');
    }
  }

  // Bakıcı için haftalık özet
  static Future<List<dynamic>> getCaregiverWeeklySummary(int userId) async {
    final url = Uri.parse('$baseUrl/statistics/caregiver/$userId/weekly-summary');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Haftalık özet alınamadı: ${res.body}');
    }
  }

  // ---------- Dosya Yükleme İşlemleri ----------

  // Görev tamamlama fotoğrafı yükler
  static Future<String> uploadTaskPhoto({
    required int taskId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/uploads/task-photo/$taskId');
      print('Görev fotoğrafı yükleniyor: $url');

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print('Fotoğraf yükleme yanıtı: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('Fotoğraf yükleme hatası: ${response.body}');
        throw Exception('Fotoğraf yüklenemedi: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['photo_url'] as String;
    } catch (e) {
      print('Fotoğraf yükleme exception: $e');
      rethrow;
    }
  }

  // Görev fotoğrafını siler
  static Future<void> deleteTaskPhoto(int taskId) async {
    final url = Uri.parse('$baseUrl/uploads/task-photo/$taskId');
    final res = await http.delete(url);

    if (res.statusCode != 200) {
      throw Exception('Fotoğraf silinemedi: ${res.body}');
    }
  }

  // ---------- Değerlendirme İşlemleri ----------

  // Görevi değerlendir (sadece hasta yakını)
  static Future<void> rateTask({
    required int taskId,
    required int userId,
    required int rating,
    String? reviewNote,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/instances/$taskId/rating').replace(
      queryParameters: {
        'current_user_id': userId.toString(),
        'rating': rating.toString(),
        if (reviewNote != null && reviewNote.isNotEmpty)
          'review_note': reviewNote,
      },
    );
    
    final res = await http.patch(url);

    if (res.statusCode != 200) {
      throw Exception('Değerlendirme yapılamadı: ${res.body}');
    }
  }
}
