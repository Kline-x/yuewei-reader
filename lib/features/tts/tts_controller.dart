import 'dart:async';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/platform/host_bridge.dart';

enum TtsPlaybackStatus { idle, playing, paused }

enum TtsSleepTimerMode {
  off('关闭', null), min15('15分', 900), min30('30分', 1800), min60('60分', 3600), chapterEnd('播完本章', null);
  const TtsSleepTimerMode(this.label, this.durationSeconds);
  final String label;
  final int? durationSeconds;
}

typedef TtsLocateCallback = FutureOr<void> Function(int chapterIndex, int charOffset);
typedef TtsChapterPayload = ({int chapterIndex, String chapterTitle, List<String> paragraphs, int totalChapters});
typedef TtsRequestChapterCallback = Future<TtsChapterPayload?> Function(int targetChapterIndex);

@immutable
class TtsState {
  const TtsState({
    this.status = TtsPlaybackStatus.idle, this.bookId, this.chapterIndex = 0,
    this.chapterTitle = '', this.totalChapters = 0, this.paragraphs = const [],
    this.paragraphIndex = 0, this.speechRate = 1.0,
    this.sleepMode = TtsSleepTimerMode.off, this.remainingSeconds,
    this.lastError,
  });

  final TtsPlaybackStatus status;
  final String? bookId;
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
          ? TtsController.cleanParagraph(paragraphs[paragraphIndex])
          : '';

