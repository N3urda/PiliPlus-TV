import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/tv/widgets/tv_video_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TvSearchPage extends StatefulWidget {
  const TvSearchPage({super.key});

  @override
  State<TvSearchPage> createState() => _TvSearchPageState();
}

class _TvSearchPageState extends State<TvSearchPage> {
  final textController = TextEditingController();
  List<SearchVideoItemModel> results = [];
  String keyword = '';
  String? error;
  bool loading = false;
  int page = 0;
  int total = 0;

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Future<void> search({bool more = false}) async {
    final query = textController.text.trim();
    if (query.isEmpty || loading) return;
    if (!more) {
      keyword = query;
      page = 0;
      results = [];
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextPage = page + 1;
      final response = await SearchHttp.searchByType<SearchVideoData>(
        searchType: SearchType.video,
        keyword: keyword,
        page: nextPage,
        onSuccess: (_) {},
      );
      if (!mounted) return;
      if (response case Success<SearchVideoData>(:final response)) {
        setState(() {
          results = [...results, ...?response.list];
          total = response.numResults ?? results.length;
          page = nextPage;
          loading = false;
        });
      } else {
        setState(() {
          error = '搜索失败：$response';
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '搜索失败：$e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10181C),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(54, 28, 54, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TvAction(
                  onPressed: Get.back,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back),
                      SizedBox(width: 8),
                      Text('返回'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const Text('搜索视频', style: TextStyle(fontSize: 30)),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 24),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: '输入视频标题、UP 主或 BV 号',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => search(),
                  ),
                ),
                const SizedBox(width: 16),
                TvAction(
                  onPressed: search,
                  child: const Text('搜索', style: TextStyle(fontSize: 21)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(fontSize: 20, color: Colors.orange),
              ),
            if (loading && results.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('输入关键词并按确认键搜索视频', style: TextStyle(fontSize: 22)),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      '搜索结果 · 共 $total 条',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 18,
                      children: results
                          .map((video) => TvVideoCard(video: video))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    if (results.length < total)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TvAction(
                          onPressed: () => search(more: true),
                          child: Text(
                            loading ? '加载中…' : '加载更多',
                            style: const TextStyle(fontSize: 21),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
