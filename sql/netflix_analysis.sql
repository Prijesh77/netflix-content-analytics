-- =====================================================================
-- Netflix Content Analytics · netflix_analysis.sql (PostgreSQL)
-- ---------------------------------------------------------------------
-- Each query answers ONE business question. Read the comment block
-- first: it states the question, the technique used, and any caveat.
--
-- Reminder: this is CATALOG metadata (what exists, when it was added).
-- Nothing here measures views, revenue or engagement.
-- Data snapshot ends 2021-09-25, so 2021 is a PARTIAL year.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. How big is the catalog? Are there repeated titles?
-- Technique: COUNT vs COUNT(DISTINCT ...)
-- Why: COUNT(*) counts catalog entries; COUNT(DISTINCT LOWER(title))
--      shows how many unique names exist. The gap reveals same-name
--      titles (e.g. a movie and a show both called "Death Note", or
--      re-listed entries) — a data-quality talking point.
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                         AS total_entries,
    COUNT(DISTINCT show_id)          AS distinct_show_ids,
    COUNT(DISTINCT title)            AS distinct_titles_exact,
    COUNT(DISTINCT LOWER(title))     AS distinct_titles_case_insensitive,
    COUNT(DISTINCT release_year)     AS distinct_release_years
FROM titles;


-- ---------------------------------------------------------------------
-- Q2. What is the Movie vs TV Show split?
-- Technique: window function SUM(...) OVER () for the grand total,
--            so we get count AND percentage in one pass.
-- ---------------------------------------------------------------------
SELECT
    type,
    COUNT(*)                                                   AS titles,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_catalog
FROM titles
GROUP BY type
ORDER BY titles DESC;


-- ---------------------------------------------------------------------
-- Q3. How many titles were added each year, by type?
-- Technique: conditional aggregation (COUNT ... FILTER) to pivot types
--            into columns.
-- Caveat: titles with no date_added (10 TV shows) are excluded.
-- ---------------------------------------------------------------------
SELECT
    added_year,
    COUNT(*)                                       AS titles_added,
    COUNT(*) FILTER (WHERE type = 'Movie')         AS movies_added,
    COUNT(*) FILTER (WHERE type = 'TV Show')       AS tv_shows_added,
    CASE WHEN added_year = 2021 THEN 'partial year (Jan–Sep)' ELSE '' END AS note
FROM titles
WHERE added_year IS NOT NULL
GROUP BY added_year
ORDER BY added_year;


-- ---------------------------------------------------------------------
-- Q4. Year-over-year change in additions
-- Technique: CTE + LAG() window function.
-- Why: LAG looks at the previous row, so we can compute growth without
--      a self-join. NULLIF avoids division by zero.
-- ---------------------------------------------------------------------
WITH yearly_additions AS (
    SELECT added_year, COUNT(*) AS titles_added
    FROM titles
    WHERE added_year IS NOT NULL
    GROUP BY added_year
)
SELECT
    added_year,
    titles_added,
    LAG(titles_added) OVER (ORDER BY added_year)                         AS prev_year_added,
    titles_added - LAG(titles_added) OVER (ORDER BY added_year)          AS yoy_change,
    ROUND(100.0 * (titles_added - LAG(titles_added) OVER (ORDER BY added_year))
          / NULLIF(LAG(titles_added) OVER (ORDER BY added_year), 0), 1)  AS yoy_change_pct
FROM yearly_additions
WHERE added_year >= 2015
ORDER BY added_year;


-- ---------------------------------------------------------------------
-- Q5. Fair comparison for the partial year: Jan–Sep additions only
-- Technique: subquery to find the last month available in 2021, so the
--            query stays correct if the data is refreshed.
-- Why: comparing 9 months of 2021 against 12 months of 2020 makes 2021
--      look like a decline. Same-period comparison fixes that.
-- ---------------------------------------------------------------------
SELECT
    added_year,
    COUNT(*) AS titles_added_same_period
FROM titles
WHERE added_month <= (SELECT MAX(added_month) FROM titles WHERE added_year = 2021)
  AND added_year >= 2017
GROUP BY added_year
ORDER BY added_year;


-- ---------------------------------------------------------------------
-- Q6. Top 10 countries by title count
-- Technique: bridge table join + RANK() window function.
-- Why the bridge table: a US–India co-production counts for BOTH
--      countries. Counting the raw `country` text would instead create a
--      separate "United States, India" bucket.
-- Caveat: shares add up to more than 100% because of co-productions.
-- ---------------------------------------------------------------------
WITH country_counts AS (
    SELECT
        tc.country,
        COUNT(*)                                      AS titles,
        COUNT(*) FILTER (WHERE t.type = 'Movie')      AS movies,
        COUNT(*) FILTER (WHERE t.type = 'TV Show')    AS tv_shows
    FROM title_countries tc
    JOIN titles t ON t.show_id = tc.show_id
    WHERE tc.country <> 'Unknown'
    GROUP BY tc.country
)
SELECT
    RANK() OVER (ORDER BY titles DESC)                                   AS country_rank,
    country,
    titles,
    movies,
    tv_shows,
    ROUND(100.0 * tv_shows / titles, 1)                                  AS tv_share_pct,
    ROUND(100.0 * titles / (SELECT COUNT(*) FROM titles), 1)             AS pct_of_all_titles
