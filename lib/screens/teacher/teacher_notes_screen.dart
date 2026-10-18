import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TeacherNotesScreen extends StatefulWidget {
  final ApiService api;
  final int studentId;
  final String studentName;
  final int? courseId;

  const TeacherNotesScreen({
    super.key,
    required this.api,
    required this.studentId,
    required this.studentName,
    this.courseId,
  });

  @override
  State<TeacherNotesScreen> createState() => _TeacherNotesScreenState();
}

class _TeacherNotesScreenState extends State<TeacherNotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.api.getTeacherNotes(widget.studentId, courseId: widget.courseId);
      setState(() => _notes = data);
    } catch (e) {
      debugPrint('Failed to load notes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final TextEditingController noteController = TextEditingController();
    String status = 'active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm ghi chú hỗ trợ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú về tình hình sinh viên',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Đang theo dõi')),
                      DropdownMenuItem(value: 'resolved', child: Text('Đã giải quyết')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => status = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    final note = noteController.text.trim();
                    if (note.isEmpty) return;
                    Navigator.pop(context);
                    await widget.api.addTeacherNote(
                      widget.studentId,
                      note,
                      courseId: widget.courseId,
                      status: status,
                    );
                    _loadNotes();
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ghi chú: ${widget.studentName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text('Chưa có ghi chú nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (listContext, index) {
                    final item = _notes[index];
                    final date = DateTime.tryParse(item['created_at'] ?? '');
                    final dateString = date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : '';
                    final bool resolved = item['status'] == 'resolved';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          resolved ? Icons.check_circle : Icons.visibility,
                          color: resolved ? Colors.green : Colors.orange,
                        ),
                        title: Text(item['note'] ?? ''),
                        subtitle: Text('Trạng thái: ${resolved ? 'Đã giải quyết' : 'Đang theo dõi'} • Ngày: $dateString'),
                        trailing: IconButton(
                          icon: Icon(resolved ? Icons.undo : Icons.check),
                          tooltip: resolved ? 'Đánh dấu đang theo dõi' : 'Đánh dấu đã giải quyết',
                          onPressed: () async {
                            final noteId = item['id'];
                            if (noteId == null) return;
                            final newStatus = resolved ? 'active' : 'resolved';
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await widget.api.updateTeacherNoteStatus(noteId, newStatus);
                              _loadNotes();
                              messenger.showSnackBar(
                                SnackBar(content: Text(resolved ? 'Đã chuyển về Đang theo dõi' : 'Đã đánh dấu Đã giải quyết')),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Không thể cập nhật trạng thái')),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm ghi chú'),
      ),
    );
  }
}
