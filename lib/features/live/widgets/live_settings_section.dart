import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../foundation/i18n/translations.g.dart';
import '../../../foundation/ui/spacing.dart';
import '../bloc/live_bloc.dart';
import '../bloc/live_state.dart';
import '../logic/live_issue.dart';
import '../settings/live_settings_manager.dart';

/// 直播面板里不是开关的那几行：房间号、SESSDATA、连接状态、指令提示。
///
/// 做成 `SettingsPanel.extra` 而不是去改 `SettingsPanel.children` 的类型：那边是
/// `List<SettingsItem>`（纯数据、由面板统一渲染成开关），为一个面板把它改成多态
/// 不划算。
///
/// 自己读一次 [LiveSettings] 把输入框填上，而不是把房间号和 SESSDATA 塞进
/// `LiveState`：那是登录凭据，没必要跟着每次状态变更在 bloc 里流转和比较。
class LiveSettingsSection extends StatefulWidget {
  const LiveSettingsSection({super.key});

  @override
  State<LiveSettingsSection> createState() => _LiveSettingsSectionState();
}

class _LiveSettingsSectionState extends State<LiveSettingsSection> {
  final _roomId = TextEditingController();
  final _sessdata = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _roomId.dispose();
    _sessdata.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final settings = await context.read<LiveSettingsManager>().load();
    if (!mounted) {
      return;
    }
    setState(() {
      _roomId.text = settings.roomId?.toString() ?? '';
      _sessdata.text = settings.sessdata ?? '';
    });
  }

  /// 提交房间号。空串表示清掉，那就断开。
  void _applyRoomId() {
    final text = _roomId.text.trim();
    context.read<LiveBloc>().setRoomId(
      text.isEmpty ? null : int.tryParse(text),
    );
  }

  void _applySessdata() {
    context.read<LiveBloc>().setSessdata(_sessdata.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveBloc, LiveState>(
      builder:
          (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                key: const ValueKey('live-room-id'),
                controller: _roomId,
                label: t.live_room_id,
                hint: t.live_room_id_hint,
                keyboardType: TextInputType.number,
                onApply: _applyRoomId,
              ),
              _field(
                key: const ValueKey('live-sessdata'),
                controller: _sessdata,
                label: t.live_sessdata,
                hint: t.live_sessdata_hint,
                // 登录凭据，不画在屏幕上——设置页有可能被直播画面拍到
                obscure: true,
                onApply: _applySessdata,
              ),
              _status(state),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.x16,
                  Spacing.x8,
                  Spacing.x16,
                  Spacing.x16,
                ),
                child: Text(
                  t.live_commands,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onApply,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return ListTile(
      key: key,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.x16),
      title: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          isDense: true,
        ),
        // 回车和点到别处都算提交。两个都挂上是因为桌面上「填完直接去点开关」
        // 比按回车更常见，只认回车会让改动静默丢失。
        onSubmitted: (_) => onApply(),
        onTapOutside: (_) => onApply(),
      ),
    );
  }

  Widget _status(LiveState state) {
    final issue = state.issue;
    final text = issue == null ? _statusLabel(state) : _issueText(issue);

    return ListTile(
      key: const ValueKey('live-status'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.x16),
      title: Text(t.live_status),
      subtitle: Text(
        text,
        style: TextStyle(
          color:
              issue != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  /// 把原因码翻成当前语言。
  ///
  /// 远端给的原始信息（HTTP 状态码、B 站自己的 message）**原样**附在后面，不翻。
  /// 那是 B 站的话，翻了反而让排查变难。
  String _issueText(LiveIssueInfo info) {
    final detail = info.detail ?? '';
    // `Detail` 首字母大写是 slang 的 `param_case: pascal` 约定，不是笔误。
    return switch (info.issue) {
      LiveIssue.unsupportedPlatform => t.live_issue_unsupported_platform,
      LiveIssue.missingRoomId => t.live_issue_missing_room_id,
      LiveIssue.disconnected => t.live_issue_disconnected,
      LiveIssue.network => t.live_issue_network(Detail: detail),
      LiveIssue.unavailable => t.live_issue_unavailable(Detail: detail),
      LiveIssue.apiError => t.live_issue_api_error(Detail: detail),
      LiveIssue.roomNotFound => t.live_issue_room_not_found,
      LiveIssue.authRejected => t.live_issue_auth_rejected(Detail: detail),
    };
  }

  String _statusLabel(LiveState state) {
    return switch (state.status) {
      LiveConnectionStatus.off => t.live_status_off,
      LiveConnectionStatus.connecting => t.live_status_connecting,
      // 参数名首字母大写是 slang 的 `param_case: pascal` 约定，不是笔误。
      LiveConnectionStatus.connected => t.live_status_connected(
        RoomId: state.roomId ?? 0,
      ),
      LiveConnectionStatus.retrying => t.live_status_retrying,
    };
  }
}
