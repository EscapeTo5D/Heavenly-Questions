class StudyRecord {
  final int? id;
  final int questionId;
  final bool isCorrect;
  final int attemptCount;
  final DateTime lastAttemptDate;
  final int reviewInterval; // 间隔重复学习的天数
  final DateTime nextReviewDate;

  StudyRecord({
    this.id,
    required this.questionId,
    required this.isCorrect,
    this.attemptCount = 1,
    DateTime? lastAttemptDate,
    this.reviewInterval = 1,
    DateTime? nextReviewDate,
  })  : lastAttemptDate = lastAttemptDate ?? DateTime.now(),
        nextReviewDate =
            nextReviewDate ?? DateTime.now().add(const Duration(days: 1));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'is_correct': isCorrect ? 1 : 0,
      'attempt_count': attemptCount,
      'last_attempt_date': lastAttemptDate.millisecondsSinceEpoch,
      'review_interval': reviewInterval,
      'next_review_date': nextReviewDate.millisecondsSinceEpoch,
    };
  }

  factory StudyRecord.fromMap(Map<String, dynamic> map) {
    return StudyRecord(
      id: map['id'],
      questionId: map['question_id'],
      isCorrect: map['is_correct'] == 1,
      attemptCount: map['attempt_count'],
      lastAttemptDate:
          DateTime.fromMillisecondsSinceEpoch(map['last_attempt_date']),
      reviewInterval: map['review_interval'],
      nextReviewDate:
          DateTime.fromMillisecondsSinceEpoch(map['next_review_date']),
    );
  }

  // 根据答题结果更新学习记录
  StudyRecord updateAfterAttempt(bool isCorrect) {
    int newAttemptCount = attemptCount + 1;
    int newReviewInterval;

    // 如果答对了，增加复习间隔（指数增长）
    // 如果答错了，重置复习间隔
    if (isCorrect) {
      newReviewInterval = reviewInterval * 2;
    } else {
      newReviewInterval = 1;
    }

    DateTime now = DateTime.now();
    DateTime newNextReviewDate = now.add(Duration(days: newReviewInterval));

    return StudyRecord(
      id: id,
      questionId: questionId,
      isCorrect: isCorrect,
      attemptCount: newAttemptCount,
      lastAttemptDate: now,
      reviewInterval: newReviewInterval,
      nextReviewDate: newNextReviewDate,
    );
  }
}
