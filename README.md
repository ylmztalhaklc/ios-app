# 🏥 HealthCare - Hasta Bakım Görev Yönetim Sistemi

Hasta yakınları ve hasta bakıcıları arasında görev takibi, iletişim ve problem raporlama için geliştirilmiş kapsamlı sağlık yönetim platformu.

## 📋 Özellikler

### 👥 Kullanıcı Rolleri
- **Hasta Yakını (Relative)**: Görev atar, ilerleyişi takip eder, sorunları görüntüler
- **Hasta Bakıcı (Caregiver)**: Görevleri tamamlar, problem bildirir, fotoğraf yükler

### ✨ Ana Özellikler
- 📅 **Görev Yönetimi**: Görev şablonları oluşturma, atama ve takip
- 🔔 **Bildirimler**: Otomatik bildirim sistemi
- 💬 **Canlı Sohbet**: Kullanıcılar arası mesajlaşma (emoji ve dosya eki desteği)
- 📸 **Fotoğraf Belgesi**: Görev tamamlama fotoğrafı yükleme
- ⭐ **Değerlendirme Sistemi**: Tamamlanan görevleri 1-5 yıldız ile derecelendirme
- 💊 **İlaç Takibi**: Özel ilaç görevi tipi (görsel olarak farklılaştırılmış)
- 🚨 **Problem Yönetimi**: 3 seviyeli (hafif/orta/ciddi) problem bildirimi
- 📊 **İstatistikler**: Görev tamamlama oranları ve performans grafikleri
- 🏥 **Kritik Sorun Bildirimi**: Ciddi sorunlar için otomatik Bakanlık bildirimi

## 🛠️ Teknoloji Stack'i

### Backend
- **Framework**: FastAPI 0.115.6
- **Veritabanı**: SQLite (SQLAlchemy ORM 2.0.36)
- **Doğrulama**: Pydantic 2.10.5
- **Server**: Uvicorn 0.34.0
- **Dosya İşleme**: python-multipart, aiofiles

### Frontend
- **Framework**: Flutter 3.9.2+
- **State Management**: flutter_riverpod 2.6.1
- **HTTP İstemcisi**: http 1.6.0
- **UI Bileşenleri**:
  - table_calendar 3.1.3 (Takvim görünümü)
  - image_picker 1.2.1 (Fotoğraf seçme)
  - emoji_picker_flutter 3.1.0 (Emoji picker)
  - cached_network_image 3.4.1 (Resim önbellekleme)
  - shared_preferences 2.3.3 (Yerel veri saklama)

## 📁 Proje Yapısı

```
HealthCare/
├── backend/
│   ├── venv/                    # Python sanal ortamı
│   │   └── app/
│   │       ├── main.py          # FastAPI ana uygulama
│   │       ├── database.py      # Veritabanı bağlantısı
│   │       ├── models.py        # SQLAlchemy modelleri
│   │       ├── schemas.py       # Pydantic şemaları
│   │       ├── crud.py          # Veritabanı işlemleri
│   │       └── routers/         # API endpoint'leri
│   │           ├── auth.py      # Kimlik doğrulama
│   │           ├── tasks.py     # Görev yönetimi
│   │           ├── messages.py  # Mesajlaşma
│   │           ├── notifications.py
│   │           ├── statistics.py
│   │           └── uploads.py   # Fotoğraf yükleme
│   ├── uploads/                 # Yüklenen görev fotoğrafları
│   ├── healthcare.db            # SQLite veritabanı
│   └── requirements.txt
│
└── frontend/
    └── healthcare_app/
        ├── lib/
        │   ├── main.dart        # Uygulama giriş noktası
        │   ├── core/
        │   │   ├── api_client.dart  # API HTTP istemcisi
        │   │   └── models.dart      # Dart veri modelleri
        │   └── pages/           # UI sayfaları
        │       ├── login_page.dart
        │       ├── caregiver_home_page.dart
        │       ├── caregiver_tasks_page.dart
        │       ├── relative_home_page.dart
        │       ├── relative_tasks_page.dart
        │       ├── chat_page.dart
        │       ├── conversations_list_page.dart
        │       └── notifications_page.dart
        ├── pubspec.yaml         # Flutter bağımlılıkları
        └── analysis_options.yaml
```

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler
- Python 3.8+
- Flutter 3.9.2+
- Dart SDK 3.9.2+

### Backend Kurulumu

1. Backend dizinine gidin:
```bash
cd backend
```

2. Python sanal ortamını oluşturun ve etkinleştirin:
```bash
python -m venv venv
.\venv\Scripts\Activate.ps1  # Windows PowerShell
# veya
source venv/bin/activate  # Linux/Mac
```

3. Gerekli paketleri yükleyin:
```bash
pip install -r requirements.txt
```

4. Veritabanı dosyasının doğru konumda olduğundan emin olun:
- `healthcare.db` dosyası `backend/` dizininde olmalıdır
- İlk çalıştırmada otomatik oluşturulacaktır

