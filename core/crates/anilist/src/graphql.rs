pub const MEDIA_PAGE_QUERY: &str = r#"
    query ($page: Int, $perPage: Int, $sort: [MediaSort], $genre: String) {
      Page(page: $page, perPage: $perPage) {
        media(type: ANIME, sort: $sort, genre: $genre) {
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
"#;

pub const DETAILS_QUERY: &str = r#"
    query ($id: Int) {
      Media(id: $id, type: ANIME) {
        id
        title { romaji english }
        coverImage { large }
        bannerImage
        description(asHtml: false)
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
      }
    }
"#;