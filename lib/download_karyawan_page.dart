import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';

class DownloadKaryawanPage extends StatefulWidget {
  const DownloadKaryawanPage({super.key});

  @override
  State<DownloadKaryawanPage> createState() => _DownloadKaryawanPageState();
}

class _DownloadKaryawanPageState extends State<DownloadKaryawanPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isProcessing = false;
  int _totalData = 0;

  @override
  void initState() {
    super.initState();
    _countCurrentData();
  }

  Future<void> _countCurrentData() async {
    final data = await _dbHelper.queryAllKaryawan();
    setState(() {
      _totalData = data.length;
    });
  }

  Future<void> _importFromUrl() async {
    setState(() => _isProcessing = true);
    try {
      final settings = await _dbHelper.getSettings();
      final url = settings?['link_data_karyawan'];

      if (url == null || url.isEmpty) {
        throw 'Link URL belum diatur di menu Setting (Sign In)';
      }

      // Convert Google Sheets Link to CSV Export link if needed
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
        await _dbHelper.deleteAllKaryawan();

        int importedCount = 0;
        // Skip header
        for (int i = 1; i < lines.length; i++) {
          final columns = lines[i].split(',');
          if (columns.length >= 4) {
            await _dbHelper.insertKaryawan({
              'nik': columns[1].trim(),
              'nama_karyawan': columns[3].trim(),
              'area_kerja': columns[4].trim(),
            });
            importedCount++;
          }
        }
        await _countCurrentData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil mengimpor $importedCount data karyawan dari URL')),
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
          
          await _dbHelper.deleteAllKaryawan();
          int importedCount = 0;

          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table];
            if (sheet == null) continue;
            
            for (int i = 1; i < sheet.maxRows; i++) {
              var row = sheet.row(i);
              if (row.length >= 3) {
                await _dbHelper.insertKaryawan({
                  'nik': row[0]?.value.toString() ?? '',
                  'nama_karyawan': row[1]?.value.toString() ?? '',
                  'area_kerja': row[2]?.value.toString() ?? '',
                });
                importedCount++;
              }
            }
          }

          await _countCurrentData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Berhasil mengimpor $importedCount data karyawan dari file')),
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
        title: const Text('Download Data Karyawan'),
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

                  /// HEADER
                  Column(
                    children: const [
                      Icon(Icons.file_download, size: 60, color: Colors.teal),
                      SizedBox(height: 12),
                      Text(
                        'Download Data Karyawan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// TOTAL DATA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Data Karyawan Saat Ini',
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

                  /// LOADING / BUTTON
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          child: Row(
                            children: const [
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

                    const SizedBox(height: 16),
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
