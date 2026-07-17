import 'package:flutter/material.dart';

import '../services/learning_course_service.dart';
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
  Future<LearningDashboard>? _dashboardFuture;
  List<Map<String, dynamic>> _results = [];
  bool _loadingSearch = true;
  LearnFilter _filter = LearnFilter.all;

  @override
  void initState() {
    super.initState();
    _reloadDashboard();
    _loadSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadDashboard() {
    _dashboardFuture = LearningCourseService.getDashboard();
  }

  Future<void> _loadSearch([String query = '']) async {
    setState(() => _loadingSearch = true);
    final results = await LocalDbService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loadingSearch = false;
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

  Future<void> _openLesson(LearningLesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonQuizScreen(lesson: lesson)),
    );
    if (!mounted) return;
    setState(_reloadDashboard);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('学习'),
          actions: [
            IconButton(
              onPressed: _openKeyboardHelper,
              icon: const Icon(Icons.keyboard_command_key_rounded),
              tooltip: '聊天键盘',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map_rounded), text: '课程'),
              Tab(icon: Icon(Icons.menu_book_rounded), text: '词库'),
            ],
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: AppThemeShell()),
            TabBarView(
              children: [
                _CourseTreeTab(
                  dashboardFuture: _dashboardFuture!,
                  onOpenLesson: _openLesson,
                ),
                _DictionaryTab(
                  searchController: _searchController,
                  loading: _loadingSearch,
                  filter: _filter,
                  results: _filteredResults,
                  onSearch: _loadSearch,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onKeyboardHelper: _openKeyboardHelper,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTreeTab extends StatelessWidget {
  final Future<LearningDashboard> dashboardFuture;
  final ValueChanged<LearningLesson> onOpenLesson;

  const _CourseTreeTab({
    required this.dashboardFuture,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningDashboard>(
      future: dashboardFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          );
        }

        final dashboard = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ProgressHero(dashboard: dashboard),
            const SizedBox(height: 12),
            _AchievementStrip(dashboard: dashboard),
            const SizedBox(height: 12),
            _DailyGoalCard(dashboard: dashboard),
            const SizedBox(height: 12),
            _BadgeGrid(dashboard: dashboard),
            const SizedBox(height: 16),
            ...dashboard.courses.map(
              (course) => _CourseCard(
                course: course,
                progress: dashboard.progress,
                onOpenLesson: onOpenLesson,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressHero extends StatelessWidget {
  final LearningDashboard dashboard;

  const _ProgressHero({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final percent = (dashboard.completionRatio * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263A29), Color(0xFF677D6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '无会员课程系统',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已完成 ${dashboard.completedLessons}/${dashboard.totalLessons} 关 · $percent%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: dashboard.completionRatio,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementStrip extends StatelessWidget {
  final LearningDashboard dashboard;

  const _AchievementStrip({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            label: '连击',
            value: '${dashboard.stats.currentStreak} 天',
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.bolt_rounded,
            label: '积分',
            value: '${dashboard.stats.totalXp} XP',
            color: AppTheme.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.workspace_premium_rounded,
            label: '成就',
            value: '${dashboard.unlockedBadgeCount}/${dashboard.badges.length}',
            color: AppTheme.cyan,
          ),
        ),
      ],
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final LearningDashboard dashboard;

  const _DailyGoalCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final percent = (dashboard.dailyGoalRatio * 100).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_circle_rounded,
                  color: AppTheme.accent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '每日目标',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${dashboard.stats.todayXp}/${dashboard.dailyGoalXp} XP',
                  style: const TextStyle(
                    color: AppTheme.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: dashboard.dailyGoalRatio,
                backgroundColor: AppTheme.panelStrong,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              percent >= 100 ? '今日目标已完成，保持连击！' : '今日已完成 $percent%，再学一关即可推进。',
              style: const TextStyle(
                color: AppTheme.inkMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final LearningDashboard dashboard;

  const _BadgeGrid({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.military_tech_rounded, color: AppTheme.amber),
                SizedBox(width: 8),
                Text(
                  '徽章成就',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dashboard.badges
                  .map((badge) => _BadgePill(badge: badge))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final LearningBadge badge;

  const _BadgePill({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: badge.unlocked
              ? AppTheme.amber.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: badge.unlocked ? AppTheme.amber : AppTheme.borderMuted,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badge.unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              color: badge.unlocked ? AppTheme.amber : AppTheme.inkMuted,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              badge.title,
              style: TextStyle(
                color: badge.unlocked ? AppTheme.ink : AppTheme.inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppTheme.inkMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final LearningCourse course;
  final Map<String, LessonProgress> progress;
  final ValueChanged<LearningLesson> onOpenLesson;

  const _CourseCard({
    required this.course,
    required this.progress,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(course.colorValue);
    final completed = course.lessons
        .where((lesson) => progress[lesson.id]?.completed ?? false)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.16),
                  child: Icon(
                    IconData(course.iconCode, fontFamily: 'MaterialIcons'),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                        ),
                      ),
                      Text(
                        course.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _TinyChip(
                  label: '$completed/${course.lessons.length}',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...course.lessons.map(
              (lesson) => _LessonTile(
                lesson: lesson,
                progress: progress[lesson.id],
                onTap: () => onOpenLesson(lesson),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final LearningLesson lesson;
  final LessonProgress? progress;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = progress?.completed ?? false;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: completed
              ? const Color(0xFFE8F5E9)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderMuted),
        ),
        child: Row(
          children: [
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              color: completed ? Colors.green : AppTheme.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    '${lesson.level} · ${lesson.questions.length} 题 · ${lesson.xp} XP · ${lesson.subtitle}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (progress != null)
              Text(
                '${progress!.bestScore}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LessonQuizScreen extends StatefulWidget {
  final LearningLesson lesson;

  const LessonQuizScreen({super.key, required this.lesson});

  @override
  State<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends State<LessonQuizScreen> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _submitted = false;
  LessonProgress? _result;

  LearningQuestion get _question => widget.lesson.questions[_index];

  Future<void> _submit(int selected) async {
    if (_submitted) return;
    final isCorrect = selected == _question.answerIndex;
    setState(() {
      _selected = selected;
      _submitted = true;
      if (isCorrect) _correct += 1;
    });
  }

  Future<void> _next() async {
    if (_index < widget.lesson.questions.length - 1) {
      setState(() {
        _index += 1;
        _selected = null;
        _submitted = false;
      });
      return;
    }

    final result = await LearningCourseService.completeLesson(
      lesson: widget.lesson,
      correct: _correct,
    );
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult(context, _result!);

    final progress = (_index + 1) / widget.lesson.questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LessonIntro(lesson: widget.lesson),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${_index + 1}/${widget.lesson.questions.length} 题',
                        style: const TextStyle(
                          color: AppTheme.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _QuestionTypeChip(type: _question.type),
                      const SizedBox(height: 8),
                      Text(
                        _question.prompt,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(
                        _question.choices.length,
                        (i) => _ChoiceButton(
                          text: _question.choices[i],
                          selected: _selected == i,
                          correct: _submitted && i == _question.answerIndex,
                          wrong: _submitted &&
                              _selected == i &&
                              i != _question.answerIndex,
                          onTap: () => _submit(i),
                        ),
                      ),
                      if (_submitted) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _question.explanation,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _next,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _index == widget.lesson.questions.length - 1
                                  ? '完成关卡'
                                  : '下一题',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, LessonProgress result) {
    final passed = result.bestScore >= 60;
    return Scaffold(
      appBar: AppBar(title: const Text('关卡结果')),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          Center(
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      passed
                          ? Icons.emoji_events_rounded
                          : Icons.refresh_rounded,
                      color: passed ? AppTheme.amber : AppTheme.accent,
                      size: 58,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      passed ? '关卡完成' : '继续练习',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本次答对 $_correct/${widget.lesson.questions.length} 题 · 最高分 ${result.bestScore}%',
                      style: const TextStyle(
                        color: AppTheme.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回课程树'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTypeChip extends StatelessWidget {
  final LearningQuestionType type;

  const _QuestionTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      LearningQuestionType.choice => '选择题',
      LearningQuestionType.matching => '匹配理解',
      LearningQuestionType.fillBlank => '填空句型',
      LearningQuestionType.speaking => '跟读口语',
    };
    final icon = switch (type) {
      LearningQuestionType.choice => Icons.checklist_rounded,
      LearningQuestionType.matching => Icons.compare_arrows_rounded,
      LearningQuestionType.fillBlank => Icons.edit_note_rounded,
      LearningQuestionType.speaking => Icons.record_voice_over_rounded,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.cyan.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.borderMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.ink),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonIntro extends StatelessWidget {
  final LearningLesson lesson;

  const _LessonIntro({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TinyChip(label: lesson.level, color: AppTheme.accent),
                const SizedBox(width: 8),
                _TinyChip(label: '${lesson.xp} XP', color: AppTheme.amber),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lesson.subtitle,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lesson.vocabulary
                  .map((word) => _TinyChip(label: word, color: AppTheme.cyan))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = AppTheme.borderMuted;
    Color background = Colors.white;
    IconData? icon;

    if (correct) {
      border = Colors.green;
      background = const Color(0xFFE8F5E9);
      icon = Icons.check_circle_rounded;
    } else if (wrong) {
      border = Colors.redAccent;
      background = const Color(0xFFFFEBEE);
      icon = Icons.cancel_rounded;
    } else if (selected) {
      border = AppTheme.accent;
      background = AppTheme.panelStrong;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, color: border),
            ],
          ),
        ),
      ),
    );
  }
}

class _DictionaryTab extends StatelessWidget {
  final TextEditingController searchController;
  final bool loading;
  final LearnFilter filter;
  final List<Map<String, dynamic>> results;
  final ValueChanged<String> onSearch;
  final ValueChanged<LearnFilter> onFilterChanged;
  final VoidCallback onKeyboardHelper;

  const _DictionaryTab({
    required this.searchController,
    required this.loading,
    required this.filter,
    required this.results,
    required this.onSearch,
    required this.onFilterChanged,
    required this.onKeyboardHelper,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: '搜索词条、释义、汉越词根…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      onSearch('');
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
                    value: filter,
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
                      if (v != null) onFilterChanged(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onKeyboardHelper,
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
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          )
        else if (results.isEmpty)
          const _EmptyLearnState()
        else
          ...results.map((item) => _LearnResultCard(item: item)),
      ],
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
                Wrap(
                  spacing: 6,
                  children: [
                    _TinyChip(
                      label: type == 'slang' ? '俚语' : '词典',
                      color: type == 'slang' ? AppTheme.amber : AppTheme.accent,
                    ),
                    if (hanZi.isNotEmpty)
                      const _TinyChip(label: '汉越', color: AppTheme.cyan),
                  ],
                ),
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
              '换个关键词试试，或先在课程页完成一组关卡。',
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
