import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/chapter_file_store.dart';
import '../reader/engine/content_pipeline.dart';
import '../sources/data/source_repository.dart';
import '../sources/engine/source_crawler_service.dart';

enum DownloadTaskStatus {
  idle,
  downloading,
  completed,
  partialFailed,
  failed,
  cancelled,
}

@immutable
class DownloadProgressSnapshot {
  const DownloadProgressSnapshot({
    required this.bookId,
    required this.status,
    required this.total,
    required this.completed,
    required this.failed,
    required this.chaptersPerSec,
    this.errorMessage,
  });

  final String bookId;
  final DownloadTaskStatus status;
  final int total;
  final int completed;
  final int failed;
  final double chaptersPerSec;
  final String? errorMessage;

  double get ratio => total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
  bool get isRunning => status == DownloadTaskStatus.downloading;
}

/// 并发离线缓存调度器：
/// 引入递增 taskGeneration 令牌，彻底终结取消重开老 Worker 踩踏新任务及算速失真。
class DownloadManager {
  DownloadManager({
    required this.db,
    required this.fileStore,
    required this.sourceRepo,
    required this.crawler,
    this.pipeline = const ContentPipeline(),
  });

  final AppDatabase db;
  final ChapterFileStore fileStore;
  final SourceRepository sourceRepo;
  final SourceCrawlerService crawler;
  final ContentPipeline pipeline;

  final Map<String, int> _generations = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadProgressSnapshot> _snapshots = {};
  final StreamController<DownloadProgressSnapshot> _streamCtrl =
      StreamController<DownloadProgressSnapshot>.broadcast();

  Stream<DownloadProgressSnapshot> get progressStream => _streamCtrl.stream;
  DownloadProgressSnapshot? currentOf(String bookId) => _snapshots[bookId];

