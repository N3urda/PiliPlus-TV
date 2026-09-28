import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/continue_watching.dart';
import 'package:PiliPlus/utils/update_asset.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryItemModel entry(
  int id, {
  int? progress = 20,
  String business = 'archive',
}) => HistoryItemModel(
  history: History(oid: id, cid: id, epid: id, business: business),
  progress: progress,
  duration: 100,
);

void main() {
  test(
    'update compares build version rather than release publication time',
    () {
      expect(
        UpdateAsset.versionCode([
          {'name': 'PiliPlus_android_1.1.8-abcdef123+2048_arm64-v8a.apk'},
        ]),
        2048,
      );
      expect(
        UpdateAsset.versionCode([
          {'name': 'app-release.apk'},
        ]),
        isNull,
      );
      expect(
        UpdateAsset.versionCode([
          {'name': 'source+2048.zip'},
        ]),
        isNull,
      );
    },
  );
  test(
    'continue watching excludes completed, unstarted and non-video history',
    () {
      final list = ContinueWatching.select([
        entry(1),
        entry(2, progress: -1),
        entry(3, progress: 0),
        entry(4, progress: null),
        entry(5, progress: 100),
        entry(6, business: 'article'),
        entry(7, business: 'live'),
        entry(8, business: 'pgc'),
      ]);
      expect(list.map((i) => i.history.oid), [1, 8]);
      expect(list.first.playbackProgress, 20000);
    },
  );
  test(
    'history keeps recency, removes duplicate episodes and caps the shelf',
    () {
      final list = ContinueWatching.select([
        entry(1),
        entry(1),
        for (var i = 2; i <= 20; i++) entry(i),
      ]);
      expect(list.map((i) => i.history.oid), List.generate(10, (i) => i + 1));
    },
  );
  test(
    'APK choice follows device ABI order and never picks an unsupported APK',
    () {
      final assets = [
        {'name': 'PiliPlus_armeabi-v7a.apk'},
        {'name': 'PiliPlus_arm64-v8a.apk'},
        {'name': 'PiliPlus_arm64-v8a.zip'},
      ];
      expect(
        UpdateAsset.selectApk(assets, ['arm64-v8a', 'armeabi-v7a'])?['name'],
        'PiliPlus_arm64-v8a.apk',
      );
      expect(UpdateAsset.selectApk(assets, ['x86_64']), isNull);
      expect(
        UpdateAsset.selectApk(
          [
            ...assets,
            {'name': 'app-release.apk'},
          ],
          ['x86_64'],
        )?['name'],
        'app-release.apk',
      );
    },
  );
  test('episodes remain distinct when history does not include a cid', () {
    final items = [
      for (final ep in [1, 2, 1])
        HistoryItemModel(
          history: History(oid: 100, epid: ep, business: 'pgc'),
          progress: 20,
          duration: 100,
        ),
    ];
    expect(ContinueWatching.select(items).map((i) => i.history.epid), [1, 2]);
  });
}
