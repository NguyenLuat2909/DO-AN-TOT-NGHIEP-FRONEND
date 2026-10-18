import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class StudentReflectionScreen extends StatefulWidget {
  final ApiService api;
  final int? courseId;
  final String? courseName;

  const StudentReflectionScreen({
    super.key,
    required this.api,
    this.courseId,
    this.courseName,
  });

  @override
  State<StudentReflectionScreen> createState() => _StudentReflectionScreenState();
}

class _StudentReflectionScreenState extends State<StudentReflectionScreen> {
  List<Map<String, dynamic>> _reflections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReflections();
  }

  Future<void> _loadReflections() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.api.getReflections(courseId: widget.courseId);
      setState(() => _reflections = data);
    } catch (e) {
      debugPrint('Failed to load reflections: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final TextEditingController contentController = TextEditingController();
    int understandingLevel = 3;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm nhật ký tự đánh giá'),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Bạn đã học được gì? (Ghi chú)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('Mức độ hiểu bài:'),
                  Slider(
                    value: understandingLevel.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: understandingLevel.toString(),
                    onChanged: (val) {
                      setDialogState(() => understandingLevel = val.toInt());
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Kém', style: TextStyle(fontSize: 12)),
                      Text('Tốt', style: TextStyle(fontSize: 12)),
                    ],
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
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    Navigator.pop(context);
                    await widget.api.addReflection(
                      content,
                      understandingLevel,
                      courseId: widget.courseId,
                    );
                    _loadReflections();
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
        title: Text(widget.courseName != null ? 'Nhật ký: ${widget.courseName}' : 'Nhật ký tự đánh giá'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reflections.isEmpty
              ? const Center(child: Text('Chưa có nhật ký nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reflections.length,
                  itemBuilder: (context, index) {
                    final item = _reflections[index];
                    final date = DateTime.tryParse(item['created_at'] ?? '');
                    final dateString = date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item['content'] ?? ''),
                        subtitle: Text('Ngày: $dateString'),
                        trailing: CircleAvatar(
                          backgroundColor: _getColor(item['understanding_level']),
                          child: Text(
                            '${item['understanding_level'] ?? '?'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ghi chép'),
      ),
    );
  }

  Color _getColor(dynamic level) {
    if (level == null) return Colors.grey;
    final intl = int.tryParse(level.toString()) ?? 0;
    if (intl <= 2) return Colors.red;
    if (intl == 3) return Colors.orange;
    return Colors.green;
  }
}
