import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class JenisKelPage extends StatefulWidget{
  const JenisKelPage({super.key});

  @override
  State<JenisKelPage> jenKelState() => _jenKelState();
}

class _jenKelState extends State<JenisKelPage>{
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _bulanController = TextEditingController();
  final TextEditingController _tahunController = TextEditingController();
  final TextEditingController _jmlLakiController = TextEditingController();
  final TextEditingController _jmlPerempuanController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
      super.initState();
      _loadDataJenkel();
    }
  }

  Future<void> _loadDataJenkel() async {
    try {
      final dataJenKel = await _dbHelper.getDataJenKel();
      if (dataJenKel != null) {

      } else {

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