import 'package:drift/drift.dart';

/// 书籍元数据与阅读进度表
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get cleanTitle => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get coverUrl => text().withDefault(const Constant(''))();
  TextColumn get intro => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get statusText => text().withDefault(const Constant('连载中'))();
  TextColumn get latestChapterTitle => text().withDefault(const Constant(''))();
  TextColumn get lastUpdateTime => text().withDefault(const Constant(''))();
  TextColumn get sourceId => text()();
  TextColumn get bookUrl => text()();
  TextColumn get tocUrl => text().withDefault(const Constant(''))();
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();
  IntColumn get currentChapterIndex => integer().withDefault(const Constant(0))();
  TextColumn get currentChapterTitle => text().withDefault(const Constant(''))();
  IntColumn get currentCharOffset => integer().withDefault(const Constant(0))();
  BoolColumn get hasEverRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isInShelf => boolean().withDefault(const Constant(false))();
  BoolColumn get hasUnreadUpdate =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 书源配置与健康度表（支持 Legado JSON 完整规则持久化）
class BookSources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get groupName => text().withDefault(const Constant('精选'))();
  TextColumn get charset => text().withDefault(const Constant('utf-8'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  TextColumn get ruleJson => text()();
  IntColumn get lastLatencyMs => integer().nullable()();
  IntColumn get healthScore => integer().withDefault(const Constant(100))();
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 章节目录与缓存状态索引表
class Chapters extends Table {
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  BoolColumn get isCached => boolean().withDefault(const Constant(false))();
  IntColumn get cachedBytes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bookId, chapterIndex};
}

/// 离线缓存调度任务状态表
class DownloadTasks extends Table {
  TextColumn get bookId => text()();
  TextColumn get status => text()();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  IntColumn get failedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// 阅读时长流水表（统一支撑今日心流与累计总时长，消除数据分裂）
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get dateKey => text()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 搜索历史表
class SearchHistory extends Table {
  TextColumn get keyword => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {keyword};
}

/// 键值偏好表（排序方式、阅读排版设置、主题预设等全进数据库）
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 书签记录表
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterTitle => text()();
  IntColumn get charOffset => integer().withDefault(const Constant(0))();
  TextColumn get excerpt => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}
