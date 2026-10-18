import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class StudentFlashcardScreen extends StatefulWidget {
  final ApiService api;
  final int courseId;
  final String courseName;

  const StudentFlashcardScreen({
    super.key,
    required this.api,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentFlashcardScreen> createState() => _StudentFlashcardScreenState();
}

class _StudentFlashcardScreenState extends State<StudentFlashcardScreen> {
  List<Map<String, dynamic>> _flashcards = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;
  
  // Review Mode State
  int _currentIndex = 0;
  bool _showBack = false;
  bool _reviewMode = false;
  int _rememberedCount = 0;
  int _needReviewCount = 0;
  bool _reviewFinished = false;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.api.getFlashcards(widget.courseId);
      final reflections = await widget.api.getReflections(courseId: widget.courseId);
      
      final weakReflections = reflections.where((r) {
        final level = int.tryParse(r['understanding_level']?.toString() ?? '5') ?? 5;
        return level <= 2;
      }).toList();

      setState(() {
        _flashcards = data;
        _suggestions = weakReflections;
        _resetReview();
      });
    } catch (e) {
      debugPrint('Failed to load flashcards: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi tải dữ liệu flashcard!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetReview() {
    _currentIndex = 0;
    _showBack = false;
    _reviewMode = false;
    _rememberedCount = 0;
    _needReviewCount = 0;
    _reviewFinished = false;
  }

  void _startReview() {
    if (_flashcards.isEmpty) return;
    setState(() {
      _resetReview();
      _reviewMode = true;
    });
  }

  void _showFlashcardDialog({Map<String, dynamic>? card, String? initialFront}) {
    final bool isEdit = card != null;
    final TextEditingController frontController = TextEditingController(text: isEdit ? card['front_text'] : (initialFront ?? ''));
    final TextEditingController backController = TextEditingController(text: isEdit ? card['back_text'] : '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Chỉnh sửa thẻ' : 'Thêm thẻ ghi nhớ mới'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: frontController,
                decoration: const InputDecoration(
                  labelText: 'Mặt trước (Câu hỏi/Thuật ngữ)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: backController,
                decoration: const InputDecoration(
                  labelText: 'Mặt sau (Câu trả lời/Định nghĩa)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Xác nhận xóa'),
                      content: const Text('Bạn có chắc chắn muốn xóa thẻ này? Dữ liệu không thể khôi phục.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(c, true), 
                          child: const Text('Xóa')
                        ),
                      ],
                    )
                  );
                  if (confirm == true) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext); // close edit dialog
                    try {
                      await widget.api.deleteFlashcard(widget.courseId, card['id']);
                      _loadFlashcards();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa thẻ')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi xóa thẻ')));
                    }
                  }
                },
                child: const Text('Xóa thẻ', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final front = frontController.text.trim();
                final back = backController.text.trim();
                if (front.isEmpty || back.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ mặt trước và mặt sau')));
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  if (isEdit) {
                    await widget.api.updateFlashcard(widget.courseId, card['id'], front, back);
                  } else {
                    await widget.api.addFlashcard(widget.courseId, front, back);
                  }
                  _loadFlashcards();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Đã cập nhật thẻ' : 'Đã thêm thẻ mới')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi lưu thẻ')));
                }
              },
              child: const Text('Lưu'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.end,
        );
      },
    );
  }

  void _nextReviewCard(bool remembered) {
    if (remembered) {
      _rememberedCount++;
    } else {
      _needReviewCount++;
    }

    if (_currentIndex < _flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showBack = false;
      });
    } else {
      setState(() {
        _reviewFinished = true;
      });
    }
  }

  Widget _buildReviewFinished() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Hoàn thành ôn tập!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('$_rememberedCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                      const Text('Đã nhớ', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('$_needReviewCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
                      const Text('Cần ôn lại', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _startReview,
                icon: const Icon(Icons.refresh),
                label: const Text('Ôn tập lại'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _reviewMode = false),
                child: const Text('Trở về danh sách'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewMode() {
    if (_reviewFinished) return _buildReviewFinished();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _reviewMode = false),
              ),
              Text(
                'Thẻ ${_currentIndex + 1} / ${_flashcards.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 48), // balance space
            ],
          ),
          LinearProgressIndicator(
            value: (_currentIndex) / _flashcards.length,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBack = !_showBack),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _showBack ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _showBack ? Colors.green.shade200 : Colors.grey.shade300,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Text(
                    _showBack
                        ? _flashcards[_currentIndex]['back_text'] ?? ''
                        : _flashcards[_currentIndex]['front_text'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: _showBack ? FontWeight.normal : FontWeight.bold,
                      color: _showBack ? Colors.green.shade900 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showBack ? 'Đánh giá mức độ ghi nhớ của bạn' : 'Chạm vào thẻ để lật',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_showBack)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: () => _nextReviewCard(false),
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: const Text('Cần ôn lại'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: () => _nextReviewCard(true),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: const Text('Đã nhớ'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => _showBack = true),
                icon: const Icon(Icons.sync),
                label: const Text('Lật thẻ'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildListMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Gợi ý từ Nhật ký tự đánh giá (Chưa hiểu rõ)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final text = _suggestions[index]['content']?.toString() ?? '';
                return Card(
                  color: Colors.orange.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade900,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _showFlashcardDialog(initialFront: text),
                            child: const Text('Tạo thẻ', style: TextStyle(fontSize: 12)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
        ],
        if (_flashcards.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Chưa có thẻ ghi nhớ nào.', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showFlashcardDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo thẻ đầu tiên'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startReview,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Bắt đầu ôn tập'),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _flashcards.length,
                    itemBuilder: (context, index) {
                      final card = _flashcards[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showFlashcardDialog(card: card),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        card['front_text'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  card['back_text'] ?? '',
                                  style: TextStyle(color: Colors.grey.shade700),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _reviewMode ? null : AppBar(
        title: Text('Thẻ ghi nhớ: ${widget.courseName}'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviewMode
                ? _buildReviewMode()
                : _buildListMode(),
      ),
      floatingActionButton: (!_reviewMode && _flashcards.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _showFlashcardDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm thẻ'),
            )
          : null,
    );
  }
}
