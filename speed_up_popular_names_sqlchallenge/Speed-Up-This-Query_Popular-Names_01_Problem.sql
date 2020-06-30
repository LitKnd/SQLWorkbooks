/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-speed-up-the-popular-names-query/

This SQLChallenge uses the free BabbyNames sample database 
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.2

*****************************************************************************/

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/****************************************************
Restore database
****************************************************/
SET NOCOUNT ON;
GO
USE master;
GO

IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO

RESTORE DATABASE BabbyNames
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
        REPLACE,
        RECOVERY;
GO

USE BabbyNames;
GO


ALTER DATABASE BabbyNames SET COMPATIBILITY_LEVEL = 140;
GO

/*****************************************************************************
CHALLENGE: SPEED UP THE "POPULAR NAMES" QUERY

Rewrite the TSQL so the query uses less than 500 logical reads when run for 1991
Do not add/change any indexes, change only the TSQL
The query should produce the exact same result set after the rewrite
*****************************************************************************/

SET STATISTICS TIME, IO ON
GO

DECLARE @YearToRank INT = 1991;

with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	startyear.ReportYear + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	startyear.ReportYear - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	startyear.ReportYear - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	startyear.ReportYear + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = @YearToRank
	and startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender;
GO

SET STATISTICS TIME, IO OFF
GO


--Table 'FirstNameByYear'. Scan count 25, logical reads 26010, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'FirstName'. Scan count 5, logical reads 1414, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- SQL Server Execution Times:
--   CPU time = 13064 ms,  elapsed time = 4596 ms.