FROM country_counts
ORDER BY country_rank
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q7. Most frequent genres — raw labels vs grouped genres
-- Technique: two aggregations on the genre bridge table.
-- Caveat: 'International ...' and regional TV labels describe origin,
--         not genre, so the grouped view excludes them.
-- ---------------------------------------------------------------------
-- 7a. Raw Netflix labels
SELECT genre, COUNT(*) AS titles
FROM title_genres
GROUP BY genre
ORDER BY titles DESC
LIMIT 10;

-- 7b. Grouped genres (movie + TV variants merged), excluding non-genre labels
SELECT
    genre_group,
    COUNT(DISTINCT show_id)                                                    AS titles,
    ROUND(100.0 * COUNT(DISTINCT show_id) / (SELECT COUNT(*) FROM titles), 1)  AS pct_of_catalog
FROM title_genres
WHERE genre_group NOT LIKE '%(label)'
GROUP BY genre_group
ORDER BY titles DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q8. Top 3 genre groups within each of the top 5 countries
-- Technique: CTEs + DENSE_RANK() OVER (PARTITION BY ...).
-- Why: "Top N per group" is a classic interview pattern. PARTITION BY
--      restarts the ranking for every country.
-- ---------------------------------------------------------------------
WITH top_countries AS (
    SELECT country
    FROM title_countries
    WHERE country <> 'Unknown'
    GROUP BY country
    ORDER BY COUNT(*) DESC
    LIMIT 5
),
country_genre AS (
    SELECT tc.country, tg.genre_group, COUNT(DISTINCT tc.show_id) AS titles
    FROM title_countries tc
    JOIN title_genres   tg ON tg.show_id = tc.show_id
    WHERE tc.country IN (SELECT country FROM top_countries)
      AND tg.genre_group NOT LIKE '%(label)'
    GROUP BY tc.country, tg.genre_group
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY country ORDER BY titles DESC) AS genre_rank
    FROM country_genre
)
SELECT country, genre_rank, genre_group, titles
FROM ranked
WHERE genre_rank <= 3
ORDER BY country, genre_rank, genre_group;


-- ---------------------------------------------------------------------
-- Q9. Content rating distribution, with audience group
-- Technique: GROUP BY two columns + window total.
-- ---------------------------------------------------------------------
SELECT
    audience_group,
    rating,
    COUNT(*)                                                AS titles,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_catalog
FROM titles
GROUP BY audience_group, rating
ORDER BY titles DESC;


-- ---------------------------------------------------------------------
-- Q10. Movie duration statistics
-- Technique: AVG plus PERCENTILE_CONT for the median and quartiles.
-- Why the median: averages are pulled by outliers (a 312-minute film);
--      the median shows the "typical" movie.
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                               AS movies,
    ROUND(AVG(duration_value), 1)                                          AS avg_minutes,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_value)           AS p25_minutes,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_value)           AS median_minutes,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_value)           AS p75_minutes,
    MIN(duration_value)                                                    AS min_minutes,
    MAX(duration_value)                                                    AS max_minutes,
    ROUND(100.0 * AVG(CASE WHEN duration_value BETWEEN 60 AND 120 THEN 1 ELSE 0 END), 1)
                                                                           AS pct_60_to_120_min
FROM titles
WHERE type = 'Movie';


-- ---------------------------------------------------------------------
-- Q11. Movie duration by runtime band
-- Technique: CASE to bucket a continuous number into readable bands.
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN duration_value < 60   THEN '1. Under 60 min'
        WHEN duration_value <= 90  THEN '2. 60–90 min'
        WHEN duration_value <= 120 THEN '3. 91–120 min'
        WHEN duration_value <= 150 THEN '4. 121–150 min'
        ELSE                            '5. Over 150 min'
    END                                                     AS runtime_band,
    COUNT(*)                                                AS movies,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_movies
FROM titles
WHERE type = 'Movie'
GROUP BY runtime_band
ORDER BY runtime_band;


