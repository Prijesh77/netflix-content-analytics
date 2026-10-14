# Power BI Dashboard: Step-by-Step Build Guide

> **Fast path:** the finished dashboard is already in this folder as a Power BI Project.
> Open `netflix_dashboard.pbip` in Power BI Desktop and click **Refresh**. This guide explains how each part was
> built and why. Read it so you can explain the model and the DAX in an interview, or follow it to rebuild the
> dashboard from scratch.
>
> Note: the generated project ranks countries, genres and ratings with measures (`Country Rank`, `Genre Rank`,
> `Titles (Top 10 Countries)` …) instead of Top N filters, so the rankings react to slicers.

A `.pbix` file can only be created inside Power BI Desktop, so this guide takes you through building it yourself.
It should take about 2–3 hours. Every step explains **why** as well as **what**. Interviewers will ask about your
data model and your DAX, so it helps to understand both.

**You need:** Power BI Desktop (free, Windows), the three CSVs in `data/processed/`, and `powerbi/netflix_theme.json`.

**Save as:** `powerbi/netflix_dashboard.pbix`

---

## Step 1 · Load the data (Power Query)

1. **Home → Get data → Text/CSV** and load each file:
   - `netflix_titles_clean.csv` → rename the query to **`titles`**
   - `netflix_title_countries.csv` → **`title_countries`**
   - `netflix_title_genres.csv` → **`title_genres`**
2. Click **Transform Data** and check the column types in Power Query:

   | Column | Type |
   |---|---|
   | `date_added` | Date |
   | `added_year`, `added_month`, `release_year`, `content_age_at_add`, `duration_value`, `country_count`, `genre_count` | Whole Number |
   | everything else | Text |

3. In `titles`, **remove the `description` and `cast` columns**. We never chart them, and dropping them keeps
   the model small and fast.
4. **Close & Apply.**

> 🧠 **Why the bridge tables?** A single `country` cell can say `"United States, India"`. Power BI can't count
> countries inside a text string, so the bridge tables already hold one row per title–country pair.

---

## Step 2 · Build the data model

### 2a. Create the dimension tables
**Modeling → New table**, then paste:

```DAX
Dim Country = DISTINCT ( title_countries[country] )
```

```DAX
Dim Genre = DISTINCT ( title_genres[genre_group] )
```

```DAX
Dim Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2008, 1, 1 ), DATE ( 2021, 12, 31 ) ),
    "Year",        YEAR ( [Date] ),
    "Month Num",   MONTH ( [Date] ),
    "Month",       FORMAT ( [Date], "mmm" ),
    "Year Month",  FORMAT ( [Date], "yyyy-mm" )
)
```
Then select **Dim Date → Table tools → Mark as date table** using `[Date]`. Also select the `Month` column and
set **Sort by column → Month Num**. Without that, months sort alphabetically (Apr, Aug, Dec…).

### 2b. Relationships (Model view)

| From (one side) | To (many side) | Cardinality | Cross-filter direction |
|---|---|---|---|
| `Dim Date[Date]` | `titles[date_added]` | 1 : * | Single |
| `titles[show_id]` | `title_countries[show_id]` | 1 : * | **Both** |
| `Dim Country[country]` | `title_countries[country]` | 1 : * | Single |
| `titles[show_id]` | `title_genres[show_id]` | 1 : * | **Both** |
| `Dim Genre[genre_group]` | `title_genres[genre_group]` | 1 : * | Single |

```
 Dim Country ──► title_countries ◄──► titles ◄──► title_genres ◄── Dim Genre
                                        ▲
                                    Dim Date
```

> 🧠 **Why "Both" on the bridge?** When you click "India" in a slicer, the filter flows Dim Country → title_countries.
> To reach `titles` it must travel *back up* the bridge, which needs bidirectional filtering. This is Microsoft's
> standard **many-to-many via bridge table** pattern. Keep "Both" only on these two bridge relationships.

---

## Step 3 · Calculated columns (in `titles`)

Calculated columns are computed **once per row** at refresh time. Use them for categories you want on an axis
or in a slicer.

```DAX
Runtime Band =
IF (
    titles[type] = "Movie",
    SWITCH (
        TRUE (),
        titles[duration_value] < 60,   "1. Under 60 min",
        titles[duration_value] <= 90,  "2. 60–90 min",
        titles[duration_value] <= 120, "3. 91–120 min",
        titles[duration_value] <= 150, "4. 121–150 min",
        "5. Over 150 min"
    )
)
```

```DAX
Season Bucket =
IF (
    titles[type] = "TV Show",
    IF ( titles[duration_value] >= 6, "6+", FORMAT ( titles[duration_value], "0" ) )
)
```

```DAX
Release Decade = FLOOR ( titles[release_year], 10 ) & "s"
```

---

## Step 4 · Measures

Create an empty table to hold them (**Enter data → name it `_Measures`**). Then add each measure with
**New measure**. Measures are calculated **at query time, in the current filter context**, which is why one
`[Total Titles]` measure gives the right number in every visual and for every slicer selection.

