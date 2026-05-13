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
  bool _isExporting = false;
  String _searchQuery = "";
  String _searchBy = "Semua"; // NIK, Nama, Area, Semua
  String _statusFilter = "Semua"; // Semua, YES, NO
  bool _isSearchVisible = false; // Default tersembunyi

  // Lebar kolom tetap minimum untuk memastikan data tidak berdesakan
  final double minColNik = 70;
  final double minColStatus = 100;
  final double minColNama = 130;
  final double minColArea = 100;
  final double minTableWidth = 600;



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

  bool _matchesLike(String value, String query) {
    if (query.isEmpty) return true;
    final valLower = value.toLowerCase();
    final qLower = query.toLowerCase();

    // Jika query adalah '%' saja, tampilkan semua
    if (qLower == '%') return true;

    // Menangani pencarian SQL LIKE menggunakan Regex
    // 1. Escape karakter regex spesial (kecuali %)
    String pattern = qLower.replaceAll(RegExp(r'([.*+?^${}()|[\]\\])'), r'\$1');

    // 2. Ganti % dengan .*
    pattern = pattern.replaceAll('%', '.*');

    // 3. Tambahkan anchor jika tidak ada % di ujung
    if (!qLower.startsWith('%')) pattern = '^$pattern';
    if (!qLower.endsWith('%')) pattern = '$pattern';

    try {
      return RegExp(pattern).hasMatch(valLower);
    } catch (e) {
      // Jika regex gagal, fallback ke contains biasa tanpa %
      return valLower.contains(qLower.replaceAll('%', ''));
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    return _displayData.where((item) {
      if (_statusFilter != "Semua") {
        if (item['status'] != _statusFilter) return false;
      }
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      final isContains = searchLower.startsWith('%');

      final keyword = isContains ? searchLower.substring(1) : searchLower;

      String nik = item['nik'].toString().toLowerCase();
      String nama = item['nama'].toString().toLowerCase();
      String area = item['area'].toString().toLowerCase();

      bool match(String value) {
        return isContains
            ? value.contains(keyword)
            : value.startsWith(keyword);
      }

      if (_searchBy == "NIK") {
        return match(nik);
      } else if (_searchBy == "Nama") {
        return match(nama);
      } else if (_searchBy == "Area") {
        return match(area);
      } else {
        return match(nik) ||
            match(nama) ||
            match(area);
      }

    }).toList();
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);

    try {
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
                child: pw.Text(
                  "Data Pegawai & Status Anggota",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['NIK', 'Nama', 'Area Kerja', 'Status'],
                data: data.map((item) => [
                  item['nik'].toString(),
                  item['nama'].toString(),
                  item['area'].toString(),
                  item['status'].toString(),
                ]).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Data_Pegawai_Status.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export PDF berhasil')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mendapatkan lebar layar
    final screenWidth = MediaQuery.of(context).size.width;
    // Anggap tablet jika lebar layar > 600
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Data Pegawai & Status Anggota',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        children: [

          /// BODY UTAMA
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      // Tombol Toggle Pencarian
                      GestureDetector(
                        onTap: () => setState(() => _isSearchVisible = !_isSearchVisible),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.search, color: Colors.teal.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pencarian & Filter',
                                    style: TextStyle(
                                      color: Colors.teal.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _isSearchVisible ? Icons.expand_less : Icons.expand_more,
                                color: Colors.teal.shade800,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Area Pencarian (Show/Hide)
                      if (_isSearchVisible) ...[
                        const SizedBox(height: 8),
                        _buildSearchAndFilterModern(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _displayData.isEmpty
                        ? const Center(child: Text('Tidak ada data karyawan.'))
                        : (MediaQuery.of(context).size.width > 600
                        ? _buildTableView()
                        : _buildCardView()),
                  ),
                ),
              ],
            ),
          ),

          /// LOADING OVERLAY EXPORT
          if (_isExporting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Sedang membuat PDF...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          /// STATISTICS LABEL (Bottom Left)
          if (!_isLoading && _displayData.isNotEmpty)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade800.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Anggota: ${_filteredData.where((e) => e['status'] == 'YES').length} (${(_filteredData.length > 0 ? (_filteredData.where((e) => e['status'] == 'YES').length / _filteredData.length * 100) : 0).toStringAsFixed(1)}%)',
                      style: TextStyle(color: Colors.white54,fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Non Anggota: ${_filteredData.where((e) => e['status'] == 'NO').length} (${(_filteredData.length > 0 ? (_filteredData.where((e) => e['status'] == 'NO').length / _filteredData.length * 100) : 0).toStringAsFixed(1)}%)',
                      style: TextStyle(color: Colors.white54,fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Pegawai: ${_filteredData.length} data',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: (!_isLoading && _filteredData.isNotEmpty)
          ? FloatingActionButton.extended(
        onPressed: _exportToPdf,
        backgroundColor: Colors.teal,
        elevation: 6,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text(
          'Export PDF',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  Widget _buildTableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
          ),
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 8,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    // --- HEADER ---
                    Container(
                      color: Colors.teal.shade900,
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
    );
  }

  Widget _buildCardView() {
    return ListView.builder(
      itemCount: _filteredData.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final item = _filteredData[index];
        final isAnggota = item['status'] == 'YES';
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Atas: NIK - Nama Pegawai
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${item['nik']} - ${item['nama']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                // Bawah: Area Kerja - Anggota (Yes/No)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            item['area'],
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAnggota ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAnggota ? "Anggota: YES" : "Anggota: NO",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAnggota ? Colors.green.shade800 : Colors.red.shade800,
                        ),
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

  Widget _buildSearchAndFilterModern() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              /// DROPDOWN SEARCH BY
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _searchBy,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  items: ['Semua', 'NIK', 'Nama', 'Area']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _searchBy = val!),
                ),
              ),

              const SizedBox(width: 8),

              /// FILTER STATUS
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintStyle : TextStyle(fontSize: 12, ),
                  ),
                  items: ['Semua', 'YES', 'NO']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _statusFilter = val!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// SEARCH
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari data...',
              hintStyle : TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12), // Sesuaikan vertical padding
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
        ),
      ),
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
          right: BorderSide(color: Colors.grey.shade300, width: 1),
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
      height: 45, // Samakan tinggi dengan _buildCell
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