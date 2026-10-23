import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/services/free_entitlement_service.dart';
import 'package:fanyi_tong/services/learning_course_service.dart';

void main() {
  group('learning course catalog', () {
    test('has stable course and lesson structure', () {
      expect(LearningCourseService.courses, isNotEmpty);

      final lessonIds = <String>{};
      for (final course in LearningCourseService.courses) {
        expect(course.id, isNotEmpty);
        expect(course.title, isNotEmpty);
        expect(course.lessons, isNotEmpty);

        for (final lesson in course.lessons) {
          expect(lesson.id, isNotEmpty);
          expect(lessonIds.add(lesson.id), isTrue);
          expect(lesson.title, isNotEmpty);
          expect(lesson.xp, greaterThan(0));
          expect(lesson.vocabulary, isNotEmpty);
          expect(lesson.questions, isNotEmpty);
        }
      }
    });

    test('all quiz answers point to valid choices', () {
      final types = <LearningQuestionType>{};
      for (final lesson in LearningCourseService.allLessons) {
        for (final question in lesson.questions) {
          types.add(question.type);
          expect(question.prompt, isNotEmpty);
          expect(question.choices.length, greaterThanOrEqualTo(2));
          expect(question.answerIndex, greaterThanOrEqualTo(0));
          expect(question.answerIndex, lessThan(question.choices.length));
          expect(question.explanation, isNotEmpty);
        }
      }
      expect(types, contains(LearningQuestionType.choice));
      expect(types, contains(LearningQuestionType.matching));
      expect(types, contains(LearningQuestionType.fillBlank));
      expect(types, contains(LearningQuestionType.speaking));
    });

    test('daily goal and badge definitions are stable', () {
      expect(LearningCourseService.dailyGoalXp, greaterThan(0));

      final dashboard = LearningDashboard(
        courses: LearningCourseService.courses,
        progress: const {},
        stats: const LearningStats.empty(),
        badges: const [
          LearningBadge(
            id: 'sample',
            title: '示例',
            description: '示例徽章',
            unlocked: false,
          ),
        ],
        dailyGoalXp: LearningCourseService.dailyGoalXp,
      );

      expect(dashboard.totalLessons, LearningCourseService.allLessons.length);
      expect(dashboard.dailyGoalRatio, 0);
      expect(dashboard.unlockedBadgeCount, 0);
    });
  });

  group('free entitlement', () {
    test('learning features are included in unlocked feature list', () {
      expect(FreeEntitlementService.areAllFeaturesUnlocked, isTrue);
      expect(FreeEntitlementService.canUse('course_tree'), isTrue);
      expect(FreeEntitlementService.unlockedFeatures, contains('课程树'));
      expect(FreeEntitlementService.unlockedFeatures, contains('关卡练习'));
      expect(FreeEntitlementService.unlockedFeatures, contains('学习进度'));
      expect(FreeEntitlementService.unlockedFeatures, contains('连击积分'));
      expect(FreeEntitlementService.unlockedFeatures, contains('成就系统'));
    });
  });
}
