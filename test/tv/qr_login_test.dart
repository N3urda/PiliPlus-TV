import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:flutter_test/flutter_test.dart';

typedef QrResult = LoadingState<({String authCode, String url})>;

void main() {
  testWidgets(
    'a transient poll error can recover and server expiry stops polling',
    (tester) async {
      var polls = 0;
      final controller = LoginPageController(
        loadQrCode: () async =>
            const Success((authCode: 'test', url: 'https://example.com/qr')),
        pollQrCode: (_) async {
          polls++;
          if (polls == 1) throw StateError('offline');
          return {'status': false, 'code': 86038};
        },
      )..onInit();
      await controller.refreshQRCode();
      controller.tabController.index = 2;
      await tester.pump(const Duration(seconds: 1));
      expect(polls, 1);
      expect(controller.statusQRCode.value, contains('网络暂时不可用'));
      await tester.pump(const Duration(seconds: 1));
      expect(polls, 2);
      expect(controller.qrCodeLeftTime.value, 0);
      expect(controller.qrCodeTimer!.isActive, isFalse);
      controller.onClose();
    },
  );
  testWidgets('QR API failure replaces the spinner and a refresh can recover', (
    tester,
  ) async {
    var calls = 0;
    final controller = LoginPageController(
      loadQrCode: () async {
        if (++calls == 1) return const Error('offline');
        return const Success((authCode: 'test', url: 'https://example.com/qr'));
      },
    )..onInit();
    await controller.refreshQRCode();
    expect(controller.codeInfo.value, isA<Error>());
    expect(controller.statusQRCode.value, contains('失败'));
    await controller.refreshQRCode();
    expect(controller.codeInfo.value, isA<Success>());
    expect(controller.qrCodeLeftTime.value, 180);
    controller.onClose();
  });
  testWidgets(
    'late responses cannot replace a refreshed or closed QR session',
    (tester) async {
      final old = Completer<QrResult>();
      final fresh = Completer<QrResult>();
      var calls = 0;
      final controller = LoginPageController(
        loadQrCode: () => ++calls == 1 ? old.future : fresh.future,
      )..onInit();
      final first = controller.refreshQRCode();
      final second = controller.refreshQRCode();
      fresh.complete(
        const Success((authCode: 'new', url: 'https://example.com/new')),
      );
      await second;
      old.complete(const Error('stale failure'));
      await first;
      expect(controller.codeInfo.value.dataOrNull?.authCode, 'new');
      controller.onClose();
    },
  );
  testWidgets('request exceptions produce an actionable QR error', (
    tester,
  ) async {
    final controller = LoginPageController(
      loadQrCode: () async => throw StateError('network'),
    )..onInit();
    await controller.refreshQRCode();
    expect(controller.codeInfo.value, isA<Error>());
    expect(controller.codeInfo.value.toString(), contains('重试'));
    controller.onClose();
  });
}