5. Backend sunucusunu başlatın:
```bash
cd venv
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Backend şimdi http://127.0.0.1:8000 adresinde çalışıyor.
- API Dokümantasyonu: http://127.0.0.1:8000/docs (Swagger UI)

### Frontend Kurulumu

1. Frontend dizinine gidin:
```bash
cd frontend/healthcare_app
```

2. Flutter bağımlılıklarını yükleyin:
```bash
flutter pub get
```

3. Uygulamayı çalıştırın:

**Chrome (Web) için:**
```bash
flutter run -d chrome
```

**Android için:**
```bash
flutter run -d <device_id>
```

**iOS için (Mac gerekli):**
```bash
flutter run -d <device_id>
```

### Test Kullanıcıları

Giriş yapmak için test kullanıcı bilgileri:

**Hasta Yakını:**
- Email: `relative@example.com`
- Şifre: Herhangi bir şey

**Hasta Bakıcı:**
- Email: `caregiver@example.com`
- Şifre: Herhangi bir şey

> Not: Şu an için basit email kontrolü yapılmaktadır. Production'da güvenli kimlik doğrulama implementasyonu gereklidir.

## 🎯 Kullanım Senaryoları

### 1. Görev Oluşturma ve Atama (Hasta Yakını)
1. Giriş yapın
2. "Görev Ekle" butonuna tıklayın
3. Görev detaylarını girin (başlık, açıklama, saat, günler)
4. İlaç görevi için "İlaç Görevi" seçeneğini işaretleyin
5. Kaydedin

### 2. Görev Tamamlama (Hasta Bakıcı)
1. Atanmış görevleri görüntüleyin
2. "Başla" butonuna tıklayın
3. Görevi tamamladıktan sonra "Tamamla" butonuna basın
4. İsteğe bağlı olarak fotoğraf yükleyin veya fotoğrafsız tamamlayın

### 3. Problem Bildirme (Hasta Bakıcı)
1. Görev detaylarında "Sorun Bildir" butonuna tıklayın
2. Sorun açıklamasını yazın
3. Ciddiyet seviyesini seçin (hafif/orta/ciddi)
4. Gönderin
- **Ciddi sorunlar** otomatik olarak hasta yakınına bildirim gönderir ve "Bakanlığa haber verildi" mesajı gösterilir

### 4. Görev Değerlendirme (Hasta Yakını)
1. Tamamlanmış görevleri görüntüleyin
2. "Değerlendir" butonuna tıklayın
3. 1-5 yıldız verin
4. İsteğe bağlı yorum ekleyin

## 📊 Veritabanı Şeması

### Ana Tablolar
- **users**: Kullanıcı bilgileri (hasta_yakini, hasta_bakici)
- **task_template**: Görev şablonları (tekrarlayan görevler için)
- **task_instance**: Görev örnekleri (belirli tarihler için atanmış görevler)
- **notifications**: Bildirimler
- **messages**: Mesajlar (bire bir sohbet)
- **conversation**: Konuşma meta verisi

### Önemli Kolonlar
- `task_type`: 'normal' veya 'medication' (ilaç)
- `completion_photo_url`: Tamamlama fotoğrafı dosya yolu
- `rating`: Görev değerlendirmesi (1-5)
- `review_note`: Değerlendirme yorumu
- `critical_notified`: Kritik problem bildirimi gönderildi mi?
- `severity`: Problem ciddiyeti (hafif/orta/ciddi)

## 🔒 Güvenlik Notları

**⚠️ Önemli**: Bu proje development aşamasındadır. Production kullanımı için:
- JWT token bazlı kimlik doğrulama ekleyin
- Şifreleri hash'leyin (bcrypt, argon2)
- CORS ayarlarını spesifik domain'lere sınırlayın
- Rate limiting ekleyin
- Input validation güçlendirin
- HTTPS kullanın
- SQL injection koruması güncelleyin (SQLAlchemy ORM kullanımı devam etsin)

## 🐛 Bilinen Sorunlar ve Geliştirme Fırsatları

- [ ] Tekrarlayan görevler UI'sı (backend hazır, frontend yok)
- [ ] Hatırlatıcı bildirimleri (görev saatinden 15-30 dk önce)
- [ ] Çoklu aile üyesi desteği
- [ ] Hasta bakıcı için acil durum butonu
- [ ] Maliyet takibi (ödemeler, masraflar)
- [ ] Vardiya yönetimi (çoklu bakıcı)
- [ ] Sesli mesaj desteği
- [ ] Mesaj dosya eki UI'sı (backend hazır)

## 📝 Lisans

Bu proje eğitim ve portföy amaçlı geliştirilmiştir.

## 👨‍💻 Geliştirici

Talha Kılıç
- GitHub: [ylmztalhaklc](https://github.com/ylmztalhaklc)

## 📞 İletişim

Sorular veya öneriler için GitHub Issues kullanabilirsiniz.
