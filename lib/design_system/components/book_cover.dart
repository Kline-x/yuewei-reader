import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';

/// 典雅纸感立体书封组件
/// 彻底废除老旧“单字硬竖排 5 字截断”，改用优雅自适应横排装帧 + 真实网络封面缓存回退
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.coverUrl,
    this.width = 64.0,
    this.height = 88.0,
    this.radius = 12.0,
  });

  final String title;
  final String? coverUrl;
  final double width;
  final double height;
  final double radius;

  static const List<List<Color>> _coverGradients = [
    [Color(0xFF285E50), Color(0xFF17382F)], // 宋瓷深青
    [Color(0xFF2B4268), Color(0xFF16233B)], // 藏青星夜
    [Color(0xFF7B492D), Color(0xFF472716)], // 暖檀羊皮
    [Color(0xFF534572), Color(0xFF2C2340)], // 丁香墨紫
    [Color(0xFF3E4E5E), Color(0xFF202A34)], // 青石钛灰
    [Color(0xFF6B3A3D), Color(0xFF3B1E20)], // 朱砂绛褐
  ];

  @override
  Widget build(BuildContext context) {
    final palette =
        _coverGradients[title.hashCode.abs() % _coverGradients.length];
    final url = coverUrl?.trim() ?? '';
    final hasNetUrl = url.startsWith('http://') || url.startsWith('https://');
    final isLocalFile = url.startsWith('/') || url.startsWith('file://');
    final localPath = url.startsWith('file://')
        ? (Uri.tryParse(url)?.toFilePath() ?? url.substring(7))
        : url;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildProceduralCover(palette),
          if (isLocalFile && localPath.isNotEmpty)
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else if (hasNetUrl)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
              placeholder: (_, _) => const SizedBox.shrink(),
            ),
          // 精装书脊侧光高光条
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProceduralCover(List<Color> palette) {
    final fontSize = width >= 96 ? 15.0 : (width >= 76 ? 12.5 : 10.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width * 0.16,
          height * 0.14,
          width * 0.10,
          height * 0.14,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(SoftRadius.control * 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
          alignment: Alignment.center,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
