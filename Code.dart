import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const StopwatchTimerApp());
}

class StopwatchTimerApp extends StatelessWidget {
  const StopwatchTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stopwatch & Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // STOPWATCH
  final Stopwatch stopwatch = Stopwatch();
  Timer? stopwatchTimer;
  List<String> lapHistory = [];
  int lapNumber = 0;

  // DEVICE ALARM SOUND
  final AudioPlayer alarmPlayer = AudioPlayer();
  String? selectedAlarmPath;
  String? selectedAlarmName;

  // TIMER
  Timer? countdownTimer;
  int remainingSeconds = 0;
  bool timerRunning = false;

  final TextEditingController hoursController =
      TextEditingController(text: '0');
  final TextEditingController minutesController =
      TextEditingController(text: '5');
  final TextEditingController secondsController =
      TextEditingController(text: '0');

  // STOPWATCH FUNCTIONS
  void startStopwatch() {
    stopwatch.start();
    stopwatchTimer?.cancel();
    stopwatchTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (mounted) setState(() {});
      },
    );
    setState(() {});
  }

  void pauseStopwatch() {
    stopwatch.stop();
    stopwatchTimer?.cancel();
    setState(() {});
  }

  void resetStopwatch() {
    stopwatch.stop();
    stopwatch.reset();
    stopwatchTimer?.cancel();
    setState(() {
      lapHistory.clear();
      lapNumber = 0;
    });
  }

  void addLap() {
    if (!stopwatch.isRunning) return;
    lapNumber++;
    final currentTime = formatStopwatchTime();
    setState(() {
      lapHistory.insert(0, 'Lap $lapNumber     $currentTime');
    });
  }

  String formatStopwatchTime() {
    final milliseconds = stopwatch.elapsedMilliseconds;
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds ~/ 60000) % 60;
    final seconds = (milliseconds ~/ 1000) % 60;
    final hundredths = (milliseconds ~/ 10) % 100;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}';
  }

  // DEVICE ALARM SOUND FUNCTIONS
  Future<void> chooseAlarmSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedAlarmPath = result.files.single.path;
          selectedAlarmName = result.files.single.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected alarm: $selectedAlarmName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select audio file: $e')),
        );
      }
    }
  }

  Future<void> playAlarmSound() async {
    if (selectedAlarmPath == null) return;
    try {
      await alarmPlayer.stop();
      await alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await alarmPlayer.play(DeviceFileSource(selectedAlarmPath!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play alarm sound: $e')),
        );
      }
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await alarmPlayer.stop();
    } catch (_) {}
  }

  // TIMER FUNCTIONS
  int getTimerInputSeconds() {
    int hours = int.tryParse(hoursController.text) ?? 0;
    int minutes = int.tryParse(minutesController.text) ?? 0;
    int seconds = int.tryParse(secondsController.text) ?? 0;

    hours = hours < 0 ? 0 : hours;
    minutes = minutes < 0 ? 0 : minutes;
    seconds = seconds < 0 ? 0 : seconds;

    return (hours * 3600) + (minutes * 60) + seconds;
  }

  void setTimer() {
    if (timerRunning) return;

    final totalSeconds = getTimerInputSeconds();
    if (totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a timer greater than 0.'),
        ),
      );
      return;
    }

    setState(() {
      remainingSeconds = totalSeconds;
    });
  }

  void startTimer() {
    if (remainingSeconds <= 0) {
      remainingSeconds = getTimerInputSeconds();
    }

    if (remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a timer first.')),
      );
      return;
    }

    countdownTimer?.cancel();
    setState(() {
      timerRunning = true;
    });

    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (remainingSeconds > 0) {
          setState(() {
            remainingSeconds--;
          });

          if (remainingSeconds == 0) {
            timer.cancel();
            setState(() {
              timerRunning = false;
            });
            playAlarmSound();
            showTimerFinishedDialog();
          }
        } else {
          timer.cancel();
          setState(() {
            timerRunning = false;
          });
          playAlarmSound();
          showTimerFinishedDialog();
        }
      },
    );
  }

  void pauseTimer() {
    countdownTimer?.cancel();
    setState(() {
      timerRunning = false;
    });
  }

  void resetTimer() {
    countdownTimer?.cancel();
    setState(() {
      timerRunning = false;
      remainingSeconds = 0;
    });
  }

  String formatTimerTime() {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // TIMER FINISHED DIALOG
  void showTimerFinishedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue),
              SizedBox(width: 10),
              Text('Timer Finished'),
            ],
          ),
          content: const Text('Your countdown timer has finished!'),
          actions: [
            TextButton(
              onPressed: () {
                stopAlarmSound();
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    stopwatchTimer?.cancel();
    countdownTimer?.cancel();
    hoursController.dispose();
    minutesController.dispose();
    secondsController.dispose();
    alarmPlayer.dispose();
    super.dispose();
  }

  // NAVIGATION
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stopwatch & Timer',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: selectedTab == 0 ? buildStopwatch() : buildTimer(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        selectedItemColor: Colors.blue,
        onTap: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Stopwatch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_bottom),
            label: 'Timer',
          ),
        ],
      ),
    );
  }

  // STOPWATCH UI
  Widget buildStopwatch() {
    return Column(
      children: [
        const SizedBox(height: 25),
        const Icon(Icons.timer, size: 65, color: Colors.blue),
        const SizedBox(height: 10),
        const Text(
          'STOPWATCH',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(blurRadius: 10, color: Colors.black12),
            ],
          ),
          child: Text(
            formatStopwatchTime(),
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: stopwatch.isRunning ? pauseStopwatch : startStopwatch,
              icon: Icon(stopwatch.isRunning ? Icons.pause : Icons.play_arrow),
              label: Text(stopwatch.isRunning ? 'Pause' : 'Start'),
            ),
            ElevatedButton.icon(
              onPressed: addLap,
              icon: const Icon(Icons.flag),
              label: const Text('Lap'),
            ),
            ElevatedButton.icon(
              onPressed: resetStopwatch,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lap History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (lapHistory.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      lapHistory.clear();
                      lapNumber = 0;
                    });
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: lapHistory.isEmpty
              ? const Center(
                  child: Text(
                    'No laps recorded yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: lapHistory.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.flag, color: Colors.white),
                        ),
                        title: Text(
                          lapHistory[index],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.timer, color: Colors.blue),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TIMER UI
  Widget buildTimer() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.hourglass_bottom, size: 70, color: Colors.blue),
              const SizedBox(height: 15),
              const Text(
                'COUNTDOWN TIMER',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Set Timer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildTimeInput(hoursController, 'Hours'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      ':',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                  buildTimeInput(minutesController, 'Minutes'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      ':',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                  buildTimeInput(secondsController, 'Seconds'),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: timerRunning ? null : setTimer,
                icon: const Icon(Icons.check),
                label: const Text('Set Timer'),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(blurRadius: 10, color: Colors.black12),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TIME REMAINING',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text(
                        formatTimerTime(),
                        style: const TextStyle(
                          fontSize: 55,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 15,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: timerRunning ? pauseTimer : startTimer,
                    icon: Icon(timerRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(timerRunning ? 'Pause' : 'Start'),
                  ),
                  ElevatedButton.icon(
                    onPressed: resetTimer,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              OutlinedButton.icon(
                onPressed: chooseAlarmSound,
                icon: const Icon(Icons.library_music),
                label: Text(
                  selectedAlarmName == null
                      ? 'Choose Alarm Sound from Device'
                      : 'Sound: $selectedAlarmName',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Selected sound plays when timer ends',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TIME INPUT
  Widget buildTimeInput(TextEditingController controller, String label) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        enabled: !timerRunning,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          final number = int.tryParse(value);
          if (number == null && value.isNotEmpty) {
            controller.text = '0';
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        },
      ),
    );
  }
}
