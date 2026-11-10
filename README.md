# NYC 311 Operational Analytics

An end-to-end analytics project exploring 2024 NYC 311 service requests using SQL and Microsoft Power BI. The project examines service demand, geographic and seasonal patterns, agency workload, resolution performance, and data quality.

## Project Overview

NYC 311 provides a channel for residents to report service needs and local issues. This project analyzes 2024 service-request records to turn a large operational dataset into clear, decision-oriented insights.

The analysis is organized around three business questions:

1. **Service demand:** Where and when are residents requesting the most services?
2. **Operational efficiency:** How do workload and resolution times vary by agency, borough, and complaint type?
3. **Data reliability:** Are request status and closure-date fields complete and consistent enough to support reliable reporting?

## Project Objectives

- Analyze service-request volume and monthly trends.
- Compare demand across NYC boroughs and complaint categories.
- Examine seasonal patterns, including Heat & Hot Water requests.
- Compare agency workload and average resolution time.
- Assess closure-date completeness and status/date consistency.
- Present findings and practical recommendations in an interactive Power BI dashboard.

## Tools and Technologies

- **SQL / MySQL** — data validation, aggregation, and analytical queries.
- **Microsoft Power BI** — data modeling, DAX measures, interactive visuals, and dashboard reporting.
- **Microsoft Excel** — supporting data review and project documentation.

## Dataset

- **Analysis period:** January–December 2024.
- **Scope:** NYC 311 service-request records.
- **Analyzed volume:** approximately 3.46 million records.
- **Key analytical fields:** request creation date, closure date, status, borough, agency, complaint type, and calculated resolution time.

The raw dataset is not included in this repository at this stage. Before reproducing the analysis, obtain the corresponding 2024 NYC 311 source data and confirm that its schema matches the SQL scripts and Power BI model.

## Power BI Dashboard

The dashboard contains four analytical pages:

| Page | Focus | Main questions |
|---|---|---|
| 1. Executive Overview | Overall KPIs and service-request trends | What is the overall service-request and closure picture? |
| 2. Service Demand Analysis | Monthly, borough, complaint-type, and seasonal patterns | Where and when is demand highest? |
| 3. Operational Efficiency | Agency workload and resolution performance | How do workload and resolution times vary? |
| 4. Data Quality & Business Insights | Missing closure dates and status/date inconsistencies | What data-quality issues could affect reporting? |

## Key Findings

- **Borough demand:** Brooklyn recorded the highest service-request volume; Staten Island recorded the lowest.
- **Seasonality:** Heat & Hot Water requests increased during winter.
- **Agency workload:** NYPD had the highest request workload among the agencies analyzed.
- **Agency resolution time:** The Department of Parks and Recreation (DPR) had the longest average agency resolution time.
- **Borough resolution time:** Staten Island had the longest average resolution time by borough.
- **HPD complaint type:** Unsanitary Condition had the longest average resolution time in the HPD complaint-type analysis.
- **Data quality:** The analysis identified requests marked Closed without closure dates, as well as non-Closed requests that contained closure dates.
- **Resolution-time distribution:** Average resolution time was 13.75 days, compared with a median of 0.34 days, indicating a highly uneven distribution and the importance of reviewing both measures.

## Business Recommendations

1. **Plan resources using borough-level demand.** Consider request volume alongside population, agency capacity, and case complexity rather than relying on citywide totals alone.
2. **Prepare for seasonal demand.** Use historical winter Heat & Hot Water patterns to support advance staffing and operational planning.
3. **Investigate longer resolution times.** Review long-running cases and potential workflow constraints, while accounting for differences in complaint complexity.
4. **Monitor workload and outcomes together.** Agency request volume should be evaluated alongside resolution-time distributions and service mix.
5. **Strengthen status/date validation.** Establish checks for Closed requests without closure dates and non-Closed requests with closure dates.
6. **Track average and median resolution time.** Use both measures and investigate unusually long-running requests.

## Data Quality Considerations

The dashboard highlights the following approximate counts from the project analysis:

- Approximately **63,000** requests with missing closure dates.
- Approximately **27,600** requests marked Closed with missing closure dates.
- Approximately **3,000** requests with a non-Closed status but a populated closure date.

These conditions should be investigated rather than automatically corrected. A missing closure date does not by itself prove that a request remains unresolved, and a populated closure date paired with a non-Closed status may reflect a source-system or status-definition issue.

## Limitations

- This is a descriptive analysis; it identifies patterns but does not establish the causes of resolution delays or differences between agencies and boroughs.
- Request volume alone is not a measure of service quality or staffing adequacy.
- Resolution times can vary with complaint complexity, operational requirements, and data completeness.
- Average resolution time can be influenced by unusually long-running records; the median provides a complementary view.
- Rounded KPI values in this README should be reconciled with the final KPI register and validated SQL outputs before publication.

## Repository Contents

The repository will contain the project README, SQL analysis files, supporting documentation, and selected Power BI deliverables and screenshots as they are added and checked.

Suggested organization:

```text
nyc-311-operational-analytics/
├── README.md
├── sql/
│   ├── data-validation/
│   ├── data-quality/
│   ├── service-demand/
│   └── operational-performance/
├── documentation/
│   ├── data-dictionary/
│   ├── data-cleaning-notes/
│   ├── sql-analysis-notes/
│   ├── project-report/
│   └── key-findings-and-recommendations/
├── power-bi/
│   ├── dashboard/
│   └── demo/
└── screenshots/
```

The folder names above describe the recommended GitHub layout; repository files should be added only after they have been reviewed and prepared for public sharing.

## Conclusion

This project demonstrates how SQL and Power BI can be used together to analyze public-service demand, evaluate operational patterns, and identify data-quality issues. It connects technical analysis with practical recommendations for resource planning, seasonal preparedness, operational monitoring, and more reliable reporting.
