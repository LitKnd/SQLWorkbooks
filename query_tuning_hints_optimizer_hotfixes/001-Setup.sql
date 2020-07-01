/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/query-tuning-with-hints-optimizer-hotfixes

Setup:
    Download the database to restore from https://github.com/LitKnd/BabbyNames/releases/tag/v1.1
    You must download all four backup files with names like 'BabbyNames_Partitioning_1_of_4.bak.zip'.
    Unzip each file, then use them to restore the BabbyNames database (edit the restore command below).
    This database is 23GB after being restored.
    You must restore to SQL Server 2016 or a higher version.
*****************************************************************************/

--RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
--GO


/******************************************************/
/* Restore database                                   */
/******************************************************/
use master;
GO
IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames FROM 
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_1_of_4.bak', 
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_2_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_3_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_4_of_4.bak'
WITH REPLACE;
GO

/* SQL Server 2016+ */
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
GO

ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
GO

exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO

exec sp_configure 'max degree of parallelism', 4;
GO

RECONFIGURE
GO


USE BabbyNames;
GO


EXEC evt.logme N'Create agg.FirstNameByYearStateWide_Stage.';
GO
 
SELECT
    ISNULL(CAST(ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS bigint),0) AS Id,
    ReportYear,
    StateCode,
    FirstNameId,
    Gender,
    NameCount,
    REPLICATE ('foo',3) AS ReportColumn1,
    REPLICATE ('fo',3) AS ReportColumn2,
    REPLICATE ('fo',3) AS ReportColumn3,
    1014 AS ReportColumn4,
    REPLICATE ('moo',3) AS ReportColumn5,
    REPLICATE ('mo',3) AS ReportColumn6,
    REPLICATE ('m',300) AS ReportColumn7,
    1 AS ReportColumn8,
    15060902002 AS ReportColumn9,
    REPLICATE ('boo',300) AS ReportColumn10,
    REPLICATE ('bo',3) AS ReportColumn11,
    REPLICATE ('b',30) AS ReportColumn12,
    CAST('true' AS BIT) AS ReportColumn13,
    2000000000000 AS ReportColumn14,
    CAST ('2016-01-01' AS DATETIME2(7))  AS ReportColumn15,
    CAST ('2015-01-01' AS DATETIME2(7)) AS ReportColumn16,
    CAST ('2014-01-01' AS DATETIME2(7)) AS ReportColumn17,
    CAST ('2013-01-01' AS DATETIME2(7)) AS ReportColumn18,
    14 AS ReportColumn19,
    CAST ('You are such a creep to add a LOB column, Kendra' AS NVARCHAR(MAX)) AS ReportColumn20
INTO agg.FirstNameByYearStateWide_Stage
FROM agg.FirstNameByYearState;
GO
 
EXEC evt.logme N'Cluster agg.FirstNameByYearStateWide_Stage.';
GO
 
CREATE UNIQUE CLUSTERED INDEX cx_agg_FirstNameByYearStateWide_Stage
    ON agg.FirstNameByYearStateWide_Stage ( Id );
GO
 
EXEC evt.logme N'Create agg.FirstNameByYearStateWide, which has an identity property';
GO
 
CREATE TABLE agg.FirstNameByYearStateWide (
    Id bigint IDENTITY NOT NULL,
    ReportYear int NOT NULL,
    StateCode char(2) NOT NULL,
    FirstNameId int NOT NULL,
    Gender char(1) NOT NULL,
    NameCount int NOT NULL,
    ReportColumn1 varchar(9) NULL,
    ReportColumn2 varchar(6) NULL,
    ReportColumn3 varchar(6) NULL,
    ReportColumn4 int NOT NULL,
    ReportColumn5 varchar(9) NULL,
    ReportColumn6 varchar(6) NULL,
    ReportColumn7 varchar(300) NULL,
    ReportColumn8 int NOT NULL,
    ReportColumn9 numeric(11, 0) NOT NULL,
    ReportColumn10 varchar(900) NULL,
    ReportColumn11 varchar(6) NULL,
    ReportColumn12 varchar(30) NULL,
    ReportColumn13 bit NULL,
    ReportColumn14 numeric(13, 0) NOT NULL,
    ReportColumn15 datetime2(7) NULL,
    ReportColumn16 datetime2(7) NULL,
    ReportColumn17 datetime2(7) NULL,
    ReportColumn18 datetime2(7) NULL,
    ReportColumn19 int NOT NULL,
    ReportColumn20 nvarchar(max) NULL
);
GO
 
CREATE UNIQUE CLUSTERED INDEX cx_agg_FirstNameByYearStateWide
    ON agg.FirstNameByYearStateWide ( Id );
GO

EXEC evt.logme N'Switch data from stage';
GO
 
ALTER TABLE agg.FirstNameByYearStateWide_Stage SWITCH TO agg.FirstNameByYearStateWide;
GO
 
EXEC evt.logme N'Drop Stage';
GO
 
DROP TABLE agg.FirstNameByYearStateWide_Stage;
GO
 
EXEC evt.logme N'Reset the identity value';
GO
DBCC CHECKIDENT ('agg.FirstNameByYearStateWide');
GO

ALTER TABLE agg.FirstNameByYearStateWide
    ADD CONSTRAINT
    pk_FirstNameByYearStateWide
    PRIMARY KEY NONCLUSTERED (ReportYear, StateCode, Gender, FirstNameId)
GO


CREATE NONCLUSTERED INDEX ix_FirstNameByYearStateWide_ReportYear_StateCode_Gender_NameCount_Includes
ON agg.FirstNameByYearStateWide (ReportYear, StateCode, Gender, NameCount DESC) INCLUDE ( FirstNameId);
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX ccx_agg_FirstNameByYearStateWide 
ON agg.FirstNameByYearStateWide
    (Id, FirstNameId, ReportYear, StateCode, Gender, NameCount);
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX ccx_agg_FirstNameByYearState 
ON agg.FirstNameByYearState
    (FirstNameId, ReportYear, StateCode, Gender, NameCount);
GO
