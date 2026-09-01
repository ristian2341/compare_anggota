import 'package:flutter/material.dart';
import 'database_helper.dart';

class JenisKelPage extends StatefulWidget {
  const JenisKelPage({super.key});

  @override
  State<JenisKelPage> createState() => _JenisKelPageState();
}

class _JenisKelPageState extends State<JenisKelPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  
  final TextEditingController _bulanController = TextEditingController();
  final TextEditingController _tahunController = TextEditingController();
  final TextEditingController _jmlLakiController = TextEditingController();
  final TextEditingController _jmlPerempuanController = TextEditingController();

  List<Map<String, dynamic>> _dataJenKel = [];
  bool _isLoading = true;

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _dbHelper.getDataJenKel(query: _searchController.text);
    setState(() {
      _dataJenKel = data;
      _isLoading = false;
    });
  }

  void _showForm([Map<String, dynamic>? item]) {
    String selectedBulan;
    if (item != null) {
      selectedBulan = item['bulan'];
      _bulanController.text = item['bulan'];
      _tahunController.text = item['tahun'];
      _jmlLakiController.text = item['jumlah_laki'].toString();
      _jmlPerempuanController.text = item['jumlah_perempuan'].toString();
    } else {
      final now = DateTime.now();
      selectedBulan = _months[now.month - 1];
      _bulanController.text = selectedBulan;
      _tahunController.text = now.year.toString();
      _jmlLakiController.clear();
      _jmlPerempuanController.clear();
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            item == null ? 'Tambah Data' : 'Edit Data',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBulan,
                  decoration: InputDecoration(
                    labelText: 'Bulan',
                    prefixIcon: const Icon(Icons.calendar_month, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _months.map((String month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(month),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        selectedBulan = newValue;
                        _bulanController.text = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tahunController,
                  decoration: InputDecoration(
                    labelText: 'Tahun',
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _jmlLakiController, 
                  decoration: InputDecoration(
                    labelText: 'Jumlah Laki-laki',
                    prefixIcon: const Icon(Icons.male, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _jmlPerempuanController, 
                  decoration: InputDecoration(
                    labelText: 'Jumlah Perempuan',
                    prefixIcon: const Icon(Icons.female, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final row = {
                  'bulan': _bulanController.text,
                  'tahun': _tahunController.text,
                  'jumlah_laki': int.tryParse(_jmlLakiController.text) ?? 0,
                  'jumlah_perempuan': int.tryParse(_jmlPerempuanController.text) ?? 0,
                };

                if (item == null) {
                  await _dbHelper.insertJenKel(row);
                } else {
                  await _dbHelper.updateJenKel({'id': item['id'], ...row});
                }

                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteData(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteJenKel(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Jenis Kelamin'),
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
            // 1. Search Data Card
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan Bulan atau Tahun...',
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
              ),
            ),

            // 2. Table Card (100% Width)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                      : ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth, // Memaksa lebar minimal 100% dari container
                              ),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
                                columnSpacing: 10, // Menyesuaikan jarak antar kolom
                                columns: const [
                                  DataColumn(label: Text('Bulan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                  DataColumn(label: Text('Tahun', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                  DataColumn(label: Text('Laki-laki', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                  DataColumn(label: Text('Perempuan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                  DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                ],
                                rows: _dataJenKel.isEmpty
                                    ? [
                                  const DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          'Data tidak ditemukan',
                                          style: TextStyle(color: Colors.teal, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                      DataCell(SizedBox.shrink()),
                                      DataCell(SizedBox.shrink()),
                                      DataCell(SizedBox.shrink()),
                                      DataCell(SizedBox.shrink()),
                                    ],
                                  )
                                ]
                                    : _dataJenKel.map((item) {
                                  return DataRow(cells: [
                                    DataCell(Text(item['bulan'] ?? '')),
                                    DataCell(Text(item['tahun'] ?? '')),
                                    DataCell(Text(item['jumlah_laki']?.toString() ?? '0')),
                                    DataCell(Text(item['jumlah_perempuan']?.toString() ?? '0')),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showForm(item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteData(item['id']),
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        color: Colors.teal.shade400,
        padding: const EdgeInsets.all(5.0),
        child: const Text(
          'create by Rtie Development @2026',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
