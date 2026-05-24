-- =============================================================================
-- FILE:    01_create_database.sql
-- PURPOSE: Create the EsportsLeague database with filegroups for partitioning
-- RUN AS:  sysadmin or dbcreator role on the SQL Server instance
-- =============================================================================

USE master;
GO

-- Drop and recreate for clean setup (comment out in production)
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'EsportsLeague')
BEGIN
    ALTER DATABASE EsportsLeague SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EsportsLeague;
END
GO

-- =============================================================================
-- DATABASE CREATION WITH FILEGROUPS
-- PRIMARY        → core tables
-- FG_STATS       → player_stat, player_rating (high read volume)
-- FG_LOGS        → viewership_log, audit_log  (partitioned, append-heavy)
-- =============================================================================

CREATE DATABASE EsportsLeague
ON PRIMARY
(
    NAME       = N'EsportsLeague_Primary',
    FILENAME   = N'C:\SQLData\EsportsLeague_Primary.mdf',
    SIZE       = 64MB,
    MAXSIZE    = 2GB,
    FILEGROWTH = 64MB
),
FILEGROUP FG_STATS
(
    NAME       = N'EsportsLeague_Stats',
    FILENAME   = N'C:\SQLData\EsportsLeague_Stats.ndf',
    SIZE       = 128MB,
    MAXSIZE    = 4GB,
    FILEGROWTH = 128MB
),
FILEGROUP FG_LOGS
(
    NAME       = N'EsportsLeague_Logs',
    FILENAME   = N'C:\SQLData\EsportsLeague_Logs.ndf',
    SIZE       = 256MB,
    MAXSIZE    = 10GB,
    FILEGROWTH = 256MB
)
LOG ON
(
    NAME       = N'EsportsLeague_Log',
    FILENAME   = N'C:\SQLData\EsportsLeague_Log.ldf',
    SIZE       = 64MB,
    MAXSIZE    = 2GB,
    FILEGROWTH = 64MB
);
GO

-- =============================================================================
-- DATABASE OPTIONS
-- =============================================================================

ALTER DATABASE EsportsLeague SET RECOVERY FULL;
ALTER DATABASE EsportsLeague SET READ_COMMITTED_SNAPSHOT ON;  -- row-level locking
ALTER DATABASE EsportsLeague SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE EsportsLeague SET COMPATIBILITY_LEVEL = 150;   -- SQL Server 2019
GO

-- =============================================================================
-- SCHEMAS  (logical namespacing for each domain)
-- dbo       → default / shared
-- comp      → competition core
-- ops       → business operations
-- audit     → audit & archiving
-- =============================================================================

USE EsportsLeague;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'comp')
    EXEC('CREATE SCHEMA comp');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit');
GO

PRINT 'Database EsportsLeague created successfully with filegroups and schemas.';
GO