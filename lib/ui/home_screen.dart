import 'package:flutter/material.dart';
import '../services/gemini_service.dart'; // Service untuk memanggil AI
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Menyimpan daftar tugas dalam bentuk List of Map
  final List<Map<String, dynamic>> tasks = [];
  // Controller untuk mengambil input dari TextField
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority; // Menyimpan nilai dropdown
  bool isLoading = false; // Status loading saat proses AI berjalan

  @override
  void dispose() {
    // Controller harus dibersihkan agar tidak memory leak
    taskController.dispose();
    durationController.dispose();
    super.dispose();
  }

  void _addTask() {
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
        });
      });
      taskController.clear();
      durationController.clear();
      setState(() => priority = null);
    }
  }

  Future<void> _generateSchedule() async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Harap tambahkan tugas dulu!")),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getColor(String value) {
    switch (value) {
      case "Tinggi":
        return Colors.red;
      case "Sedang":
        return Colors.orange;
      case "Rendah":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Schedule Generator")),
      body: Column(
        children: [
          // FORM INPUT TUGAS
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      labelText: "Nama Tugas",
                      prefixIcon: Icon(Icons.task),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Input durasi
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Durasi (Menit)",
                            prefixIcon: Icon(Icons.timer),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Dropdown prioritas
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(
                            labelText: "Prioritas",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                          items: ["Tinggi", "Sedang", "Rendah"]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => priority = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tombol tambah tugas
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah ke Daftar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // LIST TUGAS
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      "Belum ada tugas.\nTambahkan tugas di atas!",
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskName = (task['name'] ?? '').toString();
                      final taskPriority = (task['priority'] ?? '').toString();
                      final taskDuration = task['duration'];
                      return Dismissible(
                        key: Key(taskName),
                        background: Container(color: Colors.red),
                        onDismissed: (_) =>
                            setState(() => tasks.removeAt(index)),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getColor(taskPriority),
                              child: Text(
                                taskName.isNotEmpty
                                    ? taskName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              taskName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${taskDuration ?? '-'} Menit • $taskPriority",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => tasks.removeAt(index)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // FAB GENERATE AI
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _generateSchedule,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(isLoading ? "Memproses..." : "Buat Jadwal AI"),
      ),
    );
  }
}