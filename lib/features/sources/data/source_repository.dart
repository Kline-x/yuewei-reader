import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/app_http_client.dart';
import '../domain/book_source_rule.dart';
import '../engine/legado_rule_adapter.dart';
import 'builtin_sources.dart';

/// 书源仓库：统一管理数据库预置源、Legado 导入、启停与并发测速探活
class SourceRepository {
  SourceRepository({
    required this.db,
    required this.httpClient,
  });

  final AppDatabase db;
  final AppHttpClient httpClient;

  /// 首次启动及版本升级同步预置精品书源（保留用户启停状态与健康评分，自动升级内置规则结构）
  Future<void> ensureBuiltinSourcesSeeded() async {
    final existing = await db.select(db.bookSources).get();
    final existingMap = {for (final e in existing) e.id: e};

    for (final src in BuiltinSources.all) {
      final old = existingMap[src.id];
      if (old == null) {
        await db.into(db.bookSources).insertOnConflictUpdate(
              BookSourcesCompanion.insert(
                id: src.id,
                name: src.name,
                baseUrl: src.baseUrl,
                groupName: Value(src.groupName),
                charset: Value(src.charset),
                enabled: Value(src.enabled),
                isBuiltin: const Value(true),
                ruleJson: src.toJsonString(),
                healthScore: const Value(100),
              ),
            );
      } else if (old.isBuiltin) {
        await (db.update(db.bookSources)..where((t) => t.id.equals(src.id)))
            .write(
          BookSourcesCompanion(
            name: Value(src.name),
            baseUrl: Value(src.baseUrl),
            groupName: Value(src.groupName),
            charset: Value(src.charset),
            ruleJson: Value(src.toJsonString()),
          ),
        );
      }
    }
  }

  Stream<List<BookSource>> watchAllSources() => db.watchAllSources();

  Future<List<BookSourceRule>> getEnabledRules() async {
    final rows = await (db.select(db.bookSources)
          ..where((t) => t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.healthScore)]))
        .get();
    return rows.map((r) => BookSourceRule.fromJsonString(r.ruleJson)).toList();
  }

  Future<BookSourceRule?> getRuleById(String sourceId) async {
    final row = await (db.select(db.bookSources)
          ..where((t) => t.id.equals(sourceId)))
        .getSingleOrNull();
    if (row == null) return null;
    return BookSourceRule.fromJsonString(row.ruleJson);
  }

  Future<void> setEnabled(String sourceId, bool enabled) async {
    final row = await (db.select(db.bookSources)
          ..where((t) => t.id.equals(sourceId)))
        .getSingleOrNull();
    if (row == null) return;
    final rule = BookSourceRule.fromJsonString(row.ruleJson);
    final updatedRule = BookSourceRule(
      id: rule.id,
      name: rule.name,
      baseUrl: rule.baseUrl,
      groupName: rule.groupName,
      charset: rule.charset,
      enabled: enabled,
      isBuiltin: rule.isBuiltin,
      search: rule.search,
      detail: rule.detail,
      toc: rule.toc,
      chapter: rule.chapter,
    );
    await (db.update(db.bookSources)..where((t) => t.id.equals(sourceId))).write(
      BookSourcesCompanion(
        enabled: Value(enabled),
        ruleJson: Value(updatedRule.toJsonString()),
      ),
    );
  }

  /// 解析并持久化外部 Legado 书源 JSON，返回成功导入条数
  Future<int> importLegadoJson(String rawJson) async {
    final parsed = LegadoRuleAdapter.parseJson(rawJson);
    if (parsed.isEmpty) return 0;

    await db.transaction(() async {
      for (final src in parsed) {
        await db.into(db.bookSources).insertOnConflictUpdate(
              BookSourcesCompanion.insert(
                id: src.id,
                name: src.name,
                baseUrl: src.baseUrl,
                groupName: Value(src.groupName),
                charset: Value(src.charset),
                enabled: Value(src.enabled),
                isBuiltin: const Value(false),
                ruleJson: src.toJsonString(),
                healthScore: const Value(90),
              ),
            );
      }
    });
    return parsed.length;
  }

  Future<void> deleteCustomSource(String sourceId) async {
    await (db.delete(db.bookSources)
          ..where((t) => t.id.equals(sourceId) & t.isBuiltin.equals(false)))
        .go();
  }

  /// 一键全源并发探活测速，并更新数据库延迟与健康分
  Future<void> probeAllSources() async {
    final rows = await db.select(db.bookSources).get();
    await Future.wait(rows.map((row) async {
      try {
        final ms = await httpClient.ping(row.baseUrl);
        final score = (2000 - ms).clamp(40, 200);
        await (db.update(db.bookSources)..where((t) => t.id.equals(row.id)))
            .write(
          BookSourcesCompanion(
            lastLatencyMs: Value(ms),
            healthScore: Value(score),
            lastCheckedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {
        await (db.update(db.bookSources)..where((t) => t.id.equals(row.id)))
            .write(
          BookSourcesCompanion(
            lastLatencyMs: const Value(-1),
            healthScore: const Value(10),
            lastCheckedAt: Value(DateTime.now()),
          ),
        );
      }
    }));
  }
}
