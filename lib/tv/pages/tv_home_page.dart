import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/tv/tv_feed_loader.dart';
import 'package:PiliPlus/tv/tv_playback.dart';
import 'package:PiliPlus/tv/tv_video_entry.dart';
import 'package:PiliPlus/tv/widgets/tv_cover_backdrop.dart';
import 'package:PiliPlus/tv/widgets/tv_video_grid.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum _TvSection { home, following, popular }

class TvHomePage extends StatefulWidget {
  const TvHomePage({super.key, this.feedLoader});

  final Future<TvFeeds> Function()? feedLoader;

  @override
  State<TvHomePage> createState() => _TvHomePageState();
}

class _TvHomePageState extends State<TvHomePage> {
  final firstVideoFocus = FocusNode();
  final loginFocus = FocusNode();
  final refreshFocus = FocusNode();
  final homeNavFocus = FocusNode();
  final searchNavFocus = FocusNode();
  final followingNavFocus = FocusNode();
  final popularNavFocus = FocusNode();
  final loginNavFocus = FocusNode();
  final backdropCover = ValueNotifier<String?>(null);
  String? backdropVideoBvid;
  FocusNode? lastVideoFocus;
  _TvSection? pendingContentSection;
  _TvSection section = _TvSection.home;
  List<TvVideoEntry> recommended = [];
  List<TvVideoEntry> popular = [];
  List<TvVideoEntry> following = [];
  bool loadingHome = false;
  bool loadingFollowing = false;
  bool followingHasMore = true;
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
    backdropCover.dispose();
    firstVideoFocus.dispose();
    loginFocus.dispose();
    refreshFocus.dispose();
    homeNavFocus.dispose();
    searchNavFocus.dispose();
    followingNavFocus.dispose();
    popularNavFocus.dispose();
    loginNavFocus.dispose();
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

  void updateBackdrop(TvVideoEntry video) {
    backdropVideoBvid = video.bvid;
    backdropCover.value = video.cover;
  }

  void syncBackdrop({bool reset = false}) {
    final videos = activeVideos;
    if (videos.isEmpty) {
      backdropVideoBvid = null;
      backdropCover.value = null;
      return;
    }
    updateBackdrop(
      reset
          ? videos.first
          : videos.firstWhere(
              (video) => video.bvid == backdropVideoBvid,
              orElse: () => videos.first,
            ),
    );
  }

  FocusNode get activeNavFocus => switch (section) {
    _TvSection.home => homeNavFocus,
    _TvSection.following => followingNavFocus,
    _TvSection.popular => popularNavFocus,
  };

  void enterContent() {
    if (section == _TvSection.following && !Accounts.main.isLogin) {
      loginFocus.requestFocus();
    } else if (activeVideos.isNotEmpty) {
      final previous = lastVideoFocus;
      if (previous != null && previous.context != null) {
        previous.requestFocus();
      } else {
        focusFirstVideo();
      }
    } else {
      if (section == _TvSection.following ? loadingFollowing : loadingHome) {
        pendingContentSection = section;
      }
      refreshFocus.requestFocus();
    }
  }

  void returnToNavigation(FocusNode current) {
    lastVideoFocus = current;
    activeNavFocus.requestFocus();
  }

  void focusFirstVideo() {
    if (mounted && activeVideos.isNotEmpty) firstVideoFocus.requestFocus();
  }

