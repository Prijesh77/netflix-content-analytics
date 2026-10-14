# Data Dictionary — raw `netflix_titles.csv`

| column | raw_dtype | meaning | quality_notes | missing_count |
|---|---|---|---|---|
| show_id | str | Unique identifier for each catalogue entry (e.g. s1) | Primary key; no duplicates | 0 |
| type | str | Content type: Movie or TV Show | Complete | 0 |
| title | str | Title of the movie or show | A few titles contain hidden non-breaking spaces | 0 |
| director | str | Director(s), comma-separated | Mostly missing for TV shows (structural) | 2634 |
| cast | str | Main cast members, comma-separated | Partially missing | 825 |
| country | str | Country/countries of production, comma-separated | Partially missing; stray commas | 831 |
| date_added | str | Date the title was added to Netflix (text, e.g. 'September 25, 2021') | Text not date; leading spaces; few missing; ends Sep-2021 | 10 |
| release_year | int | Original release year of the title | Complete; plausible range | 0 |
| rating | str | Content maturity rating (TV-MA, PG-13, ...) | 3 rows contain durations; few missing | 4 |
| duration | str | Minutes for movies ('90 min'); seasons for TV shows ('2 Seasons') | Mixed units; 3 missing (shifted into rating) | 3 |
| listed_in | str | Netflix categories/genres, comma-separated | Multi-valued; type-specific labels | 0 |
| description | str | Short plot summary | Complete; not used for quantitative analysis | 0 |
