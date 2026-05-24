# esports-league-db

> Enterprise-scale MS SQL Server database for a full esports league management platform.  
> Built to practice real-world query optimisation — indexes, partitioning, window functions, CTEs & stored procedures.

---

## Overview

This database models every layer of a competitive esports organisation: games, leagues, tournaments, matches, player contracts, coaching staff, sponsors, venue logistics, fan ticketing, broadcast rights, and audit logging.

**28 tables across 3 schemas and 3 filegroups.**

---

## Schema domains

| Domain | Schema | Tables | Description |
|---|---|---|---|
| Competition core | `comp` | 14 | Games, leagues, teams, players, matches, stats |
| Business operations | `ops` | 13 | Venues, events, tickets, fans, sponsors, broadcast |
| Audit & archiving | `audit` | 1 | Append-only change log |

---

## Filegroups

| Filegroup | Tables | Purpose |
|---|---|---|
| `PRIMARY` | All comp + ops core tables | General read/write |
| `FG_STATS` | `player_stat`, `player_rating` | High read volume, separate I/O |
| `FG_LOGS` | `viewership_log`, `audit.log` | Append-heavy, partitioned by month |

---

## Getting started

### Prerequisites
- SQL Server 2019+ (or Azure SQL)
- `C:\SQLData\` directory (or update file paths in `01_create_database.sql`)
- `sysadmin` or `dbcreator` role

### Run order

Execute files in this exact order:

```
01_schema/01_create_database.sql
01_schema/02_core_competition.sql
01_schema/03_contracts.sql
01_schema/04_tournaments_matches.sql
01_schema/05_stats_ratings.sql
01_schema/06_venues_events.sql
01_schema/07_fans_tickets.sql
01_schema/08_sponsors.sql
01_schema/09_broadcast.sql
01_schema/10_audit.sql

02_indexes/01_clustered_indexes.sql
02_indexes/02_nonclustered_indexes.sql
02_indexes/03_covering_indexes.sql
02_indexes/04_filtered_indexes.sql

03_seed_data/  (01 through 06 in order)

04_views/      (any order)
05_stored_procedures/  (any order)

08_partitioning/ (01 through 04 in order)
```

---

## Folder guide

```
01_schema/           DDL — all CREATE TABLE statements
02_indexes/          Index strategy — clustered, nonclustered, covering, filtered
03_seed_data/        Realistic sample data for all 28 tables
04_views/            Reporting views (standings, leaderboards, revenue)
05_stored_procedures/ Business logic procedures
06_window_functions/ Practice queries — ROW_NUMBER, RANK, LAG, LEAD, PERCENTILE
07_ctes/             CTE chains — recursive bracket, pipelines, ROI analysis
08_partitioning/     Partition function, scheme, and archiving setup
09_optimisation/     Execution plan notes, index tuning, query rewrites
docs/                ERD diagrams and schema notes
```

---

## Optimisation topics covered

| Topic | Where |
|---|---|
| Clustered vs non-clustered index design | `02_indexes/` |
| Covering indexes for common query patterns | `02_indexes/03_covering_indexes.sql` |
| Filtered indexes (e.g. active contracts only) | `02_indexes/04_filtered_indexes.sql` |
| Computed columns in queries | `comp.player_stat.kda_ratio`, `comp.team_standing.map_diff` |
| Window functions — ranking, running totals, lag/lead | `06_window_functions/` |
| Recursive CTEs — tournament bracket traversal | `07_ctes/01_recursive_bracket.sql` |
| Table partitioning by date | `08_partitioning/` |
| Partition switching for archiving | `08_partitioning/04_audit_log_archiving.sql` |
| Execution plan analysis | `09_optimisation/01_execution_plan_analysis.md` |
| Statistics maintenance | `09_optimisation/04_statistics_maintenance.sql` |

---

## ERD

![Competition core](docs/erd_competition.png)
![Business operations](docs/erd_business.png)

---

## Author

Morobang Tshigidimisa — [morobangtshigidimisa.vercel.app](https://morobangtshigidimisa.vercel.app)