### Core KPIs
```DAX
Total Titles = COUNTROWS ( titles )

Total Movies = CALCULATE ( [Total Titles], KEEPFILTERS ( titles[type] = "Movie" ) )

Total TV Shows = CALCULATE ( [Total Titles], KEEPFILTERS ( titles[type] = "TV Show" ) )

Distinct Release Years = DISTINCTCOUNT ( titles[release_year] )

Movie Share % = DIVIDE ( [Total Movies], [Total Titles] )

TV Share % = DIVIDE ( [Total TV Shows], [Total Titles] )
```

> 🧠 **Why `KEEPFILTERS`?** A plain `CALCULATE(..., titles[type] = "Movie")` *replaces* any existing filter on
> `type`, so with a "TV Show" slicer selected, Total Movies would still show 6,130. `KEEPFILTERS` *intersects*
> instead: Movie ∩ TV Show = nothing → blank, which is the honest answer.

### Time intelligence (these use Dim Date, so they count by `date_added`)
```DAX
Titles Added = CALCULATE ( [Total Titles], NOT ISBLANK ( titles[date_added] ) )

Titles Added PY = CALCULATE ( [Titles Added], SAMEPERIODLASTYEAR ( 'Dim Date'[Date] ) )

Titles Added YoY % = DIVIDE ( [Titles Added] - [Titles Added PY], [Titles Added PY] )

Titles Added YTD = TOTALYTD ( [Titles Added], 'Dim Date'[Date] )

-- Same-period comparison: every year cut off at the last month present in 2021
Titles Added Jan-Sep =
VAR LastMonth2021 =
    CALCULATE ( MAX ( titles[added_month] ), titles[added_year] = 2021, REMOVEFILTERS ( 'Dim Date' ) )
RETURN
    CALCULATE ( [Titles Added], 'Dim Date'[Month Num] <= LastMonth2021 )
```

### Duration
```DAX
Avg Movie Duration (min) = CALCULATE ( AVERAGE ( titles[duration_value] ), KEEPFILTERS ( titles[type] = "Movie" ) )

Median Movie Duration (min) = CALCULATE ( MEDIAN ( titles[duration_value] ), KEEPFILTERS ( titles[type] = "Movie" ) )

Avg Seasons per Show = CALCULATE ( AVERAGE ( titles[duration_value] ), KEEPFILTERS ( titles[type] = "TV Show" ) )

Single-Season Share % =
DIVIDE (
    CALCULATE ( [Total Titles], KEEPFILTERS ( titles[type] = "TV Show" ), titles[duration_value] = 1 ),
    [Total TV Shows]
)
```

### Country & genre
```DAX
-- No special "country count" measure is needed: [Total Titles] already filters
-- correctly through the bidirectional bridge (Dim Country → title_countries → titles)

% of Catalog = DIVIDE ( [Total Titles], CALCULATE ( [Total Titles], REMOVEFILTERS () ) )

Unknown Country % =
DIVIDE ( CALCULATE ( [Total Titles], titles[country] = "Unknown" ), [Total Titles] )
```

### Dynamic text (makes the dashboard explain itself)
```DAX
Data Note =
"Catalog snapshot to "
    & FORMAT ( MAX ( titles[date_added] ), "d mmm yyyy" )
    & " · 2021 is a partial year · Counts are titles, not viewing hours"
```

### Page helpers (dynamic titles, highlight colour, genre mix)
```DAX
Runtime Chart Title =
IF (
    ISBLANK ( [Median Movie Duration (min)] ),
    "Movie runtimes (no movies in current selection)",
    "Movie runtimes · median " & FORMAT ( [Median Movie Duration (min)], "0" ) & " min"
)

Seasons Chart Title =
IF (
    ISBLANK ( [Total TV Shows] ),
    "TV seasons available (no TV shows in current selection)",
    "TV seasons available · " & FORMAT ( [Single-Season Share %], "0%" ) & " have just one"
)

Jan-Sep Bar Colour = IF ( SELECTEDVALUE ( 'Dim Date'[Year] ) = 2021, "#E50914", "#5A5A5A" )

-- Share of a country's titles tagged with each genre (denominator ignores genre filters)
% of Country Titles =
DIVIDE (
    [Total Titles],
    CALCULATE ( [Total Titles], REMOVEFILTERS ( 'Dim Genre' ), REMOVEFILTERS ( title_genres ) )
)
```

> 🧠 **Interview tip:** be ready to explain the difference between a **calculated column** (stored per row,
> computed at refresh, can go on an axis) and a **measure** (computed on the fly, responds to filters,
> used for values).

---

## Step 5 · Apply the theme

