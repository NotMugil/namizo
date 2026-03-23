pub const MEDIA_PAGE_QUERY: &str = r#"
    query (
      $page: Int
      $perPage: Int
      $sort: [MediaSort]
      $genre: String
      $genreIn: [String]
      $formatIn: [MediaFormat]
      $status: MediaStatus
      $season: MediaSeason
      $seasonYear: Int
      $search: String
      $isAdult: Boolean
    ) {
      Page(page: $page, perPage: $perPage) {
        pageInfo {
          currentPage
          hasNextPage
          total
          lastPage
          perPage
        }
        media(
          type: ANIME
          sort: $sort
          genre: $genre
          genre_in: $genreIn
          format_in: $formatIn
          status: $status
          season: $season
          seasonYear: $seasonYear
          search: $search
          isAdult: $isAdult
        ) {
          id
          title { romaji english }
          coverImage { large }
          description
          averageScore
          genres
          format
          episodes
          bannerImage
          trailer { id site }
        }
      }
    }
"#;

pub const DETAILS_QUERY: &str = r#"
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        id
        idMal
        title { romaji english native }
        coverImage { large }
        bannerImage
        description
        genres
        averageScore
        status
        season
        seasonYear
        format
        episodes
        studios(isMain: true) {
          nodes { name }
        }
        trailer { id site }

        characters(sort: [ROLE, RELEVANCE], perPage: 20) {
          edges {
            role
            node {
              id
              name { full }
              image { large }
            }
          }
        }

        relations {
          edges {
            relationType
            node {
              id
              type
              title { romaji english }
              coverImage { large }
              averageScore
              genres
              format
              episodes
            }
          }
        }

        recommendations(perPage: 10, sort: [RATING_DESC]) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { large }
              averageScore
              genres
              format
              episodes
            }
          }
        }
      }
    }
"#;