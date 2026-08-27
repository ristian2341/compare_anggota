import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';

class DownloadAnggotaPage extends StatefulWidget {
  const DownloadAnggotaPage({super.key});

  @override
  State<DownloadAnggotaPage> createState() => _DownloadAnggotaPageState();
}

class _DownloadAnggotaPageState extends State<DownloadAnggotaPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isProcessing = false;
  int _totalData = 0;

  List<Map<String, dynamic>> _listAnggota = [];
  Set<String> _existingNikKaryawan = {};

  @override
  void initState() {
    super.initState();
    _loadDataAndCompare();
  }

  /// Memuat data anggota sekaligus mengambil daftar NIK karyawan untuk komparasi
  Future<void> _loadDataAndCompare() async {
    final anggotaData = await _dbHelper.queryAllAnggota();

    // Ambil data karyawan dari database helper
    final karyawanData = await _dbHelper.queryAllKaryawan();

    final Set<String> nikSet = karyawanData
        .map((k) => k['nik']?.toString().trim() ?? '')
        .where((nik) => nik.isNotEmpty)
        .toSet();

    setState(() {
      _listAnggota = anggotaData;
      _totalData = anggotaData.length;
      _existingNikKaryawan = nikSet;
    });
  }

  Future<void> _importFromUrl() async {
    setState(() => _isProcessing = true);
    try {
      final settings = await _dbHelper.getSettings();
      final url = settings?['link_data_anggota'];

      if (url == null || url.isEmpty) {
        throw 'Link URL belum diatur di menu Setting (Sign In)';
      }

      String downloadUrl = url;
      if (url.contains('docs.google.com/spreadsheets')) {
        if (url.contains('/pubhtml')) {
          downloadUrl = url.replaceFirst('/pubhtml', '/pub?output=csv');
        } else if (url.contains('/edit')) {
          downloadUrl = url.replaceFirst('/edit#gid=', '/export?format=csv&gid=');
          if (!downloadUrl.contains('/export?format=csv')) {
            downloadUrl = url.split('/edit')[0] + '/export?format=csv';
          }
        }
      }

      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        await _dbHelper.deleteAllAnggota();

        int importedCount = 0;

        for (int i = 1; i < lines.length; i++) {
          final columns = lines[i].split(',');

          if (columns.length >= 4) {
            await _dbHelper.insertAnggota({
              'nomor_nik': columns[1].trim(),
              'barcode': columns[2].trim(),
              'nama_anggota': columns[3].trim(),
            });
            importedCount++;
          }
        }
        await _loadDataAndCompare();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil mengimpor $importedCount data dari URL')),
          );
        }
      } else {
        throw 'Gagal mendownload data. Status: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _importFromFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isProcessing = true);
        final file = File(result.files.single.path!);
        if (await file.exists()) {
          var bytes = file.readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);

          await _dbHelper.deleteAllAnggota();
          int importedCount = 0;

          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table];
            if (sheet == null) continue;

            for (int i = 1; i < sheet.maxRows; i++) {
              var row = sheet.row(i);
              if (row.length >= 4) {
                await _dbHelper.insertAnggota({
                  'nomor_nik': row[1]?.value.toString().trim() ?? '',
                  'barcode': row[2]?.value.toString().trim() ?? '',
                  'nama_anggota': row[3]?.value.toString().trim() ?? ''
                });
                importedCount++;
              }
            }
          }

          await _loadDataAndCompare();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Berhasil mengimpor $importedCount data dari file')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Data Anggota'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
              constraints: const BoxConstraints(maxWidth: 600),
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

                  /// HEADER
                  Column(
                    children: const [
                      Icon(Icons.cloud_download, size: 60, color: Colors.teal),
                      SizedBox(height: 12),
                      Text(
                        'Download Data Anggota',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// TOTAL DATA CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Data Saat Ini',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalData',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// LOADING ATAU BUTTON
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[

                    /// BUTTON URL
                    Material(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        splashColor: Colors.white24,
                        highlightColor: Colors.white10,
                        onTap: _importFromUrl,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_download, color: Colors.white),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Ambil Data dari URL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// BUTTON EXCEL FILE
                    OutlinedButton.icon(
                      onPressed: _importFromFile,
                      icon: const Icon(Icons.file_upload_outlined, color: Colors.teal),
                      label: const Text('Import dari File Excel (.xlsx)',
                          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  /// HEADER KOMPARASI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hasil Komparasi NIK',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(width: 12, height: 12, color: Colors.red.shade100),
                          const SizedBox(width: 4),
                          const Text('Tidak Ada di Karyawan', style: TextStyle(fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  /// TABEL KOMPARASI DATA ANGGOTA
                  _listAnggota.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Belum ada data anggota',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                      : ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _listAnggota.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _listAnggota[index];
                          final String nik = item['nomor_nik']?.toString().trim() ?? '';
                          final String nama = item['nama_anggota']?.toString() ?? '';
                          final String barcode = item['barcode']?.toString() ?? '';

                          // Pengecekan: NIK kosong ATAU tidak ditemukan di database karyawan
                          final bool isMissingInKaryawan = nik.isEmpty || !_existingNikKaryawan.contains(nik);

                          return Container(
                            color: isMissingInKaryawan ? Colors.red.shade100 : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nik.isEmpty ? '(NIK KOSONG)' : nik,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isMissingInKaryawan ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'Barcode: $barcode',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    nama,
                                    style: TextStyle(
                                      color: isMissingInKaryawan ? Colors.red.shade900 : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isMissingInKaryawan)
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20)
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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
}