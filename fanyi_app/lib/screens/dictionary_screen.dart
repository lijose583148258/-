import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../services/tts_service.dart';

/// 深度词典页面
///
/// 功能亮点：
///   1. 实时全文检索：同时按越南词、中文释义、汉越音搜索
///   2. 汉越词专区：高亮显示汉字根，帮助用户用中文记忆法学越南语
///   3. 点击喇叭图标可朗读越南语词汇
///   4. 展开详情查看例句和汉越对照
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  late TabController _tabCtrl;

  // 汉越学习模式：只显示有汉字根的词条
  bool _hanVietOnly = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // 初始加载：显示所有词条（不过滤）
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── 搜索逻辑 ─────────────────────────────────────────
  Future<void> _search(String q) async {
    setState(() => _isSearching = true);

    // 如果搜索词为空，加载全部词条（最多 40 条用于首屏展示）
    final results = q.isEmpty
        ? await _loadAll()
        : await LocalDbService.search(q);

    if (mounted) {
      setState(() {
        _results = _hanVietOnly
            ? results.where((r) => (r['han_zi'] ?? '').toString().isNotEmpty).toList()
            : results;
        _isSearching = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadAll() async {
    final dict = await LocalDbService.search('');
    return dict;
  }

  // ─── 朗读越南语词汇 ──────────────────────────────────
  Future<void> _speak(String word) async {
    final success = await TtsService.speakVietnamese(word);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设备不支持越南语朗读，请安装越南语语音包。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dictResults =
        _results.where((r) => r['type'] == 'dict').toList();
    final slangResults =
        _results.where((r) => r['type'] == 'slang').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '深度词典',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF677D6A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF677D6A),
          labelColor: const Color(0xFF677D6A),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: '词典 (${dictResults.length})'),
            Tab(text: '俚语 (${slangResults.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── 搜索栏 ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE7F0DC),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _search,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintText: '搜索越南词、中文释义或汉越音...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF677D6A),
                          size: 20,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _search('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                // 汉越词过滤开关
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _hanVietOnly = !_hanVietOnly);
                    _search(_searchCtrl.text);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _hanVietOnly
                          ? const Color(0xFF677D6A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF677D6A),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '汉越',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hanVietOnly
                            ? Colors.white
                            : const Color(0xFF677D6A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 汉越学习提示
          if (_hanVietOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFF2E7D32)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '汉越词模式：越南语中约 60% 的词来自汉字，掌握汉字根可以快速扩充词汇量。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2E7D32),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── 搜索结果 Tab ─────────────────────────────
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF677D6A),
                      strokeWidth: 2,
                    ),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Tab 1: 词典
                      dictResults.isEmpty
                          ? _buildEmptyState('未找到词典结果，试试其他关键词')
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: dictResults.length,
                              itemBuilder: (_, i) =>
                                  _buildDictCard(dictResults[i]),
                            ),
                      // Tab 2: 俚语
                      slangResults.isEmpty
                          ? _buildEmptyState('未找到俚语结果')
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: slangResults.length,
                              itemBuilder: (_, i) =>
                                  _buildSlangCard(slangResults[i]),
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 词典卡片 ─────────────────────────────────────────
  Widget _buildDictCard(Map<String, dynamic> item) {
    final hasHanZi = (item['han_zi'] ?? '').toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: hasHanZi ? const Color(0xFFE7F0DC) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasHanZi
              ? const Color(0xFFC5DDB0)
              : const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: hasHanZi
            ? CircleAvatar(
                backgroundColor: const Color(0xFF677D6A),
                radius: 22,
                child: Text(
                  item['han_zi'].toString().characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const CircleAvatar(
                backgroundColor: Color(0xFFD2B48C),
                radius: 22,
                child: Icon(Icons.book, color: Colors.white, size: 18),
              ),
        title: Text(
          item['word'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF333333),
          ),
        ),
        subtitle: Text(
          hasHanZi
              ? '${item['han_zi']}  ·  ${item['han_viet']}'
              : (item['meaning'] ?? ''),
          style: TextStyle(
            fontSize: 12,
            color: hasHanZi
                ? const Color(0xFF677D6A)
                : Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 朗读按钮
            IconButton(
              icon: const Icon(Icons.volume_up_outlined,
                  size: 20, color: Color(0xFF677D6A)),
              onPressed: () => _speak(item['word'] ?? ''),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: Colors.grey, size: 20),
          ],
        ),
        children: [
          // 详细信息
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              _detailRow('中文释义', item['meaning'] ?? '-'),
              if (item['examples'] != null)
                _detailRow('例句', item['examples']),
              if (hasHanZi)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 汉越词记忆法：这个词来自汉字「${item['han_zi']}」，发音和意思都接近中文，可以用中文直觉快速记忆！',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 俚语卡片 ─────────────────────────────────────────
  Widget _buildSlangCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFFE0B2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['word'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFFD2B48C),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['meaning'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item['explanation'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D5D5D),
                height: 1.5,
              ),
            ),
            if ((item['example'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '例：${item['example']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF5D5D5D)),
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF677D6A),
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
