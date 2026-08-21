import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// 统一的 Bangumi 设置页面，融合认证登录与状态同步
class UnifiedBangumiPage extends StatefulWidget {
  const UnifiedBangumiPage({super.key});

  @override
  State<UnifiedBangumiPage> createState() => _UnifiedBangumiPageState();
}

enum _LoginMethod {
  app,
  oauth,
  token,
}

class _UnifiedBangumiPageState extends State<UnifiedBangumiPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController captchaController = TextEditingController();
  final TextEditingController oauthCodeController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();
  final MenuController syncPriorityMenuController = MenuController();

  Box setting = GStorage.setting;

  bool saving = false;
  bool loadingCaptcha = false;
  bool obscurePassword = true;
  bool syncCollectiblesing = false;
  bool isVerifying = false;
  BangumiCaptchaChallenge? captchaChallenge;
  _LoginMethod selectedMethod = _LoginMethod.token;

  late bool bangumiSyncEnable;
  late bool bangumiImmediateSyncToastEnable;
  late int syncPriority;

  bool get _selectedMethodRequiresOauth =>
      selectedMethod == _LoginMethod.app ||
      selectedMethod == _LoginMethod.oauth;

  bool get _selectedMethodAvailable =>
      !_selectedMethodRequiresOauth || BangumiAuth.hasOauthConfig;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    bangumiSyncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    bangumiImmediateSyncToastEnable = setting.get(
      SettingBoxKey.bangumiImmediateSyncToastEnable,
      defaultValue: true,
    );
    syncPriority =
        setting.get(SettingBoxKey.bangumiSyncPriority, defaultValue: 0);
    // 如果有已保存的 Token，显示在 Token 输入框中
    final savedToken =
        setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
    if (savedToken.isNotEmpty) {
      tokenController.text = savedToken;
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    captchaController.dispose();
    oauthCodeController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  // ============================================================
  // Account / Auth helpers
  // ============================================================

  Future<void> _loadSavedUsername() async {
    usernameController.text = await BangumiAuth.savedUsername;
    if (mounted) setState(() {});
  }

  Future<void> _loadCaptchaIfNeeded({bool refresh = false}) async {
    if (selectedMethod != _LoginMethod.app || !BangumiAuth.hasOauthConfig) {
      return;
    }
    await _loadCaptcha(refresh: refresh);
  }

  Future<void> _loadCaptcha({bool refresh = false}) async {
    if (loadingCaptcha) return;
    setState(() => loadingCaptcha = true);
    try {
      final challenge = refresh
          ? await BangumiAuth.refreshCaptcha()
          : await BangumiAuth.loadCaptcha();
      if (!mounted) return;
      setState(() => captchaChallenge = challenge);
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: 'Bangumi 验证码加载失败 ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => loadingCaptcha = false);
    }
  }

  Future<void> _openOauthPage() async {
    try {
      final uri = Uri.parse(BangumiAuth.authorizeUrl);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('无法打开浏览器');
    } catch (e) {
      KazumiDialog.showToast(message: '打开 Bangumi OAuth 页面失败 ${e.toString()}');
    }
  }

  Future<void> _copyOauthLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: BangumiAuth.authorizeUrl));
      KazumiDialog.showToast(message: 'Bangumi OAuth 链接已复制');
    } catch (e) {
      KazumiDialog.showToast(message: '复制 Bangumi OAuth 链接失败 ${e.toString()}');
    }
  }

  Future<void> login() async {
    if (!_selectedMethodAvailable) {
      KazumiDialog.showToast(message: '当前构建未启用所选 Bangumi 登录方式');
      return;
    }
    setState(() => saving = true);
    try {
      late final String successMessage;
      switch (selectedMethod) {
        case _LoginMethod.app:
          final username = usernameController.text.trim();
          final password = passwordController.text;
          final captcha = captchaController.text.trim();
          if (username.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi 账号');
            return;
          }
          if (password.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi 密码');
            return;
          }
          final user = await BangumiAuth.loginWithPassword(
            username: username,
            password: password,
            captcha: captcha,
          );
          passwordController.clear();
          captchaController.clear();
          // 同步后的 Token 写入 token 显示字段
          tokenController.text =
              setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
          successMessage = 'Bangumi 软件内登录成功：${user.nickname}';
          break;
        case _LoginMethod.oauth:
          final oauthCode = oauthCodeController.text.trim();
          if (oauthCode.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi 授权码或回调链接');
            return;
          }
          final user = await BangumiAuth.loginWithAuthorizationCode(oauthCode);
          oauthCodeController.clear();
          tokenController.text =
              setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
          successMessage = 'Bangumi OAuth 登录成功：${user.nickname}';
          break;
        case _LoginMethod.token:
          final token = tokenController.text.trim();
          if (token.isEmpty) {
            KazumiDialog.showToast(message: '请输入 Bangumi Access Token');
            return;
          }
          final user = await BangumiAuth.verifyAndSaveToken(token);
          successMessage = 'Bangumi Token 登录成功：${user.nickname}';
          break;
      }
      if (!mounted) return;
      KazumiDialog.showToast(message: successMessage);
      // 登录成功后自动启用同步
      if (!bangumiSyncEnable) {
        await setting.put(SettingBoxKey.bangumiSyncEnable, true);
        if (mounted) setState(() => bangumiSyncEnable = true);
      }
      setState(() {});
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 登录失败 ${e.toString()}');
      if (selectedMethod == _LoginMethod.app) {
        await _loadCaptcha(refresh: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> logout() async {
    await BangumiAuth.logout();
    usernameController.clear();
    passwordController.clear();
    captchaController.clear();
    oauthCodeController.clear();
    tokenController.clear();
    // 退出时自动关闭同步
    if (bangumiSyncEnable) {
      await setting.put(SettingBoxKey.bangumiSyncEnable, false);
    }
    BangumiSyncService().reset();
    if (!mounted) return;
    setState(() {
      bangumiSyncEnable = false;
    });
    KazumiDialog.showToast(message: '已退出 Bangumi 登录');
  }

  // ============================================================
  // Sync helpers
  // ============================================================

  Future<void> updateSyncPriority(int value) async {
    await setting.put(SettingBoxKey.bangumiSyncPriority, value);
    if (!mounted) return;
    setState(() => syncPriority = value);
  }

  Future<void> syncWithProgress() async {
    if (!bangumiSyncEnable) {
      KazumiDialog.showToast(message: '请先登录并启用 Bangumi 同步');
      return;
    }

    final ValueNotifier<double?> progressValue = ValueNotifier<double?>(null);
    final ValueNotifier<String> progressText =
        ValueNotifier<String>('准备同步 Bangumi 状态...');

    try {
      setState(() => syncCollectiblesing = true);

      KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bangumi 同步进行中',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: progressText,
                        builder: (_, value, __) => Text(value),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<double?>(
                        valueListenable: progressValue,
                        builder: (_, value, __) =>
                            LinearProgressIndicator(value: value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      final bangumi = BangumiSyncService();
      await bangumi.ping();
      await bangumi.syncCollectibles(
        onProgress: (message, current, total) {
          progressText.value =
              total > 0 ? '$message ($current/$total)' : message;
          if (total > 0) {
            progressValue.value = (current / total).clamp(0.0, 1.0);
          } else {
            progressValue.value = null;
          }
        },
      );
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 同步失败 $e');
    } finally {
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
      progressValue.dispose();
      progressText.dispose();
      if (mounted) setState(() => syncCollectiblesing = false);
    }
  }

  Future<void> verifyToken() async {
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: 'Access Token 不能为空');
      return;
    }
    setState(() => isVerifying = true);
    await setting.put(SettingBoxKey.bangumiAccessToken, token);
    final bangumi = BangumiSyncService();

    if (token.isEmpty) {
      bangumi.reset();
      KazumiDialog.showToast(message: 'Bangumi Token 为空，请检查');
      if (!mounted) return;
      setState(() => isVerifying = false);
      return;
    }

    KazumiDialog.showToast(message: '正在测试 Bangumi Token...');
    try {
      await bangumi.init();
    } catch (e) {
      KazumiDialog.showToast(message: '验证失败：${e.toString()}');
      await setting.put(SettingBoxKey.bangumiSyncEnable, false);
      if (!mounted) return;
      setState(() {
        isVerifying = false;
        bangumiSyncEnable = false;
      });
      return;
    }

    KazumiDialog.showToast(message: '测试成功，用户名：${bangumi.username}');
    if (!mounted) return;
    setState(() => isVerifying = false);
  }

  // ============================================================
  // UI Builders
  // ============================================================

  Widget _buildHintCard({required String title, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    );
  }

  // --- Account Section ---

  Widget _buildAccountHeader() {
    final userName = BangumiAuth.nickname.isNotEmpty
        ? BangumiAuth.nickname
        : (BangumiAuth.username.isNotEmpty ? BangumiAuth.username : '未登录');
    final avatarUrl = BangumiAuth.avatar;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: avatarUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: NetworkImgLayer(
                        src: avatarUrl,
                        width: 44,
                        height: 44,
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bangumi 账号',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            if (BangumiAuth.isLoggedIn)
              FilledButton.tonal(
                onPressed: logout,
                child: const Text('退出'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return SegmentedButton<_LoginMethod>(
      segments: const [
        ButtonSegment<_LoginMethod>(
          value: _LoginMethod.app,
          label: Text('软件内登录'),
          icon: Icon(Icons.devices_rounded),
        ),
        ButtonSegment<_LoginMethod>(
          value: _LoginMethod.oauth,
          label: Text('OAuth'),
          icon: Icon(Icons.open_in_new_rounded),
        ),
        ButtonSegment<_LoginMethod>(
          value: _LoginMethod.token,
          label: Text('Token'),
          icon: Icon(Icons.key_rounded),
        ),
      ],
      selected: {_LoginMethod.values[selectedMethod.index]},
      onSelectionChanged: saving
          ? null
          : (selection) {
              if (selection.isEmpty) return;
              setState(() => selectedMethod = selection.first);
              _loadCaptchaIfNeeded();
            },
      multiSelectionEnabled: false,
      emptySelectionAllowed: false,
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
        selectedBackgroundColor:
            Theme.of(context).colorScheme.secondaryContainer,
        selectedForegroundColor:
            Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildAppLoginForm() {
    if (!BangumiAuth.hasOauthConfig) {
      return _buildHintCard(
        title: '软件内登录不可用',
        message:
            '当前构建未注入 Bangumi OAuth 配置，无法通过软件内登录换取 Token。请改用 Token 登录，或使用带 OAuth 配置的正式构建。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'Bangumi 账号',
            border: OutlineInputBorder(),
            helperText: '本地加密保存账号，用于自动登录换取 Token',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Bangumi 密码',
            border: const OutlineInputBorder(),
            helperText: '登录成功后本地加密保存，仅用于自动登录获取 Token',
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: captchaController,
          decoration: const InputDecoration(
            labelText: 'Bangumi 验证码',
            border: OutlineInputBorder(),
            helperText:
                '首次登录按当前页面验证码填写；成功后后续优先使用 Refresh Token 续期',
          ),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 64,
                child: Center(
                  child: loadingCaptcha
                      ? const CircularProgressIndicator()
                      : captchaChallenge == null
                          ? const Text('验证码未加载')
                          : Image.memory(
                              captchaChallenge!.imageBytes,
                              height: 48,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, _) =>
                                  const Text('验证码显示失败'),
                            ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    loadingCaptcha ? null : () => _loadCaptcha(refresh: true),
                child: Text(loadingCaptcha ? '加载中...' : '刷新验证码'),
              ),
              const SizedBox(height: 8),
              const Text(
                '该验证码与当前登录会话绑定。首次登录需要在这里填写当前图片验证码；授权成功后，后续启动会优先使用 Refresh Token 自动续期。',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOauthForm() {
    if (!BangumiAuth.hasOauthConfig) {
      return _buildHintCard(
        title: 'OAuth 登录不可用',
        message:
            '当前构建未注入 Bangumi OAuth 配置，无法生成授权链接。请改用 Token 登录，或使用带 OAuth 配置的正式构建。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: oauthCodeController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '授权码或回调链接',
            border: OutlineInputBorder(),
            helperText:
                '在浏览器完成 Bangumi 授权后，将 code 或完整回调链接粘贴到这里',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: _openOauthPage,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('打开 Bangumi 授权页'),
            ),
            OutlinedButton.icon(
              onPressed: _copyOauthLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('复制授权链接'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHintCard(
          title: 'OAuth 使用说明',
          message:
              '此方式会清除旧的本地 Bangumi 密码。打开授权页后，在浏览器中完成授权，再把回调链接中的 code 参数或完整链接粘贴回来，也支持粘贴 code=xxxx。',
        ),
      ],
    );
  }

  Widget _buildTokenForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: tokenController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Bangumi Access Token',
            border: OutlineInputBorder(),
            helperText:
                '粘贴已有 Access Token。保存前会调用 Bangumi /v0/me 校验账号信息。',
          ),
        ),
        const SizedBox(height: 12),
        _buildHintCard(
          title: 'Token 使用说明',
          message:
              '适合已经在其他地方完成授权的情况。此方式会校验并保存 Access Token，同时清除旧的本地账号密码和 Refresh Token。',
        ),
      ],
    );
  }

  Widget _buildSelectedForm() {
    switch (selectedMethod) {
      case _LoginMethod.app:
        return _buildAppLoginForm();
      case _LoginMethod.oauth:
        return _buildOauthForm();
      case _LoginMethod.token:
        return _buildTokenForm();
    }
  }

  String _buildSubmitText() {
    switch (selectedMethod) {
      case _LoginMethod.app:
        return '软件内登录并启用同步';
      case _LoginMethod.oauth:
        return '使用 OAuth 登录';
      case _LoginMethod.token:
        return '保存 Token 并登录';
    }
  }

  // --- Sync Section ---

  Widget _buildSyncSettings() {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('同步设置', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Card(
          child: SettingsSection(
            margin: EdgeInsetsDirectional.zero,
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) async {
                  final newValue = value ?? !bangumiSyncEnable;
                  await setting.put(SettingBoxKey.bangumiSyncEnable, newValue);
                  if (mounted) setState(() => bangumiSyncEnable = newValue);
                },
                title: Text('启用 Bangumi 同步', style: TextStyle(fontFamily: fontFamily)),
                description: Text('启用后，收藏状态变化时会自动同步到 Bangumi', style: TextStyle(fontFamily: fontFamily)),
                initialValue: bangumiSyncEnable,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bangumiImmediateSyncToastEnable =
                      value ?? !bangumiImmediateSyncToastEnable;
                  await setting.put(
                    SettingBoxKey.bangumiImmediateSyncToastEnable,
                    bangumiImmediateSyncToastEnable,
                  );
                  if (mounted) setState(() {});
                },
                title: Text('即时同步提示', style: TextStyle(fontFamily: fontFamily)),
                description: Text('点击追番按钮触发即时同步时显示提示框', style: TextStyle(fontFamily: fontFamily)),
                initialValue: bangumiImmediateSyncToastEnable,
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  if (syncPriorityMenuController.isOpen) {
                    syncPriorityMenuController.close();
                  } else {
                    syncPriorityMenuController.open();
                  }
                },
                title: Text('同步优先级', style: TextStyle(fontFamily: fontFamily)),
                description: Text('当本地与 Bangumi 状态不一致时优先使用哪个状态', style: TextStyle(fontFamily: fontFamily)),
                value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: syncPriorityMenuController,
                    builder: (context, controller, child) => Text(
                        BangumiSyncPriority.fromValue(syncPriority).label,
                        style: TextStyle(fontFamily: fontFamily)),
                    menuChildren: [
                      for (final entry in BangumiSyncPriority.values)
                        MenuItemButton(
                            requestFocusOnHover: false,
                            onPressed: () =>
                                updateSyncPriority(entry.value),
                            child: Container(
                                height: 48,
                                constraints:
                                    BoxConstraints(minWidth: 112),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    entry.label,
                                    style: TextStyle(
                                      color: entry.value == syncPriority
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                )))
                    ]),
              ),
              SettingsTile(
                trailing: syncCollectiblesing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                onPressed: (_) async {
                  await syncWithProgress();
                },
                title: Text("立即同步状态", style: TextStyle(fontFamily: fontFamily)),
                description: Text('同步状态不一致或仅存在于本地/远端的条目', style: TextStyle(fontFamily: fontFamily)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Main build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: !syncCollectiblesing && !saving,
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Bangumi 设置')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 1000 ? 1000 : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // === Account Section ===
                  _buildAccountHeader(),
                  const SizedBox(height: 16),

                  // Login method (only show when not logged in)
                  if (!BangumiAuth.isLoggedIn) ...[
                    Text('登录方式', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildMethodSelector(),
                    const SizedBox(height: 12),
                    Text(
                      switch (selectedMethod) {
                        _LoginMethod.app =>
                          '软件内登录：在应用内输入账号、密码和验证码，完成登录后自动保存刷新信息。',
                        _LoginMethod.oauth =>
                          'OAuth：跳转浏览器完成 Bangumi 授权，再把授权码或回调链接粘贴回来。',
                        _LoginMethod.token =>
                          'Token：直接粘贴已有 Access Token，校验成功后立即启用同步。',
                      },
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildSelectedForm(),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          saving || !_selectedMethodAvailable ? null : login,
                      child: Text(saving ? '登录中...' : _buildSubmitText()),
                    ),
                  ],

                  // === Sync Settings Section (always visible) ===
                  const SizedBox(height: 24),
                  _buildSyncSettings(),

                  // Token quick save / verify (when logged in via token)
                  if (BangumiAuth.isLoggedIn && selectedMethod == _LoginMethod.token) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: isVerifying ? null : verifyToken,
                      child: Text(isVerifying ? '验证中...' : '验证并保存 Token'),
                    ),
                  ],

                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final url =
                          Uri.parse('https://next.bgm.tv/demo/access-token');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } else {
                        KazumiDialog.showToast(message: '无法打开链接');
                      }
                    },
                    child: Text(
                      '点击此处前往 Bangumi 生成 Access Token',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: fontFamily,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
