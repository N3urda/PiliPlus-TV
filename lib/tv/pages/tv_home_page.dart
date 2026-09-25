import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/tv_feed_loader.dart';
import 'package:PiliPlus/tv/tv_playback.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/tv/widgets/tv_video_grid.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum _TvSection { home, following, popular }

class TvHomePage extends StatefulWidget {
  const TvHomePage({super.key});

  @override
  State<TvHomePage> createState() => _TvHomePageState();
}

class _TvHomePageState extends State<TvHomePage> {
  final firstVideoFocus = FocusNode();
  final loginFocus = FocusNode();
  _TvSection section = _TvSection.home;
  List<TvVideoEntry> recommended = [];
  List<TvVideoEntry> popular = [];
  List<TvVideoEntry> following = [];
  bool loadingHome = false;
  bool loadingFollowing = false;
  bool followingHasMore = true;
  bool initialFocusPending = true;
  String? followingOffset;
  String? homeError;
  String? followingError;
  int freshIndex = 0;

  @override
  void initState() {
    super.initState();
    loadHome();
  }

  @override
  void dispose() {
    firstVideoFocus.dispose();
    loginFocus.dispose();
    super.dispose();
  }

  List<TvVideoEntry> _entries(List<BaseVideoItemModel> source) => [
    for (final video in source)
      if (video.bvid case final bvid? when bvid.startsWith('BV'))
        TvVideoEntry.fromVideo(video),
  ];

  List<TvVideoEntry> get activeVideos => switch (section) {
    _TvSection.home => recommended.isNotEmpty ? recommended : popular,
    _TvSection.following => following,
    _TvSection.popular => popular,
  };

