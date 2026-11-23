import 'package:flutter/material.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../engine/page_models.dart';

/// 阅读器悬浮顶部导航栏（不腰斩长书名，保留返回、换源、加书架、缓存入口）
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.paper,
    required this.topSafe,
    required this.bookTitle,
    required this.chapterTitle,
    required this.inShelf,
    required this.onBack,
    required this.onOpenSource,
    required this.onAddToShelf,
    required this.onOpenDownload,
  });

  final ReaderPaperTheme paper;
  final double topSafe;
  final String bookTitle;
  final String chapterTitle;
  final bool inShelf;
  final VoidCallback onBack;
  final VoidCallback onOpenSource;
  final VoidCallback onAddToShelf;
  final VoidCallback onOpenDownload;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(8.0, topSafe + 4.0, 8.0, 10.0),
        decoration: BoxDecoration(
          color: paper.menuBg,
          border: Border(
            bottom: BorderSide(
              color: paper.secondaryText.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12.0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              constraints:
                  const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19.0,
                color: paper.textColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoftTypography.cardTitle
                        .copyWith(color: paper.textColor, fontSize: 14.5),
                  ),
                  Text(
                    chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoftTypography.micro
                        .copyWith(color: paper.secondaryText),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '切换书源',
              constraints:
                  const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              onPressed: onOpenSource,
              icon: Icon(Icons.swap_horiz_rounded, color: paper.textColor),
            ),
            IconButton(
              tooltip: inShelf ? '已在书架' : '加入书架',
              constraints:
                  const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              onPressed: onAddToShelf,
              icon: Icon(
                inShelf
                    ? Icons.library_add_check_rounded
                    : Icons.library_add_outlined,
                color: inShelf ? paper.accent : paper.textColor,
              ),
            ),
            IconButton(
              tooltip: '离线缓存',
              constraints:
                  const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
              onPressed: onOpenDownload,
              icon: Icon(
                Icons.download_for_offline_outlined,
                color: paper.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 阅读器悬浮底部控制栏（拖拽章节预览不乱发网络请求，松手再跳章）
class ReaderBottomBar extends StatefulWidget {
  const ReaderBottomBar({
    super.key,
    required this.paper,
    required this.botSafe,
    required this.chapterIndex,
    required this.totalChapters,
    required this.chapterTitles,
    required this.onJumpChapter,
    required this.onOpenCatalog,
    required this.onOpenSource,
    required this.onToggleDark,
    required this.onOpenTypography,
  });

  final ReaderPaperTheme paper;
  final double botSafe;
  final int chapterIndex;
  final int totalChapters;
  final List<String> chapterTitles;
  final ValueChanged<int> onJumpChapter;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenSource;
  final VoidCallback onToggleDark;
  final VoidCallback onOpenTypography;

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  int? _draggingIndex;

  @override
  void didUpdateWidget(covariant ReaderBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterIndex != widget.chapterIndex) {
      _draggingIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxChapter = widget.totalChapters <= 1 ? 0 : widget.totalChapters - 1;
    final activeIdx = (_draggingIndex ?? widget.chapterIndex).clamp(0, maxChapter);
    final previewTitle = (activeIdx < widget.chapterTitles.length)
        ? widget.chapterTitles[activeIdx]
        : '';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.0, 10.0, 16.0, widget.botSafe + 8.0),
        decoration: BoxDecoration(
          color: widget.paper.menuBg,
          border: Border(
            top: BorderSide(
              color: widget.paper.secondaryText.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_draggingIndex != null && previewTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  previewTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoftTypography.micro
                      .copyWith(color: widget.paper.accent),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: widget.chapterIndex > 0
                      ? () => widget.onJumpChapter(widget.chapterIndex - 1)
                      : null,
                  child: Text(
                    '上一章',
                    style: SoftTypography.caption.copyWith(
                      color: widget.chapterIndex > 0
                          ? widget.paper.textColor
                          : widget.paper.secondaryText,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: maxChapter > 0 ? maxChapter.toDouble() : 1.0,
                    value: activeIdx
                        .toDouble()
                        .clamp(0.0, maxChapter > 0 ? maxChapter.toDouble() : 1.0),
                    activeColor: widget.paper.accent,
                    onChanged: maxChapter <= 0
                        ? null
                        : (v) => setState(() => _draggingIndex = v.round()),
                    onChangeEnd: maxChapter <= 0
                        ? null
                        : (v) {
                            final target = v.round();
                            setState(() => _draggingIndex = null);
                            if (target != widget.chapterIndex) {
                              widget.onJumpChapter(target);
                            }
                          },
                  ),
                ),
                TextButton(
                  onPressed: widget.chapterIndex < maxChapter
                      ? () => widget.onJumpChapter(widget.chapterIndex + 1)
                      : null,
                  child: Text(
                    '下一章',
                    style: SoftTypography.caption.copyWith(
                      color: widget.chapterIndex < maxChapter
                          ? widget.paper.textColor
                          : widget.paper.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomAction(
                  icon: Icons.format_list_bulleted_rounded,
                  label: '目录',
                  color: widget.paper.textColor,
                  onTap: widget.onOpenCatalog,
                ),
                _BottomAction(
                  icon: Icons.swap_horiz_rounded,
                  label: '换源',
                  color: widget.paper.textColor,
                  onTap: widget.onOpenSource,
                ),
                _BottomAction(
                  icon: widget.paper.isDark
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  label: widget.paper.isDark ? '日间' : '夜间',
                  color: widget.paper.textColor,
                  onTap: widget.onToggleDark,
                ),
                _BottomAction(
                  icon: Icons.text_fields_rounded,
                  label: '排版',
                  color: widget.paper.textColor,
                  onTap: widget.onOpenTypography,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56.0, minHeight: 46.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20.0, color: color),
            const SizedBox(height: 3.0),
            Text(label, style: SoftTypography.micro.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
