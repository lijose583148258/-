import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../ui/app_theme.dart';

class TranslationHistoryScreen extends StatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  State<TranslationHistoryScreen> createState() => _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState extends State<TranslationHistoryScreen> {
  static const int _pageSize = 30;

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final items = await LocalDbService.getRecentTranslations(limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _offset = items.length;
      _hasMore = items.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final items = await LocalDbService.getRecentTranslations(
      limit: _pageSize,
      offset: _offset,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(items);
      _offset += items.length;
      _hasMore = items.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  String _formatTime(int? millis) {
    if (millis == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.shell,
      appBar: AppBar(
        title: const Text('最近翻译记录'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _items.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader();
                  }
                  if (index == _items.length + 1) {
                    return _buildFooter();
                  }
                  return _buildItemCard(_items[index - 1]);
                },
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: Text(
        '只保留最近 200 条，方便真机测试时回看历史翻译，也不会让数据无限长。',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildFooter() {
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('没有更多记录了', style: TextStyle(color: AppTheme.inkMuted)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadingMore ? null : _loadMore,
          icon: _loadingMore
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(_loadingMore ? '加载中...' : '加载更多'),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final source = (item['source'] ?? '').toString();
    final direction = (item['direction'] ?? '').toString();
    final original = (item['original'] ?? '').toString();
    final translated = (item['translated'] ?? '').toString();
    final normalized = (item['normalized'] ?? '').toString();
    final hanZi = (item['han_zi'] ?? '').toString();
    final explanation = (item['explanation'] ?? '').toString();
    final isSlang = (item['is_slang'] ?? 0).toString() == '1';
    final createdAt = int.tryParse((item['created_at'] ?? '').toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSlang
                        ? AppTheme.amber.withValues(alpha: 0.18)
                        : AppTheme.accentSoft.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    source.isEmpty ? 'local' : source,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSlang ? AppTheme.amber : AppTheme.accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              original,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            if (direction.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                direction,
                style: const TextStyle(fontSize: 11, color: AppTheme.inkMuted),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panelStrong.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                translated,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.ink,
                ),
              ),
            ),
            if (normalized.isNotEmpty || hanZi.isNotEmpty || explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (normalized.isNotEmpty)
                    _metaChip('规范化', normalized),
                  if (hanZi.isNotEmpty) _metaChip('汉字', hanZi),
                  if (explanation.isNotEmpty)
                    _metaChip('说明', explanation),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: AppTheme.inkMuted),
      ),
    );
  }
}
