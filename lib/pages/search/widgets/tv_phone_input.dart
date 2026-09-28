import 'dart:async';

import 'package:PiliPlus/services/tv_input_session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class TvPhoneInput extends StatefulWidget {
  const TvPhoneInput({super.key});

  @override
  State<TvPhoneInput> createState() => _TvPhoneInputState();
}

class _TvPhoneInputState extends State<TvPhoneInput> {
  TvInputSession? _session;
  StreamSubscription<String>? _subscription;
  String? _error;
  String? _text;
  int _address = 0;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final session = await TvInputSession.start();
      if (!mounted) {
        await session.close();
        return;
      }
      _subscription = session.texts.listen(
        (text) {
          if (mounted) setState(() => _text = text);
        },
        onDone: () {
          if (mounted) setState(() => _expired = true);
        },
      );
      setState(() => _session = session);
    } catch (_) {
      if (mounted) setState(() => _error = '无法启动手机输入，请检查电视的局域网连接');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('手机扫码输入'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_text != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('收到：$_text'),
              ),
            if (_error != null)
              Text(_error!)
            else if (_expired)
              const Text('连接已过期，请关闭后重新打开')
            else if (_session case final session?) ...[
              const Text('手机与电视连接同一 Wi-Fi / 局域网，使用手机相机扫码；也可以在浏览器输入下方地址。'),
              const SizedBox(height: 12),
              Container(
                width: 190,
                height: 190,
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: PrettyQrView.data(data: session.urls[_address]),
              ),
              const SizedBox(height: 8),
              Text(
                session.urls[_address],
                style: const TextStyle(fontSize: 14),
              ),
              if (session.urls.length > 1)
                TextButton(
                  onPressed: () => setState(() {
                    _address = (_address + 1) % session.urls.length;
                  }),
                  child: const Text('切换网络地址'),
                ),
              const Text('仅在本窗口打开时有效，最长 5 分钟。', style: TextStyle(fontSize: 14)),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
      FilledButton(
        onPressed: _text == null ? null : () => Navigator.pop(context, _text),
        child: const Text('搜索'),
      ),
    ],
  );
}
