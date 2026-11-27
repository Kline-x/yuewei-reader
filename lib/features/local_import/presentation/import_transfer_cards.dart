import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_button.dart';
import '../../../design_system/components/soft_card.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';
import '../wifi/wifi_transfer_server.dart';

typedef WifiReceivedEntry = ({WifiReceivedItem item, String? bookId});

Widget _surfaceBox(SoftTokens tokens, Widget child) => Container(
      padding: const EdgeInsets.all(SoftSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SoftRadius.subCard),
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
      ),
      child: child,
    );

/// 本机文件导入卡片
class LocalImportCard extends StatelessWidget {
  const LocalImportCard({
    super.key,
    required this.importing,
    required this.lastImported,
    required this.onPickAndImport,
    required this.onOpenBook,
    required this.onGoShelf,
  });

  final bool importing;
  final Book? lastImported;
  final VoidCallback onPickAndImport;
  final ValueChanged<String> onOpenBook;
  final VoidCallback onGoShelf;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final imported = lastImported;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.folder_open_rounded, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text('本机文件导入', style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(SoftRadius.pill),
              ),
              child: Text('TXT · EPUB', style: SoftTypography.micro.copyWith(color: tokens.accent)),
            ),
          ]),
          const SizedBox(height: 8.0),
          Text(
            '自动识别 UTF-8 / GBK 编码并智能分章；EPUB 自动提取封面、作者与完整目录，立即离线阅读。',
            style: SoftTypography.body.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: SoftSpacing.lg),
          SoftButton(
            label: importing ? '正在解析导入…' : '选择本地电子书',
            icon: Icons.drive_folder_upload_outlined,
            expand: true,
            isLoading: importing,
            onPressed: onPickAndImport,
          ),
          if (imported != null) ...[
            const SizedBox(height: SoftSpacing.md),
            _surfaceBox(
              tokens,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '已入库：《${imported.title}》',
                  style: SoftTypography.cardTitle.copyWith(fontSize: 14.0, color: tokens.textPrimary),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${imported.author} · 共 ${imported.totalChapters} 章',
                  style: SoftTypography.caption.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: SoftSpacing.md),
                Row(children: [
                  Expanded(
                    child: SoftButton(
                      label: '立即打开',
                      icon: Icons.menu_book_rounded,
                      compact: true,
                      onPressed: () => onOpenBook(imported.id),
                    ),
                  ),
                  const SizedBox(width: SoftSpacing.sm),
                  Expanded(
                    child: SoftButton(
                      label: '查看书架',
                      icon: Icons.collections_bookmark_outlined,
                      tone: SoftButtonTone.tonal,
                      compact: true,
                      onPressed: onGoShelf,
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// 局域网 Wi-Fi 无线传书卡片（含安全配对码展示与离开自动停服提示）
class WifiTransferCard extends StatelessWidget {
  const WifiTransferCard({
    super.key,
    required this.server,
    required this.togglingWifi,
    required this.received,
    required this.onToggleWifi,
    required this.onCopyText,
    required this.onOpenReceived,
  });

  final WifiTransferServer server;
  final bool togglingWifi;
  final List<WifiReceivedEntry> received;
  final ValueChanged<bool> onToggleWifi;
  final void Function(String text, String toast) onCopyText;
  final ValueChanged<WifiReceivedEntry> onOpenReceived;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final isRunning = server.isRunning;
    final displayUrl = server.authUrl ?? server.serverUrl;
    final token = server.accessToken;
    final altUrls = server.authListenUrls.skip(1).take(2).toList();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.wifi_tethering_rounded, size: 20.0, color: tokens.accent),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('局域网 Wi-Fi 无线传书', style: SoftTypography.cardTitle.copyWith(color: tokens.textPrimary)),
                Text(
                  isRunning ? '服务运行中 · 端口 ${server.port ?? ''}' : '开启后可在电脑浏览器批量上传',
                  style: SoftTypography.caption.copyWith(color: isRunning ? tokens.accent : tokens.textTertiary),
                ),
              ]),
            ),
            SoftSwitch(
              value: isRunning,
              semanticLabel: '开关 Wi-Fi 传书服务',
              onChanged: togglingWifi ? null : onToggleWifi,
            ),
          ]),
          const SizedBox(height: 8.0),
          Text(
            '支持同一局域网下的电脑或平板浏览器拖入上传 .txt / .epub 电子书、.json 书源与 .ttf / .otf 字体。离开本页将自动停止服务以保障局域网安全。',
            style: SoftTypography.body.copyWith(color: tokens.textSecondary),
          ),
          if (isRunning && displayUrl != null) ...[
            const SizedBox(height: SoftSpacing.md),
            _surfaceBox(
              tokens,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('电脑浏览器访问以下带配对码的一键地址：', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
                const SizedBox(height: 6.0),
                Row(children: [
                  Expanded(
                    child: SelectableText(
                      displayUrl,
                      style: SoftTypography.cardTitle.copyWith(color: tokens.accent, fontSize: 14.0),
                    ),
                  ),
                  const SizedBox(width: SoftSpacing.sm),
                  SoftButton(
                    label: '复制',
                    icon: Icons.copy_rounded,
                    tone: SoftButtonTone.tonal,
                    compact: true,
                    onPressed: () => onCopyText(displayUrl, '已复制传书地址'),
                  ),
                ]),
                if (token != null && token.isNotEmpty) ...[
                  const SizedBox(height: SoftSpacing.sm),
                  Row(children: [
                    Text('4 位安全配对码：', style: SoftTypography.caption.copyWith(color: tokens.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: BorderRadius.circular(SoftRadius.pill),
                      ),
                      child: SelectableText(
                        token,
                        style: SoftTypography.cardTitle.copyWith(
                          color: tokens.accent,
                          fontSize: 15.0,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SoftButton(
                      label: '复制码',
                      icon: Icons.key_rounded,
                      tone: SoftButtonTone.tonal,
                      compact: true,
                      onPressed: () => onCopyText(token, '已复制 4 位配对码'),
                    ),
                  ]),
                ],
                if (altUrls.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Text('备选地址：${altUrls.join(' · ')}', style: SoftTypography.micro.copyWith(color: tokens.textTertiary)),
                ] else if (displayUrl.contains('127.0.0.1')) ...[
                  const SizedBox(height: 6.0),
                  Text('未检测到局域网 IP，请确认设备已接入 Wi-Fi', style: SoftTypography.micro.copyWith(color: tokens.warning)),
                ],
              ]),
            ),
          ],
          if (isRunning || received.isNotEmpty) ...[
            const SizedBox(height: SoftSpacing.lg),
            Text(
              '本次接收记录 (${received.length})',
              style: SoftTypography.caption.copyWith(color: tokens.textSecondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8.0),
            if (received.isEmpty)
              Text('正在等待局域网设备上传文件…', style: SoftTypography.caption.copyWith(color: tokens.textTertiary))
            else
              ...received.map((rec) => _buildReceivedTile(tokens, rec)),
          ],
        ]),
      ),
    );
  }

  Widget _buildReceivedTile(SoftTokens tokens, WifiReceivedEntry rec) {
    final kind = rec.item.kind;
    final isBook = kind == 'book';
    final isFont = kind == 'font';
    final h = rec.item.receivedAt.hour.toString().padLeft(2, '0');
    final m = rec.item.receivedAt.minute.toString().padLeft(2, '0');
    final IconData leadingIcon;
    final String badgeLabel;
    final String subtitleText;
    if (isBook) {
      leadingIcon = Icons.menu_book_rounded;
      badgeLabel = '书籍';
      subtitleText = '本地藏书 · ${rec.item.itemCount} 章 · $h:$m';
    } else if (isFont) {
      leadingIcon = Icons.font_download_rounded;
      badgeLabel = '字体';
      subtitleText = '自定义字体 · 点击查看选用说明 · $h:$m';
    } else {
      leadingIcon = Icons.dns_outlined;
      badgeLabel = '书源';
      subtitleText = '书源规则 · ${rec.item.itemCount} 条 · $h:$m';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SoftRadius.control),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SoftRadius.control)),
          leading: Icon(leadingIcon, size: 18.0, color: tokens.accent),
          title: Row(children: [
            Expanded(
              child: Text(
                rec.item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SoftTypography.body.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(SoftRadius.pill),
              ),
              child: Text(badgeLabel, style: SoftTypography.micro.copyWith(color: tokens.accent)),
            ),
          ]),
          subtitle: Text(
            subtitleText,
            style: SoftTypography.micro.copyWith(color: tokens.textSecondary),
          ),
          trailing: Icon(Icons.chevron_right_rounded, size: 18.0, color: tokens.textTertiary),
          onTap: () => onOpenReceived(rec),
        ),
      ),
    );
  }
}
