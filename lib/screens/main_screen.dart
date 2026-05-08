import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/checklist_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 백그라운드에서 포그라운드로 올 때 네이티브(위젯)에서 변경된 상태를 다시 불러옴
      ref.read(checklistProvider.notifier).reload();
    }
  }

  void _showAddDialog() {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('체크리스트 추가'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: '예: 가스 밸브 잠그기'),
            autofocus: true,
            onSubmitted: (value) {
              ref.read(checklistProvider.notifier).addItem(value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                ref.read(checklistProvider.notifier).addItem(_textController.text);
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(checklistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('햇꼬 체크리스트'),
      ),
      body: checklist.isEmpty
          ? const Center(
              child: Text(
                '체크리스트가 비어있습니다.\n우측 하단 버튼을 눌러 추가해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: checklist.length,
              itemBuilder: (context, index) {
                final item = checklist[index];
                return ListTile(
                  leading: Checkbox(
                    value: item.isChecked,
                    onChanged: (value) {
                      ref.read(checklistProvider.notifier).toggleItem(item.id);
                    },
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 20,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      color: item.isChecked ? Colors.grey : Colors.black,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      ref.read(checklistProvider.notifier).removeItem(item.id);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
