import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 规则提取器字段（支持 CSS / XPath / JSONPath + 后置正则洗净/替换）
@immutable
class RuleField {
  const RuleField({
    this.selector = '',
    this.attr = '',
    this.regex = '',
    this.replacement = '',
  });

  final String selector;
  final String attr;
  final String regex;
  final String replacement;

  bool get isEmpty => selector.trim().isEmpty && attr.trim().isEmpty;

  factory RuleField.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RuleField();
    return RuleField(
      selector: (json['selector'] as String?) ?? '',
      attr: (json['attr'] as String?) ?? '',
      regex: (json['regex'] as String?) ?? '',
      replacement: (json['replacement'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'selector': selector,
        'attr': attr,
        'regex': regex,
        if (replacement.isNotEmpty) 'replacement': replacement,
      };
}

@immutable
class SearchRuleSpec {
  const SearchRuleSpec({
    required this.urlTemplate,
    this.method = 'GET',
    this.bodyTemplate = '',
    required this.item,
    required this.title,
    required this.author,
    required this.detailUrl,
    this.coverUrl = const RuleField(),
    this.intro = const RuleField(),
    this.latestChapter = const RuleField(),
  });

  final String urlTemplate;
  final String method;
  final String bodyTemplate;
  final String item;
  final RuleField title;
  final RuleField author;
  final RuleField detailUrl;
  final RuleField coverUrl;
  final RuleField intro;
  final RuleField latestChapter;

  factory SearchRuleSpec.fromJson(Map<String, dynamic> json) {
    return SearchRuleSpec(
      urlTemplate: (json['urlTemplate'] as String?) ?? '',
      method: (json['method'] as String?) ?? 'GET',
      bodyTemplate: (json['bodyTemplate'] as String?) ?? '',
      item: (json['item'] as String?) ?? '',
      title: RuleField.fromJson(json['title'] as Map<String, dynamic>?),
      author: RuleField.fromJson(json['author'] as Map<String, dynamic>?),
      detailUrl: RuleField.fromJson(json['detailUrl'] as Map<String, dynamic>?),
      coverUrl: RuleField.fromJson(json['coverUrl'] as Map<String, dynamic>?),
      intro: RuleField.fromJson(json['intro'] as Map<String, dynamic>?),
      latestChapter:
          RuleField.fromJson(json['latestChapter'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'urlTemplate': urlTemplate,
        'method': method,
        'bodyTemplate': bodyTemplate,
        'item': item,
        'title': title.toJson(),
        'author': author.toJson(),
        'detailUrl': detailUrl.toJson(),
        'coverUrl': coverUrl.toJson(),
        'intro': intro.toJson(),
        'latestChapter': latestChapter.toJson(),
      };
}

@immutable
class DetailRuleSpec {
  const DetailRuleSpec({
    this.title = const RuleField(),
    this.author = const RuleField(),
    this.intro = const RuleField(),
    this.coverUrl = const RuleField(),
    this.tocUrl = const RuleField(),
    this.statusText = const RuleField(),
    this.category = const RuleField(),
    this.latestChapter = const RuleField(),
    this.lastUpdateTime = const RuleField(),
  });

  final RuleField title;
  final RuleField author;
  final RuleField intro;
  final RuleField coverUrl;
  final RuleField tocUrl;
  final RuleField statusText;
  final RuleField category;
  final RuleField latestChapter;
  final RuleField lastUpdateTime;

  factory DetailRuleSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DetailRuleSpec();
    return DetailRuleSpec(
      title: RuleField.fromJson(json['title'] as Map<String, dynamic>?),
      author: RuleField.fromJson(json['author'] as Map<String, dynamic>?),
      intro: RuleField.fromJson(json['intro'] as Map<String, dynamic>?),
      coverUrl: RuleField.fromJson(json['coverUrl'] as Map<String, dynamic>?),
      tocUrl: RuleField.fromJson(json['tocUrl'] as Map<String, dynamic>?),
      statusText:
          RuleField.fromJson(json['statusText'] as Map<String, dynamic>?),
      category: RuleField.fromJson(json['category'] as Map<String, dynamic>?),
      latestChapter:
          RuleField.fromJson(json['latestChapter'] as Map<String, dynamic>?),
      lastUpdateTime:
          RuleField.fromJson(json['lastUpdateTime'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title.toJson(),
        'author': author.toJson(),
        'intro': intro.toJson(),
        'coverUrl': coverUrl.toJson(),
        'tocUrl': tocUrl.toJson(),
        'statusText': statusText.toJson(),
        'category': category.toJson(),
        'latestChapter': latestChapter.toJson(),
        'lastUpdateTime': lastUpdateTime.toJson(),
      };
}

@immutable
class TocRuleSpec {
  const TocRuleSpec({
    required this.item,
    required this.title,
    required this.url,
    this.nextPageUrl = const RuleField(),
  });

  final String item;
  final RuleField title;
  final RuleField url;
  final RuleField nextPageUrl;

  factory TocRuleSpec.fromJson(Map<String, dynamic> json) {
    return TocRuleSpec(
      item: (json['item'] as String?) ?? '',
      title: RuleField.fromJson(json['title'] as Map<String, dynamic>?),
      url: RuleField.fromJson(json['url'] as Map<String, dynamic>?),
      nextPageUrl:
          RuleField.fromJson(json['nextPageUrl'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item,
        'title': title.toJson(),
        'url': url.toJson(),
        'nextPageUrl': nextPageUrl.toJson(),
      };
}

@immutable
class ChapterRuleSpec {
  const ChapterRuleSpec({
    required this.content,
    this.nextPageUrl = const RuleField(),
  });

  final RuleField content;
  final RuleField nextPageUrl;

  factory ChapterRuleSpec.fromJson(Map<String, dynamic> json) {
    return ChapterRuleSpec(
      content: RuleField.fromJson(json['content'] as Map<String, dynamic>?),
      nextPageUrl:
          RuleField.fromJson(json['nextPageUrl'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content.toJson(),
        'nextPageUrl': nextPageUrl.toJson(),
      };
}

/// 统一书源规则模型（兼容内置精选与 Legado JSON 导入）
@immutable
class BookSourceRule {
  const BookSourceRule({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.groupName = '精选',
    this.charset = 'utf-8',
    this.enabled = true,
    this.isBuiltin = false,
    required this.search,
    this.detail = const DetailRuleSpec(),
    required this.toc,
    required this.chapter,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String groupName;
  final String charset;
  final bool enabled;
  final bool isBuiltin;
  final SearchRuleSpec search;
  final DetailRuleSpec detail;
  final TocRuleSpec toc;
  final ChapterRuleSpec chapter;

  factory BookSourceRule.fromJsonString(String raw) {
    return BookSourceRule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory BookSourceRule.fromJson(Map<String, dynamic> json) {
    return BookSourceRule(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      baseUrl: (json['baseUrl'] as String?) ?? '',
      groupName: (json['groupName'] as String?) ?? '精选',
      charset: (json['charset'] as String?) ?? 'utf-8',
      enabled: (json['enabled'] as bool?) ?? true,
      isBuiltin: (json['isBuiltin'] as bool?) ?? false,
      search: SearchRuleSpec.fromJson(
          (json['search'] as Map<String, dynamic>?) ?? const {}),
      detail: DetailRuleSpec.fromJson(json['detail'] as Map<String, dynamic>?),
      toc: TocRuleSpec.fromJson(
          (json['toc'] as Map<String, dynamic>?) ?? const {}),
      chapter: ChapterRuleSpec.fromJson(
          (json['chapter'] as Map<String, dynamic>?) ?? const {}),
    );
  }

  BookSourceRule copyWith({
    bool? enabled,
    bool? isBuiltin,
  }) {
    return BookSourceRule(
      id: id,
      name: name,
      baseUrl: baseUrl,
      groupName: groupName,
      charset: charset,
      enabled: enabled ?? this.enabled,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      search: search,
      detail: detail,
      toc: toc,
      chapter: chapter,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'groupName': groupName,
        'charset': charset,
        'enabled': enabled,
        'isBuiltin': isBuiltin,
        'search': search.toJson(),
        'detail': detail.toJson(),
        'toc': toc.toJson(),
        'chapter': chapter.toJson(),
      };
}
