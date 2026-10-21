import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

// 設定 → 自動記帳.
//
// iOS follows design/11-auto-record.html: setup steps and a copyable URL
// template. The 取得捷徑 action is a disabled placeholder labelled 即將提供
// — there is no shortcut file to download yet.
// Android follows design/12-auto-record-android.html: 不支援, with 去記一筆
// opening the existing record sheet. Other platforms show the iOS steps
// (the shortcut is configured on an iPhone). Colors stay the app sage
// palette; the 4-tab dock is the shell around this route.

class AutoRecordPage extends StatefulWidget {
  const AutoRecordPage({super.key});

  @override
  State<AutoRecordPage> createState() => _AutoRecordPageState();
}

class _AutoRecordPageState extends State<AutoRecordPage> {
  bool _copied = false;

  /// Android has no Wallet transaction automation, so the page does not
  /// pretend the URL scheme will record a payment there.
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Copies [applePayUrlTemplate] only. It does not open a link or save.
  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: applePayUrlTemplate));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      children: [
        const SubpageHeader(title: '自動記帳'),
        const SizedBox(height: 4),
        Text(
          _android ? '設定 · Android' : '設定 · Apple Pay 付款後自動帶入',
          style: const TextStyle(fontSize: 12, color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        if (_android) _androidBody() else _iosBody(),
      ],
    );
  }

  Widget _androidBody() {
    return SoftCard(
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0x248FB09F),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.phonelink_off_outlined,
              color: AppColors.sageDark,
              size: 36,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x1A767680),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '此裝置不支援',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '目前只支援 iPhone',
            key: Key('auto-android-title'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '自動記帳靠 iOS 捷徑與 Wallet 在付款時帶入資料，Android 沒有對應功能。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.secondary,
            ),
          ),
          const Text(
            '你仍可繼續手動記一筆。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton.icon(
              key: const Key('auto-go-record'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0x248FB09F),
                foregroundColor: AppColors.sageDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.push('/record'),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '去記一筆',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _iosBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '支援範圍',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final line in const [
                'iOS 17 以上（iOS 26 起觸發條件名稱為「錢包」）',
                'iPhone XS/XR 以上',
                '僅限實體店感應支付',
                '錢包需開啟行動數據',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.sageDark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '設定捷徑自動化',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              _Step(n: '1', text: '打開「捷徑」App，點下方「自動化」'),
              _Step(n: '2', text: '點右上「＋」→「新增個人自動化」'),
              _Step(
                n: '3',
                text: '選「Wallet」（iOS 26 起為「錢包」）→「點一下卡片或付款方式時」',
                detail: '勾選要自動記帳的卡片',
              ),
              _Step(n: '4', text: '加入動作「打開 URL」，貼上下方網址'),
              _Step(n: '5', text: '設為「立即執行」'),
              _Step(n: '6', text: '關閉「執行時通知」，完成'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x1A8FB09F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x665F8574)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    applePayUrlTemplate,
                    key: Key('auto-url-template'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.sageDark,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('auto-copy-url'),
                  tooltip: '複製網址',
                  onPressed: _copy,
                  icon: const Icon(
                    Icons.copy_outlined,
                    color: AppColors.sageDark,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_copied)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '已複製',
              key: Key('auto-copied'),
              style: TextStyle(fontSize: 12, color: AppColors.sageDark),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            // Placeholder. No shortcut file is shipped, so the button
            // stays disabled and does not navigate or download.
            key: const Key('auto-shortcut'),
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sageDark,
              disabledBackgroundColor: AppColors.sageDark.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text(
              '即將提供',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.detail});

  final String n;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x2E8FB09F),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sageDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  if (detail != null)
                    TextSpan(
                      text: '\n$detail',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
