import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/services/tv_input_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'phone can submit Chinese text only with the active pairing URL',
    () async {
      final session = await TvInputSession.start(
        bindAddress: InternetAddress.loopbackIPv4,
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await session.close();
      });
      final uri = Uri.parse(session.urls.single);
      final invalid = await (await client.getUrl(uri.replace(path: '/invalid')))
          .close();
      expect(invalid.statusCode, 404);
      await invalid.drain<void>();
      final received = session.texts.first;
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write('text=${Uri.encodeComponent('三体 第 2 集')}');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(await utf8.decoder.bind(response).join(), contains('请在电视上确认搜索'));
      expect(await received, '三体 第 2 集');
    },
  );
  test('pairing rejects cross-origin and oversized input', () async {
    final session = await TvInputSession.start(
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await session.close();
    });
    final uri = Uri.parse(session.urls.single);
    var request = await client.postUrl(uri);
    request.headers.set('Origin', 'https://example.org');
    var response = await request.close();
    expect(response.statusCode, 403);
    await response.drain<void>();
    request = await client.postUrl(uri);
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.write('text=${'a' * 201}');
    response = await request.close();
    expect(response.statusCode, 400);
    await response.drain<void>();
  });
  test('closing or expiration revokes the receiver', () async {
    final session = await TvInputSession.start(
      bindAddress: InternetAddress.loopbackIPv4,
      lifetime: const Duration(milliseconds: 100),
    );
    await session.texts.drain<void>();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    await expectLater(
      client.getUrl(Uri.parse(session.urls.single)),
      throwsA(isA<SocketException>()),
    );
    await session.close();
  });
  test('pairing only advertises private LAN addresses', () {
    for (final address in [
      '192.168.1.2',
      '10.0.0.4',
      '172.16.0.1',
      '172.31.4.2',
    ]) {
      expect(TvInputSession.isLanAddress(address), isTrue);
    }
    for (final address in [
      '127.0.0.1',
      '8.8.8.8',
      '172.32.0.1',
      '192.168.999.1',
      '::1',
    ]) {
      expect(TvInputSession.isLanAddress(address), isFalse);
    }
  });
}
