import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detection App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainActivity(),
    );
  }
}

class MainActivity extends StatefulWidget {
  const MainActivity({super.key});

  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  // Sensor data variables
  List<double> accelerometerData = [0, 0, 0];
  List<double> gyroscopeData = [0, 0, 0];

  // File and state variables
  File? file;
  int off = 0;
  int unixTimename = 0;
  Timer? dataTimer;
  double relTime = 0.0;
  DateTime? startTime;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? gyroscopeSubscription;

  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();

  // API service
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  @override
  void dispose() {
    // Cancel all subscriptions and timers
    accelerometerSubscription?.cancel();
    gyroscopeSubscription?.cancel();
    dataTimer?.cancel();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    // Request storage permission
    await Permission.storage.request();
  }

  void startRecording() async {
    setState(() {
      off = 0;
      unixTimename = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      relTime = 0.0;
      startTime = DateTime.now();
    });

    // Create CSV file
    final directory = await getExternalStorageDirectory();
    final seanDirectory = Directory('${directory?.path}/sean');
    if (!await seanDirectory.exists()) {
      await seanDirectory.create(recursive: true);
    }

    file = File('${seanDirectory.path}/output$unixTimename.csv');

    // Write CSV header
    const String entry =
        "timestamp,rel_time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z\n";
    await file?.writeAsString(entry, mode: FileMode.append);

    // Play start sound (using a placeholder)
    try {
      await audioPlayer.play(AssetSource('audio/startton.mp3'));
      await Future.delayed(const Duration(seconds: 5));
      await audioPlayer.play(AssetSource('audio/startton.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    // Start listening to sensors
    accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        accelerometerData = [event.x, event.y, event.z];
      });
    });

    gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        gyroscopeData = [event.x, event.y, event.z];
      });
    });

    // Start data collection timer
    dataTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (off == 1) {
        timer.cancel();
        return;
      }

      writeSensorData();
    });
  }

  void stopRecording() {
    setState(() {
      off = 1;
    });

    // Stop sensor listeners
    accelerometerSubscription?.cancel();
    gyroscopeSubscription?.cancel();

    // Stop timer
    dataTimer?.cancel();

    // Upload to API
    uploadToAPI();
  }

  void writeSensorData() async {
    if (startTime == null) return;

    final unixTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed =
        DateTime.now().difference(startTime!).inMilliseconds / 1000.0;

    setState(() {
      relTime = elapsed;
    });

    final String entry =
        "$unixTime,$elapsed,${accelerometerData[0]},${accelerometerData[1]},${accelerometerData[2]},"
        "${gyroscopeData[0]},${gyroscopeData[1]},${gyroscopeData[2]}\n";

    await file?.writeAsString(entry, mode: FileMode.append);
  }

  void uploadToAPI() async {
    if (file == null) return;

    try {
      final String fileContent = await file!.readAsString();
      final bool success = await apiService.uploadData(fileContent);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(success ? 'Success' : 'Error'),
            content: Text(success
                ? 'Data uploaded successfully to the server'
                : 'Failed to upload data to the server'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Upload error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Detection App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: startRecording,
              child: const Text('START'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: stopRecording,
              child: const Text('STOP'),
            ),
            const SizedBox(height: 20),
            Text('Recording: ${off == 0 ? 'ON' : 'OFF'}'),
            Text('Time: ${relTime.toStringAsFixed(2)}s'),
            Text(
                'Acc: ${accelerometerData.map((v) => v.toStringAsFixed(2)).join(", ")}'),
            Text(
                'Gyro: ${gyroscopeData.map((v) => v.toStringAsFixed(2)).join(", ")}'),
          ],
        ),
      ),
    );
  }
}

// Dummy API Service
class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  Future<bool> uploadData(String data) async {
    try {
      // Simulate API call
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'title': 'Fall Detection Data',
          'body': data.length > 100 ? '${data.substring(0, 100)}...' : data,
          'userId': 1,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint("API error: $e");
      return false;
    }
  }

  // Simulate fall detection analysis
  Future<Map<String, dynamic>> analyzeData(String data) async {
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Return mock analysis results
    return <String, dynamic>{
      'fallDetected': Random().nextDouble() > 0.7,
      'confidence': Random().nextDouble(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
