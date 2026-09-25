import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/tv_feed_loader.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/tv/widgets/tv_video_card.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class TvHomePage extends StatefulWidget {
  const TvHomePage({super.key});

  @override
  State<TvHomePage> createState() => _TvHomePageState();
}

class _TvHomePageState extends State<TvHomePage> {
  final firstVideoFocus = FocusNode();
  List<BaseVideoItemModel> recommended = [];
  List<BaseVideoItemModel> popular = [];
  bool loading = false;
  bool initialFocusPending = true;
  String? error;
  int freshIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    firstVideoFocus.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    final hadVideos = recommended.isNotEmpty || popular.isNotEmpty;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final feeds = await loadTvFeeds(
        loadRecommended: () => VideoHttp.rcmdVideoList(
          ps: 20,
          freshIdx: freshIndex++,
        ),
        loadPopular: () => VideoHttp.hotVideoList(pn: 1, ps: 20),
      );
      if (!mounted) return;
      setState(() {
        if (feeds.error == null || !hadVideos) {
          recommended = feeds.recommended;
          popular = feeds.popular;
        }
        error = feeds.error;
        loading = false;
      });
      if (initialFocusPending &&
          (recommended.isNotEmpty || popular.isNotEmpty)) {
        initialFocusPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) firstVideoFocus.requestFocus();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '视频加载失败：$e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideos = recommended.isNotEmpty || popular.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF10181C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(54, 28, 54, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'PiliPlus TV',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TvAction(
                    autofocus: true,
                    onPressed: () => Get.toNamed('/tv/search'),
                    child: const _HeaderAction(Icons.search, '搜索视频'),
                  ),
                  const SizedBox(width: 16),
                  TvAction(
                    onPressed: load,
                    child: _HeaderAction(
                      Icons.refresh,
                      loading ? '加载中' : '换一批',
                    ),
                  ),
                  const SizedBox(width: 16),
                  TvAction(
                    onPressed: () {
                      Get.toNamed('/tv/login')?.then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: _HeaderAction(
                      Icons.account_circle_outlined,
                      Accounts.main.isLogin ? '已登录' : '扫码登录',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: loading && !hasVideos
                    ? const Center(child: CircularProgressIndicator())
                    : error != null && !hasVideos
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(error!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 20),
                            TvAction(
                              autofocus: true,
                              onPressed: load,
                              child: const Text(
                                '重试',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          if (loading)
                            const LinearProgressIndicator(minHeight: 3),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          if (recommended.isNotEmpty)
                            TvVideoRow(
                              title: '为你推荐',
                              videos: recommended,
                              firstFocusNode: firstVideoFocus,
                            ),
                          if (popular.isNotEmpty)
                            TvVideoRow(
                              title: '热门视频',
                              videos: popular,
                              firstFocusNode: recommended.isEmpty
                                  ? firstVideoFocus
                                  : null,
                            ),
                        ],
                      ),
              ),
              const Text(
                '方向键选择   ·   确认键打开   ·   返回键退出',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvVideoRow extends StatelessWidget {
  const TvVideoRow({
    super.key,
    required this.title,
    required this.videos,
    this.firstFocusNode,
  });

  final String title;
  final List<BaseVideoItemModel> videos;
  final FocusNode? firstFocusNode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 248,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: videos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 18),
          itemBuilder: (context, index) => TvVideoCard(
            video: videos[index],
            focusNode: index == 0 ? firstFocusNode : null,
          ),
        ),
      ),
      const SizedBox(height: 28),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 24),
      const SizedBox(width: 9),
      Text(label, style: const TextStyle(fontSize: 19)),
    ],
  );
}
