import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/tv_feed_loader.dart';
import 'package:flutter_test/flutter_test.dart';

class _Video extends BaseVideoItemModel {
  _Video() {
    title = '可播放视频';
    owner = _Owner();
    stat = _Stat();
  }
}

class _Owner extends BaseOwner {}

class _Stat extends BaseStat {}

void main() {
  test('popular videos remain available when recommendations fail', () async {
    final feeds = await loadTvFeeds(
      loadRecommended: () async =>
          throw StateError('recommendations unavailable'),
      loadPopular: () async => Success([_Video()]),
    );
    expect(feeds.recommended, isEmpty);
    expect(feeds.popular.single.title, '可播放视频');
    expect(feeds.error, isNull);
  });
}