  void resolvePendingContentFocus({required bool followingFeed}) {
    final requested = pendingContentSection;
    if (requested == null ||
        (requested == _TvSection.following) != followingFeed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || pendingContentSection != requested) return;
      pendingContentSection = null;
      if (section == requested &&
          refreshFocus.hasFocus &&
          activeVideos.isNotEmpty) {
        firstVideoFocus.requestFocus();
      }
    });
  }

  Future<void> loadHome() async {
    if (loadingHome) return;
    setState(() {
      loadingHome = true;
      homeError = null;
    });
    try {
      final feeds =
          await (widget.feedLoader?.call() ??
              loadTvFeeds(
                loadRecommended: () => VideoHttp.rcmdVideoList(
                  ps: 20,
                  freshIdx: freshIndex++,
                ),
                loadPopular: () => VideoHttp.hotVideoList(pn: 1, ps: 20),
              ));
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
      resolvePendingContentFocus(followingFeed: false);
      syncBackdrop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        homeError = '视频加载失败：$e';
        loadingHome = false;
      });
      resolvePendingContentFocus(followingFeed: false);
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
      resolvePendingContentFocus(followingFeed: true);
      syncBackdrop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        followingError = '关注动态加载失败：$e';
        loadingFollowing = false;
      });
      resolvePendingContentFocus(followingFeed: true);
    }
  }

  Future<void> openLogin({FocusNode? returnFocus}) async {
    await Get.toNamed('/tv/login');
    if (!mounted) return;
    setState(() {});
    if (Accounts.main.isLogin) loadFollowing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Accounts.main.isLogin) {
        activeNavFocus.requestFocus();
      } else {
        (returnFocus ?? loginFocus).requestFocus();
      }
    });
  }

  Future<void> openSearch() async {
    await Get.toNamed('/tv/search');
    if (mounted) searchNavFocus.requestFocus();
  }

  void selectSection(_TvSection next) {
    if (section == next) return;
    setState(() {
      section = next;
      lastVideoFocus = null;
      pendingContentSection = null;
    });
    syncBackdrop(reset: true);
    if (next == _TvSection.following) {
      if (Accounts.main.isLogin && following.isEmpty) {
        loadFollowing();
      }
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
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<String?>(
              valueListenable: backdropCover,
              builder: (_, cover, _) => TvCoverBackdrop(coverUrl: cover),
            ),
          ),
          RepaintBoundary(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    SizedBox(width: 126, child: _buildSidebar()),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
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
                                    focusNode: refreshFocus,
                                    onArrowLeft: () =>
                                        activeNavFocus.requestFocus(),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
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
                                    isFollowing
                                        ? '关注的 UP 主暂时没有新投稿视频'
                                        : '暂无可播放的视频',
                                    retry: refreshActive,
                                  )
                                : TvVideoGrid(
                                    key: ValueKey(section),
                                    videos: videos,
                                    firstFocusNode: firstVideoFocus,
                                    showPublished: isFollowing,
                                    onOpen: TvPlayback.open,
                                    onVideoFocused: updateBackdrop,
                                    onLeftEdge: returnToNavigation,
                                    onNearEnd: isFollowing
                                        ? () => loadFollowing(more: true)
                                        : null,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() => Container(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
    decoration: BoxDecoration(
      color: const Color(0xB317191D),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              height: 27,
              width: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC51D2C),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'P',
                style: TextStyle(fontSize: 19, color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PiliPlus',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 35, top: 2),
          child: Text(
            'TV',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ),
        const SizedBox(height: 32),
        _TvRailButton(
          label: '首页',
          icon: Icons.home_outlined,
          selected: section == _TvSection.home,
          autofocus: true,
          focusNode: homeNavFocus,
          onDown: searchNavFocus.requestFocus,
          onRight: enterContent,
          onPressed: () => selectSection(_TvSection.home),
        ),
        _TvRailButton(
          label: '搜索',
          icon: Icons.search,
          focusNode: searchNavFocus,
          onUp: homeNavFocus.requestFocus,
          onDown: followingNavFocus.requestFocus,
          onRight: enterContent,
          onPressed: openSearch,
        ),
        _TvRailButton(
          label: '动态',
          icon: Icons.subscriptions_outlined,
          selected: section == _TvSection.following,
          focusNode: followingNavFocus,
          onUp: searchNavFocus.requestFocus,
          onDown: popularNavFocus.requestFocus,
          onRight: enterContent,
          onPressed: () => selectSection(_TvSection.following),
        ),
        _TvRailButton(
          label: '热门',
          icon: Icons.local_fire_department_outlined,
          selected: section == _TvSection.popular,
          focusNode: popularNavFocus,
          onUp: followingNavFocus.requestFocus,
          onDown: Accounts.main.isLogin ? null : loginNavFocus.requestFocus,
          onRight: enterContent,
          onPressed: () => selectSection(_TvSection.popular),
        ),
        const Spacer(),
        if (Accounts.main.isLogin)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '已登录',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          )
        else
          _TvRailButton(
            label: '扫码登录',
            icon: Icons.qr_code_2,
            focusNode: loginNavFocus,
            onUp: popularNavFocus.requestFocus,
            onRight: enterContent,
            onPressed: () => openLogin(returnFocus: loginNavFocus),
          ),
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
          onArrowLeft: () => activeNavFocus.requestFocus(),
          onPressed: () => openLogin(returnFocus: loginFocus),
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

class _TvRailButton extends StatefulWidget {
  const _TvRailButton({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.onPressed,
    required this.onRight,
    this.onUp,
    this.onDown,
    this.selected = false,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final bool selected;
  final bool autofocus;

  @override
  State<_TvRailButton> createState() => _TvRailButtonState();
}

class _TvRailButtonState extends State<_TvRailButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: widget.autofocus,
    focusNode: widget.focusNode,
    onFocusChange: (value) => setState(() => focused = value),
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          widget.onUp?.call();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          widget.onDown?.call();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          widget.onRight();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          return KeyEventResult.handled;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.space:
          if (event is KeyDownEvent) widget.onPressed();
          return KeyEventResult.handled;
        default:
          return KeyEventResult.ignored;
      }
    },
    child: Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF67212A)
                : focused
                ? const Color(0xFF31353B)
                : Colors.transparent,
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TvNavButton extends StatefulWidget {
  const _TvNavButton({
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.focusNode,
    this.onArrowLeft,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;
  final FocusNode? focusNode;
  final VoidCallback? onArrowLeft;

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.focusNode,
    onFocusChange: (value) => setState(() => focused = value),
    onKeyEvent: (_, event) {
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft &&
          widget.onArrowLeft != null) {
        widget.onArrowLeft!();
        return KeyEventResult.handled;
      }
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        if (event is KeyDownEvent) widget.onPressed();
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
          color: focused ? const Color(0xFF35383E) : Colors.transparent,
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
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
