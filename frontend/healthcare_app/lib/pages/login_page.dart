// Bu dosya: Kullanıcı giriş ve kayıt sayfası.
// - Email/şifre ile giriş yapma
// - Yeni kullanıcı kaydı (Ad Soyad, Email, Şifre, Rol seçimi)
// - Başarılı girişte rol bazlı sayfa yönlendirmesi (Hasta Yakını/Bakıcı)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../main.dart';
import 'relative_tasks_page.dart';
import 'caregiver_tasks_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // Form kontrolleri
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Kayıt formu için ek alanlar
  final _fullNameController = TextEditingController();
  String _selectedRole = 'hasta_yakini'; // Varsayılan rol
  bool _isRegister = false; // Giriş/Kayıt modu değiştirici

  // UI durumları
  bool _loading = false; // Yükleniyor göstergesi
  String? _error; // Hata mesajı

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiClientProvider);

    return Scaffold(
      body: Center(
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HealthCare',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // "Giriş Yap / Kayıt Ol" sekme butonları
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Giriş moduna geç
                            setState(() {
                              _isRegister = false;
                              _error = null;
                            });
                          },
                          child: Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontWeight: !_isRegister
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              decoration: !_isRegister
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Kayıt moduna geç
                            setState(() {
                              _isRegister = true;
                              _error = null;
                            });
                          },
                          child: Text(
                            'Kayıt Ol',
                            style: TextStyle(
                              fontWeight: _isRegister
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              decoration: _isRegister
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isRegister) ...[
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Şifre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isRegister) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'hasta_yakini',
                          child: Text('Hasta Yakını'),
                        ),
                        DropdownMenuItem(
                          value: 'hasta_bakici',
                          child: Text('Hasta Bakıcı'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });

                              try {
                                if (_isRegister) {
                                  // ----- KAYIT OL -----
                                  final fullName =
                                      _fullNameController.text.trim();
                                  final email =
                                      _emailController.text.trim();
                                  final password =
                                      _passwordController.text.trim();

                                  if (fullName.isEmpty ||
                                      email.isEmpty ||
                                      password.isEmpty) {
                                    throw Exception(
                                        'Lütfen tüm alanları doldurun.');
                                  }

                                  await api.register(
                                    fullName,
                                    email,
                                    password,
                                    _selectedRole,
                                  );

                                  // Kayıt başarılı -> login
                                  final user =
                                      await api.login(email, password);
                                  ref
                                      .read(
                                          currentUserProvider.notifier)
                                      .state = user;

                                  if (!mounted) return;

                                  if (user.role == 'hasta_yakini') {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RelativeTasksPage(),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CaregiverTasksPage(),
                                      ),
                                    );
                                  }
                                } else {
                                  // ----- GİRİŞ YAP -----
                                  final email =
                                      _emailController.text.trim();
                                  final password =
                                      _passwordController.text.trim();

                                  if (email.isEmpty || password.isEmpty) {
                                    throw Exception(
                                        'Email ve şifre giriniz.');
                                  }

                                  final user = await api.login(
                                      email, password);
                                  ref
                                      .read(
                                          currentUserProvider.notifier)
                                      .state = user;

                                  if (!mounted) return;

                                  if (user.role == 'hasta_yakini') {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RelativeTasksPage(),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CaregiverTasksPage(),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setState(() {
                                  _error = e.toString();
                                });
                              } finally {
                                setState(() {
                                  _loading = false;
                                });
                              }
                            },
                            child: Text(_isRegister ? 'Kayıt Ol' : 'Giriş Yap'),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
