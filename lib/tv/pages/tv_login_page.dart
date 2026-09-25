import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/tv/widgets/tv_action.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class TvLoginPage extends StatefulWidget {
  const TvLoginPage({super.key});

  @override
  State<TvLoginPage> createState() => _TvLoginPageState();
}

class _TvLoginPageState extends State<TvLoginPage> {
  Timer? timer;
  String? url;
  String? authCode;
  String status = '正在获取登录二维码…';
  int secondsLeft = 180;
  bool polling = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final requestGeneration = ++generation;
    timer?.cancel();
    setState(() {
      url = null;
      authCode = null;
      secondsLeft = 180;
      status = '正在获取登录二维码…';
    });
    try {
      final result = await LoginHttp.getHDcode();
      if (!mounted || requestGeneration != generation) return;
      if (result case Success<({String authCode, String url})>(
        :final response,
      )) {
        setState(() {
          url = response.url;
          authCode = response.authCode;
          status = '用哔哩哔哩手机 App 扫码并确认登录';
        });
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || requestGeneration != generation) return;
          if (secondsLeft <= 1) {
            timer?.cancel();
            setState(() {
              secondsLeft = 0;
              status = '二维码已过期，请选择刷新二维码';
            });
          } else {
            setState(() => secondsLeft--);
            poll(requestGeneration);
          }
        });
      } else {
        setState(() => status = '获取二维码失败：$result');
      }
    } catch (e) {
      if (mounted && requestGeneration == generation) {
        setState(() => status = '获取二维码失败：$e');
      }
    }
  }

  Future<void> poll(int requestGeneration) async {
    final code = authCode;
    if (code == null || polling) return;
    polling = true;
    try {
      final result = await LoginHttp.codePoll(code);
      if (!mounted || requestGeneration != generation) return;
      if (result['status'] == true) {
        timer?.cancel();
        final data = result['data'] as Map;
        if (data['cookie_info'] == null || data['token_info'] == null) {
          setState(
            () => status = data['message']?.toString() ?? '登录需要额外验证，请用手机完成后刷新',
          );
          return;
        }
        setState(() => status = '正在保存账号…');
        final account = LoginAccount(
          BiliCookieJar.fromList(data['cookie_info']['cookies'] as List),
          data['token_info']['access_token'],
          data['token_info']['refresh_token'],
        );
        for (final type in AccountType.values) {
          await Accounts.set(type, account);
        }
        await AnonymousAccount().delete();
        if (mounted && requestGeneration == generation) Get.back();
      } else if (result['code'] == 86038) {
        timer?.cancel();
        setState(() {
          secondsLeft = 0;
          status = '二维码已过期，请选择刷新二维码';
        });
      } else if (result['code'] != 86039) {
        setState(() => status = result['msg']?.toString() ?? '等待扫码确认');
      }
    } catch (e) {
      if (mounted && requestGeneration == generation) {
        setState(() => status = '登录出错：$e');
      }
    } finally {
      polling = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10181C),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(54),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '扫码登录',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            const Text(
              '登录后可使用账号推荐与更高的视频清晰度。',
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: url == null
                        ? const Center(child: CircularProgressIndicator())
                        : PrettyQrView.data(data: url!),
                  ),
                  const SizedBox(height: 22),
                  Text(status, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 10),
                  if (url != null && secondsLeft > 0)
                    Text(
                      '有效期还剩 $secondsLeft 秒',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TvAction(
                  autofocus: true,
                  onPressed: refresh,
                  child: const Text('刷新二维码', style: TextStyle(fontSize: 21)),
                ),
                const SizedBox(width: 20),
                TvAction(
                  onPressed: Get.back,
                  child: const Text('返回首页', style: TextStyle(fontSize: 21)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
