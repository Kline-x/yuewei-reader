// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleanTitleMeta = const VerificationMeta(
    'cleanTitle',
  );
  @override
  late final GeneratedColumn<String> cleanTitle = GeneratedColumn<String>(
    'clean_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusTextMeta = const VerificationMeta(
    'statusText',
  );
  @override
  late final GeneratedColumn<String> statusText = GeneratedColumn<String>(
    'status_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('连载中'),
  );
  static const VerificationMeta _latestChapterTitleMeta =
      const VerificationMeta('latestChapterTitle');
  @override
  late final GeneratedColumn<String> latestChapterTitle =
      GeneratedColumn<String>(
        'latest_chapter_title',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<String> lastUpdateTime = GeneratedColumn<String>(
    'last_update_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tocUrlMeta = const VerificationMeta('tocUrl');
  @override
  late final GeneratedColumn<String> tocUrl = GeneratedColumn<String>(
    'toc_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentChapterIndexMeta =
      const VerificationMeta('currentChapterIndex');
  @override
  late final GeneratedColumn<int> currentChapterIndex = GeneratedColumn<int>(
    'current_chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentChapterTitleMeta =
      const VerificationMeta('currentChapterTitle');
  @override
  late final GeneratedColumn<String> currentChapterTitle =
      GeneratedColumn<String>(
        'current_chapter_title',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _currentCharOffsetMeta = const VerificationMeta(
    'currentCharOffset',
  );
  @override
  late final GeneratedColumn<int> currentCharOffset = GeneratedColumn<int>(
    'current_char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasEverReadMeta = const VerificationMeta(
    'hasEverRead',
  );
  @override
  late final GeneratedColumn<bool> hasEverRead = GeneratedColumn<bool>(
    'has_ever_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_ever_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isInShelfMeta = const VerificationMeta(
    'isInShelf',
  );
  @override
  late final GeneratedColumn<bool> isInShelf = GeneratedColumn<bool>(
    'is_in_shelf',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_in_shelf" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasUnreadUpdateMeta = const VerificationMeta(
    'hasUnreadUpdate',
  );
  @override
  late final GeneratedColumn<bool> hasUnreadUpdate = GeneratedColumn<bool>(
    'has_unread_update',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_unread_update" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    cleanTitle,
    author,
    coverUrl,
    intro,
    category,
    statusText,
    latestChapterTitle,
    lastUpdateTime,
    sourceId,
    bookUrl,
    tocUrl,
    totalChapters,
    currentChapterIndex,
    currentChapterTitle,
    currentCharOffset,
    hasEverRead,
    isPinned,
    isInShelf,
    hasUnreadUpdate,
    lastReadAt,
    addedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('clean_title')) {
      context.handle(
        _cleanTitleMeta,
        cleanTitle.isAcceptableOrUnknown(data['clean_title']!, _cleanTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_cleanTitleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('status_text')) {
      context.handle(
        _statusTextMeta,
        statusText.isAcceptableOrUnknown(data['status_text']!, _statusTextMeta),
      );
    }
    if (data.containsKey('latest_chapter_title')) {
      context.handle(
        _latestChapterTitleMeta,
        latestChapterTitle.isAcceptableOrUnknown(
          data['latest_chapter_title']!,
          _latestChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('toc_url')) {
      context.handle(
        _tocUrlMeta,
        tocUrl.isAcceptableOrUnknown(data['toc_url']!, _tocUrlMeta),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_index')) {
      context.handle(
        _currentChapterIndexMeta,
        currentChapterIndex.isAcceptableOrUnknown(
          data['current_chapter_index']!,
          _currentChapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_title')) {
      context.handle(
        _currentChapterTitleMeta,
        currentChapterTitle.isAcceptableOrUnknown(
          data['current_chapter_title']!,
          _currentChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('current_char_offset')) {
      context.handle(
        _currentCharOffsetMeta,
        currentCharOffset.isAcceptableOrUnknown(
          data['current_char_offset']!,
          _currentCharOffsetMeta,
        ),
      );
    }
    if (data.containsKey('has_ever_read')) {
      context.handle(
        _hasEverReadMeta,
        hasEverRead.isAcceptableOrUnknown(
          data['has_ever_read']!,
          _hasEverReadMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_in_shelf')) {
      context.handle(
        _isInShelfMeta,
        isInShelf.isAcceptableOrUnknown(data['is_in_shelf']!, _isInShelfMeta),
      );
    }
    if (data.containsKey('has_unread_update')) {
      context.handle(
        _hasUnreadUpdateMeta,
        hasUnreadUpdate.isAcceptableOrUnknown(
          data['has_unread_update']!,
          _hasUnreadUpdateMeta,
        ),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      cleanTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clean_title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      )!,
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      statusText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_text'],
      )!,
      latestChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter_title'],
      )!,
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_update_time'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      tocUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toc_url'],
      )!,
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      currentChapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_chapter_index'],
      )!,
      currentChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_chapter_title'],
      )!,
      currentCharOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_char_offset'],
      )!,
      hasEverRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_ever_read'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isInShelf: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_in_shelf'],
      )!,
      hasUnreadUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unread_update'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String id;
  final String title;
  final String cleanTitle;
  final String author;
  final String coverUrl;
  final String intro;
  final String category;
  final String statusText;
  final String latestChapterTitle;
  final String lastUpdateTime;
  final String sourceId;
  final String bookUrl;
  final String tocUrl;
  final int totalChapters;
  final int currentChapterIndex;
  final String currentChapterTitle;
  final int currentCharOffset;
  final bool hasEverRead;
  final bool isPinned;
  final bool isInShelf;
  final bool hasUnreadUpdate;
  final DateTime? lastReadAt;
  final DateTime? addedAt;
  final DateTime updatedAt;
  const Book({
    required this.id,
    required this.title,
    required this.cleanTitle,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.category,
    required this.statusText,
    required this.latestChapterTitle,
    required this.lastUpdateTime,
    required this.sourceId,
    required this.bookUrl,
    required this.tocUrl,
    required this.totalChapters,
    required this.currentChapterIndex,
    required this.currentChapterTitle,
    required this.currentCharOffset,
    required this.hasEverRead,
    required this.isPinned,
    required this.isInShelf,
    required this.hasUnreadUpdate,
    this.lastReadAt,
    this.addedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['clean_title'] = Variable<String>(cleanTitle);
    map['author'] = Variable<String>(author);
    map['cover_url'] = Variable<String>(coverUrl);
    map['intro'] = Variable<String>(intro);
    map['category'] = Variable<String>(category);
    map['status_text'] = Variable<String>(statusText);
    map['latest_chapter_title'] = Variable<String>(latestChapterTitle);
    map['last_update_time'] = Variable<String>(lastUpdateTime);
    map['source_id'] = Variable<String>(sourceId);
    map['book_url'] = Variable<String>(bookUrl);
    map['toc_url'] = Variable<String>(tocUrl);
    map['total_chapters'] = Variable<int>(totalChapters);
    map['current_chapter_index'] = Variable<int>(currentChapterIndex);
    map['current_chapter_title'] = Variable<String>(currentChapterTitle);
    map['current_char_offset'] = Variable<int>(currentCharOffset);
    map['has_ever_read'] = Variable<bool>(hasEverRead);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_in_shelf'] = Variable<bool>(isInShelf);
    map['has_unread_update'] = Variable<bool>(hasUnreadUpdate);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      cleanTitle: Value(cleanTitle),
      author: Value(author),
      coverUrl: Value(coverUrl),
      intro: Value(intro),
      category: Value(category),
      statusText: Value(statusText),
      latestChapterTitle: Value(latestChapterTitle),
      lastUpdateTime: Value(lastUpdateTime),
      sourceId: Value(sourceId),
      bookUrl: Value(bookUrl),
      tocUrl: Value(tocUrl),
      totalChapters: Value(totalChapters),
      currentChapterIndex: Value(currentChapterIndex),
      currentChapterTitle: Value(currentChapterTitle),
      currentCharOffset: Value(currentCharOffset),
      hasEverRead: Value(hasEverRead),
      isPinned: Value(isPinned),
      isInShelf: Value(isInShelf),
      hasUnreadUpdate: Value(hasUnreadUpdate),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      cleanTitle: serializer.fromJson<String>(json['cleanTitle']),
      author: serializer.fromJson<String>(json['author']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      intro: serializer.fromJson<String>(json['intro']),
      category: serializer.fromJson<String>(json['category']),
      statusText: serializer.fromJson<String>(json['statusText']),
      latestChapterTitle: serializer.fromJson<String>(
        json['latestChapterTitle'],
      ),
      lastUpdateTime: serializer.fromJson<String>(json['lastUpdateTime']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      tocUrl: serializer.fromJson<String>(json['tocUrl']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      currentChapterIndex: serializer.fromJson<int>(
        json['currentChapterIndex'],
      ),
      currentChapterTitle: serializer.fromJson<String>(
        json['currentChapterTitle'],
      ),
      currentCharOffset: serializer.fromJson<int>(json['currentCharOffset']),
      hasEverRead: serializer.fromJson<bool>(json['hasEverRead']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isInShelf: serializer.fromJson<bool>(json['isInShelf']),
      hasUnreadUpdate: serializer.fromJson<bool>(json['hasUnreadUpdate']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'cleanTitle': serializer.toJson<String>(cleanTitle),
      'author': serializer.toJson<String>(author),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'intro': serializer.toJson<String>(intro),
      'category': serializer.toJson<String>(category),
      'statusText': serializer.toJson<String>(statusText),
      'latestChapterTitle': serializer.toJson<String>(latestChapterTitle),
      'lastUpdateTime': serializer.toJson<String>(lastUpdateTime),
      'sourceId': serializer.toJson<String>(sourceId),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'tocUrl': serializer.toJson<String>(tocUrl),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'currentChapterIndex': serializer.toJson<int>(currentChapterIndex),
      'currentChapterTitle': serializer.toJson<String>(currentChapterTitle),
      'currentCharOffset': serializer.toJson<int>(currentCharOffset),
      'hasEverRead': serializer.toJson<bool>(hasEverRead),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isInShelf': serializer.toJson<bool>(isInShelf),
      'hasUnreadUpdate': serializer.toJson<bool>(hasUnreadUpdate),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Book copyWith({
    String? id,
    String? title,
    String? cleanTitle,
    String? author,
    String? coverUrl,
    String? intro,
    String? category,
    String? statusText,
    String? latestChapterTitle,
    String? lastUpdateTime,
    String? sourceId,
    String? bookUrl,
    String? tocUrl,
    int? totalChapters,
    int? currentChapterIndex,
    String? currentChapterTitle,
    int? currentCharOffset,
    bool? hasEverRead,
    bool? isPinned,
    bool? isInShelf,
    bool? hasUnreadUpdate,
    Value<DateTime?> lastReadAt = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    cleanTitle: cleanTitle ?? this.cleanTitle,
    author: author ?? this.author,
    coverUrl: coverUrl ?? this.coverUrl,
    intro: intro ?? this.intro,
    category: category ?? this.category,
    statusText: statusText ?? this.statusText,
    latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
    lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    sourceId: sourceId ?? this.sourceId,
    bookUrl: bookUrl ?? this.bookUrl,
    tocUrl: tocUrl ?? this.tocUrl,
    totalChapters: totalChapters ?? this.totalChapters,
    currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
    currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
    currentCharOffset: currentCharOffset ?? this.currentCharOffset,
    hasEverRead: hasEverRead ?? this.hasEverRead,
    isPinned: isPinned ?? this.isPinned,
    isInShelf: isInShelf ?? this.isInShelf,
    hasUnreadUpdate: hasUnreadUpdate ?? this.hasUnreadUpdate,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      cleanTitle: data.cleanTitle.present
          ? data.cleanTitle.value
          : this.cleanTitle,
      author: data.author.present ? data.author.value : this.author,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      intro: data.intro.present ? data.intro.value : this.intro,
      category: data.category.present ? data.category.value : this.category,
      statusText: data.statusText.present
          ? data.statusText.value
          : this.statusText,
      latestChapterTitle: data.latestChapterTitle.present
          ? data.latestChapterTitle.value
          : this.latestChapterTitle,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      tocUrl: data.tocUrl.present ? data.tocUrl.value : this.tocUrl,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      currentChapterIndex: data.currentChapterIndex.present
          ? data.currentChapterIndex.value
          : this.currentChapterIndex,
      currentChapterTitle: data.currentChapterTitle.present
          ? data.currentChapterTitle.value
          : this.currentChapterTitle,
      currentCharOffset: data.currentCharOffset.present
          ? data.currentCharOffset.value
          : this.currentCharOffset,
      hasEverRead: data.hasEverRead.present
          ? data.hasEverRead.value
          : this.hasEverRead,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isInShelf: data.isInShelf.present ? data.isInShelf.value : this.isInShelf,
      hasUnreadUpdate: data.hasUnreadUpdate.present
          ? data.hasUnreadUpdate.value
          : this.hasUnreadUpdate,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('cleanTitle: $cleanTitle, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('category: $category, ')
          ..write('statusText: $statusText, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('sourceId: $sourceId, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentChapterTitle: $currentChapterTitle, ')
          ..write('currentCharOffset: $currentCharOffset, ')
          ..write('hasEverRead: $hasEverRead, ')
          ..write('isPinned: $isPinned, ')
          ..write('isInShelf: $isInShelf, ')
          ..write('hasUnreadUpdate: $hasUnreadUpdate, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    cleanTitle,
    author,
    coverUrl,
    intro,
    category,
    statusText,
    latestChapterTitle,
    lastUpdateTime,
    sourceId,
    bookUrl,
    tocUrl,
    totalChapters,
    currentChapterIndex,
    currentChapterTitle,
    currentCharOffset,
    hasEverRead,
    isPinned,
    isInShelf,
    hasUnreadUpdate,
    lastReadAt,
    addedAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.cleanTitle == this.cleanTitle &&
          other.author == this.author &&
          other.coverUrl == this.coverUrl &&
          other.intro == this.intro &&
          other.category == this.category &&
          other.statusText == this.statusText &&
          other.latestChapterTitle == this.latestChapterTitle &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.sourceId == this.sourceId &&
          other.bookUrl == this.bookUrl &&
          other.tocUrl == this.tocUrl &&
          other.totalChapters == this.totalChapters &&
          other.currentChapterIndex == this.currentChapterIndex &&
          other.currentChapterTitle == this.currentChapterTitle &&
          other.currentCharOffset == this.currentCharOffset &&
          other.hasEverRead == this.hasEverRead &&
          other.isPinned == this.isPinned &&
          other.isInShelf == this.isInShelf &&
          other.hasUnreadUpdate == this.hasUnreadUpdate &&
          other.lastReadAt == this.lastReadAt &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> cleanTitle;
  final Value<String> author;
  final Value<String> coverUrl;
  final Value<String> intro;
  final Value<String> category;
  final Value<String> statusText;
  final Value<String> latestChapterTitle;
  final Value<String> lastUpdateTime;
  final Value<String> sourceId;
  final Value<String> bookUrl;
  final Value<String> tocUrl;
  final Value<int> totalChapters;
  final Value<int> currentChapterIndex;
  final Value<String> currentChapterTitle;
  final Value<int> currentCharOffset;
  final Value<bool> hasEverRead;
  final Value<bool> isPinned;
  final Value<bool> isInShelf;
  final Value<bool> hasUnreadUpdate;
  final Value<DateTime?> lastReadAt;
  final Value<DateTime?> addedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.cleanTitle = const Value.absent(),
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.category = const Value.absent(),
    this.statusText = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.tocUrl = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.currentChapterIndex = const Value.absent(),
    this.currentChapterTitle = const Value.absent(),
    this.currentCharOffset = const Value.absent(),
    this.hasEverRead = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isInShelf = const Value.absent(),
    this.hasUnreadUpdate = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    required String cleanTitle,
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.category = const Value.absent(),
    this.statusText = const Value.absent(),
    this.latestChapterTitle = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    required String sourceId,
    required String bookUrl,
    this.tocUrl = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.currentChapterIndex = const Value.absent(),
    this.currentChapterTitle = const Value.absent(),
    this.currentCharOffset = const Value.absent(),
    this.hasEverRead = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isInShelf = const Value.absent(),
    this.hasUnreadUpdate = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       cleanTitle = Value(cleanTitle),
       sourceId = Value(sourceId),
       bookUrl = Value(bookUrl),
       updatedAt = Value(updatedAt);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? cleanTitle,
    Expression<String>? author,
    Expression<String>? coverUrl,
    Expression<String>? intro,
    Expression<String>? category,
    Expression<String>? statusText,
    Expression<String>? latestChapterTitle,
    Expression<String>? lastUpdateTime,
    Expression<String>? sourceId,
    Expression<String>? bookUrl,
    Expression<String>? tocUrl,
    Expression<int>? totalChapters,
    Expression<int>? currentChapterIndex,
    Expression<String>? currentChapterTitle,
    Expression<int>? currentCharOffset,
    Expression<bool>? hasEverRead,
    Expression<bool>? isPinned,
    Expression<bool>? isInShelf,
    Expression<bool>? hasUnreadUpdate,
    Expression<DateTime>? lastReadAt,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (cleanTitle != null) 'clean_title': cleanTitle,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (intro != null) 'intro': intro,
      if (category != null) 'category': category,
      if (statusText != null) 'status_text': statusText,
      if (latestChapterTitle != null)
        'latest_chapter_title': latestChapterTitle,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (sourceId != null) 'source_id': sourceId,
      if (bookUrl != null) 'book_url': bookUrl,
      if (tocUrl != null) 'toc_url': tocUrl,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (currentChapterIndex != null)
        'current_chapter_index': currentChapterIndex,
      if (currentChapterTitle != null)
        'current_chapter_title': currentChapterTitle,
      if (currentCharOffset != null) 'current_char_offset': currentCharOffset,
      if (hasEverRead != null) 'has_ever_read': hasEverRead,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isInShelf != null) 'is_in_shelf': isInShelf,
      if (hasUnreadUpdate != null) 'has_unread_update': hasUnreadUpdate,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? cleanTitle,
    Value<String>? author,
    Value<String>? coverUrl,
    Value<String>? intro,
    Value<String>? category,
    Value<String>? statusText,
    Value<String>? latestChapterTitle,
    Value<String>? lastUpdateTime,
    Value<String>? sourceId,
    Value<String>? bookUrl,
    Value<String>? tocUrl,
    Value<int>? totalChapters,
    Value<int>? currentChapterIndex,
    Value<String>? currentChapterTitle,
    Value<int>? currentCharOffset,
    Value<bool>? hasEverRead,
    Value<bool>? isPinned,
    Value<bool>? isInShelf,
    Value<bool>? hasUnreadUpdate,
    Value<DateTime?>? lastReadAt,
    Value<DateTime?>? addedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      cleanTitle: cleanTitle ?? this.cleanTitle,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      category: category ?? this.category,
      statusText: statusText ?? this.statusText,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      sourceId: sourceId ?? this.sourceId,
      bookUrl: bookUrl ?? this.bookUrl,
      tocUrl: tocUrl ?? this.tocUrl,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      currentCharOffset: currentCharOffset ?? this.currentCharOffset,
      hasEverRead: hasEverRead ?? this.hasEverRead,
      isPinned: isPinned ?? this.isPinned,
      isInShelf: isInShelf ?? this.isInShelf,
      hasUnreadUpdate: hasUnreadUpdate ?? this.hasUnreadUpdate,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (cleanTitle.present) {
      map['clean_title'] = Variable<String>(cleanTitle.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (statusText.present) {
      map['status_text'] = Variable<String>(statusText.value);
    }
    if (latestChapterTitle.present) {
      map['latest_chapter_title'] = Variable<String>(latestChapterTitle.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<String>(lastUpdateTime.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (tocUrl.present) {
      map['toc_url'] = Variable<String>(tocUrl.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (currentChapterIndex.present) {
      map['current_chapter_index'] = Variable<int>(currentChapterIndex.value);
    }
    if (currentChapterTitle.present) {
      map['current_chapter_title'] = Variable<String>(
        currentChapterTitle.value,
      );
    }
    if (currentCharOffset.present) {
      map['current_char_offset'] = Variable<int>(currentCharOffset.value);
    }
    if (hasEverRead.present) {
      map['has_ever_read'] = Variable<bool>(hasEverRead.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isInShelf.present) {
      map['is_in_shelf'] = Variable<bool>(isInShelf.value);
    }
    if (hasUnreadUpdate.present) {
      map['has_unread_update'] = Variable<bool>(hasUnreadUpdate.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('cleanTitle: $cleanTitle, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('category: $category, ')
          ..write('statusText: $statusText, ')
          ..write('latestChapterTitle: $latestChapterTitle, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('sourceId: $sourceId, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentChapterTitle: $currentChapterTitle, ')
          ..write('currentCharOffset: $currentCharOffset, ')
          ..write('hasEverRead: $hasEverRead, ')
          ..write('isPinned: $isPinned, ')
          ..write('isInShelf: $isInShelf, ')
          ..write('hasUnreadUpdate: $hasUnreadUpdate, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookSourcesTable extends BookSources
    with TableInfo<$BookSourcesTable, BookSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('精选'),
  );
  static const VerificationMeta _charsetMeta = const VerificationMeta(
    'charset',
  );
  @override
  late final GeneratedColumn<String> charset = GeneratedColumn<String>(
    'charset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('utf-8'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isBuiltinMeta = const VerificationMeta(
    'isBuiltin',
  );
  @override
  late final GeneratedColumn<bool> isBuiltin = GeneratedColumn<bool>(
    'is_builtin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_builtin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ruleJsonMeta = const VerificationMeta(
    'ruleJson',
  );
  @override
  late final GeneratedColumn<String> ruleJson = GeneratedColumn<String>(
    'rule_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastLatencyMsMeta = const VerificationMeta(
    'lastLatencyMs',
  );
  @override
  late final GeneratedColumn<int> lastLatencyMs = GeneratedColumn<int>(
    'last_latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthScoreMeta = const VerificationMeta(
    'healthScore',
  );
  @override
  late final GeneratedColumn<int> healthScore = GeneratedColumn<int>(
    'health_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckedAt =
      GeneratedColumn<DateTime>(
        'last_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    groupName,
    charset,
    enabled,
    isBuiltin,
    ruleJson,
    lastLatencyMs,
    healthScore,
    lastCheckedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('charset')) {
      context.handle(
        _charsetMeta,
        charset.isAcceptableOrUnknown(data['charset']!, _charsetMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('is_builtin')) {
      context.handle(
        _isBuiltinMeta,
        isBuiltin.isAcceptableOrUnknown(data['is_builtin']!, _isBuiltinMeta),
      );
    }
    if (data.containsKey('rule_json')) {
      context.handle(
        _ruleJsonMeta,
        ruleJson.isAcceptableOrUnknown(data['rule_json']!, _ruleJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleJsonMeta);
    }
    if (data.containsKey('last_latency_ms')) {
      context.handle(
        _lastLatencyMsMeta,
        lastLatencyMs.isAcceptableOrUnknown(
          data['last_latency_ms']!,
          _lastLatencyMsMeta,
        ),
      );
    }
    if (data.containsKey('health_score')) {
      context.handle(
        _healthScoreMeta,
        healthScore.isAcceptableOrUnknown(
          data['health_score']!,
          _healthScoreMeta,
        ),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      charset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}charset'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      isBuiltin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_builtin'],
      )!,
      ruleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_json'],
      )!,
      lastLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_latency_ms'],
      ),
      healthScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}health_score'],
      )!,
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_checked_at'],
      ),
    );
  }

  @override
  $BookSourcesTable createAlias(String alias) {
    return $BookSourcesTable(attachedDatabase, alias);
  }
}

class BookSource extends DataClass implements Insertable<BookSource> {
  final String id;
  final String name;
  final String baseUrl;
  final String groupName;
  final String charset;
  final bool enabled;
  final bool isBuiltin;
  final String ruleJson;
  final int? lastLatencyMs;
  final int healthScore;
  final DateTime? lastCheckedAt;
  const BookSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.groupName,
    required this.charset,
    required this.enabled,
    required this.isBuiltin,
    required this.ruleJson,
    this.lastLatencyMs,
    required this.healthScore,
    this.lastCheckedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['group_name'] = Variable<String>(groupName);
    map['charset'] = Variable<String>(charset);
    map['enabled'] = Variable<bool>(enabled);
    map['is_builtin'] = Variable<bool>(isBuiltin);
    map['rule_json'] = Variable<String>(ruleJson);
    if (!nullToAbsent || lastLatencyMs != null) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs);
    }
    map['health_score'] = Variable<int>(healthScore);
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt);
    }
    return map;
  }

  BookSourcesCompanion toCompanion(bool nullToAbsent) {
    return BookSourcesCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      groupName: Value(groupName),
      charset: Value(charset),
      enabled: Value(enabled),
      isBuiltin: Value(isBuiltin),
      ruleJson: Value(ruleJson),
      lastLatencyMs: lastLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLatencyMs),
      healthScore: Value(healthScore),
      lastCheckedAt: lastCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckedAt),
    );
  }

  factory BookSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookSource(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      groupName: serializer.fromJson<String>(json['groupName']),
      charset: serializer.fromJson<String>(json['charset']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isBuiltin: serializer.fromJson<bool>(json['isBuiltin']),
      ruleJson: serializer.fromJson<String>(json['ruleJson']),
      lastLatencyMs: serializer.fromJson<int?>(json['lastLatencyMs']),
      healthScore: serializer.fromJson<int>(json['healthScore']),
      lastCheckedAt: serializer.fromJson<DateTime?>(json['lastCheckedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'groupName': serializer.toJson<String>(groupName),
      'charset': serializer.toJson<String>(charset),
      'enabled': serializer.toJson<bool>(enabled),
      'isBuiltin': serializer.toJson<bool>(isBuiltin),
      'ruleJson': serializer.toJson<String>(ruleJson),
      'lastLatencyMs': serializer.toJson<int?>(lastLatencyMs),
      'healthScore': serializer.toJson<int>(healthScore),
      'lastCheckedAt': serializer.toJson<DateTime?>(lastCheckedAt),
    };
  }

  BookSource copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? groupName,
    String? charset,
    bool? enabled,
    bool? isBuiltin,
    String? ruleJson,
    Value<int?> lastLatencyMs = const Value.absent(),
    int? healthScore,
    Value<DateTime?> lastCheckedAt = const Value.absent(),
  }) => BookSource(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    groupName: groupName ?? this.groupName,
    charset: charset ?? this.charset,
    enabled: enabled ?? this.enabled,
    isBuiltin: isBuiltin ?? this.isBuiltin,
    ruleJson: ruleJson ?? this.ruleJson,
    lastLatencyMs: lastLatencyMs.present
        ? lastLatencyMs.value
        : this.lastLatencyMs,
    healthScore: healthScore ?? this.healthScore,
    lastCheckedAt: lastCheckedAt.present
        ? lastCheckedAt.value
        : this.lastCheckedAt,
  );
  BookSource copyWithCompanion(BookSourcesCompanion data) {
    return BookSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      charset: data.charset.present ? data.charset.value : this.charset,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isBuiltin: data.isBuiltin.present ? data.isBuiltin.value : this.isBuiltin,
      ruleJson: data.ruleJson.present ? data.ruleJson.value : this.ruleJson,
      lastLatencyMs: data.lastLatencyMs.present
          ? data.lastLatencyMs.value
          : this.lastLatencyMs,
      healthScore: data.healthScore.present
          ? data.healthScore.value
          : this.healthScore,
      lastCheckedAt: data.lastCheckedAt.present
          ? data.lastCheckedAt.value
          : this.lastCheckedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('groupName: $groupName, ')
          ..write('charset: $charset, ')
          ..write('enabled: $enabled, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('ruleJson: $ruleJson, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('healthScore: $healthScore, ')
          ..write('lastCheckedAt: $lastCheckedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    groupName,
    charset,
    enabled,
    isBuiltin,
    ruleJson,
    lastLatencyMs,
    healthScore,
    lastCheckedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.groupName == this.groupName &&
          other.charset == this.charset &&
          other.enabled == this.enabled &&
          other.isBuiltin == this.isBuiltin &&
          other.ruleJson == this.ruleJson &&
          other.lastLatencyMs == this.lastLatencyMs &&
          other.healthScore == this.healthScore &&
          other.lastCheckedAt == this.lastCheckedAt);
}

class BookSourcesCompanion extends UpdateCompanion<BookSource> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> groupName;
  final Value<String> charset;
  final Value<bool> enabled;
  final Value<bool> isBuiltin;
  final Value<String> ruleJson;
  final Value<int?> lastLatencyMs;
  final Value<int> healthScore;
  final Value<DateTime?> lastCheckedAt;
  final Value<int> rowid;
  const BookSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.groupName = const Value.absent(),
    this.charset = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isBuiltin = const Value.absent(),
    this.ruleJson = const Value.absent(),
    this.lastLatencyMs = const Value.absent(),
    this.healthScore = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookSourcesCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    this.groupName = const Value.absent(),
    this.charset = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isBuiltin = const Value.absent(),
    required String ruleJson,
    this.lastLatencyMs = const Value.absent(),
    this.healthScore = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl),
       ruleJson = Value(ruleJson);
  static Insertable<BookSource> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? groupName,
    Expression<String>? charset,
    Expression<bool>? enabled,
    Expression<bool>? isBuiltin,
    Expression<String>? ruleJson,
    Expression<int>? lastLatencyMs,
    Expression<int>? healthScore,
    Expression<DateTime>? lastCheckedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (groupName != null) 'group_name': groupName,
      if (charset != null) 'charset': charset,
      if (enabled != null) 'enabled': enabled,
      if (isBuiltin != null) 'is_builtin': isBuiltin,
      if (ruleJson != null) 'rule_json': ruleJson,
      if (lastLatencyMs != null) 'last_latency_ms': lastLatencyMs,
      if (healthScore != null) 'health_score': healthScore,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? groupName,
    Value<String>? charset,
    Value<bool>? enabled,
    Value<bool>? isBuiltin,
    Value<String>? ruleJson,
    Value<int?>? lastLatencyMs,
    Value<int>? healthScore,
    Value<DateTime?>? lastCheckedAt,
    Value<int>? rowid,
  }) {
    return BookSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      groupName: groupName ?? this.groupName,
      charset: charset ?? this.charset,
      enabled: enabled ?? this.enabled,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      ruleJson: ruleJson ?? this.ruleJson,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      healthScore: healthScore ?? this.healthScore,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (charset.present) {
      map['charset'] = Variable<String>(charset.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isBuiltin.present) {
      map['is_builtin'] = Variable<bool>(isBuiltin.value);
    }
    if (ruleJson.present) {
      map['rule_json'] = Variable<String>(ruleJson.value);
    }
    if (lastLatencyMs.present) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs.value);
    }
    if (healthScore.present) {
      map['health_score'] = Variable<int>(healthScore.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('groupName: $groupName, ')
          ..write('charset: $charset, ')
          ..write('enabled: $enabled, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('ruleJson: $ruleJson, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('healthScore: $healthScore, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCachedMeta = const VerificationMeta(
    'isCached',
  );
  @override
  late final GeneratedColumn<bool> isCached = GeneratedColumn<bool>(
    'is_cached',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cached" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cachedBytesMeta = const VerificationMeta(
    'cachedBytes',
  );
  @override
  late final GeneratedColumn<int> cachedBytes = GeneratedColumn<int>(
    'cached_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    chapterIndex,
    title,
    url,
    isCached,
    cachedBytes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('is_cached')) {
      context.handle(
        _isCachedMeta,
        isCached.isAcceptableOrUnknown(data['is_cached']!, _isCachedMeta),
      );
    }
    if (data.containsKey('cached_bytes')) {
      context.handle(
        _cachedBytesMeta,
        cachedBytes.isAcceptableOrUnknown(
          data['cached_bytes']!,
          _cachedBytesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, chapterIndex};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      isCached: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cached'],
      )!,
      cachedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_bytes'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String bookId;
  final int chapterIndex;
  final String title;
  final String url;
  final bool isCached;
  final int cachedBytes;
  const Chapter({
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.url,
    required this.isCached,
    required this.cachedBytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    map['is_cached'] = Variable<bool>(isCached);
    map['cached_bytes'] = Variable<int>(cachedBytes);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      title: Value(title),
      url: Value(url),
      isCached: Value(isCached),
      cachedBytes: Value(cachedBytes),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      isCached: serializer.fromJson<bool>(json['isCached']),
      cachedBytes: serializer.fromJson<int>(json['cachedBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'isCached': serializer.toJson<bool>(isCached),
      'cachedBytes': serializer.toJson<int>(cachedBytes),
    };
  }

  Chapter copyWith({
    String? bookId,
    int? chapterIndex,
    String? title,
    String? url,
    bool? isCached,
    int? cachedBytes,
  }) => Chapter(
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    title: title ?? this.title,
    url: url ?? this.url,
    isCached: isCached ?? this.isCached,
    cachedBytes: cachedBytes ?? this.cachedBytes,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      isCached: data.isCached.present ? data.isCached.value : this.isCached,
      cachedBytes: data.cachedBytes.present
          ? data.cachedBytes.value
          : this.cachedBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('isCached: $isCached, ')
          ..write('cachedBytes: $cachedBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, chapterIndex, title, url, isCached, cachedBytes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.title == this.title &&
          other.url == this.url &&
          other.isCached == this.isCached &&
          other.cachedBytes == this.cachedBytes);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> title;
  final Value<String> url;
  final Value<bool> isCached;
  final Value<int> cachedBytes;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.isCached = const Value.absent(),
    this.cachedBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String bookId,
    required int chapterIndex,
    required String title,
    required String url,
    this.isCached = const Value.absent(),
    this.cachedBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       title = Value(title),
       url = Value(url);
  static Insertable<Chapter> custom({
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? title,
    Expression<String>? url,
    Expression<bool>? isCached,
    Expression<int>? cachedBytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (isCached != null) 'is_cached': isCached,
      if (cachedBytes != null) 'cached_bytes': cachedBytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<String>? title,
    Value<String>? url,
    Value<bool>? isCached,
    Value<int>? cachedBytes,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      url: url ?? this.url,
      isCached: isCached ?? this.isCached,
      cachedBytes: cachedBytes ?? this.cachedBytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (isCached.present) {
      map['is_cached'] = Variable<bool>(isCached.value);
    }
    if (cachedBytes.present) {
      map['cached_bytes'] = Variable<int>(cachedBytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('isCached: $isCached, ')
          ..write('cachedBytes: $cachedBytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCountMeta = const VerificationMeta(
    'totalCount',
  );
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
    'total_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedCountMeta = const VerificationMeta(
    'completedCount',
  );
  @override
  late final GeneratedColumn<int> completedCount = GeneratedColumn<int>(
    'completed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failedCountMeta = const VerificationMeta(
    'failedCount',
  );
  @override
  late final GeneratedColumn<int> failedCount = GeneratedColumn<int>(
    'failed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    status,
    totalCount,
    completedCount,
    failedCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('total_count')) {
      context.handle(
        _totalCountMeta,
        totalCount.isAcceptableOrUnknown(data['total_count']!, _totalCountMeta),
      );
    }
    if (data.containsKey('completed_count')) {
      context.handle(
        _completedCountMeta,
        completedCount.isAcceptableOrUnknown(
          data['completed_count']!,
          _completedCountMeta,
        ),
      );
    }
    if (data.containsKey('failed_count')) {
      context.handle(
        _failedCountMeta,
        failedCount.isAcceptableOrUnknown(
          data['failed_count']!,
          _failedCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  DownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTask(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_count'],
      )!,
      completedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_count'],
      )!,
      failedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTask extends DataClass implements Insertable<DownloadTask> {
  final String bookId;
  final String status;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final DateTime updatedAt;
  const DownloadTask({
    required this.bookId,
    required this.status,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['status'] = Variable<String>(status);
    map['total_count'] = Variable<int>(totalCount);
    map['completed_count'] = Variable<int>(completedCount);
    map['failed_count'] = Variable<int>(failedCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      bookId: Value(bookId),
      status: Value(status),
      totalCount: Value(totalCount),
      completedCount: Value(completedCount),
      failedCount: Value(failedCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTask(
      bookId: serializer.fromJson<String>(json['bookId']),
      status: serializer.fromJson<String>(json['status']),
      totalCount: serializer.fromJson<int>(json['totalCount']),
      completedCount: serializer.fromJson<int>(json['completedCount']),
      failedCount: serializer.fromJson<int>(json['failedCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'status': serializer.toJson<String>(status),
      'totalCount': serializer.toJson<int>(totalCount),
      'completedCount': serializer.toJson<int>(completedCount),
      'failedCount': serializer.toJson<int>(failedCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadTask copyWith({
    String? bookId,
    String? status,
    int? totalCount,
    int? completedCount,
    int? failedCount,
    DateTime? updatedAt,
  }) => DownloadTask(
    bookId: bookId ?? this.bookId,
    status: status ?? this.status,
    totalCount: totalCount ?? this.totalCount,
    completedCount: completedCount ?? this.completedCount,
    failedCount: failedCount ?? this.failedCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadTask copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTask(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      status: data.status.present ? data.status.value : this.status,
      totalCount: data.totalCount.present
          ? data.totalCount.value
          : this.totalCount,
      completedCount: data.completedCount.present
          ? data.completedCount.value
          : this.completedCount,
      failedCount: data.failedCount.present
          ? data.failedCount.value
          : this.failedCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTask(')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('totalCount: $totalCount, ')
          ..write('completedCount: $completedCount, ')
          ..write('failedCount: $failedCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    status,
    totalCount,
    completedCount,
    failedCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTask &&
          other.bookId == this.bookId &&
          other.status == this.status &&
          other.totalCount == this.totalCount &&
          other.completedCount == this.completedCount &&
          other.failedCount == this.failedCount &&
          other.updatedAt == this.updatedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTask> {
  final Value<String> bookId;
  final Value<String> status;
  final Value<int> totalCount;
  final Value<int> completedCount;
  final Value<int> failedCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.bookId = const Value.absent(),
    this.status = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.failedCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String bookId,
    required String status,
    this.totalCount = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.failedCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadTask> custom({
    Expression<String>? bookId,
    Expression<String>? status,
    Expression<int>? totalCount,
    Expression<int>? completedCount,
    Expression<int>? failedCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (status != null) 'status': status,
      if (totalCount != null) 'total_count': totalCount,
      if (completedCount != null) 'completed_count': completedCount,
      if (failedCount != null) 'failed_count': failedCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? bookId,
    Value<String>? status,
    Value<int>? totalCount,
    Value<int>? completedCount,
    Value<int>? failedCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      bookId: bookId ?? this.bookId,
      status: status ?? this.status,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (completedCount.present) {
      map['completed_count'] = Variable<int>(completedCount.value);
    }
    if (failedCount.present) {
      map['failed_count'] = Variable<int>(failedCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('totalCount: $totalCount, ')
          ..write('completedCount: $completedCount, ')
          ..write('failedCount: $failedCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions
    with TableInfo<$ReadingSessionsTable, ReadingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    dateKey,
    durationSeconds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSession extends DataClass implements Insertable<ReadingSession> {
  final int id;
  final String bookId;
  final String dateKey;
  final int durationSeconds;
  final DateTime createdAt;
  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.dateKey,
    required this.durationSeconds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['date_key'] = Variable<String>(dateKey);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      dateKey: Value(dateKey),
      durationSeconds: Value(durationSeconds),
      createdAt: Value(createdAt),
    );
  }

  factory ReadingSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSession(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'dateKey': serializer.toJson<String>(dateKey),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReadingSession copyWith({
    int? id,
    String? bookId,
    String? dateKey,
    int? durationSeconds,
    DateTime? createdAt,
  }) => ReadingSession(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    dateKey: dateKey ?? this.dateKey,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    createdAt: createdAt ?? this.createdAt,
  );
  ReadingSession copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSession(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSession(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('dateKey: $dateKey, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, dateKey, durationSeconds, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSession &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.dateKey == this.dateKey &&
          other.durationSeconds == this.durationSeconds &&
          other.createdAt == this.createdAt);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSession> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> dateKey;
  final Value<int> durationSeconds;
  final Value<DateTime> createdAt;
  const ReadingSessionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String dateKey,
    required int durationSeconds,
    required DateTime createdAt,
  }) : bookId = Value(bookId),
       dateKey = Value(dateKey),
       durationSeconds = Value(durationSeconds),
       createdAt = Value(createdAt);
  static Insertable<ReadingSession> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? dateKey,
    Expression<int>? durationSeconds,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (dateKey != null) 'date_key': dateKey,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReadingSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? dateKey,
    Value<int>? durationSeconds,
    Value<DateTime>? createdAt,
  }) {
    return ReadingSessionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      dateKey: dateKey ?? this.dateKey,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('dateKey: $dateKey, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [keyword, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass
    implements Insertable<SearchHistoryData> {
  final String keyword;
  final DateTime searchedAt;
  const SearchHistoryData({required this.keyword, required this.searchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      keyword: Value(keyword),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      keyword: serializer.fromJson<String>(json['keyword']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryData copyWith({String? keyword, DateTime? searchedAt}) =>
      SearchHistoryData(
        keyword: keyword ?? this.keyword,
        searchedAt: searchedAt ?? this.searchedAt,
      );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('keyword: $keyword, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.keyword == this.keyword &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<String> keyword;
  final Value<DateTime> searchedAt;
  final Value<int> rowid;
  const SearchHistoryCompanion({
    this.keyword = const Value.absent(),
    this.searchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    required String keyword,
    required DateTime searchedAt,
    this.rowid = const Value.absent(),
  }) : keyword = Value(keyword),
       searchedAt = Value(searchedAt);
  static Insertable<SearchHistoryData> custom({
    Expression<String>? keyword,
    Expression<DateTime>? searchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (searchedAt != null) 'searched_at': searchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<String>? keyword,
    Value<DateTime>? searchedAt,
    Value<int>? rowid,
  }) {
    return SearchHistoryCompanion(
      keyword: keyword ?? this.keyword,
      searchedAt: searchedAt ?? this.searchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('keyword: $keyword, ')
          ..write('searchedAt: $searchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final String key;
  final String value;
  const AppPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppPreference copyWith({String? key, String? value}) =>
      AppPreference(key: key ?? this.key, value: value ?? this.value);
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charOffsetMeta = const VerificationMeta(
    'charOffset',
  );
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
    'char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    chapterTitle,
    charOffset,
    excerpt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterTitleMeta);
    }
    if (data.containsKey('char_offset')) {
      context.handle(
        _charOffsetMeta,
        charOffset.isAcceptableOrUnknown(data['char_offset']!, _charOffsetMeta),
      );
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      )!,
      charOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_offset'],
      )!,
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final int charOffset;
  final String excerpt;
  final DateTime createdAt;
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.charOffset,
    required this.excerpt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['char_offset'] = Variable<int>(charOffset);
    map['excerpt'] = Variable<String>(excerpt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      chapterTitle: Value(chapterTitle),
      charOffset: Value(charOffset),
      excerpt: Value(excerpt),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      excerpt: serializer.fromJson<String>(json['excerpt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'charOffset': serializer.toJson<int>(charOffset),
      'excerpt': serializer.toJson<String>(excerpt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    int? charOffset,
    String? excerpt,
    DateTime? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    charOffset: charOffset ?? this.charOffset,
    excerpt: excerpt ?? this.excerpt,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      charOffset: data.charOffset.present
          ? data.charOffset.value
          : this.charOffset,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('charOffset: $charOffset, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    chapterTitle,
    charOffset,
    excerpt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterTitle == this.chapterTitle &&
          other.charOffset == this.charOffset &&
          other.excerpt == this.excerpt &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> chapterTitle;
  final Value<int> charOffset;
  final Value<String> excerpt;
  final Value<DateTime> createdAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    this.charOffset = const Value.absent(),
    this.excerpt = const Value.absent(),
    required DateTime createdAt,
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       chapterTitle = Value(chapterTitle),
       createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterTitle,
    Expression<int>? charOffset,
    Expression<String>? excerpt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (charOffset != null) 'char_offset': charOffset,
      if (excerpt != null) 'excerpt': excerpt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<String>? chapterTitle,
    Value<int>? charOffset,
    Value<String>? excerpt,
    Value<DateTime>? createdAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      charOffset: charOffset ?? this.charOffset,
      excerpt: excerpt ?? this.excerpt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('charOffset: $charOffset, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookSourcesTable bookSources = $BookSourcesTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $ReadingSessionsTable readingSessions = $ReadingSessionsTable(
    this,
  );
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookSources,
    chapters,
    downloadTasks,
    readingSessions,
    searchHistory,
    appPreferences,
    bookmarks,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      required String cleanTitle,
      Value<String> author,
      Value<String> coverUrl,
      Value<String> intro,
      Value<String> category,
      Value<String> statusText,
      Value<String> latestChapterTitle,
      Value<String> lastUpdateTime,
      required String sourceId,
      required String bookUrl,
      Value<String> tocUrl,
      Value<int> totalChapters,
      Value<int> currentChapterIndex,
      Value<String> currentChapterTitle,
      Value<int> currentCharOffset,
      Value<bool> hasEverRead,
      Value<bool> isPinned,
      Value<bool> isInShelf,
      Value<bool> hasUnreadUpdate,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> addedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> cleanTitle,
      Value<String> author,
      Value<String> coverUrl,
      Value<String> intro,
      Value<String> category,
      Value<String> statusText,
      Value<String> latestChapterTitle,
      Value<String> lastUpdateTime,
      Value<String> sourceId,
      Value<String> bookUrl,
      Value<String> tocUrl,
      Value<int> totalChapters,
      Value<int> currentChapterIndex,
      Value<String> currentChapterTitle,
      Value<int> currentCharOffset,
      Value<bool> hasEverRead,
      Value<bool> isPinned,
      Value<bool> isInShelf,
      Value<bool> hasUnreadUpdate,
      Value<DateTime?> lastReadAt,
      Value<DateTime?> addedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanTitle => $composableBuilder(
    column: $table.cleanTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusText => $composableBuilder(
    column: $table.statusText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasEverRead => $composableBuilder(
    column: $table.hasEverRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInShelf => $composableBuilder(
    column: $table.isInShelf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUnreadUpdate => $composableBuilder(
    column: $table.hasUnreadUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanTitle => $composableBuilder(
    column: $table.cleanTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusText => $composableBuilder(
    column: $table.statusText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasEverRead => $composableBuilder(
    column: $table.hasEverRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInShelf => $composableBuilder(
    column: $table.isInShelf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUnreadUpdate => $composableBuilder(
    column: $table.hasUnreadUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get cleanTitle => $composableBuilder(
    column: $table.cleanTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get statusText => $composableBuilder(
    column: $table.statusText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestChapterTitle => $composableBuilder(
    column: $table.latestChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get bookUrl =>
      $composableBuilder(column: $table.bookUrl, builder: (column) => column);

  GeneratedColumn<String> get tocUrl =>
      $composableBuilder(column: $table.tocUrl, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasEverRead => $composableBuilder(
    column: $table.hasEverRead,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isInShelf =>
      $composableBuilder(column: $table.isInShelf, builder: (column) => column);

  GeneratedColumn<bool> get hasUnreadUpdate => $composableBuilder(
    column: $table.hasUnreadUpdate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> cleanTitle = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String> intro = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> statusText = const Value.absent(),
                Value<String> latestChapterTitle = const Value.absent(),
                Value<String> lastUpdateTime = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> tocUrl = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<int> currentChapterIndex = const Value.absent(),
                Value<String> currentChapterTitle = const Value.absent(),
                Value<int> currentCharOffset = const Value.absent(),
                Value<bool> hasEverRead = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isInShelf = const Value.absent(),
                Value<bool> hasUnreadUpdate = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                cleanTitle: cleanTitle,
                author: author,
                coverUrl: coverUrl,
                intro: intro,
                category: category,
                statusText: statusText,
                latestChapterTitle: latestChapterTitle,
                lastUpdateTime: lastUpdateTime,
                sourceId: sourceId,
                bookUrl: bookUrl,
                tocUrl: tocUrl,
                totalChapters: totalChapters,
                currentChapterIndex: currentChapterIndex,
                currentChapterTitle: currentChapterTitle,
                currentCharOffset: currentCharOffset,
                hasEverRead: hasEverRead,
                isPinned: isPinned,
                isInShelf: isInShelf,
                hasUnreadUpdate: hasUnreadUpdate,
                lastReadAt: lastReadAt,
                addedAt: addedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String cleanTitle,
                Value<String> author = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String> intro = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> statusText = const Value.absent(),
                Value<String> latestChapterTitle = const Value.absent(),
                Value<String> lastUpdateTime = const Value.absent(),
                required String sourceId,
                required String bookUrl,
                Value<String> tocUrl = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<int> currentChapterIndex = const Value.absent(),
                Value<String> currentChapterTitle = const Value.absent(),
                Value<int> currentCharOffset = const Value.absent(),
                Value<bool> hasEverRead = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isInShelf = const Value.absent(),
                Value<bool> hasUnreadUpdate = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                cleanTitle: cleanTitle,
                author: author,
                coverUrl: coverUrl,
                intro: intro,
                category: category,
                statusText: statusText,
                latestChapterTitle: latestChapterTitle,
                lastUpdateTime: lastUpdateTime,
                sourceId: sourceId,
                bookUrl: bookUrl,
                tocUrl: tocUrl,
                totalChapters: totalChapters,
                currentChapterIndex: currentChapterIndex,
                currentChapterTitle: currentChapterTitle,
                currentCharOffset: currentCharOffset,
                hasEverRead: hasEverRead,
                isPinned: isPinned,
                isInShelf: isInShelf,
                hasUnreadUpdate: hasUnreadUpdate,
                lastReadAt: lastReadAt,
                addedAt: addedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$BookSourcesTableCreateCompanionBuilder =
    BookSourcesCompanion Function({
      required String id,
      required String name,
      required String baseUrl,
      Value<String> groupName,
      Value<String> charset,
      Value<bool> enabled,
      Value<bool> isBuiltin,
      required String ruleJson,
      Value<int?> lastLatencyMs,
      Value<int> healthScore,
      Value<DateTime?> lastCheckedAt,
      Value<int> rowid,
    });
typedef $$BookSourcesTableUpdateCompanionBuilder =
    BookSourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> groupName,
      Value<String> charset,
      Value<bool> enabled,
      Value<bool> isBuiltin,
      Value<String> ruleJson,
      Value<int?> lastLatencyMs,
      Value<int> healthScore,
      Value<DateTime?> lastCheckedAt,
      Value<int> rowid,
    });

class $$BookSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get charset => $composableBuilder(
    column: $table.charset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleJson => $composableBuilder(
    column: $table.ruleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get charset => $composableBuilder(
    column: $table.charset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleJson => $composableBuilder(
    column: $table.ruleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookSourcesTable> {
  $$BookSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get charset =>
      $composableBuilder(column: $table.charset, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltin =>
      $composableBuilder(column: $table.isBuiltin, builder: (column) => column);

  GeneratedColumn<String> get ruleJson =>
      $composableBuilder(column: $table.ruleJson, builder: (column) => column);

  GeneratedColumn<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get healthScore => $composableBuilder(
    column: $table.healthScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );
}

class $$BookSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookSourcesTable,
          BookSource,
          $$BookSourcesTableFilterComposer,
          $$BookSourcesTableOrderingComposer,
          $$BookSourcesTableAnnotationComposer,
          $$BookSourcesTableCreateCompanionBuilder,
          $$BookSourcesTableUpdateCompanionBuilder,
          (
            BookSource,
            BaseReferences<_$AppDatabase, $BookSourcesTable, BookSource>,
          ),
          BookSource,
          PrefetchHooks Function()
        > {
  $$BookSourcesTableTableManager(_$AppDatabase db, $BookSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> charset = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isBuiltin = const Value.absent(),
                Value<String> ruleJson = const Value.absent(),
                Value<int?> lastLatencyMs = const Value.absent(),
                Value<int> healthScore = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookSourcesCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                groupName: groupName,
                charset: charset,
                enabled: enabled,
                isBuiltin: isBuiltin,
                ruleJson: ruleJson,
                lastLatencyMs: lastLatencyMs,
                healthScore: healthScore,
                lastCheckedAt: lastCheckedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                Value<String> groupName = const Value.absent(),
                Value<String> charset = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> isBuiltin = const Value.absent(),
                required String ruleJson,
                Value<int?> lastLatencyMs = const Value.absent(),
                Value<int> healthScore = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookSourcesCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                groupName: groupName,
                charset: charset,
                enabled: enabled,
                isBuiltin: isBuiltin,
                ruleJson: ruleJson,
                lastLatencyMs: lastLatencyMs,
                healthScore: healthScore,
                lastCheckedAt: lastCheckedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookSourcesTable,
      BookSource,
      $$BookSourcesTableFilterComposer,
      $$BookSourcesTableOrderingComposer,
      $$BookSourcesTableAnnotationComposer,
      $$BookSourcesTableCreateCompanionBuilder,
      $$BookSourcesTableUpdateCompanionBuilder,
      (
        BookSource,
        BaseReferences<_$AppDatabase, $BookSourcesTable, BookSource>,
      ),
      BookSource,
      PrefetchHooks Function()
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      required String bookId,
      required int chapterIndex,
      required String title,
      required String url,
      Value<bool> isCached,
      Value<int> cachedBytes,
      Value<int> rowid,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<String> title,
      Value<String> url,
      Value<bool> isCached,
      Value<int> cachedBytes,
      Value<int> rowid,
    });

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCached => $composableBuilder(
    column: $table.isCached,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCached => $composableBuilder(
    column: $table.isCached,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<bool> get isCached =>
      $composableBuilder(column: $table.isCached, builder: (column) => column);

  GeneratedColumn<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => column,
  );
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
          Chapter,
          PrefetchHooks Function()
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<bool> isCached = const Value.absent(),
                Value<int> cachedBytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                url: url,
                isCached: isCached,
                cachedBytes: cachedBytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int chapterIndex,
                required String title,
                required String url,
                Value<bool> isCached = const Value.absent(),
                Value<int> cachedBytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                url: url,
                isCached: isCached,
                cachedBytes: cachedBytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
      Chapter,
      PrefetchHooks Function()
    >;
typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String bookId,
      required String status,
      Value<int> totalCount,
      Value<int> completedCount,
      Value<int> failedCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> bookId,
      Value<String> status,
      Value<int> totalCount,
      Value<int> completedCount,
      Value<int> failedCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedCount => $composableBuilder(
    column: $table.failedCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTask,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (
            DownloadTask,
            BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
          ),
          DownloadTask,
          PrefetchHooks Function()
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalCount = const Value.absent(),
                Value<int> completedCount = const Value.absent(),
                Value<int> failedCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                bookId: bookId,
                status: status,
                totalCount: totalCount,
                completedCount: completedCount,
                failedCount: failedCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String status,
                Value<int> totalCount = const Value.absent(),
                Value<int> completedCount = const Value.absent(),
                Value<int> failedCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                bookId: bookId,
                status: status,
                totalCount: totalCount,
                completedCount: completedCount,
                failedCount: failedCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTask,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (
        DownloadTask,
        BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
      ),
      DownloadTask,
      PrefetchHooks Function()
    >;
typedef $$ReadingSessionsTableCreateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      required String bookId,
      required String dateKey,
      required int durationSeconds,
      required DateTime createdAt,
    });
typedef $$ReadingSessionsTableUpdateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> dateKey,
      Value<int> durationSeconds,
      Value<DateTime> createdAt,
    });

class $$ReadingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReadingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingSessionsTable,
          ReadingSession,
          $$ReadingSessionsTableFilterComposer,
          $$ReadingSessionsTableOrderingComposer,
          $$ReadingSessionsTableAnnotationComposer,
          $$ReadingSessionsTableCreateCompanionBuilder,
          $$ReadingSessionsTableUpdateCompanionBuilder,
          (
            ReadingSession,
            BaseReferences<
              _$AppDatabase,
              $ReadingSessionsTable,
              ReadingSession
            >,
          ),
          ReadingSession,
          PrefetchHooks Function()
        > {
  $$ReadingSessionsTableTableManager(
    _$AppDatabase db,
    $ReadingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReadingSessionsCompanion(
                id: id,
                bookId: bookId,
                dateKey: dateKey,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String dateKey,
                required int durationSeconds,
                required DateTime createdAt,
              }) => ReadingSessionsCompanion.insert(
                id: id,
                bookId: bookId,
                dateKey: dateKey,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingSessionsTable,
      ReadingSession,
      $$ReadingSessionsTableFilterComposer,
      $$ReadingSessionsTableOrderingComposer,
      $$ReadingSessionsTableAnnotationComposer,
      $$ReadingSessionsTableCreateCompanionBuilder,
      $$ReadingSessionsTableUpdateCompanionBuilder,
      (
        ReadingSession,
        BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>,
      ),
      ReadingSession,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      required String keyword,
      required DateTime searchedAt,
      Value<int> rowid,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<String> keyword,
      Value<DateTime> searchedAt,
      Value<int> rowid,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryData,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryData,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTable,
              SearchHistoryData
            >,
          ),
          SearchHistoryData,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> keyword = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryCompanion(
                keyword: keyword,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String keyword,
                required DateTime searchedAt,
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryCompanion.insert(
                keyword: keyword,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryData,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryData,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
      ),
      SearchHistoryData,
      PrefetchHooks Function()
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreference,
            BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
          ),
          AppPreference,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  AppPreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreference,
        BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
      ),
      AppPreference,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterIndex,
      required String chapterTitle,
      Value<int> charOffset,
      Value<String> excerpt,
      required DateTime createdAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<String> chapterTitle,
      Value<int> charOffset,
      Value<String> excerpt,
      Value<DateTime> createdAt,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> chapterTitle = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<String> excerpt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                charOffset: charOffset,
                excerpt: excerpt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterIndex,
                required String chapterTitle,
                Value<int> charOffset = const Value.absent(),
                Value<String> excerpt = const Value.absent(),
                required DateTime createdAt,
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                charOffset: charOffset,
                excerpt: excerpt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookSourcesTableTableManager get bookSources =>
      $$BookSourcesTableTableManager(_db, _db.bookSources);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
}