-- ---------------------------------------------------------------------
-- Q12. TV shows grouped by number of seasons
-- Technique: CASE to cap the long tail at '6+', plus running total
--            with SUM() OVER (ORDER BY ...) for a cumulative share.
-- ---------------------------------------------------------------------
WITH season_buckets AS (
    SELECT
        CASE WHEN duration_value >= 6 THEN 6 ELSE duration_value END AS season_bucket
    FROM titles
    WHERE type = 'TV Show'
)
SELECT
    CASE WHEN season_bucket = 6 THEN '6+' ELSE season_bucket::TEXT END     AS seasons,
    COUNT(*)                                                                AS tv_shows,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                      AS pct_of_tv_shows,
    ROUND(100.0 * SUM(COUNT(*)) OVER (ORDER BY season_bucket)
          / SUM(COUNT(*)) OVER (), 1)                                       AS cumulative_pct
FROM season_buckets
GROUP BY season_bucket
ORDER BY season_bucket;


-- ---------------------------------------------------------------------
-- Q13. How "fresh" is content when it's added?
-- Technique: median of a derived column, grouped by type.
-- Caveat: for TV shows, release_year may refer to the latest season,
--         which makes shows look fresher than they are.
-- ---------------------------------------------------------------------
SELECT
    type,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY content_age_at_add)                     AS median_years_old_when_added,
    ROUND(AVG(content_age_at_add), 1)                                                   AS avg_years_old_when_added,
    ROUND(100.0 * AVG(CASE WHEN content_age_at_add <= 1 THEN 1 ELSE 0 END), 1)          AS pct_added_within_1_year,
    ROUND(100.0 * AVG(CASE WHEN content_age_at_add >= 10 THEN 1 ELSE 0 END), 1)         AS pct_10plus_years_old
FROM titles
WHERE content_age_at_add IS NOT NULL
GROUP BY type;


-- ---------------------------------------------------------------------
-- Q14. TV share of additions over time + 3-year moving average
-- Technique: window frame ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- Why: a moving average smooths year-to-year noise to show direction.
-- ---------------------------------------------------------------------
WITH yearly_mix AS (
    SELECT
        added_year,
        COUNT(*)                                                             AS titles_added,
        ROUND(100.0 * COUNT(*) FILTER (WHERE type = 'TV Show') / COUNT(*), 1) AS tv_share_pct
    FROM titles
    WHERE added_year >= 2016
    GROUP BY added_year
)
SELECT
    added_year,
    titles_added,
    tv_share_pct,
    ROUND(AVG(tv_share_pct) OVER (ORDER BY added_year
                                  ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS tv_share_3yr_avg
FROM yearly_mix
ORDER BY added_year;


-- ---------------------------------------------------------------------
-- Q15. Busiest month for additions in each year
-- Technique: ROW_NUMBER() to pick the single top row per partition.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT added_year, added_month, added_month_name, COUNT(*) AS titles_added
    FROM titles
    WHERE added_year BETWEEN 2016 AND 2021
    GROUP BY added_year, added_month, added_month_name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY added_year ORDER BY titles_added DESC, added_month) AS rn
    FROM monthly
)
SELECT added_year, added_month_name AS busiest_month, titles_added
FROM ranked
WHERE rn = 1
ORDER BY added_year;


-- ---------------------------------------------------------------------
-- Q16. Countries whose catalog is more TV-heavy than the overall average
-- Technique: subquery in HAVING to compare each group with a global value.
-- Why: shows which markets are "TV-first" (min. 100 titles for stability).
-- ---------------------------------------------------------------------
SELECT
    tc.country,
    COUNT(*)                                                                AS titles,
    ROUND(100.0 * COUNT(*) FILTER (WHERE t.type = 'TV Show') / COUNT(*), 1) AS tv_share_pct
FROM title_countries tc
JOIN titles t ON t.show_id = tc.show_id
WHERE tc.country <> 'Unknown'
GROUP BY tc.country
HAVING COUNT(*) >= 100
   AND 1.0 * COUNT(*) FILTER (WHERE t.type = 'TV Show') / COUNT(*)
       > (SELECT 1.0 * COUNT(*) FILTER (WHERE type = 'TV Show') / COUNT(*) FROM titles)
ORDER BY tv_share_pct DESC;


-- ---------------------------------------------------------------------
-- Q17. Data-quality view: same-name titles
-- Technique: GROUP BY + HAVING COUNT(*) > 1, STRING_AGG to list ids.
-- Why: analysts should show the issues they DIDN'T silently delete.
-- ---------------------------------------------------------------------
SELECT
    LOWER(title)                                         AS normalised_title,
    COUNT(*)                                             AS entries,
    STRING_AGG(show_id || ' (' || type || ', added ' || COALESCE(date_added::TEXT, 'n/a') || ')',
               '; ' ORDER BY show_id)                    AS details
FROM titles
GROUP BY LOWER(title)
HAVING COUNT(*) > 1
ORDER BY normalised_title;
