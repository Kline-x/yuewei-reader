import 'dart:async';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

enum TtsPlaybackStatus { idle, playing, paused }

enum TtsSleepTimerMode {
  off('关闭', null),
  min15('15分', 900),
  min30('30分', 1800),
  min60('60分', 3600),
  chapterEnd('播完本章', null);

  const TtsSleepTimerMode(this.label, this.durationSeconds);
  final String label;
  final int? durationSeconds;
}

typedef TtsLocateCallback = FutureOr<void> Function(
    int chapterIndex, int charOffset);
typedef TtsChapterPayload = ({
  int chapterIndex,
  String chapterTitle,
  List<String> paragraphs,
  int totalChapters,
});
typedef TtsRequestChapterCallback = Future<TtsChapterPayload?> Function(
    int targetChapterIndex);

@immutable
class TtsState {
  const TtsState({
    this.status = TtsPlaybackStatus.idle,
    this.bookId,
    this.bookTitle = '',
    this.author = '',
    this.coverUrl = '',
    this.isReaderAttached = false,
    this.chapterIndex = 0,
    this.chapterTitle = '',
    this.totalChapters = 0,
    this.paragraphs = const [],
    this.paragraphIndex = 0,
    this.speechRate = 1.0,
    this.sleepMode = TtsSleepTimerMode.off,
    this.remainingSeconds,
    this.lastError,
  });

  final TtsPlaybackStatus status;
  final String? bookId;
  final String bookTitle, author, coverUrl;
  final bool isReaderAttached;
  final int chapterIndex, totalChapters, paragraphIndex;
  final String chapterTitle;
  final List<String> paragraphs;
  final double speechRate;
  final TtsSleepTimerMode sleepMode;
  final int? remainingSeconds;
  final String? lastError;

  bool get isActive => status != TtsPlaybackStatus.idle;
  bool get isPlaying => status == TtsPlaybackStatus.playing;
  bool get isPaused => status == TtsPlaybackStatus.paused;

  String get currentParagraphText =>
      (paragraphIndex >= 0 && paragraphIndex < paragraphs.length)
          ? TtsTextChunker.cleanParagraph(paragraphs[paragraphIndex])
          : '';

  String get formattedSleepBadge {
    if (sleepMode == TtsSleepTimerMode.off) return '';
    if (sleepMode == TtsSleepTimerMode.chapterEnd) return '本章播完停';
    final sec = remainingSeconds ?? 0;
    return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  TtsState copyWith({
    TtsPlaybackStatus? status,
    String? bookId,
    String? bookTitle,
    String? author,
    String? coverUrl,
    bool? isReaderAttached,
    int? chapterIndex,
    String? chapterTitle,
    int? totalChapters,
    List<String>? paragraphs,
    int? paragraphIndex,
    double? speechRate,
    TtsSleepTimerMode? sleepMode,
    int? remainingSeconds,
    bool clearRemaining = false,
    String? lastError,
    bool clearError = false,
  }) =>
      TtsState(
        status: status ?? this.status,
        bookId: bookId ?? this.bookId,
        bookTitle: bookTitle ?? this.bookTitle,
        author: author ?? this.author,
        coverUrl: coverUrl ?? this.coverUrl,
        isReaderAttached: isReaderAttached ?? this.isReaderAttached,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        totalChapters: totalChapters ?? this.totalChapters,
        paragraphs: paragraphs ?? this.paragraphs,
        paragraphIndex: paragraphIndex ?? this.paragraphIndex,
        speechRate: speechRate ?? this.speechRate,
        sleepMode: sleepMode ?? this.sleepMode,
        remainingSeconds:
            clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// TTS 段落清洗、超长段安全切片（按句末标点与字素簇边界）与字符偏移换算工具
class TtsTextChunker {
  const TtsTextChunker._();

  static const int maxChunkChars = 1200;

  static const Set<String> _strongBreaks = {
    '。', '！', '？', '!', '?', '；', ';', '…',
  };
  static const Set<String> _softBreaks = {
    '，', ',', '、', '：', ':', ' ',
  };
  static const Set<String> _closingPunct = {
    '”', '’', '」', '』', '）', ')', '】', ']', '》',
  };

  static String cleanParagraph(String raw) =>
      raw.replaceAll('\u3000', '').replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();

  /// 超长段落（> 1200 字素）按句末标点与 characters 边界拆分为安全子片段，绝不丢字、绝不劈裂代理对
  static List<String> splitForSpeech(
    String raw, {
    int maxChars = maxChunkChars,
  }) {
    final cleaned = cleanParagraph(raw);
    if (cleaned.isEmpty) return const [];
    final safeMax = maxChars < 1 ? 1 : maxChars;
    final clusters = cleaned.characters.toList();
    if (clusters.length <= safeMax) return [cleaned];

    final chunks = <String>[];
    var start = 0;
    while (start < clusters.length) {
      if (clusters.length - start <= safeMax) {
        final tail = clusters.sublist(start).join();
        if (tail.isNotEmpty) chunks.add(tail);
        break;
      }
      final hardEnd = start + safeMax;
      final minSplit = start + (safeMax ~/ 2);
      var cut = _findBreak(clusters, minSplit, hardEnd, _strongBreaks);
      cut ??= _findBreak(clusters, minSplit, hardEnd, _softBreaks);
      cut ??= hardEnd;
      if (cut <= start) cut = hardEnd;
      final piece = clusters.sublist(start, cut).join();
      if (piece.isNotEmpty) chunks.add(piece);
      start = cut;
    }
    return chunks;
  }

  static int? _findBreak(
    List<String> clusters,
    int minSplit,
    int hardEnd,
    Set<String> marks,
  ) {
    for (var i = hardEnd - 1; i >= minSplit; i--) {
      if (marks.contains(clusters[i])) {
        var cut = i + 1;
        while (cut < hardEnd && _closingPunct.contains(clusters[cut])) {
          cut++;
        }
        return cut;
      }
    }
    return null;
  }

  static int? findNextNonEmpty(List<String> paragraphs, int fromIndex) {
    for (var i = fromIndex.clamp(0, paragraphs.length);
        i < paragraphs.length;
        i++) {
      if (cleanParagraph(paragraphs[i]).isNotEmpty) return i;
    }
    return null;
  }

  static int? findPrevNonEmpty(List<String> paragraphs, int fromIndex) {
    if (paragraphs.isEmpty || fromIndex < 0) return null;
    for (var i = fromIndex.clamp(0, paragraphs.length - 1); i >= 0; i--) {
      if (cleanParagraph(paragraphs[i]).isNotEmpty) return i;
    }
    return null;
  }

  static int charOffsetOfParagraph(List<String> paragraphs, int targetIndex) {
    var offset = 0;
    for (var i = 0; i < targetIndex.clamp(0, paragraphs.length); i++) {
      if (paragraphs[i].characters.isNotEmpty) {
        offset += paragraphs[i].length + 1;
      }
    }
    return offset;
  }

  static int paragraphIndexAtCharOffset(List<String> paragraphs, int offset) {
    if (paragraphs.isEmpty || offset <= 0) return 0;
    var cur = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].characters.isEmpty) continue;
      final end = cur + paragraphs[i].length + 1;
      if (offset < end) return i;
      cur = end;
    }
    return paragraphs.length - 1;
  }
}
