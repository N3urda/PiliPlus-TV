import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

abstract final class TvPlayback {
  static bool _opening = false;

  /// Open the player directly. Dynamic entries do not carry a cid, so resolve
  /// that once from the video detail API before navigating.
  static Future<void> open(TvVideoEntry video) async {
    if (_opening) return;
    _opening = true;
    var loadingShown = false;
    try {
      var cid = video.cid;
      if (cid == null || cid <= 0) {
        loadingShown = true;
        SmartDialog.showLoading(msg: '正在打开视频');
        final response = await VideoHttp.videoIntro(bvid: video.bvid);
        cid = response.dataOrNull?.cid;
      }
      if (loadingShown) {
        SmartDialog.dismiss();
        loadingShown = false;
      }
      if (cid == null || cid <= 0) {
        SmartDialog.showToast('视频暂时无法播放');
        return;
      }
      final route = PageUtils.toVideoPage(
        bvid: video.bvid,
        cid: cid,
        cover: video.cover,
        title: video.title,
      );
      if (route != null) await route;
    } catch (_) {
      SmartDialog.showToast('视频暂时无法播放');
    } finally {
      if (loadingShown) SmartDialog.dismiss();
      _opening = false;
    }
  }
}