  /// 发起批量离线缓存（支持指定章数上限或全本；已缓存章自动跳过不浪费流量）
  Future<void> startDownload({
    required String bookId,
    required int startIndex,
    int? maxCount,
  }) async {
    // 若已有旧任务在运行，先原子作废上一代令牌并中断在途 HTTP
    cancelDownload(bookId);

    final book = await db.getBookById(bookId);
    final allChapters = await db.getChaptersByBook(bookId);
    if (book == null || allChapters.isEmpty) {
      _emit(
        DownloadProgressSnapshot(
          bookId: bookId,
          status: DownloadTaskStatus.failed,
          total: 0,
          completed: 0,
          failed: 0,
          chaptersPerSec: 0,
          errorMessage: '暂无可下载目录，请先刷新目录',
        ),
      );
      return;
    }

    final rule = await sourceRepo.getRuleById(book.sourceId);
    if (rule == null) {
      _emit(
        DownloadProgressSnapshot(
          bookId: bookId,
          status: DownloadTaskStatus.failed,
          total: 0,
          completed: 0,
          failed: 0,
          chaptersPerSec: 0,
          errorMessage: '当前书源不存在或已删除',
        ),
      );
      return;
    }

    final safeStart = startIndex.clamp(0, allChapters.length - 1);
    final end = maxCount == null
        ? allChapters.length
        : (safeStart + maxCount).clamp(0, allChapters.length);
    final targets = allChapters.sublist(safeStart, end);
    final uncached = targets.where((c) => !c.isCached).toList();

    if (uncached.isEmpty) {
      _emit(
        DownloadProgressSnapshot(
          bookId: bookId,
          status: DownloadTaskStatus.completed,
          total: targets.length,
          completed: targets.length,
          failed: 0,
          chaptersPerSec: 0,
        ),
      );
      return;
    }

    final gen = (_generations[bookId] ?? 0) + 1;
    _generations[bookId] = gen;
    final token = CancelToken();
    _cancelTokens[bookId] = token;

    final queue = Queue<Chapter>.from(uncached);
    final total = targets.length;
    var completed = targets.length - uncached.length;
    var newlyFetched = 0;
    var failed = 0;
    final taskStopwatch = Stopwatch()..start();

    _emit(
      DownloadProgressSnapshot(
        bookId: bookId,
        status: DownloadTaskStatus.downloading,
        total: total,
        completed: completed,
        failed: 0,
        chaptersPerSec: 0,
      ),
    );

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (_generations[bookId] != gen || token.isCancelled) return;
        final ch = queue.removeFirst();
        try {
          final paragraphs = await crawler.fetchChapterParagraphs(
            rule,
            ch.url,
            chapterTitle: ch.title,
            cancelToken: token,
          );
          if (_generations[bookId] != gen || token.isCancelled) return;

          if (paragraphs.isEmpty) {
            failed++;
          } else {
            final text = pipeline.serializeParagraphs(paragraphs);
            final bytes = await fileStore.writeChapter(
              bookId,
              ch.chapterIndex,
              text,
            );
            await db.markChapterCached(
              bookId: bookId,
              chapterIndex: ch.chapterIndex,
              isCached: true,
              cachedBytes: bytes,
            );
            completed++;
            newlyFetched++;
          }
        } catch (_) {
          if (_generations[bookId] != gen || token.isCancelled) return;
          failed++;
        }

        final sec = taskStopwatch.elapsedMilliseconds / 1000.0;
        final speed = sec > 0.05 ? newlyFetched / sec : 0.0;
        _emit(
          DownloadProgressSnapshot(
            bookId: bookId,
            status: DownloadTaskStatus.downloading,
            total: total,
            completed: completed,
            failed: failed,
            chaptersPerSec: speed,
          ),
        );
      }
    }

    const concurrency = 6;
    await Future.wait(List.generate(concurrency, (_) => worker()));
    taskStopwatch.stop();

    if (_generations[bookId] != gen || token.isCancelled) return;

    final DownloadTaskStatus finalStatus;
    String? errorMsg;
    if (failed == 0) {
      finalStatus = DownloadTaskStatus.completed;
    } else if (newlyFetched == 0) {
      finalStatus = DownloadTaskStatus.failed;
      errorMsg = '当前书源连接异常，未能抓取到章节内容';
    } else {
      finalStatus = DownloadTaskStatus.partialFailed;
      errorMsg = '部分成功：$failed 章抓取失败，可重试补全';
    }

    final sec = taskStopwatch.elapsedMilliseconds / 1000.0;
    final speed = sec > 0.05 ? newlyFetched / sec : 0.0;
    _emit(
      DownloadProgressSnapshot(
        bookId: bookId,
        status: finalStatus,
        total: total,
        completed: completed,
        failed: failed,
        chaptersPerSec: speed,
        errorMessage: errorMsg,
      ),
    );
  }

  void cancelDownload(String bookId) {
    final nextGen = (_generations[bookId] ?? 0) + 1;
    _generations[bookId] = nextGen;
    final token = _cancelTokens.remove(bookId);
    if (token != null && !token.isCancelled) {
      token.cancel('下载已取消');
    }
    final prev = _snapshots[bookId];
    if (prev != null && prev.isRunning) {
      _emit(
        DownloadProgressSnapshot(
          bookId: bookId,
          status: DownloadTaskStatus.cancelled,
          total: prev.total,
          completed: prev.completed,
          failed: prev.failed,
          chaptersPerSec: 0,
        ),
      );
    }
  }

  void _emit(DownloadProgressSnapshot snap) {
    _snapshots[snap.bookId] = snap;
    if (!_streamCtrl.isClosed) {
      _streamCtrl.add(snap);
    }
    db.into(db.downloadTasks).insertOnConflictUpdate(
          DownloadTasksCompanion.insert(
            bookId: snap.bookId,
            status: snap.status.name,
            totalCount: Value(snap.total),
            completedCount: Value(snap.completed),
            failedCount: Value(snap.failed),
            updatedAt: DateTime.now(),
          ),
        );
  }

  void cancelAll() {
    for (final bookId in _cancelTokens.keys.toList()) {
      cancelDownload(bookId);
    }
  }

  void dispose() {
    for (final t in _cancelTokens.values) {
      if (!t.isCancelled) t.cancel();
    }
    _cancelTokens.clear();
    _streamCtrl.close();
  }
}
