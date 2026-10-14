-- =====================================================================
-- Netflix Content Analytics · schema.sql (PostgreSQL 13+)
-- ---------------------------------------------------------------------
-- Creates three tables that mirror the processed CSVs:
--   titles            one row per title            (fact / dimension)
--   title_countries   one row per title × country  (bridge)
--   title_genres      one row per title × genre    (bridge)
--
-- WHY bridge tables? The raw `country` and `listed_in` columns hold
-- comma-separated lists ("United States, India"). Counting on that text
-- would treat each unique combination as its own "country". Splitting
-- into one row per value (first normal form) lets us GROUP BY properly.
--
-- How to run (from the project root, in psql):
--   CREATE DATABASE netflix_analytics;
--   \c netflix_analytics
--   \i sql/schema.sql
-- =====================================================================

DROP TABLE IF EXISTS title_genres;
DROP TABLE IF EXISTS title_countries;
DROP TABLE IF EXISTS titles;

CREATE TABLE titles (
    show_id             VARCHAR(10)  PRIMARY KEY,
    type                VARCHAR(10)  NOT NULL CHECK (type IN ('Movie', 'TV Show')),
    title               TEXT         NOT NULL,
    director            TEXT         NOT NULL,          -- 'Not Listed' when missing
    cast_members        TEXT         NOT NULL,          -- renamed: CAST is a SQL keyword
    country             TEXT         NOT NULL,          -- original list, 'Unknown' when missing
    primary_country     VARCHAR(60)  NOT NULL,          -- first listed country (assumption)
    country_count       SMALLINT     NOT NULL,
    date_added          DATE,                           -- NULL for 10 TV shows (not imputed)
    added_year          SMALLINT,
    added_month         SMALLINT     CHECK (added_month BETWEEN 1 AND 12),
    added_month_name    CHAR(3),
    release_year        SMALLINT     NOT NULL,
    content_age_at_add  SMALLINT,                       -- added_year - release_year
    rating              VARCHAR(10)  NOT NULL,          -- 'Unknown' when missing
    audience_group      VARCHAR(10)  NOT NULL,
    duration            VARCHAR(15)  NOT NULL,          -- original text, e.g. '90 min'
    duration_value      SMALLINT     NOT NULL,
    duration_unit       VARCHAR(10)  NOT NULL CHECK (duration_unit IN ('minutes', 'seasons')),
    listed_in           TEXT         NOT NULL,
    genre_count         SMALLINT     NOT NULL,
    description         TEXT         NOT NULL
);

CREATE TABLE title_countries (
    show_id  VARCHAR(10) NOT NULL REFERENCES titles (show_id),
    country  VARCHAR(60) NOT NULL,
    PRIMARY KEY (show_id, country)
);

CREATE TABLE title_genres (
    show_id      VARCHAR(10) NOT NULL REFERENCES titles (show_id),
    genre        VARCHAR(40) NOT NULL,   -- Netflix label, e.g. 'TV Dramas'
    genre_group  VARCHAR(40) NOT NULL,   -- our grouping, e.g. 'Drama'
    PRIMARY KEY (show_id, genre)
);

-- Indexes on the columns we filter / group by most often
CREATE INDEX idx_titles_type        ON titles (type);
CREATE INDEX idx_titles_added_year  ON titles (added_year);
CREATE INDEX idx_countries_country  ON title_countries (country);
CREATE INDEX idx_genres_group       ON title_genres (genre_group);

-- ---------------------------------------------------------------------
-- Load the processed CSVs.
-- \copy runs on YOUR machine (client side), so it works without
-- superuser rights. Paths are relative to where you started psql —
-- start psql from the project root folder.
-- ---------------------------------------------------------------------
\copy titles          FROM 'data/processed/netflix_titles_clean.csv'    WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy title_countries FROM 'data/processed/netflix_title_countries.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy title_genres    FROM 'data/processed/netflix_title_genres.csv'    WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Sanity check: expect 8,806 / 10,842 / 19,320
SELECT 'titles' AS table_name, COUNT(*) AS row_count FROM titles
UNION ALL SELECT 'title_countries', COUNT(*) FROM title_countries
UNION ALL SELECT 'title_genres',    COUNT(*) FROM title_genres;
