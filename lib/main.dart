import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  final TextEditingController _searchAreaController = TextEditingController();

  String user_name = '';
  String password = '';

  int _currentIndex = 0;
  int _totalAnggota = 0;
  int _totalKaryawan = 0;
  int _totalAnggota_l = 0;
  int _totalAnggota_p = 0;
  int _totalAnggota_kontrak = 0;
  int _totalAnggota_tetap = 0;
  bool _isLoadingDashboard = true;

  Map<String, dynamic>? _selectedAreaDetail;

  // 1. Tambahkan variabel Future di _DataPageState kamu
  late Future<List<Map<String, dynamic>>> _areaFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDataSync();
      _loadDashboardData();
    });
    _areaFuture = _dbHelper.queryDataCount(); // Inisialisasi sekali saja
  }

  @override
  void dispose() {
    _searchAreaController.dispose();
    super.dispose();
  }

  // 🔹 FUNGSI UNTUK REFRESH DATA
  Future<void> _refreshData() async {
    await Future.wait([
      _loadDashboardData(),
      _checkDataSync(),
      _areaFuture = _dbHelper.queryDataCount(), // Inisialisasi sekali saja
    ]);
  }

  // Mengambil statistik jumlah data dari SQLite lokal
  Future<void> _loadDashboardData() async {
    try {
      final anggotaList = await _dbHelper.queryAllAnggota();
      final karyawanList = await _dbHelper.queryAllKaryawan();
      final dataJenKel = await _dbHelper.queryLatestDataJenKel();
      final dataCompare = await _dbHelper.queryCompareAnggota();

      int tempKontrak = 0;int tempTetap = 0;
      if (dataCompare != null && dataCompare.isNotEmpty) {
        for (var row in dataCompare) {
          if (row['status']?.toString() == '02' || row['status']?.toString() == '2') {
            tempKontrak++;
          }

          if(row['status']?.toString() == '01' || row['status']?.toString() == '1'){
            tempTetap++;
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
          _totalAnggota_tetap = tempTetap;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
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
                          builder: (context) => const DownloadKaryawanPage(),
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
      debugPrint('Sync check skipped: $e');
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

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Menu Utama';
      case 2:
        return 'Area Kerja';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final box = GetStorage();
    bool isLoggedIn = box.read('isLoggin') ?? false;

    final List<Widget> pages = [
      _buildDashboardPage(context, screenWidth),
      _buildMainMenuPage(context, screenWidth),
      _buildAreaKerjaPage(context),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        elevation: 0,
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
              decoration: const BoxDecoration(
                color: Color(0xFF004D40),
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
              leading: const Icon(Icons.badge),
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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF054942), Color(0xFF177565)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CurvedNavigationBar(
            key: _bottomNavigationKey,
            index: _currentIndex,
            height: 60.0,
            items: <Widget>[
              // Item 1: Dashboard
              Builder(
                builder: (context) {
                  final isSelected = _currentIndex == 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dashboard_rounded,
                        size: isSelected ? 28 : 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: isSelected ? 10 : 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Item 2: Menu
              Builder(
                builder: (context) {
                  final isSelected = _currentIndex == 1;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.widgets_rounded,
                        size: isSelected ? 28 : 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Menu',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: isSelected ? 10 : 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Item 3: Area Kerja
              Builder(
                builder: (context) {
                  final isSelected = _currentIndex == 2;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_work,
                        size: isSelected ? 28 : 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Area Kerja',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: isSelected ? 10 : 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            color: const Color(0xFF004D40),
            buttonBackgroundColor: Colors.teal.shade400,
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 350),
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            letIndexChange: (index) => true,
          ),
          Container(
            color: const Color(0xFF004D40),
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 4.0,
              bottom: MediaQuery.of(context).padding.bottom + 6.0,
            ),
            child: const Text(
              'create by Rtie Development @2026 (Version 2)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                                if (_totalAnggota_l <= 0) return const SizedBox.shrink();
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
                              Builder(builder: (context) {
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
                              Divider(height: 1, thickness: 0.8, color: Colors.black87.withOpacity(0.2)),
                              const SizedBox(height: 20),
                              Builder(builder: (context) {
                                if (_totalAnggota_tetap <= 0) return const SizedBox.shrink();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_2_rounded, color: Colors.teal, size: 16),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jml Anggota Tetap',
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
                                      '$_totalAnggota_tetap (${(((_totalAnggota_tetap / _totalAnggota) * 100).toStringAsFixed(2))}) %',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              Builder(builder: (context) {
                                if (_totalAnggota_kontrak <= 0) return const SizedBox.shrink();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_2_rounded, color: Colors.teal, size: 16),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jml Anggota Kontrak',
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
                                      '$_totalAnggota_kontrak (${(((_totalAnggota_kontrak / _totalAnggota) * 100).toStringAsFixed(2))}) %',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                          Builder(builder: (context) {
                            int total_anggota = _selectedAreaDetail!['total_anggota'] ?? 0;
                            int total_non_anggota = _selectedAreaDetail!['total_non_anggota'] ?? 0;
                            int total_pegawai = _selectedAreaDetail!['total_karyawan'] ?? 0;
                            return _dashboardCard(
                              (_selectedAreaDetail!['area_kerja'] ?? 'AREA KERJA')
                                  .toString()
                                  .replaceAll('"', '')
                                  .trim(),
                              '${total_pegawai} (${(((total_pegawai ?? 0) / _totalKaryawan) * 100).toStringAsFixed(0)}%)',
                              Icons.location_city,
                              Colors.teal,
                              '${total_anggota} (${((total_anggota / total_pegawai) * 100).toStringAsFixed(0)}%)',
                              '${total_non_anggota} (${((total_non_anggota / total_pegawai) * 100).toStringAsFixed(0)}%)',
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                      ],
                    )
                  ],
                ),
                // TAMBAHKAN SIZEDBOX DI SINI UNTUK MEMBERI RUANG SCROLL DI BAWAH NAV BAR
                const SizedBox(height: 80),
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
                  'Total Anggota :',
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
                  'Total Non Anggota :',
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔍 HALAMAN AREA KERJA DENGAN INPUT PENCARIAN REAL-TIME
  // 3. Widget _buildAreaKerjaPage yang sudah diperbaiki
  Widget _buildAreaKerjaPage(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.teal,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _areaFuture, // Ganti pemanggilan fungsi dengan variabel State
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final allAreaList = snapshot.data ?? [];
          final query = _searchAreaController.text.toLowerCase().trim();

          // Saring daftar berdasarkan teks pencarian
          final filteredAreaList = allAreaList.where((area) {
            final areaName = (area['area_kerja'] ?? '')
                .toString()
                .replaceAll('"', '')
                .toLowerCase();
            return areaName.contains(query);
          }).toList();

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // 🔍 Field Input Pencarian
                  TextField(
                    controller: _searchAreaController,
                    onChanged: (value) {
                      setState(() {}); // Sekarang setState hanya memfilter list lokal, tanpa mereload DB
                    },
                    decoration: InputDecoration(
                      hintText: "Cari area kerja...",
                      hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      suffixIcon: _searchAreaController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchAreaController.clear();
                          });
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 📋 List Area Kerja
                  Expanded(
                    child: filteredAreaList.isEmpty
                        ? const Center(
                      child: Text(
                        'Area kerja tidak ditemukan',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    )
                        : ListView.builder(
                      itemCount: filteredAreaList.length,
                      itemBuilder: (context, index) {
                        final item = filteredAreaList[index];
                        String areaName = (item['area_kerja'] ?? 'TANPA AREA')
                            .toString()
                            .replaceAll('"', '')
                            .trim();
                        int totalKaryawan = item['total_karyawan'] ?? 0;
                        int totalAnggota = item['total_anggota'] ?? 0;
                        int totalNonAnggota = item['total_non_anggota'] ?? 0;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFF004D40),
                                      child: Icon(Icons.location_city, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        areaName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.teal.shade200),
                                      ),
                                      child: Text(
                                        '$totalKaryawan Orang',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20, thickness: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.teal, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Anggota: $totalAnggota',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.cancel, color: Colors.orange, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Non-Anggota: $totalNonAnggota',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 80), // Menambahkan ruang scroll bawah agar tidak terpotong nav bar
                ],
              ),
            ),
          );
        },
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