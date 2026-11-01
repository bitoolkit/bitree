sealed class MoocProgress {
  const MoocProgress();
}

final class MoocCourseListProgress extends MoocProgress {
  const MoocCourseListProgress({required this.isSpoc});

  final bool isSpoc;
}

final class MoocCourseReadProgress extends MoocProgress {
  const MoocCourseReadProgress({
    required this.index,
    required this.total,
    required this.course,
  });

  final int index;
  final int total;
  final String course;
}
