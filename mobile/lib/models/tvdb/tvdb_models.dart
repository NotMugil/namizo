class TvdbMappingEntry {
  final int malId;
  final int tvdbId;
  final int tvdbSeason;
  final int start;
  final bool useMapping;

  const TvdbMappingEntry({
    required this.malId,
    required this.tvdbId,
    required this.tvdbSeason,
    required this.start,
    required this.useMapping,
  });

  Map<String, dynamic> toJson() => {
        'malId': malId,
        'tvdbId': tvdbId,
        'tvdbSeason': tvdbSeason,
        'start': start,
        'useMapping': useMapping,
      };

  factory TvdbMappingEntry.fromJson(Map<String, dynamic> json) {
    return TvdbMappingEntry(
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      tvdbId: (json['tvdbId'] as num?)?.toInt() ?? 0,
      tvdbSeason: (json['tvdbSeason'] as num?)?.toInt() ?? 1,
      start: (json['start'] as num?)?.toInt() ?? 0,
      useMapping: json['useMapping'] as bool? ?? false,
    );
  }
}

class TvdbArtworkMetadata {
  final String? logoUrl;
  final String? posterUrl;
  final String? bannerUrl;
  final String? carouselBackdropUrl;

  const TvdbArtworkMetadata({
    this.logoUrl,
    this.posterUrl,
    this.bannerUrl,
    this.carouselBackdropUrl,
  });

  Map<String, dynamic> toJson() => {
        'logoUrl': logoUrl ?? '',
        'posterUrl': posterUrl ?? '',
        'bannerUrl': bannerUrl ?? '',
        'carouselBackdropUrl': carouselBackdropUrl ?? '',
      };

  factory TvdbArtworkMetadata.fromJson(Map<String, dynamic> json) {
    String? toNullableString(dynamic value) {
      final normalized = value?.toString().trim();
      if (normalized == null || normalized.isEmpty) return null;
      return normalized;
    }

    return TvdbArtworkMetadata(
      logoUrl: toNullableString(json['logoUrl']),
      posterUrl: toNullableString(json['posterUrl']),
      bannerUrl: toNullableString(json['bannerUrl']),
      carouselBackdropUrl: toNullableString(json['carouselBackdropUrl']),
    );
  }
}

class TvdbSimilarSeries {
  final int? tvdbId;
  final int? malId;
  final String? sourceType;
  final String title;
  final String? overview;
  final String? imageUrl;
  final double? score;
  final int? year;

  const TvdbSimilarSeries({
    required this.tvdbId,
    required this.malId,
    required this.sourceType,
    required this.title,
    required this.overview,
    required this.imageUrl,
    required this.score,
    required this.year,
  });

  Map<String, dynamic> toJson() => {
        'tvdbId': tvdbId,
        'malId': malId,
        'sourceType': sourceType ?? 'anime',
        'title': title,
        'overview': overview ?? '',
        'imageUrl': imageUrl ?? '',
        'score': score,
        'year': year,
      };

  factory TvdbSimilarSeries.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score'];
    return TvdbSimilarSeries(
      tvdbId: (json['tvdbId'] as num?)?.toInt(),
      malId: (json['malId'] as num?)?.toInt(),
        sourceType: (json['sourceType']?.toString().trim().isEmpty ?? true)
          ? 'anime'
          : json['sourceType']?.toString().trim().toLowerCase(),
      title: json['title']?.toString() ?? '',
      overview: json['overview']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      score: rawScore is num ? rawScore.toDouble() : double.tryParse('${rawScore ?? ''}'),
      year: (json['year'] as num?)?.toInt(),
    );
  }
}
