import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import '../engine/reader_page_slot.dart';
import 'page_painter.dart';

/// 单页 ui.Picture 矢量录制 LRU 缓存（支撑 120Hz 跟手拖拽每帧 < 0.2ms 绘制开销）
class PagePictureCache {
  PagePictureCache({this.maxEntries = 10});

  final int maxEntries;
  final LinkedHashMap<String, ui.Picture> _cache = LinkedHashMap();

  ui.Picture obtain(
    PageRenderItem item,
    TypographyConfig config,
    ReaderPaperTheme theme,
    Size size,
  ) {
    final fullKey =
        '${item.cacheKey}_${config.hashCode}_${theme.id}_${size.width.round()}x${size.height.round()}';

    final existing = _cache.remove(fullKey);
    if (existing != null) {
      // 命中后放至尾部（最近使用）
      _cache[fullKey] = existing;
      return existing;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    PagePainter.drawPage(
      canvas,
      size,
      page: item.page,
      totalPages: item.totalPagesInChapter,
      chapterTitle: item.chapterTitle,
      bookTitle: item.bookTitle,
      config: config,
      theme: theme,
    );
    final picture = recorder.endRecording();
    _cache[fullKey] = picture;

    while (_cache.length > maxEntries) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      removed?.dispose();
    }
    return picture;
  }

  void clear() {
    for (final pic in _cache.values) {
      pic.dispose();
    }
    _cache.clear();
  }
}
