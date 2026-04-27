import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';
import 'home_page.dart'; // This is the comparison page

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Anggota',
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
  int? _selectedMenuIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Data Anggota',
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
                  Text(
                    'Menu Utama',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign In'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Column(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 80,
                      color: Colors.teal,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Data Anggota',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    Text(
                      'PUK SPAMK FSPMI PT. JAI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _buildMenuButton(
                  context,
                  0,
                  'Pendaftaran Anggota',
                  Icons.person_add,
                  () async {
                    setState(() => _selectedMenuIndex = 0);
                    final Uri url = Uri.parse('https://www.google.com/');
                    if (!await launchUrl(url)) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tidak dapat membuka link')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  1,
                  'Download Anggota',
                  Icons.download,
                  () {
                    setState(() => _selectedMenuIndex = 1);
                    // TODO: Implement navigation
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  2,
                  'Download Data Karyawan',
                  Icons.file_download,
                  () {
                    setState(() => _selectedMenuIndex = 2);
                    // TODO: Implement navigation
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  3,
                  'Data Anggota',
                  Icons.group,
                  () {
                    setState(() => _selectedMenuIndex = 3);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, int index, String label, IconData icon, VoidCallback onPressed) {
    bool isSelected = _selectedMenuIndex == index;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.teal[800] : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.teal,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? Colors.teal[900]! : Colors.teal, width: 1),
        ),
        elevation: isSelected ? 4 : 2,
      ),
    );
  }
}
