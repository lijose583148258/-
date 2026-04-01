import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../ui/app_theme.dart';
import 'keyboard_helper_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  LearnFilter _filter = LearnFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([String query = '']) async {
    setState(() => _loading = true);
    final results = await LocalDbService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredResults {
    switch (_filter) {
      case LearnFilter.all:
        return _results;
      case LearnFilter.hanViet:
        return _results
            .where((item) => (item['han_zi'] ?? '').toString().isNotEmpty)
            .toList();
      case LearnFilter.slang:
        return _results.where((item) => item['type'] == 'slang').toList();
    }
  }

  void _openKeyboardHelper() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KeyboardHelperScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        actions: [
          IconButton(
            onPressed: _openKeyboardHelper,
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: '聊天键盘',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              TextField(
                controller: _searchController,
                onChanged: _load,
                decoration: InputDecoration(
                  hintText: '搜索词条、释义、汉越词根…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _load('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderMuted),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<LearnFilter>(
                          value: _filter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: LearnFilter.all,
                              child: Text('全部'),
                            ),
                            DropdownMenuItem(
                              value: LearnFilter.hanViet,
                              child: Text('只看汉越'),
                            ),
                            DropdownMenuItem(
                              value: LearnFilter.slang,
                              child: Text('只看俚语'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _filter = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _openKeyboardHelper,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('插入到Zalo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_filteredResults.isEmpty)
                const _EmptyLearnState()
              else
                ..._filteredResults.map((item) => _LearnResultCard(item: item)),
            ],
          ),
        ],
      ),
    );
  }
}

enum LearnFilter {
  all,
  hanViet,
  slang,
}

class _LearnResultCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _LearnResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] ?? 'dict').toString();
    final word = (item['word'] ?? '').toString().trim();
    final meaning = (item['meaning'] ?? '').toString().trim();
    final hanViet = (item['han_viet'] ?? '').toString().trim();
    final hanZi = (item['han_zi'] ?? '').toString().trim();

    final chips = <Widget>[
      _TinyChip(
        label: type == 'slang' ? '俚语' : '词典',
        color: type == 'slang' ? AppTheme.amber : AppTheme.accentSoft,
      ),
      if (hanZi.isNotEmpty)
        const _TinyChip(label: '汉越', color: AppTheme.cyan),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.isEmpty ? '未命名词条' : word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Wrap(spacing: 6, children: chips),
              ],
            ),
            if (hanViet.isNotEmpty || hanZi.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (hanViet.isNotEmpty) 'Han-Viet: $hanViet',
                  if (hanZi.isNotEmpty) '汉字: $hanZi',
                ].join('   '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.inkMuted,
                  height: 1.3,
                ),
              ),
            ],
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                meaning,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.inkMuted,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.ink,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyLearnState extends StatelessWidget {
  const _EmptyLearnState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: AppTheme.inkMuted),
            SizedBox(height: 12),
            Text(
              '没有找到内容',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '换个关键词试试，或先在翻译页产生一些常用句子。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.inkMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

