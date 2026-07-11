# Cyclistic Bike-Share Case Study

## Project Overview
Cyclistic is a fictional bike-share company operating in Chicago. This project analyzes trip data to understand how **casual riders** and **annual members** use the service differently, in order to support a marketing strategy aimed at converting casual riders into annual members.

## Dataset
12 months of Cyclistic bike-share trip data, **May 2025 – May 2026**.

## Tools Used
- **PostgreSQL 16** — data cleaning
- **Excel** — analysis and visualization
- **PowerPoint** — presentation of findings

## Data Cleaning
The full cleaning process is documented in [`sql_cleaning.sql`](sql_cleaning.sql). Summary:

| Metric | Value |
|---|---|
| Rows before cleaning | 6,213,372 |
| Rows after cleaning | 6,169,867 |
| Total rows removed | 43,505 |

Removals by reason:
- **35** exact duplicate rows (same `ride_id`)
- **37,212** logically invalid trips (negative duration, or under 1 minute at the same start/end station)
- **6,208** trips longer than 24 hours (likely bikes not properly docked, lost, or stolen)
- **50** rows with corrupted timestamps outside the reporting window

Station names were also trimmed of leading/trailing whitespace, and derived columns (trip duration, day of week, start hour) were added to the cleaned table to support analysis.

## Findings
The full analysis and findings are documented in the accompanying PDF presentation. In summary:
- **Annual embers** ride primarily on weekdays during rush hours, concentrated at commuter locations.
- **Casual riders** peak on weekends in the afternoon, concentrated at tourist destinations.

## Limitations
- January 2026 data was unavailable and excluded from this analysis.
- Station ID inconsistencies were identified (1,305 station names mapped to more than one station ID) but were not corrected.
