import 'package:flutter/material.dart';
import 'database_helper.dart';

class DataKaryawanPage extends StatefulWidget {
  const DataKaryawanPage({super.key});

  @override
  State<DataKaryawanPage> createState() => _DataKaryawanPageState();
}

class _DataKaryawanPageState extends State<DataKaryawanPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();

  List<Map<String, dynamic>> _allKaryawan = [];
  List<Map<String, dynamic>> _filteredKaryawan = [];
  Set<String> _duplicateNiks = {}; // Menampung NIK Karyawan yang duplikat

  bool _showDouble = false; // State Checkbox NIK Double
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// Memuat data dari SQLite & mengecek NIK duplikat
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final karyawan = await _dbHelper.queryAllKaryawan();

    // DETEKSI NIK DUPLIKAT DI DATA KARYAWAN
    final Set<String> seenNiks = {};
    final Set<String> duplicateNiks = {};

    for (var item in karyawan) {
      final nik = (item['nik'] ?? item['nomor_nik'] ?? '').toString().trim();
      if (nik.isNotEmpty) {
        if (seenNiks.contains(nik)) {
          duplicateNiks.add(nik);
        } else {
          seenNiks.add(nik);
        }
      }
    }

    setState(() {
      _allKaryawan = karyawan;
      _filteredKaryawan = karyawan;
      _duplicateNiks = duplicateNiks;
      _isLoading = false;
    });

    if (_searchController.text.isNotEmpty) {
      _filterData(_searchController.text);
    }
  }

  /// Fungsi pencarian lokal
  void _filterData(String query) {
    final cleanQuery = query.toLowerCase().trim();

    if (cleanQuery.isEmpty) {
      setState(() {
        _filteredKaryawan = _allKaryawan;
      });
      return;
    }

    final results = _allKaryawan.where((item) {
      final nik = (item['nik'] ?? item['nomor_nik'] ?? '').toString().toLowerCase();
      final nama = (item['nama_karyawan'] ?? item['nama'] ?? '').toString().toLowerCase();
      final areaKerja = (item['area_kerja'] ?? '').toString().toLowerCase();

      return nik.contains(cleanQuery) ||
          nama.contains(cleanQuery) ||
          areaKerja.contains(cleanQuery);
    }).toList();

    setState(() {
      _filteredKaryawan = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FILTER DISPLAY LIST BERDASARKAN CHECKBOX NIK DOUBLE
    final displayList = _showDouble
        ? _filteredKaryawan.where((item) {
      final nik = (item['nik'] ?? item['nomor_nik'] ?? '').toString().trim();
      return _duplicateNiks.contains(nik);
    }).toList()
        : _filteredKaryawan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Karyawan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade800,
              Colors.teal.shade400,
            ],
          ),
        ),
        child: Column(
          children: [
            // 1. Search Bar Card & Checkbox
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari NIK / Nama / Area Kerja...',
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal.shade100),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.teal),
                          onPressed: () {
                            _searchController.clear();
                            _filterData('');
                          },
                        ),
                      ),
                      onChanged: (value) => _filterData(value),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Checkbox(
                          value: _showDouble,
                          activeColor: Colors.orange.shade800,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (bool? value) {
                            setState(() {
                              _showDouble = value ?? false;
                            });
                          },
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showDouble = !_showDouble;
                            });
                          },
                          child: const Text(
                            'NIK Yang Double',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Karyawan : ${displayList.length}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // 2. Responsive Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : displayList.isEmpty
                  ? Center(
                child: Text(
                  _showDouble
                      ? 'Tidak ada data NIK karyawan yang double'
                      : 'Data tidak ditemukan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
                  : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 600) {
                    return _buildDataTable(constraints, displayList);
                  } else {
                    return _buildCardList(displayList);
                  }
                },
              ),
            ),
          ],
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

  /// WIDGET TABEL DATA (Untuk Layar Tablet / Laptop)
  Widget _buildDataTable(BoxConstraints constraints, List<Map<String, dynamic>> list) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 900),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.teal.shade100),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('NIK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                      DataColumn(label: Text('Nama Karyawan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                      DataColumn(label: Text('Area Kerja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                      DataColumn(label: Text('Tgl Berhenti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    ],
                    rows: list.map((item) {
                      final nik = (item['nik'] ?? item['nomor_nik'] ?? '').toString().trim();
                      final nama = (item['nama_karyawan'] ?? item['nama'] ?? '-').toString();
                      final tglBerhenti = (item['tgl_berhenti'] ?? '-').toString();
                      final areaKerja = (item['area_kerja'] ?? '-').toString();

                      final statusMap = {
                        "1": "Tetap", "01": "Tetap",
                        "2": "Kontrak", "02": "Kontrak",
                        "3": "Magang", "03": "Magang",
                      };
                      final rawStatus = item['status']?.toString().trim();
                      final status = statusMap[rawStatus] ?? "-";

                      final isDuplicate = _duplicateNiks.contains(nik);

                      return DataRow(
                        color: WidgetStateProperty.all(
                          isDuplicate ? Colors.yellowAccent.shade200 : Colors.transparent,
                        ),
                        cells: [
                          DataCell(Text(
                            nik.isEmpty ? '(NIK KOSONG)' : nik,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDuplicate ? Colors.deepOrange.shade900 : Colors.black87,
                            ),
                          )),
                          DataCell(Text(nama)),
                          DataCell(Text(areaKerja)),
                          DataCell(Text(status)),
                          DataCell(Text(tglBerhenti)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// WIDGET LIST CARD (Untuk Layar HP Mobile)
  Widget _buildCardList(List<Map<String, dynamic>> list) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];

        final nik = (item['nik'] ?? item['nomor_nik'] ?? '').toString().trim();
        final nama = (item['nama_karyawan'] ?? item['nama'] ?? '-').toString();
        final tglBerhenti = (item['tgl_berhenti'] ?? '').toString();
        final areaKerja = (item['area_kerja'] ?? '-').toString();

        final statusMap = {
          "1": "Tetap", "01": "Tetap",
          "2": "Kontrak", "02": "Kontrak",
          "3": "Magang", "03": "Magang",
        };
        final rawStatus = item['status']?.toString().trim();
        final status = statusMap[rawStatus] ?? "-";

        final isDuplicate = _duplicateNiks.contains(nik);

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: isDuplicate ? Colors.yellow.shade200 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDuplicate ? Icons.warning_amber_rounded : Icons.person,
                      color: isDuplicate ? Colors.orange.shade900 : Colors.teal,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nik.isEmpty ? '(NIK KOSONG)' : 'NIK : $nik',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDuplicate ? Colors.orange.shade900 : Colors.teal.shade900,
                        ),
                      ),
                    ),
                    if (isDuplicate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'NIK Double',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDuplicate ? Colors.yellow.shade100 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDuplicate ? Colors.orange.shade300 : Colors.teal.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.work_outline, size: 14, color: Colors.teal.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          areaKerja,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 70, child: Text('Nama', style: TextStyle(fontSize: 13, color: Colors.black54))),
                    const Text(': ', style: TextStyle(color: Colors.black54)),
                    Expanded(child: Text(nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 70, child: Text('Status', style: TextStyle(fontSize: 13, color: Colors.black54))),
                    const Text(': ', style: TextStyle(color: Colors.black54)),
                    Expanded(
                      child: Text(
                        '$status${tglBerhenti.isNotEmpty ? ' (Tgl Berhenti: $tglBerhenti)' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}