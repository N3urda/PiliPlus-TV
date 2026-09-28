import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A short-lived, capability-protected LAN text receiver. It exposes only one
/// search field, never account data, files, navigation or player commands.
class TvInputSession {
  TvInputSession._(this._server, this._token, this.urls, Duration lifetime) {
    _server.listen(_handle);
    _expiry = Timer(lifetime, close);
  }

  final HttpServer _server;
  final String _token;
  final List<String> urls;
  final _texts = StreamController<String>.broadcast();
  late final Timer _expiry;
  bool _closed = false;
  Stream<String> get texts => _texts.stream;

  static bool isLanAddress(String address) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    return parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }

  static Future<TvInputSession> start({
    InternetAddress? bindAddress,
    Duration lifetime = const Duration(minutes: 5),
  }) async {
    final addresses = bindAddress == null
        ? (await NetworkInterface.list(type: InternetAddressType.IPv4))
              .expand((i) => i.addresses)
              .map((a) => a.address)
              .where(isLanAddress)
              .toSet()
              .toList()
        : [bindAddress.address];
    if (addresses.isEmpty) {
      throw const SocketException('没有可用的局域网地址，请连接 Wi-Fi 或网线');
    }
    final random = Random.secure();
    final token = base64Url
        .encode(List.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final server = await HttpServer.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      0,
    );
    server.idleTimeout = const Duration(seconds: 10);
    return TvInputSession._(server, token, [
      for (final address in addresses) 'http://$address:${server.port}/$token',
    ], lifetime);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'",
      );
    try {
      if (_closed || request.uri.path != '/$_token') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      String? status;
      if (request.method == 'POST') {
        final origin = request.headers.value('origin');
        if (origin != null &&
            !urls.any((url) => Uri.parse(url).origin == origin)) {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        if (request.headers.contentType?.mimeType !=
                'application/x-www-form-urlencoded' ||
            request.contentLength > 4096) {
          response.statusCode = HttpStatus.badRequest;
          return;
        }
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 10),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) {
            response.statusCode = HttpStatus.requestEntityTooLarge;
            return;
          }
        }
        final text =
            Uri.splitQueryString(utf8.decode(bytes))['text']?.trim() ?? '';
        if (text.isEmpty || text.length > 200 || _closed) {
          response.statusCode = HttpStatus.badRequest;
          status = '请输入 1–200 个字符';
        } else {
          _texts.add(text);
          status = '已发送，请在电视上确认搜索';
        }
      } else if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      response.headers.contentType = ContentType.html;
      response.write('''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>PiliPlus TV 搜索</title>
<style>body{font:18px system-ui;background:#171a22;color:#fff;max-width:560px;margin:48px auto;padding:24px}input,button{box-sizing:border-box;width:100%;padding:16px;margin:12px 0;font:inherit;border-radius:12px}button{background:#ffd166;border:0}p{line-height:1.7}</style>
<h1>在电视上搜索</h1><p>手机和电视需连接同一局域网。本页在关闭电视上的输入窗口或 5 分钟后失效。</p>
<form method="post"><label for="text">视频、UP 主或番剧名称</label><input id="text" name="text" maxlength="200" required autofocus autocomplete="off"><button>发送到电视</button></form>
<p>${status ?? '可使用手机键盘的语音输入。'}</p></html>''');
    } catch (_) {
      response.statusCode = HttpStatus.badRequest;
    } finally {
      try {
        await response.close();
      } on SocketException {
        // The receiver may expire while the phone is still sending a request.
      } on HttpException {
        // Disconnected clients must not surface an uncaught async error.
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _expiry.cancel();
    await _server.close(force: true);
    await _texts.close();
  }
}
