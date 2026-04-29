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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isProcessing = true);
      try {
        var bytes = File(result.files.single.path!).readAsBytesSync();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Data Karyawan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Data Karyawan Saat Ini:',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '$_totalData',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: _importFromUrl,
                icon: const Icon(Icons.cloud_download),
                label: const Text('AMBIL DATA DARI URL SETTING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('ATAU')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _importFromFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('IMPORT DARI FILE EXPORT (EXCEL)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const Spacer(),
            const Text(
              '* Pastikan format Excel: Kolom A (NIK), Kolom B (Nama), Kolom C (Area)',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ],
        ),
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
}
