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
      version: 2, // Menaikkan versi dari 1 ke 2
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Jika user punya versi 1, tambahkan tabel setting yang belum ada
          await db.execute('''
            CREATE TABLE IF NOT EXISTS setting (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              link_data_anggota TEXT,
              link_data_karyawan TEXT
            )
          ''');
          
          await db.insert('setting', {
            'id': 1,
            'link_data_anggota': '',
            'link_data_karyawan': '',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table User
    await db.execute('''
      CREATE TABLE user (
        id_user INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_user TEXT,
        password TEXT
      )
    ''');

    // Table Data Anggota
    await db.execute('''
      CREATE TABLE data_anggota (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_nik TEXT,
        barcode TEXT,
        nama_anggota TEXT
      )
    ''');

    // Table Data Karyawan
    await db.execute('''
      CREATE TABLE data_karyawan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nik TEXT,
        nama_karyawan TEXT,
        area_kerja TEXT
      )
    ''');

    // Table Setting
    await db.execute('''
      CREATE TABLE setting (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        link_data_anggota TEXT,
        link_data_karyawan TEXT
      )
    ''');

    // Insert default users for testing
    await db.insert('user', {
      'nama_user': 'admin',
      'password': 'admin',
    });
    // ... rest of inserts ...
    await db.insert('user', {
      'nama_user': 'puk',
      'password': 'puk',
    });
    await db.insert('user', {
      'nama_user': 'user1',
      'password': 'password123',
    });

    // Insert default setting row
    await db.insert('setting', {
      'id': 1,
      'link_data_anggota': '',
      'link_data_karyawan': '',
    });
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
    return await db.insert('data_anggota', row);
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
    return await db.insert('data_karyawan', row);
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
}
