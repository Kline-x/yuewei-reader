import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../design_system/components/soft_bottom_sheet.dart';
import '../../../design_system/components/soft_text_field.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

/// 阅读器目录底部抽屉（支持搜索高亮、正倒序、一键定位当前章、已缓存标志）
class ReaderCatalogSheet extends StatefulWidget {
  const ReaderCatalogSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onSelectChapter,
  });

  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onSelectChapter;

  static Future<void> show(
    BuildContext context, {
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required ValueChanged<int> onSelectChapter,
  }) {
    return SoftBottomSheet.show(
      context,
      title: '全书目录',
      subtitle: '共 ${chapters.length} 章',
      headerIcon: Icons.format_list_bulleted_rounded,
      maxHeightFactor: 0.84,
      builder: (_) => ReaderCatalogSheet(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onSelectChapter: onSelectChapter,
      ),
    );
  }

  @override
  State<ReaderCatalogSheet> createState() => _ReaderCatalogSheetState();
}

class _ReaderCatalogSheetState extends State<ReaderCatalogSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _descending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Chapter> get _displayList {
    Iterable<Chapter> list =
        _descending ? widget.chapters.reversed : widget.chapters;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) => c.title.toLowerCase().contains(q));
    }
    return list.toList();
  }

  void _jumpToCurrent() {
    if (!_scrollCtrl.hasClients) return;
    final list = _displayList;
    final idx =
        list.indexWhere((c) => c.chapterIndex == widget.currentChapterIndex);
    if (idx < 0) return;
    final targetOffset = (idx * 50.0 - 120.0)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final list = _displayList;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SoftSpacing.lg,
            SoftSpacing.md,
            SoftSpacing.lg,
            SoftSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SoftTextField(
                  controller: _searchCtrl,
                  hintText: '搜索章节名称…',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(width: SoftSpacing.sm),
              IconButton(
                tooltip: '定位当前章',
                constraints:
                    const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: _jumpToCurrent,
                icon: Icon(Icons.my_location_rounded, color: tokens.accent),
              ),
              IconButton(
                tooltip: _descending ? '切回正序' : '切为倒序',
                constraints:
                    const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                onPressed: () {
                  setState(() => _descending = !_descending);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _jumpToCurrent());
                },
                icon: Icon(
                  _descending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    '未匹配到相关章节',
                    style: SoftTypography.body
                        .copyWith(color: tokens.textTertiary),
                  ),
                )
              : ListView.separated(
                  controller: _scrollCtrl,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1.0,
                    indent: 20.0,
                    endIndent: 20.0,
                    color: tokens.borderSubtle,
                  ),
                  itemBuilder: (ctx, i) {
                    final ch = list[i];
                    final isCurrent =
                        ch.chapterIndex == widget.currentChapterIndex;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SoftSpacing.xl,
                        vertical: 2.0,
                      ),
                      selected: isCurrent,
                      selectedTileColor: tokens.accentSoft,
                      title: Text(
                        ch.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.body.copyWith(
                          color: isCurrent ? tokens.accent : tokens.textPrimary,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      trailing: ch.isCached
                          ? Icon(
                              Icons.offline_pin_rounded,
                              size: 16.0,
                              color: isCurrent
                                  ? tokens.accent
                                  : tokens.textTertiary,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelectChapter(ch.chapterIndex);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
