# Key Findings: Netflix Content Analytics

**Data:** Netflix Movies and TV Shows (Kaggle, Shivam Bansal). The snapshot contains 8,807 raw rows, which
became **8,806 titles after cleaning**. Titles were added between Jan 2008 and **25 Sep 2021**.
**Scope:** this is **catalog metadata**: which titles are available, when they were added, and how they are
described. It has **no viewing, revenue, subscriber or engagement data**. Every finding below describes the
*catalog*, not audience behaviour or business performance.

**How to read each finding:** **Observation** is what the data shows. **Evidence** is the metric and where it
comes from. **Why it matters** is the analytical relevance. **Limitation** is what we can't conclude from it.

---

### 1. The catalog is movie-heavy by title count: about 70% movies, 30% TV shows
- **Evidence:** 6,130 movies (69.6%) and 2,676 TV shows (30.4%). See `q1_movies_vs_tv.png` and SQL Q2.
- **Why it matters:** this is the baseline for every other comparison. Because the mix is uneven, comparisons
  between types should use **shares within each type**, not raw counts.
- **Limitation:** a title is not a unit of content. A five-season show can contain more hours than dozens of films, so
  this finding says nothing about **viewing time** or **content hours**.

### 2. Catalog growth accelerated sharply after 2015, and the 2021 "dip" is a partial-year artefact
- **Evidence:** titles added per year went from 82 (2015) to 429 (2016), 1,188 (2017), 1,649 (2018) and a peak of
  **2,015 (2019)**, then 1,879 (2020). In the calendar view, 2021 appears to fall 20% (1,498). But comparing the
  **same January–September window**, additions were 1,353 (2019), 1,389 (2020) and **1,498 (2021)**, the highest of
  the three. See `q3_additions_per_year.png` and SQL Q4–Q5.
- **Why it matters:** this shows why an analyst must check whether the last period is complete before reporting a
  decline. The naive reading reverses the actual direction.
- **Limitation:** the data is a single snapshot. Titles added in earlier years and **removed before 2021** are absent,
  so early-year counts are understated (survivorship bias). Some of the apparent growth is therefore a measurement effect.

### 3. The catalog is overwhelmingly recent content
- **Evidence:** 84.8% of titles were released in 2010 or later, and 70.6% in 2015 or later. The median release year is
  2017. Titles span 74 distinct release years (oldest: 1925). See `q2_release_year_by_type.png`.
- **Why it matters:** the catalog leans heavily toward contemporary titles rather than a deep back-catalogue.
- **Limitation:** for TV shows, `release_year` may reflect the most recent season, which pushes series toward recent
  years. The snapshot effect (finding 2) also removes older titles that were licensed and later dropped.

### 4. The United States dominates production-country credits, followed by India and the UK
- **Evidence:** the US is credited on **3,690 titles (41.9%)**, India on 1,046 (11.9%) and the UK on 806 (9.2%). The
  country mix differs by format: **India is 92% movies**, while **South Korea (73.6% TV)** and **Japan (62.6% TV)** are
  TV-first. 831 titles (9.4%) have no country recorded. See `q4_top_countries.png` and SQL Q6/Q16.
- **Why it matters:** country and format are linked. Any country-level comparison should be split by type, or it will
  mostly reflect each country's movie/TV balance.
- **Limitation:** "country" means **production** country, not where a title is available or watched. Co-productions are
  credited to every listed country, so shares add up to more than 100%.

### 5. Nearly half the catalog carries an "International" label; Drama and Comedy are the leading genres
- **Evidence:** "International Movies" is the most frequent raw label (2,751 titles), and **46.6%** of titles carry an
  International tag. After merging movie and TV variants, **Drama (36.2% of titles)**, **Comedy (25.6%)** and
  **Documentary (14.4%)** lead. See `q5_top_genres.png` and SQL Q7.
- **Why it matters:** the catalog is strongly global and anchored in broad, general-interest genres.
- **Limitation:** genres are Netflix's own tags, and titles have several, so percentages don't sum to 100%. Some tags
  exist for only one format. For example, "Crime TV Shows" has no movie equivalent, so cross-format genre comparisons
  must exclude those tags.

### 6. Mature content is the single largest rating band
- **Evidence:** **TV-MA** is the most common rating (3,206 titles, 36.4%), followed by TV-14 (24.5%). Grouped into
  audience bands, **Adults** account for 45.5% of the catalog and **Teens** for 30.1%. Kids content is 4.5% of movies
  but **13.9% of TV shows**. See `q6_ratings.png` and SQL Q9.
- **Why it matters:** the catalog skews toward older audiences. Children's content is concentrated in series rather
  than films.
- **Limitation:** the audience bands are this project's grouping of US rating codes, not an official Netflix
  classification. 90 titles are unrated or have an unknown rating.

### 7. Most movies run 1.5–2 hours; most TV shows have only one season available
- **Evidence:** median movie runtime is **98 minutes** (average 99.6, IQR 87–114), and **73.9%** of movies run 60–120
  minutes. **67.0%** of TV shows have exactly **one season** on the platform, and only 3.7% have 6 or more. See
  `q7_movie_durations.png`, `q8_tv_seasons.png` and SQL Q10–Q12.
- **Why it matters:** runtimes follow standard feature-film conventions. The large share of single-season shows is a
  distinctive feature of the catalog.
- **Limitation:** seasons are counted **as available at snapshot time**. A one-season show could be new, a limited
  series, cancelled, or only partly licensed. This data can't tell these apart.

### 8. TV shows are added "fresher" than movies, and the TV share of additions has crept up since 2018
- **Evidence:** median age at the time of addition is **0 years for TV shows** and **2 years for movies**. 67.4% of
  shows are added within a year of their release year, against 49.6% of movies, and 19.4% of movies are 10+ years old
  when added. The TV share of yearly additions moved from 25.0% (2018) to 29.4%, 31.7% and **33.7% (2021)**. By
  release year, the TV share climbs much faster, reaching 53.2% of 2021 releases. See `q10_tv_share_trend.png` and
  SQL Q13–Q14.
- **Why it matters:** the movie side includes more **library/back-catalogue** titles, while series arrive closer to
  release. The mix of additions is gradually shifting toward TV.
- **Limitation:** TV "freshness" and the steep release-year trend are likely inflated because a series'
  `release_year` may refer to its latest season. The **added-year** view is the more reliable read.

---

## Data-quality notes that affect interpretation
- 1 proven duplicate was removed (identical except for an invisible character in the title). 3 same-name pairs with
  different add dates were **kept** and documented (SQL Q17).
- 3 rows had the runtime shifted into `rating`. These were repaired, and their rating is set to "Unknown".
- 10 TV shows have no `date_added`. They were left missing rather than imputed, so they are excluded from time-based views.

## Follow-up analyses that would need additional data
| Question | Data required |
|---|---|
| Which genres or countries drive **viewing**? | Viewing hours or completion rates per title (e.g. Netflix's published engagement reports) |
| Do new additions **acquire or retain subscribers**? | Subscriber sign-ups and churn by region and month |
| Is content **cost-effective**? | Licensing and production cost per title |
| How does the catalog **differ by country**? | Regional availability data (catalogs vary by market) |
| How has the catalog **really** changed over time? | Historical snapshots, including titles that were removed |
| Are original productions growing? | A "Netflix Original" flag |
| How do audiences **rate** the content? | IMDb/TMDB ratings joined by title and year |
