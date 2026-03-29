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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              const ModemStatusBar(
                pills: [
                  StatusPillData('LEARN PATH', AppTheme.accentSoft),
                  StatusPillData('HAN-VIET', AppTheme.cyan),
                  StatusPillData('CHAT READY', AppTheme.amber),
                ],
              ),
              const SizedBox(height: 16),
              const _LearnHeroCard(),
              const SizedBox(height: 16),
              _QuickModules(
                onKeyboardTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KeyboardHelperScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _load,
                decoration: InputDecoration(
                  hintText: 'Search dictionary, slang, or Han-Viet roots',
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == LearnFilter.all,
                    onTap: () => setState(() => _filter = LearnFilter.all),
                  ),
                  _FilterChip(
                    label: 'Han-Viet',
                    selected: _filter == LearnFilter.hanViet,
                    onTap: () => setState(() => _filter = LearnFilter.hanViet),
                  ),
                  _FilterChip(
                    label: 'Slang',
                    selected: _filter == LearnFilter.slang,
                    onTap: () => setState(() => _filter = LearnFilter.slang),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                ..._filteredResults
                    .map((item) => _LearnResultCard(item: item))
                    .toList(),
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

class _LearnHeroCard extends StatelessWidget {
  const _LearnHeroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Turn translation into language memory.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
                height: 1.2,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'This page combines dictionary entries, slang, Han-Viet roots, and the chat keyboard helper into one practical study flow.',
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

class _QuickModules extends StatelessWidget {
  final VoidCallback onKeyboardTap;

  const _QuickModules({
    required this.onKeyboardTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _ModuleData(
        title: 'Chat Keyboard',
        subtitle: 'Insert text into Zalo',
        icon: Icons.keyboard_rounded,
        color: AppTheme.accent,
        onTap: onKeyboardTap,
      ),
      _ModuleData(
        title: 'Han-Viet Roots',
        subtitle: 'Learn faster',
        icon: Icons.auto_stories_rounded,
        color: AppTheme.cyan,
      ),
      _ModuleData(
        title: 'Daily Slang',
        subtitle: 'Sound more natural',
        icon: Icons.bolt_rounded,
        color: AppTheme.amber,
      ),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderMuted),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSoft : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.borderMuted,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.ink : AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _LearnResultCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _LearnResultCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSlang = item['type'] == 'slang';
    final String title = (item['word'] ?? '').toString();
    final String meaning = (item['meaning'] ?? '').toString();
    final String hanZi = (item['han_zi'] ?? '').toString();
    final String hanViet = (item['han_viet'] ?? '').toString();
    final String detail = isSlang
        ? (item['explanation'] ?? '').toString()
        : (item['examples'] ?? '').toString();

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSlang
                        ? AppTheme.amber.withValues(alpha: 0.18)
                        : AppTheme.accentSoft.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isSlang ? 'Slang' : 'Dictionary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSlang ? AppTheme.amber : AppTheme.accent,
                    ),
                  ),
                ),
                const Spacer(),
                if (hanZi.isNotEmpty)
                  Text(
                    hanZi,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meaning,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.ink,
                height: 1.45,
              ),
            ),
            if (hanViet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Han-Viet: $hanViet',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkMuted,
                ),
              ),
            ],
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.panelStrong.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.inkMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyLearnState extends StatelessWidget {
  const _EmptyLearnState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: const [
            Icon(Icons.search_off_rounded, size: 38, color: AppTheme.inkMuted),
            SizedBox(height: 12),
            Text(
              'Nothing matched this search yet.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a simpler word, a Han-Viet root, or a slang phrase.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
