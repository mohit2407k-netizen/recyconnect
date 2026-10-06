import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineSyncManager {
  OfflineSyncManager._();

  static final OfflineSyncManager instance = OfflineSyncManager._();

  Database? _database;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ------------------------------------------------------------
  // DATABASE
  // ------------------------------------------------------------

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();

    final path = join(
      dbPath,
      'recyconnect_offline.db',
    );

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_lots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lot_id TEXT UNIQUE,
            lot_data TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  // ------------------------------------------------------------
  // INITIALIZE OFFLINE SYNC
  // ------------------------------------------------------------

  Future<void> initialize() async {
    await database;

    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen(
      (results) async {
        final hasInternet =
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.ethernet);

        if (hasInternet) {
          await syncPendingLots();
        }
      },
    );

    // Also try syncing when app starts.
    await syncPendingLots();
  }

  // ------------------------------------------------------------
  // SAVE LOT LOCALLY
  // ------------------------------------------------------------

  Future<void> saveLotLocally(
    Map<String, dynamic> lot,
  ) async {
    final db = await database;

    final lotId = lot['lotId']?.toString();

    if (lotId == null || lotId.isEmpty) {
      throw Exception('Lot ID is missing');
    }

    await db.insert(
      'offline_lots',
      {
        'lot_id': lotId,
        'lot_data': jsonEncode(lot),
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ------------------------------------------------------------
  // CHECK INTERNET
  // ------------------------------------------------------------

  Future<bool> hasInternet() async {
    final results = await Connectivity().checkConnectivity();

    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);
  }

  // ------------------------------------------------------------
  // SYNC PENDING LOTS
  // ------------------------------------------------------------

  Future<void> syncPendingLots() async {
    try {
      if (!await hasInternet()) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final db = await database;

      final pendingLots = await db.query(
        'offline_lots',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'id ASC',
      );

      if (pendingLots.isEmpty) {
        return;
      }

      for (final row in pendingLots) {
        try {
          final lotData = jsonDecode(
            row['lot_data'] as String,
          ) as Map<String, dynamic>;

          final lotId = lotData['lotId']?.toString();

          if (lotId == null || lotId.isEmpty) {
            continue;
          }

          // Add sync information.
          lotData['userId'] = user.uid;
          lotData['syncStatus'] = 'synced';
          lotData['syncedAt'] =
              FieldValue.serverTimestamp();

          // Use lotId as Firestore document ID.
          // This prevents duplicate documents.
          await FirebaseFirestore.instance
              .collection('lots')
              .doc(lotId)
              .set(
            lotData,
            SetOptions(merge: true),
          );

          // Mark local record as synced.
          await db.update(
            'offline_lots',
            {
              'synced': 1,
            },
            where: 'lot_id = ?',
            whereArgs: [lotId],
          );
        } catch (e) {
          // Keep the lot pending if sync fails.
          print(
            'Offline lot sync failed: $e',
          );
        }
      }
    } catch (e) {
      print(
        'Offline sync error: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // GET PENDING LOT COUNT
  // ------------------------------------------------------------

  Future<int> getPendingLotCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count '
      'FROM offline_lots '
      'WHERE synced = 0',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ------------------------------------------------------------
  // CLOSE DATABASE
  // ------------------------------------------------------------

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _database?.close();
    _database = null;
  }
}