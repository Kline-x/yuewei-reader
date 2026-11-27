import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/platform/host_bridge.dart';
import 'tts_models.dart';

export 'tts_models.dart';
part 'tts_playback_ops.dart';

/// 沉浸 TTS 听书状态机（段级/超长段安全切片推进、跨章续播、5档倍速持久化与暂停冻时睡眠定时）
class TtsController extends Notifier<TtsState> {
  static const String speechRatePrefKey = 'yuewei_tts_speech_rate';
  static const List<double> supportedRates = [0.75, 1.0, 1.25, 1.5, 1.75];

  StreamSubscription<({String utteranceId, bool isError, String? message})>?
      _eventSub;
  Timer? _sleepTimer;
  Object? _callbackOwner;
  TtsLocateCallback? _onLocate;
  TtsRequestChapterCallback? _onRequestChapter;
  String? _activeUtteranceId;
  List<String> _chunks = const [];
  int _chunkIndex = 0;
  int _utteranceSeq = 0, _opGen = 0;
  bool _rateModifiedByUser = false, _disposed = false;

  TtsState get _cur => state;
  set _cur(TtsState value) => state = value;

  @override
  TtsState build() {
    _disposed = false;
    _rateModifiedByUser = false;
    _chunks = const [];
    _chunkIndex = 0;
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
    _chunks = const [];
    _chunkIndex = 0;
    _sleepTimer = _eventSub =
        _activeUtteranceId = _callbackOwner = _onLocate = _onRequestChapter = null;
  }

  Future<void> _loadPersistedRate() =>
      reloadSpeechRateFromPrefs(respectUserEdit: true);

  /// 供本地/云端备份热恢复后主动刷新内存语速（忽略 _rateModifiedByUser 守卫）
  Future<void> reloadSpeechRateFromPrefs({bool respectUserEdit = false}) async {
    try {
      final raw =
          await ref.read(appDatabaseProvider).getPreference(speechRatePrefKey);
      final parsed = double.tryParse(raw ?? '');
      if (parsed == null ||
          _disposed ||
          (respectUserEdit && _rateModifiedByUser)) {
        return;
      }
      final target = normalizeRate(parsed.clamp(0.75, 1.75).toDouble());
      if (target != state.speechRate) {
        state = state.copyWith(speechRate: target);
        if (!respectUserEdit && state.isPlaying) {
          await _speakCurrent(++_opGen, resetChunks: _chunks.isEmpty);
        }
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
      TtsTextChunker.cleanParagraph(raw);

  static List<String> splitForSpeech(
    String raw, {
    int maxChars = TtsTextChunker.maxChunkChars,
  }) =>
      TtsTextChunker.splitForSpeech(raw, maxChars: maxChars);

  static int? findNextNonEmpty(List<String> paragraphs, int fromIndex) =>
      TtsTextChunker.findNextNonEmpty(paragraphs, fromIndex);

  static int? findPrevNonEmpty(List<String> paragraphs, int fromIndex) =>
      TtsTextChunker.findPrevNonEmpty(paragraphs, fromIndex);

  static int charOffsetOfParagraph(List<String> paragraphs, int targetIndex) =>
      TtsTextChunker.charOffsetOfParagraph(paragraphs, targetIndex);

  static int paragraphIndexAtCharOffset(List<String> paragraphs, int offset) =>
      TtsTextChunker.paragraphIndexAtCharOffset(paragraphs, offset);

  void bindReader({
    required Object owner,
    required TtsLocateCallback onLocate,
    required TtsRequestChapterCallback onRequestChapter,
  }) {
    _callbackOwner = owner;
    _onLocate = onLocate;
    _onRequestChapter = onRequestChapter;
  }

  void unbindAndStopOnDispose(Object owner) {
    // 若已有新阅读器实例接管绑定，旧页面释放时不可误停新会话的听书播放
    if (_callbackOwner != null && _callbackOwner != owner) return;
    if (_callbackOwner == owner) {
      _callbackOwner = _onLocate = _onRequestChapter = null;
    }
    if (!state.isActive) return;
    final stopGen = ++_opGen;
    _activeUtteranceId = null;
    _chunks = const [];
    _chunkIndex = 0;
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
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required List<String> paragraphs,
    int startParagraphIndex = 0,
    int totalChapters = 0,
  }) async {
    final targetIdx = findNextNonEmpty(paragraphs, startParagraphIndex) ??
        findNextNonEmpty(paragraphs, 0);
    if (targetIdx == null) return false;
    final wasActive = state.isActive;
    final gen = ++_opGen;
    _chunks = const [];
    _chunkIndex = 0;
    state = state.copyWith(
      status: TtsPlaybackStatus.playing,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      totalChapters: totalChapters,
      paragraphs: paragraphs,
      paragraphIndex: targetIdx,
      clearError: true,
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
    final keepChunks = _chunks.isNotEmpty && _chunkIndex < _chunks.length;
    return _speakCurrent(++_opGen, resetChunks: !keepChunks);
  }

  Future<void> togglePlayPause() => state.isPlaying ? pause() : resume();

  Future<void> previousParagraph() async {
    if (!state.isActive) return;
    final prevIdx = findPrevNonEmpty(state.paragraphs, state.paragraphIndex - 1);
    if (prevIdx != null) return _jumpToParagraphInCurrentChapter(prevIdx);
    if (state.chapterIndex > 0) {
      await _switchChapter(state.chapterIndex - 1, landOnLastParagraph: true);
    }
  }

  Future<void> nextParagraph() async {
    if (!state.isActive) return;
    final nextIdx = findNextNonEmpty(state.paragraphs, state.paragraphIndex + 1);
    nextIdx != null
        ? await _jumpToParagraphInCurrentChapter(nextIdx)
        : await nextChapter();
  }

  Future<bool> previousChapter({bool landOnLastParagraph = false}) =>
      _switchChapter(
        state.chapterIndex - 1,
        landOnLastParagraph: landOnLastParagraph,
      );

  Future<bool> nextChapter() => _switchChapter(state.chapterIndex + 1);

  Future<void> setSpeechRate(double rate) async {
    final normalized = normalizeRate(rate);
    final gen = ++_opGen;
    _rateModifiedByUser = true;
    state = state.copyWith(speechRate: normalized);
    try {
      await ref
          .read(appDatabaseProvider)
          .setPreference(speechRatePrefKey, '$normalized');
    } catch (_) {}
    if (!_disposed && gen == _opGen && state.isPlaying) {
      final keepChunks = _chunks.isNotEmpty && _chunkIndex < _chunks.length;
      await _speakCurrent(gen, resetChunks: !keepChunks);
    }
  }

  void setSleepTimer(TtsSleepTimerMode mode) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (mode.durationSeconds == null) {
      state = state.copyWith(sleepMode: mode, clearRemaining: true);
      return;
    }
    state = state.copyWith(
      sleepMode: mode,
      remainingSeconds: mode.durationSeconds,
    );
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || state.remainingSeconds == null) {
        return _sleepTimer?.cancel();
      }
      // 暂停态期间冻结倒计时，恢复朗读后再继续扣减
      if (state.isPaused || !state.isPlaying) return;
      final next = state.remainingSeconds! - 1;
      next <= 0 ? stop() : state = state.copyWith(remainingSeconds: next);
    });
  }

  Future<void> stop() async {
    _opGen++;
    _activeUtteranceId = null;
    _chunks = const [];
    _chunkIndex = 0;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = TtsState(speechRate: state.speechRate);
    await HostBridge.instance.ttsStop();
  }
}

final ttsControllerProvider =
    NotifierProvider<TtsController, TtsState>(TtsController.new);
