import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_video.dart';

typedef TvFeeds = ({
  List<BaseVideoItemModel> recommended,
  List<BaseVideoItemModel> popular,
  String? error,
});

Future<TvFeeds> loadTvFeeds({
  required Future<LoadingState<List<BaseVideoItemModel>>> Function()
  loadRecommended,
  required Future<LoadingState<List<BaseVideoItemModel>>> Function()
  loadPopular,
}) async {
  Future<LoadingState<List<BaseVideoItemModel>>> safeLoad(
    Future<LoadingState<List<BaseVideoItemModel>>> Function() request,
  ) async {
    try {
      return await request();
    } catch (e) {
      return Error('$e');
    }
  }

  final recommendedFuture = safeLoad(loadRecommended);
  final popularFuture = safeLoad(loadPopular);
  final recommendedResult = await recommendedFuture;
  final popularResult = await popularFuture;
  final recommended = recommendedResult.dataOrNull ?? <BaseVideoItemModel>[];
  final popular = popularResult.dataOrNull ?? <BaseVideoItemModel>[];
  return (
    recommended: recommended,
    popular: popular,
    error: recommended.isEmpty && popular.isEmpty
        ? '视频加载失败：$recommendedResult；$popularResult'
        : null,
  );
}
