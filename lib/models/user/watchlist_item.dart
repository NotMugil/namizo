import 'package:hive/hive.dart';

part 'watchlist_item.g.dart';

@HiveType(typeId: 5)
class WatchlistItem extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  @HiveField(8)
  final String? backdropPath;

  @HiveField(3)
  final String mediaType;

  @HiveField(4)
  final DateTime addedAt;

  @HiveField(5)
  final double? voteAverage;

  @HiveField(6)
  final String? releaseDate;

  @HiveField(7)
  final String? overview;

  WatchlistItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.mediaType,
    required this.addedAt,
    this.voteAverage,
    this.releaseDate,
    this.overview,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'mediaType': mediaType,
      'addedAt': addedAt.toIso8601String(),
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'overview': overview,
    };
  }

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      mediaType: json['mediaType'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      voteAverage: json['voteAverage'] as double?,
      releaseDate: json['releaseDate'] as String?,
      overview: json['overview'] as String?,
    );
  }
}
