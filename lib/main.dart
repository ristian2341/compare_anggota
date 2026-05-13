import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'download_anggota_page.dart';
import 'download_karyawan_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daftar Anggota',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    // Jalankan pengecekan sinkronisasi data saat aplikasi dibuka (foreground check saja)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDataSync();
    });
  }

  Future<void> _checkDataSync() async {
    try {
      final settings = await _dbHelper.getSettings();
      if (settings == null) return;

      final urlAnggota = settings['link_data_anggota'] ?? '';
      final urlKaryawan = settings['link_data_karyawan'] ?? '';

      if (urlAnggota.isEmpty && urlKaryawan.isEmpty) return;

      bool needsUpdate = false;
      String updateMessage = "";
      String pageOpen = "";

      // 1. Cek Data Anggota
      if (urlAnggota.isNotEmpty) {
        int remoteCount = await _getRemoteRowCount(urlAnggota);
        int localCount = (await _dbHelper.queryAllAnggota()).length;
        if (remoteCount != -1 && remoteCount != localCount) {
          needsUpdate = true;
          pageOpen = "anggota";
          updateMessage = "Data Anggota belum sinkron!";
        }
      }

      // 2. Cek Data Karyawan
      if (!needsUpdate && urlKaryawan.isNotEmpty) {
        int remoteCount = await _getRemoteRowCount(urlKaryawan);
        int localCount = (await _dbHelper.queryAllKaryawan()).length;
        if (remoteCount != -1 && remoteCount != localCount) {
          needsUpdate = true;
          pageOpen = "karyawan";
          updateMessage = "Data Karyawan belum sinkron!";
        }
      }

      if (needsUpdate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Expanded(
                  child: Text(
                    updateMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    if (pageOpen == 'anggota') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadAnggotaPage(),
                        ),
                      );
                    } else if (pageOpen == "karyawan") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadKaryawanPage(),
                        ),
                      );
                    }
                  },
                  child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Sync check skipped: $e");
    }
  }

  Future<int> _getRemoteRowCount(String url) async {
    try {
      String downloadUrl = url;
      if (url.contains('/pubhtml')) {
        downloadUrl = url.replaceFirst('/pubhtml', '/pub?output=csv');
      } else if (url.contains('/edit')) {
        downloadUrl = url.split('/edit')[0] + '/export?format=csv';
      }

      final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        return lines.where((line) => line.trim().isNotEmpty).length - 1;
      }
    } catch (_) {}
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Daftar Anggota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_circle, size: 50, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Menu Utama',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Setting Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/images/my_icon.png',
                          width: screenWidth * 0.20 > 80 ? 80 : screenWidth * 0.20,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Text(
                        'Data Anggota',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const Text(
                        'PUK SPAMK FSPMI PT. JAI',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _modernMenuButton(
                    context, 'Pendaftaran Anggota', Icons.person_add, Colors.teal,
                        () async {
                      final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSc-KGxy1af-CKOozYGerxkTMaNjWmo8ghDyJWAwSyf5nmfsCg/viewform');
                      if (!await launchUrl(url)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka link')));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _modernMenuButton(
                    context, 'Download Anggota', Icons.download, Colors.blue,
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadAnggotaPage()));
                    },
                  ),
                  const SizedBox(height: 16),
                  _modernMenuButton(
                    context, 'Download Data Karyawan', Icons.file_download, Colors.orange,
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadKaryawanPage()));
                    },
                  ),
                  const SizedBox(height: 16),
                  _modernMenuButton(
                    context, 'Data Anggota', Icons.group, Colors.purple,
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'create by Rtie Development @2026',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _modernMenuButton(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