**View → Themes → Browse for themes →** `powerbi/netflix_theme.json`.
This gives a dark background (#141414), card panels (#1F1F1F) and Netflix red (#E50914), with light steel
blue (#8FB8DE) as the TV Show colour.

**Consistency rule:** Movie = red and TV Show = blue on **every** page. Set this once per visual under
*Format → Colors* if Power BI assigns them differently. Use red sparingly: for movies and for the one thing
you want the reader to notice.

Canvas: **1280 × 720 (16:9)**. Use a 16 px outer margin and 12 px gaps between visuals.

---

## Step 6 · Build the pages

### Page 1 · Executive Overview
| Position | Visual | Fields |
|---|---|---|
| Top band | **Text box** title "Netflix Content Analytics" + card showing `[Data Note]` | — |
| Row 1 (4 cards) | **Card (new)** × 4 | `[Total Titles]`, `[Total Movies]`, `[Total TV Shows]`, `[Distinct Release Years]` |
| Row 2 left (⅓) | **Donut** or 100% bar | Legend `titles[type]`, Values `[Total Titles]` |
| Row 2 right (⅔) | **Stacked column** | X `Dim Date[Year]`, Y `[Titles Added]`, Legend `titles[type]` |
| Right rail | **Slicer** (tile) | `titles[type]` |

Add a small text label on the column chart: "2021 = Jan–Sep only". **Don't hide the partial year. Label it.**

### Page 2 · Content Trends
| Position (x, y, w, h) | Visual | Fields | Notes |
|---|---|---|---|
| 16, 88, 616, 286 | **Line chart**: titles by release year | X `titles[release_year]`, Y `[Total Titles]`, Legend `titles[type]` | Visual filter `release_year >= 1980` |
| 644, 88, 620, 286 | **Matrix heatmap**: added by year × month | Rows `Dim Date[Year]`, Columns `Dim Date[Month]`, Values `[Titles Added]` | Year ≥ 2016; subtotals off; background gradient #1F1F1F → #E50914 |
| 16, 386, 303, 286 | **Column**: same-period comparison | X `Dim Date[Year]` (2017–2021), Y `[Titles Added Jan-Sep]` | Columns colour via fx → Field value `[Jan-Sep Bar Colour]` |
| 331, 386, 303, 286 | **Bar**: rating distribution | Y `titles[rating]`, X `[Total Titles]` | Top N 10; sort descending; neutral grey |
| 646, 386, 303, 286 | **Column**: runtime bands | X `titles[Runtime Band]`, Y `[Total Movies]` | Title via fx → `[Runtime Chart Title]`; red |
| 961, 386, 303, 286 | **Column**: seasons | X `titles[Season Bucket]`, Y `[Total TV Shows]` | Title via fx → `[Seasons Chart Title]`; blue |

### Page 3 · Global Content & Genres
| Position (x, y, w, h) | Visual | Fields | Notes |
|---|---|---|---|
| 16, 88, 220, 584 | **Slicer rail** | `titles[type]` (tile), `titles[release_year]` (between), `Dim Country[country]` (dropdown + search), `titles[rating]` (dropdown), **Clear all slicers** button | Sync the type slicer to all pages |
| 248, 88, 502, 286 | **Stacked bar**: Top 10 countries | Y `Dim Country[country]`, X `[Total Titles]`, Legend `titles[type]` | Top N 10 on `Dim Country[country]`; exclude Unknown via `title_countries[country]` |
| 762, 88, 502, 286 | **Bar**: genre groups | Y `Dim Genre[genre_group]`, X `[Total Titles]` | Top N 12 on `Dim Genre[genre_group]`; exclude "(label)" via `title_genres[genre_group]` does not contain |
| 248, 386, 800, 286 | **Matrix**: Country × Genre mix | Rows `Dim Country[country]`, Columns `Dim Genre[genre_group]`, Values `[% of Country Titles]` | Top 10 countries, top 8 genres, same exclusions; background gradient |
| 1060, 386, 204, 286 | **Card** | `[Unknown Country %]` | Label: "of titles have no country recorded" |

> 💡 **Why exclude via the bridge column?** A field can carry only one filter type in the Filters pane. Top N goes on
> the dimension column, and the "exclude" rule goes on the matching bridge column.

> ⚠️ **Avoid a filled map.** Choropleths make large countries look important simply because they cover more area,
> and the US would drown out everything else. A sorted bar chart is more accurate and easier to read.

---

## Step 7 · Check your numbers before you publish

With **no slicers applied**, your cards should match the Python/SQL results:

| Check | Expected |
|---|---|
| Total Titles | 8,806 |
| Total Movies / TV Shows | 6,130 / 2,676 |
| Distinct Release Years | 74 |
| Titles Added 2019 | 2,015 |
| United States (bridge count) | 3,690 |
| Median Movie Duration | 98 |

If any number is different, check the relationship directions (Step 2b) first.

---

## Step 8 · Screenshots for GitHub

1. Clear all slicers.
2. **File → Export → Export to PDF**, or use Windows **Snipping Tool** (Win + Shift + S) on each page.
3. Save as `powerbi/dashboard_screenshots/01_executive_overview.png`, `02_content_trends.png`, `03_global_content_genres.png`.
4. The README already links to these filenames, so the images will appear once the files exist.
