# Safari_Connect — Business Performance Analysis

A data cleaning, SQL analytics, and Power BI dashboard project for SafariConnect, a Kenyan intercity transport booking platform. This project takes raw, messy booking data through cleaning, analysis, and view creation, ending in a business-facing Power BI dashboard for executive reporting.

## Project Overview

SafariConnect's booking data arrived as a raw export full of common real-world data quality issues — inconsistent phone number formats, mixed-case text fields, text-typed numeric columns, duplicate records, and inconsistent date formats. This project cleans that data, answers a series of business questions using SQL, and packages the results as reusable database views consumed directly by a Power BI dashboard.

**Business questions answered:**
- Which routes earn the most, are most popular, and are most efficient per seat sold?
- Which vehicle type (Bus, Matatu, Minibus) is most profitable?
- Which drivers generate the most revenue and how do they rank within their vehicle type?
- Does driver rating correlate with passenger satisfaction?
- What's the monthly revenue trend, and which were the best/worst 3 months?
- Who are the top passenger cities, and how do gender and seat class interact?
- What's the passenger satisfaction breakdown, and how are passengers distributed by spend quartile?
- What's the cancellation and no-show rate by route, and how much revenue is lost to them?
- What are the busiest travel days and departure time slots?
- How full does each vehicle type typically run?

## Tech Stack

- **PostgreSQL** — data cleaning, transformation, and analytical queries
- **Power BI Desktop** — dashboard and visualization layer
- **DAX** — dynamic KPI measures (Top Route, Top Driver)

## Project Structure

```
safariconnect/
├── sql/
│   ├── 01_schema_and_staging.sql       -- raw staging table setup
│   ├── 02_data_cleaning.sql            -- cleaning transformations
│   ├── 03_production_load.sql          -- clean bookings table + v_trips view
│   ├── 04_business_analysis.sql        -- Questions 1–6 (route, driver, revenue,
│   │                                       passenger, cancellation, operational)
│   └── 05_bi_views.sql                 -- final views handed off to Power BI
├── dashboard/
│   └── SafariConnect_Dashboard.pbix    -- Power BI dashboard file
├── screenshots/
│   └── dashboard_overview.png
└── README.md
```

## Data Pipeline

**1. Staging** — raw CSV loaded into `staging_bookings` with every column typed as `TEXT`, preserving the data exactly as received.

**2. Cleaning** — transformations applied directly on staging data:
- Name and city fields: trimmed, standardized to title case
- Phone numbers: stripped of formatting, normalized to a consistent local format (`07XXXXXXXX`)
- Gender, seat class, booking status, payment method: standardized casing and spelling variants merged (e.g., `'no show'`, `'NO SHOW'` → `'No Show'`)
- Fare fields: cleaned of stray characters and cast to numeric
- Dates: multiple inconsistent formats (`DD/MM/YYYY`, `YYYY-MM-DD`, `DD-MM-YY`, ambiguous `MM-DD` vs `DD-MM`) parsed into a single standard `DATE` type
- Invalid rows removed: negative seat counts, exact duplicate bookings

**3. Production load** — cleaned, properly typed data loaded into `bookings`, a permanent table with real data types (`NUMERIC`, `DATE`, `INTEGER`) instead of `TEXT`.

**4. Analysis view (`v_trips`)** — a reusable, query-ready view built on top of clean data, used as the primary source for all business analysis queries.

## Key SQL Techniques Used

- **CTEs** for multi-step aggregations (monthly revenue ranking, driver totals, passenger quartiles)
- **Window functions** — `RANK()`, `NTILE()`, `LAG()`, `SUM() OVER()` for rankings, quartile segmentation, month-over-month change, and running percentages
- **CASE WHEN pivots** — turning row-based categories (seat class, route, booking status) into side-by-side columns
- **HAVING vs WHERE** — filtering on aggregated vs. row-level conditions
- Type casting for legacy text-typed numeric columns

## Business Intelligence Views

Five core views were created as the final handoff layer to Power BI:

| View | Purpose |
|---|---|
| `v_route_performance` | Revenue by route |
| `v_driver_performance` | Trips, revenue, and ratings by driver |
| `v_monthly_revenue` | Monthly revenue with month-over-month change |
| `v_cancellation_analysis` | Bookings, cancellations, and no-shows by route |
| `v_passenger_insights` | Top passenger cities (3+ bookings) |
| `v_satisfaction_breakdown` | Passenger satisfaction category counts |

## Dashboard

The Power BI dashboard presents a single-page executive overview featuring:
- **KPI cards**: Total Revenue, Total Bookings, Average Cancellation Rate, Top Route, Top Driver
- **Cancellation Rate by Route** — bar chart identifying high-risk routes
- **Monthly Revenue Trend** — line chart with month-over-month change
- **Driver Performance Summary** — sortable table of driver metrics
- **Top Passenger Cities** — bar chart of booking volume by city
- **Revenue by Route** — bar chart of top-earning routes
- **Passenger Satisfaction Breakdown** — pie chart of Satisfied / Neutral / Unsatisfied / No Rating


<img width="1748" height="748" alt="image" src="https://github.com/user-attachments/assets/63c1cde1-6c98-488a-b237-e06469e20489" />


## Key Findings

- Route **RT001 (Nairobi → Mombasa)** is the top-earning route, generating the highest revenue in the network.
- **Isaac Korir** is the top-performing driver by total revenue.
- Cancellation rates vary significantly by route, with **Nairobi → Mombasa** showing the highest cancellation percentage despite also being the top earner — flagged as a priority for operational review.
- Overall passenger satisfaction skews positive, though a meaningful share of trips carry no rating at all, suggesting a gap in post-trip feedback collection.

## How to Reproduce

1. Run the SQL scripts in `sql/` in numbered order against a PostgreSQL instance.
2. Confirm all 6 views return data:
   ```sql
   SELECT * FROM v_route_performance;
   SELECT * FROM v_driver_performance;
   SELECT * FROM v_monthly_revenue;
   SELECT * FROM v_cancellation_analysis;
   SELECT * FROM v_passenger_insights;
   SELECT * FROM v_satisfaction_breakdown;
   ```
3. Open `dashboard/SafariConnect_Dashboard.pbix` in Power BI Desktop.
4. Update the data source connection (Home → Transform Data → Data Source Settings) to point at your local PostgreSQL instance.
5. Refresh the data.

## Author

Joy Jerop Cheptoo (Yego)
BSc Information Technology, Dedan Kimathi University of Technology
