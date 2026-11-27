part of 'tts_controller.dart';

/// TTS 状态机的跨章切换、长段切片播报调度与原生回调处理子模块
extension _TtsPlaybackOps on TtsController {
  Future<bool> _switchChapter(
    int targetChapterIndex, {
    bool landOnLastParagraph = false,
  }) async {
    if (!_cur.isActive || targetChapterIndex < 0) return false;
    if (_cur.totalChapters > 0 && targetChapterIndex >= _cur.totalChapters) {
      return false;
    }
    final loader = _onRequestChapter;
    if (loader == null) {
      if (_cur.isPlaying) {
        _cur = _cur.copyWith(
          status: TtsPlaybackStatus.paused,
          lastError: '章节加载通道未就绪，请点击播放重试',
        );
      }
      return false;
    }
    final gen = ++_opGen;
    _activeUtteranceId = null;
    _chunks = const [];
    _chunkIndex = 0;
    await HostBridge.instance.ttsStop();
    final nextData = await loader(targetChapterIndex);
    if (_disposed || gen != _opGen) return false;
    if (nextData == null) {
      _cur = _cur.copyWith(
        status: TtsPlaybackStatus.paused,
        lastError: '目标章节加载失败，请检查网络或切换书源后重试',
      );
      return false;
    }
    final targetIdx = landOnLastParagraph
        ? TtsController.findPrevNonEmpty(
            nextData.paragraphs,
            nextData.paragraphs.length - 1,
          )
        : TtsController.findNextNonEmpty(nextData.paragraphs, 0);
    if (targetIdx == null) {
      _cur = _cur.copyWith(
        status: TtsPlaybackStatus.paused,
        lastError: '目标章节正文为空，已暂停朗读',
      );
      return false;
    }
    _cur = _cur.copyWith(
      status: TtsPlaybackStatus.playing,
      chapterIndex: nextData.chapterIndex,
      chapterTitle: nextData.chapterTitle,
      totalChapters: nextData.totalChapters,
      paragraphs: nextData.paragraphs,
      paragraphIndex: targetIdx,
      clearError: true,
    );
    await _onLocate?.call(
      nextData.chapterIndex,
      TtsController.charOffsetOfParagraph(nextData.paragraphs, targetIdx),
    );
    return (!_disposed && gen == _opGen) ? _speakCurrent(gen) : false;
  }

  Future<void> _jumpToParagraphInCurrentChapter(int targetIdx) async {
    final gen = ++_opGen;
    _chunks = const [];
    _chunkIndex = 0;
    _cur = _cur.copyWith(
      status: TtsPlaybackStatus.playing,
      paragraphIndex: targetIdx,
      clearError: true,
    );
    await _onLocate?.call(
      _cur.chapterIndex,
      TtsController.charOffsetOfParagraph(_cur.paragraphs, targetIdx),
    );
    if (!_disposed && gen == _opGen) await _speakCurrent(gen);
  }

  Future<bool> _speakCurrent(
    int gen, {
    bool fallbackToIdle = false,
    bool resetChunks = true,
  }) async {
    if (resetChunks || _chunks.isEmpty || _chunkIndex >= _chunks.length) {
      _chunks = TtsController.splitForSpeech(_cur.currentParagraphText);
      _chunkIndex = 0;
    }
    if (_chunks.isEmpty) return false;
    final text = _chunks[_chunkIndex];

    Future<bool> invokeSpeak() {
      final uid =
          'utt_${++_utteranceSeq}_${_cur.chapterIndex}_${_cur.paragraphIndex}_$_chunkIndex';
      _activeUtteranceId = uid;
      return HostBridge.instance.ttsSpeak(
        text: text,
        utteranceId: uid,
        rate: _cur.speechRate,
      );
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
      if (_cur.lastError != null) _cur = _cur.copyWith(clearError: true);
      return true;
    }
    _activeUtteranceId = null;
    if (fallbackToIdle) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _chunks = const [];
      _chunkIndex = 0;
      _cur = TtsState(speechRate: _cur.speechRate);
    } else {
      _cur = _cur.copyWith(
        status: TtsPlaybackStatus.paused,
        lastError: '语音引擎连接中断，请点击播放重试',
      );
    }
    return false;
  }

  Future<void> _handleNativeEvent(
    ({String utteranceId, bool isError, String? message}) event,
  ) async {
    if (_disposed ||
        !_cur.isPlaying ||
        event.utteranceId.isEmpty ||
        event.utteranceId != _activeUtteranceId) {
      return;
    }
    _activeUtteranceId = null;
    if (event.isError) {
      final msg = (event.message ?? '').trim();
      _cur = _cur.copyWith(
        status: TtsPlaybackStatus.paused,
        lastError: msg.isNotEmpty ? msg : '语音播放出现异常，请点击播放重试',
      );
      return;
    }
    if (_chunkIndex + 1 < _chunks.length) {
      _chunkIndex++;
      await _speakCurrent(_opGen, resetChunks: false);
      return;
    }
    final nextIdx =
        TtsController.findNextNonEmpty(_cur.paragraphs, _cur.paragraphIndex + 1);
    if (nextIdx != null) return _jumpToParagraphInCurrentChapter(nextIdx);
    if (_cur.sleepMode == TtsSleepTimerMode.chapterEnd) return stop();
    final hasMoreChapter =
        _cur.totalChapters <= 0 || _cur.chapterIndex + 1 < _cur.totalChapters;
    if (!hasMoreChapter) return stop();
    final advanced = await nextChapter();
    if (!advanced && !_disposed && _cur.isPlaying && _activeUtteranceId == null) {
      _cur = _cur.copyWith(
        status: TtsPlaybackStatus.paused,
        lastError: _cur.lastError ?? '自动续播下一章失败，请点击播放重试',
      );
    }
  }
}
