import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/app_http_client.dart';
import '../domain/book_source_rule.dart';
import '../engine/legado_rule_adapter.dart';
import 'builtin_sources.dart';

/// 书源仓库：统一管理数据库预置源、Legado 本地/远程导入导出、失效清理与并发探活
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
    final List<BookSourceRule> parsed;
    try {
      parsed = LegadoRuleAdapter.parseJson(rawJson);
    } catch (_) {
      throw const FormatException('书源 JSON 格式无效，请检查语法后重试');
    }
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

  /// 通过远程 HTTP(S) 订阅链接拉取 Legado JSON（UTF-8 / GBK 自动兼容）并导入
  Future<int> importFromUrl(String url) async {
    final clean = url.trim();
    final uri = Uri.tryParse(clean);
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const FormatException('书源订阅链接无效，请输入 http:// 或 https:// 完整地址');
    }

    final HttpFetchResult res;
    try {
      res = await httpClient.fetchText(
        clean,
        charsetHint: 'auto',
        timeout: const Duration(seconds: 12),
      );
    } catch (_) {
      throw const FormatException('拉取远程书源失败，请检查订阅链接或网络连接');
    }

    final count = await importLegadoJson(res.body);
    if (count <= 0) {
      throw const FormatException('远程内容未包含可识别的有效 Legado 书源规则');
    }
    return count;
  }

  /// 导出全部非内置自定义书源为 Legado 3.0 兼容 JSON 数组字符串
  Future<String> exportCustomSourcesJson() async {
    final rows = await (db.select(db.bookSources)
          ..where((t) => t.isBuiltin.equals(false)))
        .get();
    final list = rows.map((row) {
      final rule = BookSourceRule.fromJsonString(row.ruleJson);
      return _toLegadoCompatibleMap(rule);
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// 清理测速不可达（lastLatencyMs == -1）的非内置自定义书源，返回删除条数
  Future<int> clearUnreachableCustomSources() {
    return (db.delete(db.bookSources)
          ..where(
            (t) => t.isBuiltin.equals(false) & t.lastLatencyMs.equals(-1),
          ))
        .go();
  }

  Future<void> deleteCustomSource(String sourceId) async {
    await (db.delete(db.bookSources)
          ..where((t) => t.id.equals(sourceId) & t.isBuiltin.equals(false)))
        .go();
  }

  /// 一键全源并发探活测速（限制并发度为 6 防建连拥塞），并更新数据库延迟与健康分
  Future<void> probeAllSources() async {
    final rows = await db.select(db.bookSources).get();
    if (rows.isEmpty) return;

    const maxConcurrency = 6;
    var nextIndex = 0;
    final workerCount =
        rows.length < maxConcurrency ? rows.length : maxConcurrency;

    Future<void> runWorker() async {
      while (nextIndex < rows.length) {
        final row = rows[nextIndex++];
        await _probeSingleSource(row);
      }
    }

    await Future.wait(List.generate(workerCount, (_) => runWorker()));
  }

  Future<void> _probeSingleSource(BookSource row) async {
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
  }

  static String _fmtField(RuleField f, {required String defaultAttr}) {
    if (f.isEmpty) return '';
    var out = f.selector;
    final isXpathOrJson = out.startsWith('@xpath:') || out.startsWith(r'$.');
    if (!isXpathOrJson && f.attr.isNotEmpty && f.attr != defaultAttr) {
      out = '$out@${f.attr}';
    }
    if (f.regex.isNotEmpty) out = '$out##${f.regex}';
    return out;
  }

  static Map<String, dynamic> _toLegadoCompatibleMap(BookSourceRule r) {
    var searchUrl = r.search.urlTemplate.replaceAll('{key}', '{{key}}');
    if (r.search.method.toUpperCase() == 'POST' || r.charset != 'utf-8') {
      final opt = <String, dynamic>{
        'method': r.search.method.toUpperCase(),
        if (r.search.bodyTemplate.isNotEmpty)
          'body': r.search.bodyTemplate.replaceAll('{key}', '{{key}}'),
        if (r.charset != 'utf-8') 'charset': r.charset,
      };
      searchUrl = '$searchUrl,${jsonEncode(opt)}';
    }
    return {
      'bookSourceName': r.name,
      'bookSourceUrl': r.baseUrl,
      'bookSourceGroup': r.groupName,
      'bookSourceType': 0,
      'enabled': r.enabled,
      'searchUrl': searchUrl,
      'ruleSearch': {
        'bookList': r.search.item,
        'name': _fmtField(r.search.title, defaultAttr: 'text'),
        'author': _fmtField(r.search.author, defaultAttr: 'text'),
        'bookUrl': _fmtField(r.search.detailUrl, defaultAttr: 'href'),
        'coverUrl': _fmtField(r.search.coverUrl, defaultAttr: 'src'),
        'intro': _fmtField(r.search.intro, defaultAttr: 'text'),
        'lastChapter': _fmtField(r.search.latestChapter, defaultAttr: 'text'),
      },
      'ruleBookInfo': {
        'name': _fmtField(r.detail.title, defaultAttr: 'text'),
        'author': _fmtField(r.detail.author, defaultAttr: 'text'),
        'intro': _fmtField(r.detail.intro, defaultAttr: 'text'),
        'coverUrl': _fmtField(r.detail.coverUrl, defaultAttr: 'src'),
        'tocUrl': _fmtField(r.detail.tocUrl, defaultAttr: 'href'),
        'kind': _fmtField(r.detail.category, defaultAttr: 'text'),
        'lastChapter': _fmtField(r.detail.latestChapter, defaultAttr: 'text'),
        'updateTime': _fmtField(r.detail.lastUpdateTime, defaultAttr: 'text'),
      },
      'ruleToc': {
        'chapterList': r.toc.item,
        'chapterName': _fmtField(r.toc.title, defaultAttr: 'text'),
        'chapterUrl': _fmtField(r.toc.url, defaultAttr: 'href'),
        'nextTocUrl': _fmtField(r.toc.nextPageUrl, defaultAttr: 'href'),
      },
      'ruleContent': {
        'content': _fmtField(r.chapter.content, defaultAttr: 'html'),
        'nextContentUrl': _fmtField(r.chapter.nextPageUrl, defaultAttr: 'href'),
      },
      ...r.toJson(),
    };
  }
}
