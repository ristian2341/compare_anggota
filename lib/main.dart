import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'download_anggota_page.dart';
import 'download_karyawan_page.dart';
import 'jenis_kel_page.dart';
import 'data_anggota_page.dart';
import 'data_karyawan_page.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'settings_page.dart';

Future<void> main() async {
  await GetStorage.init();
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
  final PageController _pageController = PageController(initialPage: 0);

  String user_name = '';
  String password = '';

  int _currentPage = 0;
  int _totalAnggota = 0;
  int _totalKaryawan = 0;
  int _totalAnggota_l = 0;
  int _totalAnggota_p = 0;
  int _totalAnggota_kontrak = 0;
  bool _isLoadingDashboard = true;

  Map<String, dynamic>? _selectedAreaDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDataSync();
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 🔹 FUNGSI UNTUK REFRESH DATA (Pull-to-Refresh & Manual Action)
  Future<void> _refreshData() async {
    await Future.wait([
      _loadDashboardData(),
      _checkDataSync(),
    ]);
  }

  // Mengambil statistik jumlah data dari SQLite lokal
  Future<void> _loadDashboardData() async {
    try {
      final anggotaList = await _dbHelper.queryAllAnggota();
      final karyawanList = await _dbHelper.queryAllKaryawan();
      final dataJenKel = await _dbHelper.queryLatestDataJenKel();
      final dataCompare = await _dbHelper.queryCompareAnggota();

      int tempKontrak = 0;
      if (dataCompare != null && dataCompare.isNotEmpty) {
        for (var row in dataCompare) {
          // Gunakan toString() aman untuk mengantisipasi jika tipe data di SQLite berupa int/String
          if (row['status']?.toString() == '02') {
            tempKontrak++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalAnggota = anggotaList.length;
          _totalKaryawan = karyawanList.length;
          _totalAnggota_l = int.tryParse(dataJenKel?['jumlah_laki']?.toString() ?? '0') ?? 0;
          _totalAnggota_p = int.tryParse(dataJenKel?['jumlah_perempuan']?.toString() ?? '0') ?? 0;
          _totalAnggota_kontrak = tempKontrak;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
        // Tampilkan pesan error dengan benar ke layar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error get data : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                      ).then((_) => _loadDashboardData());
                    } else if (pageOpen == "karyawan") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadAnggotaPage(),
                        ),
                      ).then((_) => _loadDashboardData());
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
      SnackBar(content: Text('Sync check skipped: $e'));
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
    final box = GetStorage();

    bool isLoggedIn = box.read('isLoggin') ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _currentPage == 0 ? 'Dashboard' : 'Daftar Anggota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memuat ulang data...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await _refreshData();
            },
          ),
        ],
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoggedIn) ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Login'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  ).then((_) => _loadDashboardData());
                },
              ),
            ],
            if (isLoggedIn) ...[
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Setting Data'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                  _loadDashboardData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.supervised_user_circle_rounded),
                title: const Text('Input Data Jen Kel'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JenisKelPage()),
                  ).then((_) => _loadDashboardData());
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Data Anggota'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataAnggotaPage()),
                ).then((_) => _loadDashboardData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Data Karyawan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataKaryawanPage()),
                ).then((_) => _loadDashboardData());
              },
            ),
            if (isLoggedIn) ...[
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Konfirmasi Logout'),
                        content: const Text('Apakah Anda yakin ingin keluar?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final box = GetStorage();
                              await box.erase();

                              if (mounted) {
                                Navigator.pop(dialogContext);
                                setState(() {
                                  isLoggedIn = false;
                                });
                                _loadDashboardData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Berhasil Logout')),
                                );
                              }
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPageIndicator(0),
                  const SizedBox(width: 8),
                  _buildPageIndicator(1),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildDashboardPage(context, screenWidth),
                  _buildMainMenuPage(context, screenWidth),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'create by Rtie Development @2026 (Version 2)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Widget Halaman Dashboard dengan RefreshIndicator
  Widget _buildDashboardPage(BuildContext context, double screenWidth) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/images/my_icon.png',
                        width: screenWidth * 0.20 > 70 ? 70 : screenWidth * 0.20,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Text(
                      'Dashboard Statistik Anggota',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const Text(
                      'PUK SPAMK FSPMI PT. JAI',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _isLoadingDashboard
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final double persentase = _totalKaryawan > 0
                            ? (_totalAnggota / _totalKaryawan) * 100
                            : 0.0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.badge, color: Colors.orange, size: 26),
                                      SizedBox(width: 10),
                                      Text(
                                        'Data Karyawan',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$_totalKaryawan',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.group, color: Colors.teal, size: 26),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Data Anggota',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$_totalAnggota (${persentase.toStringAsFixed(1)}%)',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Builder(builder: (context) {
                                final double persentase = _totalAnggota > 0
                                    ? (_totalAnggota_l / _totalAnggota) * 100
                                    : 0.0;
                                if(_totalAnggota_l <= 0) return const SizedBox.shrink();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.man_2_rounded, color: Colors.teal, size: 26),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jumlah Laki-Laki',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$_totalAnggota_l (${((_totalAnggota_l / _totalAnggota) * 100).toStringAsFixed(2)} %)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              Builder(builder: (context){
                                if (_totalAnggota_p <= 0) return const SizedBox.shrink();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [

                                      Row(
                                        children: [
                                          const Icon(Icons.woman_2_rounded, color: Colors.teal, size: 26),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Jumlah Perempuan',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      Text(
                                        '$_totalAnggota_p (${((_totalAnggota_p / _totalAnggota) * 100).toStringAsFixed(2)} %)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                  ],
                                );
                              }),
                              Builder(builder: (context){
                                if (_totalAnggota_kontrak <= 0) return const SizedBox.shrink();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.woman_2_rounded, color: Colors.teal, size: 26),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Jumlah Anggota Kontrak',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '$_totalAnggota_kontrak',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      Text(
                                        '(${(((_totalAnggota_kontrak / _totalAnggota) * 100).toStringAsFixed(2))}) %',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownSearch<Map<String, dynamic>>(
                          items: (filter, loadProps) async {
                            final areaDataList = await _dbHelper.queryGroupedByArea();
                            if (filter.isEmpty) return areaDataList;
                            return areaDataList.where((area) {
                              String name = (area['area_kerja'] ?? '').toString().toLowerCase();
                              return name.contains(filter.toLowerCase());
                            }).toList();
                          },
                          itemAsString: (item) => (item['area_kerja'] ?? 'TANPA AREA')
                              .toString()
                              .replaceAll('"', '')
                              .trim(),
                          compareFn: (item1, item2) =>
                          item1['area_kerja'] == item2['area_kerja'],
                          popupProps: PopupProps.dialog(
                            showSearchBox: true,
                            dialogProps: const DialogProps(
                              elevation: 16,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(20)),
                              ),
                            ),
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                hintText: "Ketik nama area kerja...",
                                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            itemBuilder: (context, item, isDisabled, isSelected) {
                              String areaName = (item['area_kerja'] ?? 'TANPA AREA')
                                  .toString()
                                  .replaceAll('"', '')
                                  .trim();
                              int total = item['total_karyawan'] ?? 0;

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    areaName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.teal.shade200),
                                    ),
                                    child: Text(
                                      '$total Orang',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          decoratorProps: DropDownDecoratorProps(
                            decoration: InputDecoration(
                              hintText: "Cari atau pilih Area Kerja...",
                              hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
                              prefixIcon: const Icon(Icons.location_city, color: Colors.teal),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                              ),
                            ),
                          ),
                          onChanged: (selectedArea) {
                            setState(() {
                              _selectedAreaDetail = selectedArea;
                            });
                          },
                        ),
                        if (_selectedAreaDetail != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            "Jumlah Anggota Per Area Kerja",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                         Builder(builder: (context){
                           int total_anggota = _selectedAreaDetail!['total_karyawan'] ?? 0;
                           int total_status_01 = _selectedAreaDetail!['total_status_01'] ?? 0;
                           int total_status_02 = _selectedAreaDetail!['total_status_02'] ?? 0;
                           return  _dashboardCard(
                             (_selectedAreaDetail!['area_kerja'] ?? 'AREA KERJA')
                                 .toString()
                                 .replaceAll('"', '')
                                 .trim(),
                             '${total_anggota} (${(((_selectedAreaDetail!['total_karyawan'] ?? 0) / _totalAnggota) * 100).toStringAsFixed(2)}%)',
                             Icons.location_city,
                             Colors.teal,
                             '${total_status_01} (${((total_status_01 / _totalAnggota) * 100).toStringAsFixed(2)}%)',
                             '${total_status_02} (${((total_status_02 / _totalAnggota) * 100).toStringAsFixed(2)}%)',
                           );
                         }), const SizedBox(height: 6),
                        ],
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Material(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(25),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () {
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Geser ke Menu Utama',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.teal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardCard(
      String title,
      String count,
      IconData icon,
      Color color,
      [
        String? countL,
        String? countP,
      ]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (countL != null && countP != null) ...[
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 0.8, color: color.withOpacity(0.3)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Tetap :',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                Text(
                  countL,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Kontrak :',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                Text(
                  countP,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Widget Halaman Menu Utama dengan RefreshIndicator
  Widget _buildMainMenuPage(BuildContext context, double screenWidth) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
                      padding: const EdgeInsets.all(12),
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka link')));
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                _modernMenuButton(
                  context, 'Download Anggota', Icons.download, Colors.blue,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DownloadAnggotaPage()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
                const SizedBox(height: 16),
                _modernMenuButton(
                  context, 'Download Data Karyawan', Icons.file_download, Colors.orange,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DownloadKaryawanPage()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
                const SizedBox(height: 16),
                _modernMenuButton(
                  context, 'Data Anggota', Icons.group, Colors.purple,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(25),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Geser ke Dashboard',
                              style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
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