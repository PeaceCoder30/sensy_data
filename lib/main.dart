import 'dart:async';
import 'dart:io';
import 'package:flutter_application_1/file_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  // Ensure cameras are initialized
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensors Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0x9f4376f8),
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page', camera: camera),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String? title;
  final CameraDescription camera;

  const MyHomePage({super.key, this.title, required this.camera});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Sensors Plus Example'),
        elevation: 4,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CameraScreen(camera: camera),
              ),
            );
          },
          child: const Text('Open Camera'),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const Duration _ignoreDuration = Duration(milliseconds: 20);

  UserAccelerometerEvent? _userAccelerometerEvent;
  AccelerometerEvent? _accelerometerEvent;
  GyroscopeEvent? _gyroscopeEvent;

  DateTime? _userAccelerometerUpdateTime;
  DateTime? _accelerometerUpdateTime;
  DateTime? _gyroscopeUpdateTime;

  int? _userAccelerometerLastInterval;
  int? _accelerometerLastInterval;
  int? _gyroscopeLastInterval;

  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  final List<List<dynamic>> _sensorData = [];
  bool _isRecording = false;

  Duration sensorInterval = SensorInterval.normalInterval;

  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _cameraController!.initialize();
    _initializeSensors();
  }

  void _initializeSensors() {
    _streamSubscriptions.add(
      userAccelerometerEventStream(samplingPeriod: sensorInterval).listen(
        (UserAccelerometerEvent event) {
          final now = event.timestamp;
          setState(() {
            _userAccelerometerEvent = event;
            if (_userAccelerometerUpdateTime != null) {
              final interval = now.difference(_userAccelerometerUpdateTime!);
              if (interval > _ignoreDuration) {
                _userAccelerometerLastInterval = interval.inMilliseconds;
              }
            }
          });
          _userAccelerometerUpdateTime = now;
          if (_isRecording) {
            _sensorData.add([
              now.toIso8601String(),
              'UserAccelerometer',
              event.x,
              event.y,
              event.z,
            ]);
          }
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support User Accelerometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
    _streamSubscriptions.add(
      accelerometerEventStream(samplingPeriod: sensorInterval).listen(
        (AccelerometerEvent event) {
          final now = event.timestamp;
          setState(() {
            _accelerometerEvent = event;
            if (_accelerometerUpdateTime != null) {
              final interval = now.difference(_accelerometerUpdateTime!);
              if (interval > _ignoreDuration) {
                _accelerometerLastInterval = interval.inMilliseconds;
              }
            }
          });
          _accelerometerUpdateTime = now;
          if (_isRecording) {
            _sensorData.add([
              now.toIso8601String(),
              'Accelerometer',
              event.x,
              event.y,
              event.z,
            ]);
          }
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Accelerometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEventStream(samplingPeriod: sensorInterval).listen(
        (GyroscopeEvent event) {
          final now = event.timestamp;
          setState(() {
            _gyroscopeEvent = event;
            if (_gyroscopeUpdateTime != null) {
              final interval = now.difference(_gyroscopeUpdateTime!);
              if (interval > _ignoreDuration) {
                _gyroscopeLastInterval = interval.inMilliseconds;
              }
            }
          });
          _gyroscopeUpdateTime = now;
          if (_isRecording) {
            _sensorData.add([
              now.toIso8601String(),
              'Gyroscope',
              event.x,
              event.y,
              event.z,
            ]);
          }
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Gyroscope Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
    _cameraController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Screen'),
        elevation: 4,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: CameraPreview(_cameraController!),
                ),
                ElevatedButton(
                  onPressed: _toggleRecording,
                  child:
                      Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<Uint8List> getVideoBytes(String videoPath) async {
    final file = File(videoPath);
    return await file.readAsBytes(); // Read the file as a list of bytes
  }

  void processVideo(String videoPath) async {
    try {
      // Get video bytes
      Uint8List videoBytes = await getVideoBytes(videoPath);

      // If you just need the bytes, you can use `videoBytes` directly
      print("Video bytes length: ${videoBytes.length}");

      FileStorage.writeCounter(
          videoBytes.toString(), "${DateTime.now().millisecondsSinceEpoch}.mp4");
    } catch (e) {
      print("Error processing video: $e");
    }
  }

  void _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final file1 = await _cameraController!.stopVideoRecording();
      final path = file1.path;
      processVideo(path);      
      _saveDataToCSV();
      setState(() {
        _isRecording = false;
      });
    } else {
      // Start recording
      // final directory = await getExternalStorageDirectory();
      // final videoPath =
      //     '${directory!.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
      // print("videoPath: $videoPath");
      await _cameraController!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _videoPath = FileStorage.getExternalDocumentPath() as String?;
      });
    }
  }

  void _saveDataToCSV() async {
    List<List<dynamic>> rows = [
      ['Timestamp', 'Sensor', 'X', 'Y', 'Z'],
      ..._sensorData,
    ];

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/sensor_data.csv';
    final file = File(path);

    await file.writeAsString(csvData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data saved to $path')),
    );
  }
}
