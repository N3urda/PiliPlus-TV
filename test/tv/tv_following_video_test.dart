import 'dart:io';

import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

DynamicItemModel dynamicVideo({
  String type = 'DYNAMIC_TYPE_AV',
  String? bvid = 'BV1example',
  bool forwarded = false,
}) => DynamicItemModel.fromJson({
  'type': type,
  if (forwarded) 'orig': {'type': 'DYNAMIC_TYPE_WORD'},
  'modules': {
    'module_author': {
      'mid': 42,
      'name': '关注的 UP 主',
      'pub_ts': 1700000000,
    },
    'module_dynamic': {
      'major': {
        'type': 'MAJOR_TYPE_ARCHIVE',
        'archive': {
          'bvid': bvid,
          'aid': 123,
          'cover': 'https://example.com/cover.jpg',
          'duration_text': '12:34',
          'title': '新投稿视频',
          'stat': {'play': '1.2万'},
        },
      },
    },
  },
});

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'piliplus-tv-dynamic-test-',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('following feed keeps only original playable video posts', () {
    final videos = tvFollowingVideos([
      dynamicVideo(),
      dynamicVideo(forwarded: true),
      dynamicVideo(type: 'DYNAMIC_TYPE_LIVE_RCMD'),
      dynamicVideo(bvid: ''),
      dynamicVideo(),
    ]);

    expect(videos, hasLength(1));
    expect(videos.single.bvid, 'BV1example');
    expect(videos.single.title, '新投稿视频');
    expect(videos.single.owner, '关注的 UP 主');
    expect(videos.single.viewsLabel, '1.2万播放');
    expect(videos.single.durationLabel, '12:34');
    expect(videos.single.publishedAt, 1700000000);
  });

  test('publication age uses the creator post timestamp', () {
    final video = tvFollowingVideos([dynamicVideo()]).single;
    expect(
      video.publishedLabel(DateTime.fromMillisecondsSinceEpoch(1700003600000)),
      '1小时前',
    );
  });
}
