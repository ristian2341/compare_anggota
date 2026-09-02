import 'package:flutter/material.dart';
import 'database_helper.dart';

class DataAnggotaPage extends StatefulWidget {
  const DataAnggotaPage({super.key});

  @override
  State<DataAnggotaPage> createState() => _DataAnggotaPageState();
}

class _DataAnggotaPageState extends State<DataAnggotaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyMissing = false;
  bool _showDouble = false;
  int total_anggota = 0;

  List<Map<String, dynamic>> _dataAnggota = [];
  List<Map<String, dynamic>> _dataKaryawan = [];
  Set<String> _nikKaryawanSet = {};
  Set<String> _duplicateNiks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final karyawan = await _dbHelper.queryAllKaryawan();
    final anggota = await _dbHelper.queryAllAnggota();

    final nikSet = karyawan
        .map((k) => k['nik']?.toString().trim() ?? '')
        .where((nik) => nik.isNotEmpty)
        .toSet();

    _dataKaryawan = karyawan;

    // DETEKSI NIK DOUBLE SEKALIGUS
    final Set<String> seenNiks = {};
    final Set<String> duplicateNiks = {};

    for (var item in anggota) {
      final nik = (item['nomor_nik'] ?? item['nik'] ?? '').toString().trim();
      if (nik.isNotEmpty) {
        if (seenNiks.contains(nik)) {
          duplicateNiks.add(nik);
        } else {
          seenNiks.add(nik);
        }
      }
    }

    // FILTER SEARCH TEXTFIELD
    final query = _searchController.text.toLowerCase().trim();
    final filteredAnggota = anggota.where((item) {
      final nik = (item['nomor_nik'] ?? item['nik'] ?? '').toString().toLowerCase();
      final nama = (item['nama_anggota'] ?? item['nama'] ?? '').toString().toLowerCase();
      return nik.contains(query) || nama.contains(query);
    }).toList();

    setState(() {
      _nikKaryawanSet = nikSet;
      _dataAnggota = filteredAnggota;
      _duplicateNiks = duplicateNiks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. FILTER DISPLAY LIST DILAKUKAN SEKALI DI SINI
    final displayList = _dataAnggota.where((item) {
      final nik = (item['nomor_nik'] ?? item['nik'] ?? '').toString().trim();

      if (_showDouble) {
        return _duplicateNiks.contains(nik);
      }
      if (_showOnlyMissing) {
        return nik.isEmpty || !_nikKaryawanSet.contains(nik);
      }
      return true;
    }).toList();

    total_anggota = displayList.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Anggota'),
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
                        hintText: 'Cari berdasarkan NIK / Nama...',
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
                            _loadData();
                          },
                        ),
                      ),
                      onChanged: (value) => _loadData(),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Checkbox(
                          value: _showOnlyMissing,
                          activeColor: Colors.red,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (bool? value) {
                            setState(() {
                              _showOnlyMissing = value ?? false;
                              if (_showOnlyMissing) _showDouble = false;
                            });
                          },
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showOnlyMissing = !_showOnlyMissing;
                              if (_showOnlyMissing) _showDouble = false;
                            });
                          },
                          child: const Text(
                            'NIK Tidak Ada di Data Karyawan',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Checkbox(
                          value: _showDouble,
                          activeColor: Colors.orange.shade800,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (bool? value) {
                            setState(() {
                              _showDouble = value ?? false;
                              if (_showDouble) _showOnlyMissing = false;
                            });
                          },
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showDouble = !_showDouble;
                              if (_showDouble) _showOnlyMissing = false;
                            });
                          },
                          child: const Text(
                            'NIK Yang Double',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Anggota : $total_anggota',
                            style: TextStyle(
                              fontSize: 15,
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

            // 2. EXPANDED BODY (TANPA DEKLARASI DISPLAYLIST ULANG)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : displayList.isEmpty
                  ? Center(
                child: Text(
                  _showDouble
                      ? 'Tidak ada data NIK yang double'
                      : _showOnlyMissing
                      ? 'Tidak ada data anggota yang bermasalah/hilang dari karyawan'
                      : 'Data tidak ditemukan',
                  textAlign: TextAlign.center,
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
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.teal.shade100),
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('NIK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    DataColumn(label: Text('Nama Anggota', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    DataColumn(label: Text('Tgl Berhenti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    DataColumn(label: Text('Karyawan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                  ],
                  rows: list.map((item) {
                    final nik = (item['nomor_nik'] ?? item['nik'] ?? '').toString().trim();
                    final nama = (item['nama_anggota'] ?? item['nama'] ?? '-').toString();
                    final isKaryawan = nik.isNotEmpty && _nikKaryawanSet.contains(nik);

                    final karyawanData = isKaryawan
                        ? _dataKaryawan.firstWhere(
                          (k) => (k['nik'] ?? '').toString().trim() == nik,
                      orElse: () => {},
                    )
                        : null;

                    String tglBerhenti = karyawanData?['tgl_berhenti'] ?? '-';
                    String status = "";

                    if (isKaryawan) {
                      final statusMap = {
                        "1": "Tetap", "01": "Tetap",
                        "2": "Kontrak", "02": "Kontrak",
                        "3": "Magang", "03": "Magang",
                      };
                      final rawStatus = karyawanData?['status']?.toString().trim();
                      status = statusMap[rawStatus] ?? "-";
                    }

                    final isDuplicate = _duplicateNiks.contains(nik);

                    Color rowColor;
                    if (isDuplicate) {
                      rowColor = Colors.yellowAccent.shade200;
                    } else if (!isKaryawan) {
                      rowColor = Colors.red.shade300;
                    } else {
                      rowColor = Colors.transparent;
                    }

                    return DataRow(
                      color: WidgetStateProperty.all(rowColor),
                      cells: [
                        DataCell(Text(nik.isEmpty ? '(NIK KOSONG)' : nik, style: TextStyle(fontWeight: FontWeight.bold, color: isKaryawan ? Colors.black87 : Colors.red.shade900))),
                        DataCell(Text(nama)),
                        DataCell(Text(status)),
                        DataCell(Text(tglBerhenti)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isKaryawan ? Colors.teal.shade50 : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isKaryawan ? 'Yes' : 'No',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isKaryawan ? Colors.teal.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardList(List<Map<String, dynamic>> list) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final nik = (item['nomor_nik'] ?? item['nik'] ?? '').toString().trim();
        final nama = (item['nama_anggota'] ?? item['nama'] ?? '-').toString();
        final isKaryawan = nik.isNotEmpty && _nikKaryawanSet.contains(nik);
        final isDuplicate = _duplicateNiks.contains(nik);

        final karyawanData = isKaryawan
            ? _dataKaryawan.firstWhere(
              (k) => (k['nik'] ?? '').toString().trim() == nik,
          orElse: () => {},
        )
            : null;

        String tglBerhenti = karyawanData?['tgl_berhenti'] ?? '';
        String status = "";

        if (isKaryawan) {
          final statusMap = {
            "1": "Tetap", "01": "Tetap",
            "2": "Kontrak", "02": "Kontrak",
            "3": "Magang", "03": "Magang",
          };
          final rawStatus = karyawanData?['status']?.toString().trim();
          status = statusMap[rawStatus] ?? "-";
        }

        Color cardColor = Colors.white;
        if (isDuplicate) {
          cardColor = Colors.yellow.shade200;
        } else if (!isKaryawan) {
          cardColor = Colors.red.shade50;
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isKaryawan ? Icons.person : Icons.warning_amber_rounded,
                      color: isKaryawan ? Colors.teal : Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nik.isEmpty ? '(NIK KOSONG)' : 'NIK : $nik',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isKaryawan ? Colors.teal.shade900 : Colors.red.shade900,
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
                      )
                    else if (!isKaryawan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          'Tidak ada di Data Karyawan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                  ],
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