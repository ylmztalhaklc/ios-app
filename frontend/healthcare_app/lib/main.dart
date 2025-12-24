// Bu dosya: Flutter uygulamasının giriş noktası ve temel yapılandırması.
// - Riverpod ile state management kurulumu
// - Ana tema ayarları (Material 3, Teal renk)
// - Başlangıç sayfası olarak LoginPage gösterimi

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/models.dart';
import 'pages/login_page.dart';

// API istemcisi için global provider - tüm uygulama boyunca aynı instance kullanılır
final apiClientProvider = Provider((ref) => ApiClient());

// Giriş yapmış kullanıcı bilgisini tutan provider - null ise kullanıcı giriş yapmamış
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

void main() async {
  // Flutter binding'i başlat
  WidgetsFlutterBinding.ensureInitialized();
  
  // Türkçe tarih formatlamasını başlat
  await initializeDateFormatting('tr_TR', null);
  
  // Uygulamayı ProviderScope ile sarmalayarak Riverpod'u aktif hale getir
  runApp(const ProviderScope(child: HealthCareApp()));
}

class HealthCareApp extends ConsumerWidget {
  const HealthCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HealthCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Açık tonlarda sağlık temalı renk paleti
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4ECDC4),        // Soft teal - Ana renk
          secondary: Color(0xFF95E1D3),      // Açık mint - İkincil renk
          tertiary: Color(0xFFFEDBD0),       // Soft peach - Üçüncül renk
          surface: Color(0xFFF8F9FD),        // Çok açık mavi - Arka plan
          onPrimary: Colors.white,
          onSecondary: Color(0xFF2C3E50),
          onSurface: Color(0xFF2C3E50),
          error: Color(0xFFFF6B6B),          // Soft red - Hata rengi
          onError: Colors.white,
        ),
        // AppBar teması
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2C3E50),
          iconTheme: IconThemeData(color: Color(0xFF2C3E50)),
        ),
        // Kart teması
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        // Elevated button teması
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4ECDC4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        // Floating action button teması
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4ECDC4),
          foregroundColor: Colors.white,
        ),
        // İkon teması
        iconTheme: const IconThemeData(
          color: Color(0xFF4ECDC4),
        ),
        // Scaffold arka plan rengi
        scaffoldBackgroundColor: const Color(0xFFF8F9FD),
      ),
      home: const LoginPage(),
    );
  }
}
