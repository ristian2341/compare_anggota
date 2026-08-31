import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows or Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (Platform.isWindows) {
      // Jika di Windows, simpan di folder 'database' relatif terhadap lokasi executable
      // Saat development (debug), ini akan berada di root project
      path = join(Directory.current.path, 'database', 'anggota_database.db');
      
      // Pastikan folder database ada
      final dbDir = Directory(join(Directory.current.path, 'database'));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
    } else {
      // Untuk Android/iOS tetap gunakan standar path aplikasi
      path = join(await getDatabasesPath(), 'anggota_database.db');
    }

    print("Lokasi Database: $path");

    return await openDatabase(
      path,
      version: 2, // 1. Naikkan versi ke 3
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        print("Mendeteksi upgrade dari versi $oldVersion ke $newVersion");
        await _onCreate(db, newVersion);
      },
      onOpen: (db) async {
        // Jalankan pengecekan kolom setiap kali database dibuka
        await _checkAndAddColumns(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print("Menjalankan _onCreate...");
      // Table User
      await db.execute('''
      CREATE TABLE IF NOT EXISTS user (
        id_user INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_user TEXT,
        password TEXT
      )
    ''');

      // Table Data Anggota
      await db.execute('''
      CREATE TABLE IF NOT EXISTS data_anggota (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_nik TEXT,
        barcode TEXT,
        nama_anggota TEXT
      )
    ''');

      // Table Data Karyawan
      await db.execute('''
      CREATE TABLE IF NOT EXISTS data_karyawan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nik TEXT,
        nama_karyawan TEXT,
        area_kerja TEXT,
        status TEXT,
        tgl_kontrak TEXT
      )
    ''');

      // Table Setting
      await db.execute('''
      CREATE TABLE IF NOT EXISTS setting (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        link_data_anggota TEXT,
        link_data_karyawan TEXT
      )
    ''');

      // Table Status
      await db.execute('''
      CREATE TABLE IF NOT EXISTS status (
        code TEXT PRIMARY KEY,
        status TEXT
      ) 
    ''');

      // Table Input Jenis Kelamin
      await db.execute('''
      CREATE TABLE IF NOT EXISTS data_jen_kel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bulan TEXT,
        tahun TEXT,
        jumlah_laki INTEGER,
        jumlah_perempuan INTEGER
      )
    ''');

      // Insert default user (Abaikan jika data sudah ada)
      await db.insert(
        'user',
        {
          'nama_user': 'admin',
          'password': 'P@ssw0rd',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Insert default setting row (Abaikan jika ID 1 sudah ada)
      await db.insert(
        'setting',
        {
          'id': 1,
          'link_data_anggota': 'https://docs.google.com/spreadsheets/d/1IC7IBXQEjRX9a-HAIChOJPijwKa_nwJ25gzZWJm163o/edit?usp=drivesdk',
          'link_data_karyawan': 'https://docs.google.com/spreadsheets/d/1AKaZQgwJKf7Nz6AxwyEtxZJy0zJWvUkXIZ--mR8VW80/edit?usp=drivesdk',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
  }

  // --- SETTING METHODS ---
  Future<Map<String, dynamic>?> getSettings() async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query('setting', where: 'id = 1');
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> updateSettings(String linkAnggota, String linkKaryawan) async {
    Database db = await database;
    return await db.update(
      'setting',
      {
        'link_data_anggota': linkAnggota,
        'link_data_karyawan': linkKaryawan,
      },
      where: 'id = 1',
    );
  }

  // --- USER METHODS ---
  Future<int> insertUser(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('user', row);
  }

  Future<List<Map<String, dynamic>>> queryAllUsers() async {
    Database db = await database;
    return await db.query('user');
  }

  Future<int> updateUser(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id_user'];
    return await db.update('user', row, where: 'id_user = ?', whereArgs: [id]);
  }

  Future<int> deleteUser(int id) async {
    Database db = await database;
    return await db.delete('user', where: 'id_user = ?', whereArgs: [id]);
  }

  // --- DATA ANGGOTA METHODS ---
  Future<int> insertAnggota(Map<String, dynamic> row) async {
    Database db = await database;

    return await db.insert(
      'data_anggota',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> queryAllAnggota() async {
    Database db = await database;
    return await db.query('data_anggota');
  }

  Future<int> deleteAllAnggota() async {
    Database db = await database;
    int result = await db.delete('data_anggota');
    await db.execute("DELETE FROM sqlite_sequence WHERE name = 'data_anggota'");
    return result;
  }

  // --- DATA KARYAWAN METHODS ---
  Future<int> insertKaryawan(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(
        'data_karyawan',
        row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

  }

  Future<List<Map<String, dynamic>>> queryAllKaryawan() async {
    Database db = await database;
    return await db.query('data_karyawan');
  }

  Future<int> deleteAllKaryawan() async {
    Database db = await database;
    int result = await db.delete('data_karyawan');
    await db.execute("DELETE FROM sqlite_sequence WHERE name = 'data_karyawan'");
    return result;
  }

  // Auth function
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'user',
      where: 'nama_user = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Mengambil jumlah total karyawan per area_kerja
  Future<List<Map<String, dynamic>>> queryGroupedByArea() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
          dk.area_kerja,
          COUNT(dk.nik) AS total_karyawan,
          COUNT(CASE WHEN da.nomor_nik IS NOT NULL THEN 1 END) AS total_anggota,
          COUNT(CASE WHEN da.nomor_nik IS NULL THEN 1 END) AS total_non_anggota
      FROM data_karyawan dk
      LEFT JOIN data_anggota da ON (dk.nik = da.nomor_nik)
      group by dk.area_kerja
      ORDER BY total_anggota asc;
    ''');
  }

  /// ambil data Input jumlah jenis kelamin ///
  Future<List<Map<String, dynamic>>> getDataJenKel({String? query}) async {
    Database db = await database;
    if (query != null && query.isNotEmpty) {
      return await db.query(
        'data_jen_kel',
        where: 'bulan LIKE ? OR tahun LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
    }
    return await db.query('data_jen_kel');
  }

  Future<int> insertJenKel(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('data_jen_kel', row);
  }

  Future<int> updateJenKel(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('data_jen_kel', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteJenKel(int id) async {
    Database db = await database;
    return await db.delete('data_jen_kel', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> queryAllDataJenKel() async {
    Database db = await database;
    return await db.query('data_jen_kel');
  }

  Future<Map<String, dynamic>?> queryLatestDataJenKel() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'data_jen_kel', // Sesuaikan dengan nama tabel Anda
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
  
  Future<List<Map<String, dynamic>>> queryCompareAnggota() async {
    Database db = await database;
    String sql = ''' select dk.nik,da.nama_anggota,dk.status,dk.tgl_berhenti from data_karyawan dk inner join data_anggota da on(dk.nik = da.nomor_nik) order by dk.nik ''';
    return await db.rawQuery(sql);
  }

  Future<void> _checkAndAddColumns(Database db) async {
    // 1. Ambil semua informasi kolom dari tabel 'data_karyawan'
    List<Map<String, dynamic>> columns = await db.rawQuery("PRAGMA table_info(data_karyawan)");

    // 2. Ekstrak nama-nama kolom ke dalam List String
    List<String> existingColumns = columns.map((c) => c['name'].toString()).toList();

    // 3. Cek dan tambah kolom 'status' jika belum ada
    if (!existingColumns.contains('status')) {
      await db.execute("ALTER TABLE data_karyawan ADD COLUMN status TEXT;");
    }

    // 4. Cek dan tambah kolom 'tgl_berhenti' (atau 'tgl_kontrak') jika belum ada
    if (!existingColumns.contains('tgl_berhenti')) {
      await db.execute("ALTER TABLE data_karyawan ADD COLUMN tgl_berhenti TEXT;");
    }

    // 5. cek tabel 'data_jen_kel Table Input Jenis Kelamin
    await db.execute('''
      CREATE TABLE IF NOT EXISTS data_jen_kel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bulan TEXT,
        tahun TEXT,
        jumlah_laki INTEGER,
        jumlah_perempuan INTEGER
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> queryDataCount() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
          dk.area_kerja,
          COUNT(dk.nik) AS total_karyawan,
          COUNT(CASE WHEN da.nomor_nik IS NOT NULL THEN 1 END) AS total_anggota,
          COUNT(CASE WHEN da.nomor_nik IS NULL THEN 1 END) AS total_non_anggota,
          (COUNT(CASE WHEN da.nomor_nik IS NULL THEN 1 END) - COUNT(CASE WHEN da.nomor_nik IS NOT NULL THEN 1 END)) AS total
      FROM data_karyawan dk
      LEFT JOIN data_anggota da ON (dk.nik = da.nomor_nik)
      GROUP BY dk.area_kerja
      ORDER BY total DESC, total_anggota ASC, total_non_anggota DESC;
    ''');
  }

  Future<List<Map<String, dynamic>>> queryDataKaryawanAnggota() async {
    Database db = await database;
    return await db.rawQuery(''' 
       SELECT dk.*,(case when da.nomor_nik is not null then 'YES' else 'NO' end) anggota
        FROM data_karyawan dk
        LEFT JOIN data_anggota da ON (dk.nik = da.nomor_nik)
        GROUP BY dk.nik
        ORDER BY CAST(dk.nik AS integer)
    ''');
  }
}