  void focusFirstVideo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && activeVideos.isNotEmpty) firstVideoFocus.requestFocus();
    });
  }

  Future<void> loadHome() async {
    if (loadingHome) return;
    setState(() {
      loadingHome = true;
      homeError = null;
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
      final nextRecommended = _entries(feeds.recommended);
      final nextPopular = _entries(feeds.popular);
      setState(() {
        if (nextRecommended.isNotEmpty || nextPopular.isNotEmpty) {
          recommended = nextRecommended;
          popular = nextPopular;
        }
        homeError = feeds.error;
        loadingHome = false;
      });
      if (initialFocusPending && activeVideos.isNotEmpty) {
        initialFocusPending = false;
        focusFirstVideo();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        homeError = '视频加载失败：$e';
        loadingHome = false;
      });
    }
  }

  Future<void> loadFollowing({bool more = false}) async {
    if (!Accounts.main.isLogin || loadingFollowing) return;
    if (more && !followingHasMore) return;
    setState(() {
      loadingFollowing = true;
      followingError = null;
    });
    try {
      var offset = more ? followingOffset : null;
      var hasMore = true;
      final collected = <TvVideoEntry>[];
      final seen = more
          ? following.map((video) => video.bvid).toSet()
          : <String>{};

      // The video feed can include reposts. Fill from at most three pages.
      for (var page = 0; page < 3 && collected.length < 18; page++) {
        final result = await DynamicsHttp.followDynamic(
          type: DynamicsTabType.video,
          offset: offset,
        );
        if (result is! Success) throw StateError('$result');
        final data = result.data;
        for (final video in tvFollowingVideos(data.items ?? [])) {
          if (seen.add(video.bvid)) collected.add(video);
        }
        hasMore = data.hasMore == true;
        final nextOffset = data.offset;
        if (!hasMore || nextOffset == null || nextOffset == offset) {
          hasMore = false;
          break;
        }
        offset = nextOffset;
      }

      if (!mounted || !Accounts.main.isLogin) return;
      setState(() {
        following = more ? [...following, ...collected] : collected;
        followingOffset = offset;
        followingHasMore = hasMore;
        loadingFollowing = false;
      });
      if (!more && section == _TvSection.following && following.isNotEmpty) {
        focusFirstVideo();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        followingError = '关注动态加载失败：$e';
        loadingFollowing = false;
      });
    }
  }

  Future<void> openLogin() async {
    await Get.toNamed('/tv/login');
    if (!mounted) return;
    setState(() {});
    if (Accounts.main.isLogin) loadFollowing();
  }

  void selectSection(_TvSection next) {
    if (section == next) return;
    setState(() => section = next);
    if (next == _TvSection.following) {
      if (Accounts.main.isLogin && following.isEmpty) {
        loadFollowing();
      } else if (!Accounts.main.isLogin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) loginFocus.requestFocus();
        });
      } else {
        focusFirstVideo();
      }
    } else {
      focusFirstVideo();
    }
  }

  void refreshActive() {
    if (section == _TvSection.following) {
      loadFollowing();
    } else {
      loadHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = section == _TvSection.following;
    final loggedOut = isFollowing && !Accounts.main.isLogin;
    final videos = activeVideos;
    final loading = isFollowing ? loadingFollowing : loadingHome;
    final error = isFollowing ? followingError : homeError;
    final title = switch (section) {
      _TvSection.home => '为你推荐',
      _TvSection.following => '关注动态',
      _TvSection.popular => '热门视频',
    };
    final subtitle = switch (section) {
      _TvSection.home => '精选视频',
      _TvSection.following => '你关注的 UP 主 · 最新投稿',
      _TvSection.popular => '正在热播',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              SizedBox(
                height: 39,
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const Spacer(),
                    if (!loggedOut)
                      _TvNavButton(
                        label: loading ? '加载中' : '刷新',
                        onPressed: refreshActive,
                        compact: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              if (loading && videos.isNotEmpty)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFFC51D2C),
                ),
              if (error != null && videos.isNotEmpty)
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              Expanded(
                child: loggedOut
                    ? _buildLoggedOut()
                    : loading && videos.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFC51D2C),
                        ),
                      )
                    : error != null && videos.isEmpty
                    ? _buildMessage(error, retry: refreshActive)
                    : videos.isEmpty
                    ? _buildMessage(
                        isFollowing ? '关注的 UP 主暂时没有新投稿视频' : '暂无可播放的视频',
                        retry: refreshActive,
                      )
                    : TvVideoGrid(
                        key: ValueKey(section),
                        videos: videos,
                        firstFocusNode: firstVideoFocus,
                        showPublished: isFollowing,
                        onOpen: TvPlayback.open,
                        onNearEnd: isFollowing
                            ? () => loadFollowing(more: true)
                            : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    height: 51,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF17191D),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          height: 29,
          width: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFC51D2C),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'P',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
        const SizedBox(width: 7),
        const Text(
          'PiliPlus',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        const Text('TV', style: TextStyle(fontSize: 12, color: Colors.white60)),
        const Spacer(),
        _TvNavButton(
          label: '首页',
          selected: section == _TvSection.home,
          autofocus: true,
          onPressed: () => selectSection(_TvSection.home),
        ),
        _TvNavButton(
          label: '搜索',
          onPressed: () => Get.toNamed('/tv/search'),
        ),
        _TvNavButton(
          label: '动态',
          selected: section == _TvSection.following,
          onPressed: () => selectSection(_TvSection.following),
        ),
        _TvNavButton(
          label: '热门',
          selected: section == _TvSection.popular,
          onPressed: () => selectSection(_TvSection.popular),
        ),
        const Spacer(),
        if (Accounts.main.isLogin)
          const Text(
            '已登录',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          )
        else
          _TvNavButton(label: '扫码登录', compact: true, onPressed: openLogin),
      ],
    ),
  );

  Widget _buildLoggedOut() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.subscriptions_outlined,
          size: 52,
          color: Colors.white54,
        ),
        const SizedBox(height: 14),
        const Text(
          '登录后查看关注 UP 主的新投稿',
          style: TextStyle(fontSize: 22, color: Colors.white),
        ),
        const SizedBox(height: 18),
        _TvNavButton(
          label: '扫码登录',
          focusNode: loginFocus,
          onPressed: openLogin,
        ),
      ],
    ),
  );

  Widget _buildMessage(String message, {required VoidCallback retry}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: const TextStyle(fontSize: 17, color: Colors.white),
        ),
        const SizedBox(height: 15),
        _TvNavButton(label: '重试', onPressed: retry),
      ],
    ),
  );
}

class _TvNavButton extends StatefulWidget {
  const _TvNavButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
    this.compact = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;
  final bool compact;
  final FocusNode? focusNode;

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: widget.autofocus,
    focusNode: widget.focusNode,
    onFocusChange: (value) => setState(() => focused = value),
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        widget.onPressed();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 15,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? const Color(0xFFF2F2F3)
              : focused
              ? const Color(0xFF35383E)
              : Colors.transparent,
          border: Border.all(
            color: focused ? const Color(0xFFC51D2C) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.compact ? 13 : 15,
            color: widget.selected ? const Color(0xFF151619) : Colors.white,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
