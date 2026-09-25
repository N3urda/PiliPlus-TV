import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/widgets/tv_feature_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Video extends BaseVideoItemModel {
  _Video() {
    title = 'Minecraft：这是一个很长很长的视频标题，用于检查电视首页在长标题下的排版';
    desc = '这是一段较长的简介，说明视频内容并检查电视屏幕上的主推区域不会溢出。';
    duration = 4090;
    owner = _Owner();
    stat = _Stat();
  }
}

class _Owner extends BaseOwner {
  _Owner() {
    name = '测试 UP 主';
  }
}

class _Stat extends BaseStat {
  _Stat() {
    view = 1234567;
  }
}

void main() {
  testWidgets('featured video fits a 1080p TV viewport and shows metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 852,
            child: TvFeatureBanner(
              video: _Video(),
              focusNode: focus,
              label: '正在热播',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('正在热播'), findsOneWidget);
    expect(find.textContaining('123.5万播放'), findsOneWidget);
    expect(find.textContaining('01:08:10'), findsOneWidget);
    expect(find.text('查看视频'), findsOneWidget);
  });
}
