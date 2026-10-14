# Portfolio Kit: Netflix Content Analytics

Everything you need to present this project: GitHub, LinkedIn, resume and interviews.
All numbers come from the analysis outputs.

---

## 1. GitHub repository description (≤ 350 characters)

> End-to-end analysis of 8,800+ Netflix titles: Python data cleaning with documented decisions and automated
> validation, EDA, PostgreSQL analytics (CTEs, window functions) and a 3-page Power BI dashboard on catalog
> growth, genres, countries and ratings.

**Topics/tags:** `data-analysis` `python` `pandas` `sql` `postgresql` `power-bi` `eda` `data-cleaning` `netflix` `portfolio`

---

## 2. LinkedIn project post

> 🎬 **What does Netflix's catalog actually contain? I analysed 8,800+ titles to find out.**
>
> I just finished an end-to-end data analytics project using the public Netflix Movies & TV Shows dataset:
> **Python → PostgreSQL → Power BI**.
>
> A few things I found:
> 📈 Catalog additions peaked in **2019 (2,015 titles)**. The data seemed to show a 20% drop in 2021, but 2021
> only runs to September. Comparing the **same Jan–Sep period**, 2021 had *more* additions (1,498) than 2019 or 2020.
> Always check whether your last period is complete!
> 🌍 The US is credited on **42%** of titles. India's titles are **92% movies**, while South Korea's are **74% TV shows**.
> 🎭 Nearly **half** the catalog carries an "International" tag. Drama and Comedy are the leading genres.
> 📺 **67%** of TV shows have just one season available.
>
> What I practised:
> ✅ Investigating data before cleaning it: I found shifted columns, invisible characters and a hidden duplicate
> ✅ Documenting every cleaning decision and validating the output with automated checks
> ✅ Normalising multi-value fields into bridge tables for SQL and Power BI
> ✅ Window functions, CTEs and percentiles in PostgreSQL
> ✅ A star-schema Power BI model with DAX time intelligence
>
> One important caveat: this dataset is **catalog metadata**, not viewing data. It shows what Netflix *offers*,
> not what people *watch*. Keeping that line clear was one of my main goals.
>
> 🔗 GitHub: [link]
> Feedback welcome, especially from analysts working in media and streaming!
>
> #DataAnalytics #Python #SQL #PowerBI #DataVisualization #Portfolio #OpenToWork

*(Attach 2–3 images: the Executive Overview dashboard page and the "additions per year" chart.)*

---

## 3. Resume bullet points

- **Cleaned and validated an 8,807-record Netflix catalog dataset in Python (pandas).** Resolved 12 documented
  data-quality issues, including shifted columns, hidden-character duplicates and multi-valued fields, and enforced
  12 automated validation checks before publishing the analysis-ready tables.
- **Designed a normalised PostgreSQL model with 3 tables and 2 many-to-many bridge tables, and wrote 17 analytical
  queries** using CTEs, window functions (RANK, LAG, moving averages) and percentiles. Results matched the Python
  outputs exactly.
- **Built a 3-page interactive Power BI dashboard (star schema, 28 DAX measures, synced slicers)** covering catalog
  growth, genre, country and rating mix. Corrected a misleading 20% "decline" in 2021 additions by introducing a
  same-period comparison, which showed 2021 was actually 8% above 2020.

> 💡 Jan–Sep 2021 (1,498) vs Jan–Sep 2020 (1,389) = +7.8%, which rounds to 8%.

---

## 4. Interview questions & sample answers

### Q1. "Walk me through this project."
> "I analysed Netflix's public catalog dataset, about 8,800 titles, to understand content mix, growth, countries,
> genres and ratings. I worked in four stages. First, a read-only profiling notebook where I logged 12 data-quality
> issues. Second, a cleaning notebook where each issue got a documented decision and the output passed automated
> checks. Third, EDA in Python and analytical queries in PostgreSQL. Finally, a Power BI dashboard. One thing I was
> careful about: the data is catalog metadata, so I only made claims about what's *offered*, not what's *watched*."

### Q2. "How did you handle missing values?"
> "I asked *why* each value was missing before deciding anything. Director was missing for over 90% of TV shows,
> which is structural, because series have many episode directors. Deleting those rows would have removed most TV
> shows and biased everything, so I labelled them 'Not Listed'. Missing countries became 'Unknown', and I report
> that share (9.4%) on the dashboard instead of hiding it. The 10 missing add dates I left empty, because inventing
> dates would distort the time trends. I didn't fill anything with a mode or a guess."

### Q3. "How did you deal with duplicates?"
> "Exact-match checks found zero duplicates, but I didn't stop there. After normalising case and whitespace, six
> potential pairs appeared. I compared them field by field. One pair was identical except for an invisible
> non-breaking space, so I removed it. Two pairs were a movie and a TV show with the same name, so they weren't
> duplicates. Three pairs had the same title but different add dates. I couldn't prove those were errors, so I kept
> them and documented them, and I wrote a SQL query that surfaces them. Only one row was removed in total."

### Q4. "The data shows additions dropped 20% in 2021. What would you tell a stakeholder?"
> "That the drop isn't real, at least not from this data. The dataset ends on 25 September 2021, so 2021 has only
> about nine months. When I compared the same January-to-September window, 2021 had 1,498 additions, more than 2020
> (1,389) and 2019 (1,353). I'd also mention a second caveat: the file is a single snapshot, so titles that were
> added and later removed aren't counted. That means early years are understated too."

### Q5. "Why did you build bridge tables, and how did that affect Power BI?"
> "Country and genre were comma-separated lists. If you group by the raw text, 'United States, India' becomes its
> own country. I exploded them into one row per title-country and title-genre. That's first normal form, and it
> made SQL grouping correct. In Power BI I connected them as a star schema with dimension tables, setting
> bidirectional filtering only on the bridge-to-titles relationships so a country slicer filters the titles table.
> It also means shares add up to more than 100% because of co-productions, and I explain that on the charts."

**Bonus questions to prepare:**
- *"What's the difference between a measure and a calculated column?"* (See `powerbi/DASHBOARD_BUILD_GUIDE.md`, Step 4.)
- *"Why the median movie duration rather than the mean?"* Because of outliers from 3 to 312 minutes.
- *"What would you analyse with more data?"* Viewing hours by genre, subscriber churn vs new releases, and
  historical snapshots. (See the follow-up table in `key_findings.md`.)
