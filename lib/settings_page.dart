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
      debugPrint("Error loading settings: $e");
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
      const SnackBar(
        content: Text('Konfigurasi berhasil disimpan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportAllSettings() async {
    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      sheetObject.appendRow([
        TextCellValue('Tipe Data'),
        TextCellValue('URL Google Sheet'),
      ]);

      sheetObject.appendRow([
        TextCellValue('Data Anggota'),
        TextCellValue(_linkAnggotaController.text),
      ]);

      sheetObject.appendRow([
        TextCellValue('Data Karyawan'),
        TextCellValue(_linkKaryawanController.text),
      ]);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Konfigurasi URL',
        fileName: 'konfigurasi_url_settings.xlsx',
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
              SnackBar(content: Text('Berhasil export konfigurasi ke: $outputFile')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export konfigurasi: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportData(String type) async {
    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      if (type == 'Data Anggota') {
        final data = await _dbHelper.queryAllAnggota();
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
      appBar: AppBar(
        title: const Text('Pengaturan Data'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Konfigurasi URL',
            onPressed: _exportAllSettings,
          ),
        ],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        _buildDataCard(
                          title: 'Frame Data Anggota',
                          icon: Icons.people,
                          controller: _linkAnggotaController,
                          label: 'URL Google Sheet Anggota',
                          onUpload: () => _pickFile('Data Anggota'),
                          onExport: () => _exportData('Data Anggota'),
                        ),
                        const SizedBox(height: 20),
                        _buildDataCard(
                          title: 'Frame Data Karyawan',
                          icon: Icons.badge,
                          controller: _linkKaryawanController,
                          label: 'URL Google Sheet Karyawan',
                          onUpload: () => _pickFile('Data Karyawan'),
                          onExport: () => _exportData('Data Karyawan'),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _saveSettings,
                                icon: const Icon(Icons.save),
                                label: const Text(
                                  'SIMPAN PERUBAHAN',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.teal.shade800,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: ElevatedButton.icon(
                                onPressed: _exportAllSettings,
                                icon: const Icon(Icons.share),
                                label: const Text(
                                  'EXPORT URL',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: Container(
        color: Colors.teal.shade400,
        padding: const EdgeInsets.all(12.0),
        child: const Text(
          'create by Rtie Developer @2026',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String label,
    required VoidCallback onUpload,
    required VoidCallback onExport,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(thickness: 1),
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Masukkan link google sheet...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.teal.shade200),
              ),
              prefixIcon: const Icon(Icons.link, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('UPLOAD EXCEL', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                    side: BorderSide(color: Colors.teal.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  label: const Text('EXPORT DATA', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade50,
                    foregroundColor: Colors.teal.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.teal.shade100),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
