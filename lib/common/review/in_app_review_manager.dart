import 'package:in_app_review/in_app_review.dart';

class InAppReviewManager {
  InAppReviewManager({InAppReview? inAppReview})
    : inAppReview = inAppReview ?? InAppReview.instance;

  bool _alreadyRequested = false;

  final InAppReview inAppReview;

  void tryRequestReview() async {
    if (_alreadyRequested) {
      return;
    }
    _alreadyRequested = true;

    final isAvailable = await inAppReview.isAvailable();
    if (isAvailable) {
      await inAppReview.requestReview();
    }
  }
}
