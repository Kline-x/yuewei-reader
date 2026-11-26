import 'package:flutter/foundation.dart';
import 'backup_snapshot_codec.dart';
import 'webdav_sync_client.dart';

/// WebDAV 安全上传（先拉取远端 LWW 合并再上传）结果
@immutable
class WebdavSafeUploadResult {
  const WebdavSafeUploadResult({
    required this.mergedFromRemote,
    this.remoteMergeSummary,
    this.remoteEtag,
  });

  final bool mergedFromRemote;
  final BackupRestoreSummary? remoteMergeSummary;
  final String? remoteEtag;
}

/// WebDAV 双向无损合并协调器：上传前必先拉取远端快照执行本地 LWW 合并，杜绝盲覆盖云端增量
class WebdavSyncCoordinator {
  const WebdavSyncCoordinator._();

  static Future<WebdavSafeUploadResult> uploadWithPreMerge({
    required WebdavSyncClient client,
    required BackupSnapshotCodec codec,
  }) async {
    final remote = await client.downloadBackupWithMeta();
    BackupRestoreSummary? summary;
    final hasRemote = remote != null && remote.content.trim().isNotEmpty;
    if (hasRemote) {
      summary = await codec.mergeSnapshotJson(remote.content);
    }
    final mergedJson = await codec.exportSnapshotJson();
    await client.uploadBackup(mergedJson, expectedEtag: remote?.etag);
    return WebdavSafeUploadResult(
      mergedFromRemote: hasRemote,
      remoteMergeSummary: summary,
      remoteEtag: client.lastRemoteEtag,
    );
  }
}
