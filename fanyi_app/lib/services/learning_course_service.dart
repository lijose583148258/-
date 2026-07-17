import 'package:sqflite/sqflite.dart';

import 'local_db_service.dart';

class LearningCourseService {
  LearningCourseService._();

  static const int dailyGoalXp = 80;

  static final List<LearningCourse> courses = [
    LearningCourse(
      id: 'starter',
      title: '入门生存越南语',
      subtitle: '问候、感谢、数字、方向',
      iconCode: 0xe7fb,
      colorValue: 0xFF677D6A,
      lessons: [
        LearningLesson(
          id: 'starter_hello',
          title: '见面问候',
          subtitle: '你好、谢谢、再见',
          level: 'A0',
          xp: 40,
          vocabulary: const ['xin chào', 'cảm ơn', 'tạm biệt', 'vâng'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“xin chào” 的中文意思是？',
              choices: ['你好', '再见', '多少钱', '我不懂'],
              answerIndex: 0,
              explanation: 'xin chào 是最常用的越南语问候。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“谢谢” 对应哪一个越南语？',
              choices: ['tạm biệt', 'cảm ơn', 'không', 'ở đâu'],
              answerIndex: 1,
              explanation: 'cảm ơn = 谢谢。',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '“tạm biệt” 常用于什么场景？',
              choices: ['点菜', '告别', '问路', '付款'],
              answerIndex: 1,
              explanation: 'tạm biệt = 再见。',
            ),
          ],
        ),
        LearningLesson(
          id: 'starter_numbers',
          title: '数字与价格',
          subtitle: '买东西先会数',
          level: 'A0',
          xp: 50,
          vocabulary: const ['một', 'hai', 'ba', 'bao nhiêu tiền'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“bao nhiêu tiền?” 的意思是？',
              choices: ['你好吗', '多少钱', '在哪里', '我需要帮助'],
              answerIndex: 1,
              explanation: 'bao nhiêu tiền? = 多少钱？',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '“một, hai, ba” 是？',
              choices: ['一二三', '今天明天后天', '上中下', '红黄蓝'],
              answerIndex: 0,
              explanation: 'một=一，hai=二，ba=三。',
            ),
            LearningQuestion(
              type: LearningQuestionType.speaking,
              prompt: '购物时最该先掌握的句子是？',
              choices: ['Tôi tên là...', 'Bao nhiêu tiền?', 'Tạm biệt', 'Vâng'],
              answerIndex: 1,
              explanation: '问价格用 Bao nhiêu tiền?',
            ),
          ],
        ),
      ],
    ),
    LearningCourse(
      id: 'daily',
      title: '日常会话',
      subtitle: '吃饭、交通、住宿、求助',
      iconCode: 0xe0ca,
      colorValue: 0xFF0277BD,
      lessons: [
        LearningLesson(
          id: 'daily_food',
          title: '餐厅点餐',
          subtitle: '菜单、口味、结账',
          level: 'A1',
          xp: 60,
          vocabulary: const ['thực đơn', 'không cay', 'tính tiền', 'ngon'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“thực đơn” 是什么？',
              choices: ['菜单', '车票', '房间', '护照'],
              answerIndex: 0,
              explanation: 'thực đơn = 菜单。',
            ),
            LearningQuestion(
              type: LearningQuestionType.fillBlank,
              prompt: '如果想说“不辣”，应选择？',
              choices: ['rất cay', 'không cay', 'ngon quá', 'tính tiền'],
              answerIndex: 1,
              explanation: 'không cay = 不辣。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“tính tiền” 常用于？',
              choices: ['结账', '问路', '打招呼', '道歉'],
              answerIndex: 0,
              explanation: 'tính tiền = 结账/买单。',
            ),
          ],
        ),
        LearningLesson(
          id: 'daily_direction',
          title: '问路交通',
          subtitle: '地址、左右、打车',
          level: 'A1',
          xp: 60,
          vocabulary: const ['ở đâu', 'bên trái', 'bên phải', 'taxi'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“ở đâu?” 的中文意思是？',
              choices: ['在哪里', '多少钱', '什么时候', '好吃吗'],
              answerIndex: 0,
              explanation: 'ở đâu? = 在哪里？',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '“bên trái / bên phải” 分别表示？',
              choices: ['前/后', '左/右', '上/下', '快/慢'],
              answerIndex: 1,
              explanation: 'bên trái=左边，bên phải=右边。',
            ),
            LearningQuestion(
              type: LearningQuestionType.speaking,
              prompt: '需要打车时可以直接说？',
              choices: ['taxi', 'ngon', 'cảm ơn', 'một'],
              answerIndex: 0,
              explanation: 'taxi 在越南语日常中也常用。',
            ),
          ],
        ),
      ],
    ),
    LearningCourse(
      id: 'work',
      title: '工作沟通',
      subtitle: '工厂、仓库、时间、确认',
      iconCode: 0xe8f9,
      colorValue: 0xFFD2B48C,
      lessons: [
        LearningLesson(
          id: 'work_confirm',
          title: '确认与反馈',
          subtitle: '明白、完成、稍等',
          level: 'A2',
          xp: 70,
          vocabulary: const ['hiểu rồi', 'xong rồi', 'chờ chút', 'kiểm tra'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“hiểu rồi” 表示？',
              choices: ['明白了', '完成了', '稍等', '检查'],
              answerIndex: 0,
              explanation: 'hiểu rồi = 明白了。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“xong rồi” 更接近？',
              choices: ['还没开始', '完成了', '请帮忙', '我迷路了'],
              answerIndex: 1,
              explanation: 'xong rồi = 已完成/好了。',
            ),
            LearningQuestion(
              type: LearningQuestionType.fillBlank,
              prompt: '让对方稍等可以说？',
              choices: ['chờ chút', 'không cay', 'bao nhiêu', 'bên trái'],
              answerIndex: 0,
              explanation: 'chờ chút = 等一下/稍等。',
            ),
          ],
        ),
        LearningLesson(
          id: 'work_time',
          title: '时间安排',
          subtitle: '今天、明天、几点',
          level: 'A2',
          xp: 70,
          vocabulary: const ['hôm nay', 'ngày mai', 'mấy giờ', 'đúng giờ'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“ngày mai” 是？',
              choices: ['今天', '明天', '昨天', '现在'],
              answerIndex: 1,
              explanation: 'ngày mai = 明天。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '问“几点？”可以说？',
              choices: ['mấy giờ?', 'ở đâu?', 'bao nhiêu tiền?', 'ngon không?'],
              answerIndex: 0,
              explanation: 'mấy giờ? = 几点？',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '“đúng giờ” 表示？',
              choices: ['准时', '迟到', '提前', '取消'],
              answerIndex: 0,
              explanation: 'đúng giờ = 准时。',
            ),
          ],
        ),
      ],
    ),
    LearningCourse(
      id: 'grammar',
      title: '语法与句型',
      subtitle: '否定、疑问、时间表达',
      iconCode: 0xe8d2,
      colorValue: 0xFF7E57C2,
      lessons: [
        LearningLesson(
          id: 'grammar_negative',
          title: '否定句',
          subtitle: 'không 的常见位置',
          level: 'A1',
          xp: 65,
          vocabulary: const ['không', 'không phải', 'chưa', 'không biết'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.fillBlank,
              prompt: '“我不知道” 应选择？',
              choices: ['Tôi không biết', 'Tôi biết', 'Tôi ở đây', 'Tôi ăn cơm'],
              answerIndex: 0,
              explanation: 'không biết = 不知道。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '越南语里常用哪个词表示“不/没有”？',
              choices: ['không', 'rất', 'đẹp', 'ngon'],
              answerIndex: 0,
              explanation: 'không 是最常用的否定词。',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '“chưa” 更常表达？',
              choices: ['还没/尚未', '已经', '总是', '马上'],
              answerIndex: 0,
              explanation: 'chưa 常用于“还没有”。',
            ),
          ],
        ),
        LearningLesson(
          id: 'grammar_question',
          title: '疑问句',
          subtitle: '吗、哪里、多少、几点',
          level: 'A1',
          xp: 65,
          vocabulary: const ['không?', 'ở đâu?', 'bao nhiêu?', 'mấy giờ?'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“Bạn khỏe không?” 的功能是？',
              choices: ['问候身体状况', '问价格', '问路线', '问时间'],
              answerIndex: 0,
              explanation: 'khỏe không? = 身体好吗？',
            ),
            LearningQuestion(
              type: LearningQuestionType.fillBlank,
              prompt: '问地点应该用？',
              choices: ['ở đâu?', 'bao nhiêu?', 'mấy giờ?', 'không cay'],
              answerIndex: 0,
              explanation: 'ở đâu? = 在哪里？',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '“bao nhiêu?” 通常问？',
              choices: ['多少', '哪里', '谁', '为什么'],
              answerIndex: 0,
              explanation: 'bao nhiêu? = 多少？',
            ),
          ],
        ),
      ],
    ),
    LearningCourse(
      id: 'pronunciation',
      title: '发音训练',
      subtitle: '声调、常用音节、跟读',
      iconCode: 0xe029,
      colorValue: 0xFFE76F51,
      lessons: [
        LearningLesson(
          id: 'pronunciation_tone',
          title: '声调感知',
          subtitle: '先分辨，再跟读',
          level: 'A0',
          xp: 55,
          vocabulary: const ['ma', 'má', 'mà', 'mã'],
          questions: const [
            LearningQuestion(
              type: LearningQuestionType.speaking,
              prompt: '跟读 “xin chào” 时重点注意？',
              choices: ['声调和重音', '只看拼写', '不用发音', '只读中文'],
              answerIndex: 0,
              explanation: '越南语声调会影响词义，跟读时要注意高低变化。',
            ),
            LearningQuestion(
              type: LearningQuestionType.choice,
              prompt: '越南语是有声调的语言吗？',
              choices: ['是', '不是', '只在英文里有', '只在数字里有'],
              answerIndex: 0,
              explanation: '越南语有声调，学习时需要训练听辨和跟读。',
            ),
            LearningQuestion(
              type: LearningQuestionType.matching,
              prompt: '发音训练最适合配合哪个功能？',
              choices: ['TTS朗读', '清理缓存', '切换主题', '删除历史'],
              answerIndex: 0,
              explanation: '先听 TTS，再模仿跟读，效果更稳定。',
            ),
          ],
        ),
      ],
    ),
  ];

  static List<LearningLesson> get allLessons =>
      courses.expand((course) => course.lessons).toList(growable: false);

  static LearningLesson? findLesson(String id) {
    for (final lesson in allLessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  static Future<LearningDashboard> getDashboard() async {
    final db = await LocalDbService.appDatabase;
    final progressRows = await db.query('learning_progress');
    final statsRows = await db.query(
      'learning_stats',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    final progress = {
      for (final row in progressRows) row['lesson_id'] as String:
          LessonProgress.fromRow(row),
    };
    final stats = statsRows.isEmpty
        ? const LearningStats.empty()
        : LearningStats.fromRow(statsRows.first);

    return LearningDashboard(
      courses: courses,
      progress: progress,
      stats: stats,
      badges: _buildBadges(progress, stats),
      dailyGoalXp: dailyGoalXp,
    );
  }

  static List<LearningBadge> _buildBadges(
    Map<String, LessonProgress> progress,
    LearningStats stats,
  ) {
    final completed = progress.values.where((item) => item.completed).length;
    final perfect = progress.values.where((item) => item.bestScore == 100).length;
    return [
      LearningBadge(
        id: 'first_lesson',
        title: '第一关',
        description: '完成任意 1 个关卡',
        unlocked: completed >= 1,
      ),
      LearningBadge(
        id: 'three_day_streak',
        title: '连续学习',
        description: '连击达到 3 天',
        unlocked: stats.currentStreak >= 3,
      ),
      LearningBadge(
        id: 'xp_300',
        title: '学习能量',
        description: '累计获得 300 XP',
        unlocked: stats.totalXp >= 300,
      ),
      LearningBadge(
        id: 'perfect_score',
        title: '满分达人',
        description: '任意关卡最高分 100%',
        unlocked: perfect >= 1,
      ),
      LearningBadge(
        id: 'all_clear',
        title: '全课程通关',
        description: '完成当前全部课程',
        unlocked: completed >= allLessons.length,
      ),
    ];
  }

  static Future<LessonProgress> completeLesson({
    required LearningLesson lesson,
    required int correct,
  }) async {
    final db = await LocalDbService.appDatabase;
    final now = DateTime.now().millisecondsSinceEpoch;
    final score = ((correct / lesson.questions.length) * 100).round();
    final completed = score >= 60;
    final existingRows = await db.query(
      'learning_progress',
      where: 'lesson_id = ?',
      whereArgs: [lesson.id],
      limit: 1,
    );
    final existing = existingRows.isEmpty
        ? null
        : LessonProgress.fromRow(existingRows.first);

    final wasCompleted = existing?.completed ?? false;
    final attempts = (existing?.attempts ?? 0) + 1;
    final bestScore = score > (existing?.bestScore ?? 0)
        ? score
        : (existing?.bestScore ?? 0);

    await db.insert('learning_progress', {
      'lesson_id': lesson.id,
      'attempts': attempts,
      'correct': correct,
      'question_count': lesson.questions.length,
      'best_score': bestScore,
      'completed': (completed || wasCompleted) ? 1 : 0,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _updateStats(
      db,
      xpGained: correct * 10 + (completed && !wasCompleted ? lesson.xp : 0),
      newlyCompleted: completed && !wasCompleted,
    );

    final rows = await db.query(
      'learning_progress',
      where: 'lesson_id = ?',
      whereArgs: [lesson.id],
      limit: 1,
    );
    return LessonProgress.fromRow(rows.first);
  }

  static Future<void> _updateStats(
    Database db, {
    required int xpGained,
    required bool newlyCompleted,
  }) async {
    final rows = await db.query(
      'learning_stats',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    final stats = rows.isEmpty
        ? const LearningStats.empty()
        : LearningStats.fromRow(rows.first);

    final today = _dayKey(DateTime.now());
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final lastDay = stats.lastStudyDay;
    final streak = lastDay == today
        ? stats.currentStreak
        : lastDay == yesterday
            ? stats.currentStreak + 1
            : 1;

    await db.insert('learning_stats', {
      'id': 1,
      'total_xp': stats.totalXp + xpGained,
      'today_xp': lastDay == today ? stats.todayXp + xpGained : xpGained,
      'current_streak': streak,
      'completed_lessons': stats.completedLessons + (newlyCompleted ? 1 : 0),
      'last_study_day': today,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class LearningDashboard {
  final List<LearningCourse> courses;
  final Map<String, LessonProgress> progress;
  final LearningStats stats;
  final List<LearningBadge> badges;
  final int dailyGoalXp;

  const LearningDashboard({
    required this.courses,
    required this.progress,
    required this.stats,
    required this.badges,
    required this.dailyGoalXp,
  });

  int get totalLessons =>
      courses.fold(0, (sum, course) => sum + course.lessons.length);

  int get completedLessons =>
      progress.values.where((item) => item.completed).length;

  double get completionRatio =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  int get unlockedBadgeCount => badges.where((badge) => badge.unlocked).length;

  double get dailyGoalRatio =>
      dailyGoalXp == 0
          ? 0.0
          : (stats.todayXp / dailyGoalXp).clamp(0.0, 1.0).toDouble();
}

class LearningCourse {
  final String id;
  final String title;
  final String subtitle;
  final int iconCode;
  final int colorValue;
  final List<LearningLesson> lessons;

  const LearningCourse({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconCode,
    required this.colorValue,
    required this.lessons,
  });
}

class LearningLesson {
  final String id;
  final String title;
  final String subtitle;
  final String level;
  final int xp;
  final List<String> vocabulary;
  final List<LearningQuestion> questions;

  const LearningLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.xp,
    required this.vocabulary,
    required this.questions,
  });
}

class LearningQuestion {
  final LearningQuestionType type;
  final String prompt;
  final List<String> choices;
  final int answerIndex;
  final String explanation;

  const LearningQuestion({
    this.type = LearningQuestionType.choice,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
  });
}

enum LearningQuestionType {
  choice,
  matching,
  fillBlank,
  speaking,
}

class LearningBadge {
  final String id;
  final String title;
  final String description;
  final bool unlocked;

  const LearningBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class LessonProgress {
  final String lessonId;
  final int attempts;
  final int correct;
  final int questionCount;
  final int bestScore;
  final bool completed;
  final int updatedAt;

  const LessonProgress({
    required this.lessonId,
    required this.attempts,
    required this.correct,
    required this.questionCount,
    required this.bestScore,
    required this.completed,
    required this.updatedAt,
  });

  factory LessonProgress.fromRow(Map<String, Object?> row) {
    return LessonProgress(
      lessonId: row['lesson_id'] as String,
      attempts: row['attempts'] as int,
      correct: row['correct'] as int,
      questionCount: row['question_count'] as int,
      bestScore: row['best_score'] as int,
      completed: row['completed'] == 1,
      updatedAt: row['updated_at'] as int,
    );
  }
}

class LearningStats {
  final int totalXp;
  final int todayXp;
  final int currentStreak;
  final int completedLessons;
  final String? lastStudyDay;

  const LearningStats({
    required this.totalXp,
    required this.todayXp,
    required this.currentStreak,
    required this.completedLessons,
    required this.lastStudyDay,
  });

  const LearningStats.empty()
      : totalXp = 0,
        todayXp = 0,
        currentStreak = 0,
        completedLessons = 0,
        lastStudyDay = null;

  factory LearningStats.fromRow(Map<String, Object?> row) {
    final today = LearningCourseService._dayKey(DateTime.now());
    final lastStudyDay = row['last_study_day'] as String?;
    final storedTodayXp = (row['today_xp'] as int?) ?? 0;
    return LearningStats(
      totalXp: row['total_xp'] as int,
      todayXp: lastStudyDay == today ? storedTodayXp : 0,
      currentStreak: row['current_streak'] as int,
      completedLessons: row['completed_lessons'] as int,
      lastStudyDay: lastStudyDay,
    );
  }
}