  String get formattedSleepBadge {
    if (sleepMode == TtsSleepTimerMode.off) return '';
    if (sleepMode == TtsSleepTimerMode.chapterEnd) return '本章播完停';
    final sec = remainingSeconds ?? 0;
    return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  TtsState copyWith({
    TtsPlaybackStatus? status, String? bookId, int? chapterIndex, String? chapterTitle,
    int? totalChapters, List<String>? paragraphs, int? paragraphIndex, double? speechRate,
    TtsSleepTimerMode? sleepMode, int? remainingSeconds, bool clearRemaining = false,
    String? lastError, bool clearError = false,
  }) => TtsState(
        status: status ?? this.status, bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex, chapterTitle: chapterTitle ?? this.chapterTitle,
        totalChapters: totalChapters ?? this.totalChapters, paragraphs: paragraphs ?? this.paragraphs,
        paragraphIndex: paragraphIndex ?? this.paragraphIndex, speechRate: speechRate ?? this.speechRate,
        sleepMode: sleepMode ?? this.sleepMode,
        remainingSeconds: clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// 沉浸 TTS 听书状态机（段级推进、跨章续播、5档倍速持久化与睡眠定时）
class TtsController extends Notifier<TtsState> {
  static const String speechRatePrefKey = 'yuewei_tts_speech_rate';
  static const List<double> supportedRates = [0.75, 1.0, 1.25, 1.5, 1.75];

  StreamSubscription<({String utteranceId, bool isError, String? message})>? _eventSub;
  Timer? _sleepTimer;
  Object? _callbackOwner;
  TtsLocateCallback? _onLocate;
  TtsRequestChapterCallback? _onRequestChapter;
  String? _activeUtteranceId;
  int _utteranceSeq = 0, _opGen = 0;
  bool _rateModifiedByUser = false, _disposed = false;

  @override
  TtsState build() {
    _disposed = false;
    _rateModifiedByUser = false;
    _eventSub?.cancel();
    _eventSub = HostBridge.instance.ttsEventStream.listen(_handleNativeEvent);
    ref.onDispose(_disposeResources);
    _loadPersistedRate();
    return const TtsState();
  }

  void _disposeResources() {
    _disposed = true;
    _sleepTimer?.cancel();
    _eventSub?.cancel();
    _sleepTimer = _eventSub = _activeUtteranceId = _callbackOwner = _onLocate = _onRequestChapter = null;
  }

  Future<void> _loadPersistedRate() => reloadSpeechRateFromPrefs(respectUserEdit: true);

  /// 供本地/云端备份热恢复后主动刷新内存语速（忽略 _rateModifiedByUser 守卫）
  Future<void> reloadSpeechRateFromPrefs({bool respectUserEdit = false}) async {
    try {
      final raw = await ref.read(appDatabaseProvider).getPreference(speechRatePrefKey);
      final parsed = double.tryParse(raw ?? '');
      if (parsed == null || _disposed || (respectUserEdit && _rateModifiedByUser)) return;
      final target = normalizeRate(parsed.clamp(0.75, 1.75).toDouble());
      if (target != state.speechRate) {
        state = state.copyWith(speechRate: target);
        if (!respectUserEdit && state.isPlaying) await _speakCurrent(++_opGen);
      }
    } catch (_) {}
  }

  static double normalizeRate(double rate) {
    var best = supportedRates[1];
    for (final r in supportedRates) {
      if ((r - rate).abs() < (best - rate).abs()) best = r;
    }
    return best;
  }

  static String cleanParagraph(String raw) =>
      raw.replaceAll('\u3000', '').replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();

  static int? findNextNonEmpty(List<String> paragraphs, int fromIndex) {
    for (var i = fromIndex.clamp(0, paragraphs.length); i < paragraphs.length; i++) {
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
      if (paragraphs[i].characters.isNotEmpty) offset += paragraphs[i].length + 1;
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

  void bindReader({
    required Object owner, required TtsLocateCallback onLocate, required TtsRequestChapterCallback onRequestChapter,
  }) {
    _callbackOwner = owner;
    _onLocate = onLocate;
    _onRequestChapter = onRequestChapter;
  }

  void unbindAndStopOnDispose(Object owner) {
    // 若已有新阅读器实例接管绑定，旧页面释放时不可误停新会话的听书播放
    if (_callbackOwner != null && _callbackOwner != owner) return;
    if (_callbackOwner == owner) _callbackOwner = _onLocate = _onRequestChapter = null;
    if (!state.isActive) return;
    final stopGen = ++_opGen;
    _activeUtteranceId = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    unawaited(HostBridge.instance.ttsStop());
    final savedRate = state.speechRate;
    Future.microtask(() {
      if (!_disposed && stopGen == _opGen && state.isActive) {
        state = TtsState(speechRate: savedRate);
      }
    });
  }

  Future<bool> startReading({
    required String bookId, required int chapterIndex, required String chapterTitle,
    required List<String> paragraphs, int startParagraphIndex = 0, int totalChapters = 0,
  }) async {
    final targetIdx = findNextNonEmpty(paragraphs, startParagraphIndex) ?? findNextNonEmpty(paragraphs, 0);
    if (targetIdx == null) return false;
    final wasActive = state.isActive;
    final gen = ++_opGen;
    state = state.copyWith(
      status: TtsPlaybackStatus.playing, bookId: bookId, chapterIndex: chapterIndex,
      chapterTitle: chapterTitle, totalChapters: totalChapters,
      paragraphs: paragraphs, paragraphIndex: targetIdx, clearError: true,
    );
    return _speakCurrent(gen, fallbackToIdle: !wasActive);
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    _opGen++;
    _activeUtteranceId = null;
    state = state.copyWith(status: TtsPlaybackStatus.paused);
    await HostBridge.instance.ttsStop();
  }

  Future<bool> resume() async {
    if (!state.isPaused || state.paragraphs.isEmpty) return false;
    state = state.copyWith(status: TtsPlaybackStatus.playing, clearError: true);
    return _speakCurrent(++_opGen);
  }

  Future<void> togglePlayPause() => state.isPlaying ? pause() : resume();

  Future<void> previousParagraph() async {
    if (!state.isActive) return;
    final prevIdx = findPrevNonEmpty(state.paragraphs, state.paragraphIndex - 1);
    if (prevIdx != null) return _jumpToParagraphInCurrentChapter(prevIdx);
    if (state.chapterIndex > 0) await previousChapter();
  }

  Future<void> nextParagraph() async {
    if (!state.isActive) return;
    final nextIdx = findNextNonEmpty(state.paragraphs, state.paragraphIndex + 1);
    nextIdx != null ? await _jumpToParagraphInCurrentChapter(nextIdx) : await nextChapter();
  }

  Future<bool> previousChapter() => _switchChapter(state.chapterIndex - 1);
  Future<bool> nextChapter() => _switchChapter(state.chapterIndex + 1);

  Future<bool> _switchChapter(int targetChapterIndex) async {
    if (!state.isActive || targetChapterIndex < 0) return false;
    if (state.totalChapters > 0 && targetChapterIndex >= state.totalChapters) return false;
    final loader = _onRequestChapter;
    if (loader == null) return false;
    final gen = ++_opGen;
    _activeUtteranceId = null;
    await HostBridge.instance.ttsStop();
    final nextData = await loader(targetChapterIndex);
    if (_disposed || gen != _opGen || nextData == null) return false;
    final firstIdx = findNextNonEmpty(nextData.paragraphs, 0);
    if (firstIdx == null) return false;
    state = state.copyWith(
      status: TtsPlaybackStatus.playing, chapterIndex: nextData.chapterIndex,
      chapterTitle: nextData.chapterTitle, totalChapters: nextData.totalChapters,
      paragraphs: nextData.paragraphs, paragraphIndex: firstIdx, clearError: true,
    );
    await _onLocate?.call(nextData.chapterIndex, charOffsetOfParagraph(nextData.paragraphs, firstIdx));
    return (!_disposed && gen == _opGen) ? _speakCurrent(gen) : false;
  }

  Future<void> setSpeechRate(double rate) async {
    final normalized = normalizeRate(rate);
    final gen = ++_opGen;
    _rateModifiedByUser = true;
    state = state.copyWith(speechRate: normalized);
    try { await ref.read(appDatabaseProvider).setPreference(speechRatePrefKey, '$normalized'); } catch (_) {}
    if (!_disposed && gen == _opGen && state.isPlaying) await _speakCurrent(gen);
  }

  void setSleepTimer(TtsSleepTimerMode mode) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (mode.durationSeconds == null) {
      state = state.copyWith(sleepMode: mode, clearRemaining: true);
      return;
    }
    state = state.copyWith(sleepMode: mode, remainingSeconds: mode.durationSeconds);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || state.remainingSeconds == null) return _sleepTimer?.cancel();
      final next = state.remainingSeconds! - 1;
      next <= 0 ? stop() : state = state.copyWith(remainingSeconds: next);
    });
  }

  Future<void> stop() async {
    _opGen++;
    _activeUtteranceId = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = TtsState(speechRate: state.speechRate);
    await HostBridge.instance.ttsStop();
  }

  Future<void> _jumpToParagraphInCurrentChapter(int targetIdx) async {
    final gen = ++_opGen;
    state = state.copyWith(status: TtsPlaybackStatus.playing, paragraphIndex: targetIdx, clearError: true);
    await _onLocate?.call(state.chapterIndex, charOffsetOfParagraph(state.paragraphs, targetIdx));
    if (!_disposed && gen == _opGen) await _speakCurrent(gen);
  }

  Future<bool> _speakCurrent(int gen, {bool fallbackToIdle = false}) async {
    final text = state.currentParagraphText;
    if (text.isEmpty) return false;
    Future<bool> invokeSpeak() {
      final uid = 'utt_${++_utteranceSeq}_${state.chapterIndex}_${state.paragraphIndex}';
      _activeUtteranceId = uid;
      return HostBridge.instance.ttsSpeak(text: text, utteranceId: uid, rate: state.speechRate);
    }

    var ok = await invokeSpeak();
    if (_disposed || gen != _opGen) return ok;
    if (!ok) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_disposed || gen != _opGen) return false;
      ok = await invokeSpeak();
      if (_disposed || gen != _opGen) return ok;
    }
    if (ok) {
      if (state.lastError != null) state = state.copyWith(clearError: true);
      return true;
    }
    _activeUtteranceId = null;
    if (fallbackToIdle) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      state = TtsState(speechRate: state.speechRate);
    } else {
      state = state.copyWith(status: TtsPlaybackStatus.paused, lastError: '语音引擎连接中断，请点击播放重试');
    }
    return false;
  }

  Future<void> _handleNativeEvent(({String utteranceId, bool isError, String? message}) event) async {
    if (_disposed || !state.isPlaying || event.utteranceId.isEmpty || event.utteranceId != _activeUtteranceId) return;
    _activeUtteranceId = null;
    if (event.isError) { state = state.copyWith(status: TtsPlaybackStatus.paused); return; }
    final nextIdx = findNextNonEmpty(state.paragraphs, state.paragraphIndex + 1);
    if (nextIdx != null) return _jumpToParagraphInCurrentChapter(nextIdx);
    if (state.sleepMode == TtsSleepTimerMode.chapterEnd) return stop();
    final advanced = await nextChapter();
    if (!advanced && !_disposed && state.isPlaying && _activeUtteranceId == null) await stop();
  }
}

final ttsControllerProvider = NotifierProvider<TtsController, TtsState>(TtsController.new);
