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
  bool _showOnlyMissing = false; // State untuk checkbox filter

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
    setState(() {
      _listAnggota = anggotaData;
      _totalData = anggotaData.length;
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
        int skippedCount = 0;

        // Set untuk melacak NIK yang sudah diproses agar tidak ada duplikasi NIK dari CSV
        final Set<String> processedNiks = {};

        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue; // Lewati baris kosong

          final columns = line.split(',');

          if (columns.length >= 4) {
            // Bersihkan NIK dari tanda petik, spasi, dan karakter tersembunyi
            final rawNik = columns[1].replaceAll('"', '').trim();
            final barcode = columns[2].replaceAll('"', '').trim();
            final namaAnggota = columns[3].replaceAll('"', '').trim();

            // 🔍 PENGECEKAN NIK
            // 1. Validasi NIK tidak boleh kosong
            // 2. Validasi NIK belum pernah diimpor dalam perulangan ini (mencegah duplikasi)
            if (rawNik.isNotEmpty && !processedNiks.contains(rawNik)) {
              processedNiks.add(rawNik);

              await _dbHelper.insertAnggota({
                'nomor_nik': rawNik,
                'barcode': barcode,
                'nama_anggota': namaAnggota,
              });
              importedCount++;
            } else {
              skippedCount++; // Catat jika NIK kosong atau duplikat
            }
          }
        }

        await _loadDataAndCompare();

        if (mounted) {
          String message = 'Berhasil mengimpor $importedCount data anggota';
          if (skippedCount > 0) {
            message += ' ($skippedCount NIK kosong/duplikat dilewati)';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
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
          int skippedCount = 0;

          // Track NIK unik untuk mencegah duplikasi data anggota
          final Set<String> processedNiks = {};

          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table];
            if (sheet == null) continue;

            // Skip header (i = 1)
            for (int i = 1; i < sheet.maxRows; i++) {
              var row = sheet.row(i);
              if (row.isEmpty) continue;

              // Ambil NIK dari kolom indeks ke-1 (kolom B di Excel)
              String rawNik = row.length > 1 && row[1]?.value != null
                  ? row[1]!.value.toString()
                  : '';

              // Clean NIK: Menghapus format desimal Excel (.0) dan karakter tak diinginkan
              if (rawNik.contains('.')) {
                rawNik = rawNik.split('.').first;
              }
              rawNik = rawNik.replaceAll('"', '').trim();

              // 🔍 PENGECEKAN NIK
              // 1. Validasi NIK tidak boleh kosong
              // 2. Validasi NIK belum pernah diimpor (mencegah duplikat)
              if (rawNik.isNotEmpty && !processedNiks.contains(rawNik)) {
                processedNiks.add(rawNik);

                await _dbHelper.insertAnggota({
                  'nomor_nik': rawNik,
                  'barcode': row.length > 2 && row[2]?.value != null
                      ? row[2]!.value.toString().replaceAll('"', '').trim()
                      : '',
                  'nama_anggota': row.length > 3 && row[3]?.value != null
                      ? row[3]!.value.toString().replaceAll('"', '').trim()
                      : '',
                });
                importedCount++;
              } else {
                skippedCount++; // Catat jika NIK kosong/duplikat
              }
            }
          }

          await _loadDataAndCompare();

          if (mounted) {
            String message = 'Berhasil mengimpor $importedCount data anggota dari file';
            if (skippedCount > 0) {
              message += ' ($skippedCount NIK kosong/duplikat dilewati)';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

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