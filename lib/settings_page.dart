import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _linkAnggotaController = TextEditingController();
  final TextEditingController _linkKaryawanController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _dbHelper.getSettings();
      if (settings != null) {
        setState(() {
          _linkAnggotaController.text = settings['link_data_anggota'] ?? '';
          _linkKaryawanController.text = settings['link_data_karyawan'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e. Coba hapus database lama.')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    await _dbHelper.updateSettings(
      _linkAnggotaController.text,
      _linkKaryawanController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konfigurasi disimpan')),
    );
  }

  Future<void> _exportData(String type) async {
    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      if (type == 'Data Anggota') {
        final data = await _dbHelper.queryAllAnggota();
        // Header
        sheetObject.appendRow([
          TextCellValue('nomor_nik'),
          TextCellValue('barcode'),
          TextCellValue('nama_anggota')
        ]);
        for (var row in data) {
          sheetObject.appendRow([
            TextCellValue(row['nomor_nik']?.toString() ?? ''),
            TextCellValue(row['barcode']?.toString() ?? ''),
            TextCellValue(row['nama_anggota']?.toString() ?? ''),
          ]);
        }
      } else {
        final data = await _dbHelper.queryAllKaryawan();
        // Header
        sheetObject.appendRow([
          TextCellValue('nik'),
          TextCellValue('nama_karyawan'),
          TextCellValue('area_kerja')
        ]);
        for (var row in data) {
          sheetObject.appendRow([
            TextCellValue(row['nik']?.toString() ?? ''),
            TextCellValue(row['nama_karyawan']?.toString() ?? ''),
            TextCellValue(row['area_kerja']?.toString() ?? ''),
          ]);
        }
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Hasil Export $type',
        fileName: 'export_${type.toLowerCase().replaceAll(' ', '_')}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        var fileBytes = excel.save();
        if (fileBytes != null) {
          File(outputFile)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Berhasil export ke: $outputFile')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile(String type) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        if (await file.exists()) {
          var bytes = file.readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);
          
          int importedCount = 0;

          if (type == 'Data Anggota') {
            await _dbHelper.deleteAllAnggota();
            for (var table in excel.tables.keys) {
              var sheet = excel.tables[table];
              if (sheet == null) continue;
              for (int i = 1; i < sheet.maxRows; i++) {
                var row = sheet.row(i);
                if (row.length >= 3) {
                  await _dbHelper.insertAnggota({
                    'nomor_nik': row[0]?.value.toString() ?? '',
                    'barcode': row[1]?.value.toString() ?? '',
                    'nama_anggota': row[2]?.value.toString() ?? '',
                  });
                  importedCount++;
                }
              }
            }
          } else {
            // Data Karyawan
            await _dbHelper.deleteAllKaryawan();
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
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Berhasil mengimpor $importedCount $type')),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Pengaturan Data'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Simpan Semua',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDataCard(
                    title: 'Frame Data Anggota',
                    controller: _linkAnggotaController,
                    label: 'URL Google Sheet Anggota',
                    onUpload: () => _pickFile('Data Anggota'),
                    onExport: () => _exportData('Data Anggota'),
                  ),
                  const SizedBox(height: 20),
                  _buildDataCard(
                    title: 'Frame Data Karyawan',
                    controller: _linkKaryawanController,
                    label: 'URL Google Sheet Karyawan',
                    onUpload: () => _pickFile('Data Karyawan'),
                    onExport: () => _exportData('Data Karyawan'),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('SIMPAN SEMUA PERUBAHAN',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
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

  Widget _buildDataCard({
    required String title,
    required TextEditingController controller,
    required String label,
    required VoidCallback onUpload,
    required VoidCallback onExport,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(thickness: 1.5),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: 'Masukkan link google sheet...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('UPLOAD EXCEL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('EXPORT DATA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.teal.shade200),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _linkAnggotaController.dispose();
    _linkKaryawanController.dispose();
    super.dispose();
  }
}
