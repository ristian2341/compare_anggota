import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File terpilih untuk $type: ${result.files.single.name}')),
        );
      }
      // TODO: Implement actual excel parsing and database insert
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
                  ),
                  const SizedBox(height: 20),
                  _buildDataCard(
                    title: 'Frame Data Karyawan',
                    controller: _linkKaryawanController,
                    label: 'URL Google Sheet Karyawan',
                    onUpload: () => _pickFile('Data Karyawan'),
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
    );
  }

  Widget _buildDataCard({
    required String title,
    required TextEditingController controller,
    required String label,
    required VoidCallback onUpload,
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text('UPLOAD DARI FILE EXCEL LOCAL'),
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
