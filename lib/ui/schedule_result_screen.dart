import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/auth_service.dart';
import '../services/calendar_service.dart';

class ScheduleResultScreen extends StatefulWidget {
  final String scheduleResult;
  final List<Map<String, dynamic>> tasks;

  const ScheduleResultScreen({
    super.key,
    required this.scheduleResult,
    required this.tasks,
  });

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen> {
  bool isSyncing = false;
  String selectedCalendarId = 'primary';
  String selectedCalendarName = 'Primary Calendar';

  Future<void> _showCalendarPicker() async {
    final user = AuthService.currentUser;
    if (user == null || !user.isGoogleUser) {
      _showErrorDialog(
        "Fitur ini hanya tersedia jika Anda masuk menggunakan Google Account.",
      );
      return;
    }
    try {
      // Show loading while fetching calendars
      _showLoadingDialog('Mengambil daftar kalender...');
      final calendars = await CalendarService.getCalendarList();
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.indigo),
              SizedBox(width: 10),
              Text("Pilih Kalender"),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: calendars.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final cal = calendars[index];
                final isSelected = selectedCalendarId == cal.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Colors.indigo
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.event,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  title: Text(
                    cal.summary ?? 'Tanpa Nama',
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    cal.id == 'primary' ? 'Kalender Utama' : 'Kalender Custom',
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.indigo)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedCalendarId = cal.id ?? 'primary';
                      selectedCalendarName = cal.summary ?? 'Primary Calendar';
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showErrorDialog("Gagal mengambil daftar kalender: $e");
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToCalendar() async {
    final user = AuthService.currentUser;
    if (user == null || !user.isGoogleUser) {
      _showErrorDialog(
        "Fitur ini hanya tersedia jika Anda masuk menggunakan Google Account.",
      );
      return;
    }

    final events = CalendarService.parseMarkdown(widget.scheduleResult);
    if (events.isEmpty) {
      _showErrorDialog("Tidak ada jadwal yang valid untuk diekspor.");
      return;
    }

    setState(() => isSyncing = true);
    _showLoadingDialog('Sedang mengekspor ke $selectedCalendarName...');

    try {
      await CalendarService.exportEventsToCalendar(
        events,
        calendarId: selectedCalendarId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Berhasil disinkronkan ke Google Calendar!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      _showErrorDialog("Gagal sinkron: $e");
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Hasil Jadwal Optimal"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            tooltip: "Pilih Kalender",
            onPressed: isSyncing ? null : _showCalendarPicker,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Salin Jadwal",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.scheduleResult));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Jadwal berhasil disalin!")),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.indigo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Mengekspor ke: $selectedCalendarName",
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: isSyncing ? null : _showCalendarPicker,
                      child: const Text("Ganti"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Markdown(
                      data: widget.scheduleResult,
                      selectable: true,
                      padding: const EdgeInsets.all(20),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigoAccent,
                        ),
                        tableBorder: TableBorder.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        tableHeadAlign: TextAlign.center,
                        tablePadding: const EdgeInsets.all(8),
                        tableHead: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isSyncing ? null : _syncToCalendar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        isSyncing ? "Menyinkronkan..." : "Export ke Calendar",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
