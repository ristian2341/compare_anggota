import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _displayData = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _searchBy = "Semua"; // NIK, Nama, Area, Semua
  String _statusFilter = "Semua"; // Semua, YES, NO

  // Lebar kolom tetap minimum untuk memastikan data tidak berdesakan
  // Cari bagian ini di atas (Line 23-26)
  final double minColNik = 70;
  final double minColStatus = 100;
  final double minColNama = 150; // Tambahkan ini jika ingin mengatur lebar Nama
  final double minColArea = 100; // Tambahkan ini jika ingin mengatur lebar Area
  final double minTableWidth = 1000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final karyawan = await _dbHelper.queryAllKaryawan();
      final anggota = await _dbHelper.queryAllAnggota();

      final Set<String> nikAnggotaSet = anggota
          .map((a) => a['nomor_nik']?.toString() ?? '')
          .where((nik) => nik.isNotEmpty)
          .toSet();

      final List<Map<String, dynamic>> combined = [];
      for (var i = 0; i < karyawan.length; i++) {
        final k = karyawan[i];
        final nik = k['nik']?.toString() ?? '';
        final isAnggota = nikAnggotaSet.contains(nik);

        combined.add({
          'nik': nik,
          'nama': k['nama_karyawan'] ?? '',
          'area': k['area_kerja'] ?? '',
          'status': isAnggota ? 'YES' : 'NO',
        });
      }

      setState(() {
        _displayData = combined;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    return _displayData.where((item) {
      if (_statusFilter != "Semua") {
        if (item['status'] != _statusFilter) return false;
      }
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      
      if (_searchBy == "NIK") {
        return item['nik'].toString().toLowerCase().startsWith(searchLower);
      } else if (_searchBy == "Nama") {
        return item['nama'].toString().toLowerCase().startsWith(searchLower);
      } else if (_searchBy == "Area") {
        return item['area'].toString().toLowerCase().startsWith(searchLower);
      } else {
        return item['nik'].toString().toLowerCase().startsWith(searchLower) ||
            item['nama'].toString().toLowerCase().startsWith(searchLower) ||
            item['area'].toString().toLowerCase().startsWith(searchLower);
      }
    }).toList();
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final data = _filteredData;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("Data Pegawai & Status Anggota", 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
            ),
            pw.TableHelper.fromTextArray(
              headers: ['NIK', 'Nama', 'Area Kerja', 'Status'],
              data: data.map((item) => [
                item['nik'].toString(),
                item['nama'].toString(),
                item['area'].toString(),
                item['status'].toString(),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              columnWidths: {
                0: const pw.FixedColumnWidth(100), // NIK
                1: const pw.FlexColumnWidth(3),    // Nama
                2: const pw.FlexColumnWidth(3),    // Area Kerja
                3: const pw.FixedColumnWidth(80),  // Status
              },
            ),
            pw.Padding(padding: const pw.EdgeInsets.only(top: 20)),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Dicetak pada: ${DateTime.now().toString().substring(0, 19)}",
                style: const pw.TextStyle(fontSize: 10))
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Data_Pegawai_Status.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Data Pegawai & Status Anggota',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayData.isEmpty
                    ? const Center(child: Text('Tidak ada data karyawan.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          double tableWidth = constraints.maxWidth > minTableWidth
                              ? constraints.maxWidth 
                              : minTableWidth;
                          
                          // Konfigurasi agar bisa di-scroll dengan mouse drag (klik & tahan) di Windows/Desktop
                          return ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch, // Mendukung scroll sentuh (HP)
                                PointerDeviceKind.mouse, // Mendukung scroll dengan klik & tarik mouse (Desktop)
                              },
                            ),
                            child: Scrollbar(
                              thumbVisibility: true, // Scrollbar selalu terlihat
                              thickness: 8,          // Ketebalan batang scrollbar
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: tableWidth, // Mengunci lebar tabel agar scroll horizontal muncul
                                  height: constraints.maxHeight,
                                  child: Column(
                                    children: [
                                      // --- HEADER ---
                                      Container(
                                        color: Colors.teal.shade700,
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          children: [
                                            _buildHeaderCell('NIK', width: minColNik),
                                            _buildHeaderCell('Nama',width: minColNama, isExpanded: true),
                                            _buildHeaderCell('Area Kerja',width:  minColArea, isExpanded: true),
                                            _buildHeaderCell('Anggota', width: minColStatus, isCenter: true),
                                          ],
                                        ),
                                      ),
                                      // --- BODY ---
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: _filteredData.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = _filteredData[index];
                                            final isAnggota = item['status'] == 'YES';
                                            return Container(
                                              // padding: const EdgeInsets.symmetric(vertical: 12),
                                              child: Row(
                                                children: [
                                                  _buildCell(item['nik'].toString(), width: minColNik),
                                                  _buildCell(item['nama'].toString(), isExpanded: true),
                                                  _buildCell(item['area'].toString(), isExpanded: true),
                                                  _buildStatusBadge(isAnggota, item['status']),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Tombol Export PDF
          if (!_isLoading && _filteredData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exportToPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('EXPORT PDF DATA TERPILIH', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'create by Rtie Developer @2026',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _searchBy,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                onChanged: (String? newValue) {
                  setState(() {
                    _searchBy = newValue!;
                  });
                },
                items: <String>['Semua', 'NIK', 'Nama', 'Area']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari ${_searchBy}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                icon: const Icon(Icons.filter_list, color: Colors.teal),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                onChanged: (String? newValue) {
                  setState(() {
                    _statusFilter = newValue!;
                  });
                },
                items: <String>['Semua', 'YES', 'NO']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {double? width, bool isExpanded = false, bool isCenter = false}) {
    Widget content = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: Text(
        label,
        textAlign: isCenter ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
      ),
    );

    if (isExpanded) return Expanded(child: content);
    return content;
  }

  Widget _buildCell(String value, {double? width, bool isExpanded = false}) {
    Widget content = Container(
      width: width,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );

    if (isExpanded) return Expanded(child: content);
    return content;
  }

  Widget _buildStatusBadge(bool isAnggota, String status) {
    return Container(
      width: minColStatus,
      height: 35,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAnggota ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: isAnggota ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
