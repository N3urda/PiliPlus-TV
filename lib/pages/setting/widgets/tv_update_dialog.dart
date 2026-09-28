import 'dart:io';

import 'package:PiliPlus/utils/tv_platform.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

class TvUpdateDialog extends StatefulWidget {
  const TvUpdateDialog({super.key, required this.asset});
  final Map<String, dynamic> asset;

  @override
  State<TvUpdateDialog> createState() => _TvUpdateDialogState();
}

class _TvUpdateDialogState extends State<TvUpdateDialog> {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );
  CancelToken? _cancel;
  File? _apk;
  String? _error;
  String? _message;
  double? _progress;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _progress = null;
    });
    final cancel = _cancel = CancelToken();
    File? partial;
    try {
      final uri = Uri.parse(widget.asset['browser_download_url'] as String);
      if (uri.scheme != 'https' ||
          uri.host != 'github.com' ||
          !uri.path.startsWith('/N3urda/PiliPlus-TV/releases/download/')) {
        throw const FormatException('安装包来源不匹配');
      }
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/tv-updates',
      ).create(recursive: true);
      // Clean only this app's previous update files; never touch other cache data.
      await for (final file in directory.list()) {
        if (file is File &&
            DateTime.now().difference(file.statSync().modified).inDays >= 1) {
          await file.delete();
        }
      }
      final target = File(
        '${directory.path}/update-${DateTime.now().microsecondsSinceEpoch}.apk',
      );
      partial = File('${target.path}.part');
      await _dio.downloadUri(
        uri,
        partial.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() => _progress = total > 0 ? received / total : null);
          }
        },
      );
      final expectedSize = widget.asset['size'];
      if (expectedSize is int &&
          expectedSize > 0 &&
          await partial.length() != expectedSize) {
        throw const FormatException('下载不完整，请重试');
      }
      final digest = widget.asset['digest'];
      if (digest is String && digest.startsWith('sha256:')) {
        final actual = (await sha256.bind(partial.openRead()).first).toString();
        if (actual != digest.substring(7)) {
          throw const FormatException('安装包校验失败，请重新下载');
        }
      }
      if (cancel.isCancelled) return;
      _apk = await partial.rename(target.path);
      if (mounted) setState(() => _message = '下载完成，选择安装后由系统确认更新');
    } catch (e) {
      if (mounted && !cancel.isCancelled) {
        setState(
          () => _error = e is FormatException ? e.message : '下载失败，请检查网络后重试',
        );
      }
    } finally {
      if (partial != null && partial.existsSync()) await partial.delete();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final launched = await TvPlatform.installUpdate(_apk!.path);
      if (mounted) {
        setState(
          () => _message = launched
              ? '已打开系统安装程序，请按提示完成更新'
              : '请允许此应用安装更新，返回后再次选择安装',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法安装，请确认安装包与当前应用的包名、签名一致');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('更新 PiliPlus TV'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.asset['name'] as String),
          const SizedBox(height: 20),
          if (_busy) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(
              _progress == null
                  ? '正在准备…'
                  : '已下载 ${(_progress! * 100).toStringAsFixed(0)}%',
            ),
          ],
          if (_message != null) Text(_message!),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_busy ? '取消下载' : '关闭'),
      ),
      if (!_busy && _apk == null)
        FilledButton(onPressed: _download, child: const Text('重新下载')),
      if (!_busy && _apk != null)
        FilledButton(onPressed: _install, child: const Text('安装')),
    ],
  );
}
