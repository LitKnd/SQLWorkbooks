/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/


USE BabbyNames;
GO



IF (SELECT COUNT(*) FROM sys.indexes WHERE name='ix_lazynamer') = 0
    CREATE INDEX ix_lazynamer ON dbo.FirstNameByBirthDate_2000_2017 (FakeBirthDateStamp);
GO
IF (SELECT COUNT(*) FROM sys.indexes WHERE name='ix_FirstNameId') = 0
    CREATE INDEX ix_FirstNameId ON dbo.FirstNameByBirthDate_2000_2017 (FirstNameId) WHERE (FakeSystemCreateDateTime > '2015-01-01');
GO


IF (SELECT COUNT(*) FROM sys.indexes WHERE name='ix_FirstNameByYear_FirstNameId') = 0
    CREATE NONCLUSTERED INDEX ix_FirstNameByYear_FirstNameId ON agg.FirstNameByYear (FirstNameId ASC);
GO

/* Reset (makes it rerunnable) */
ALTER DATABASE BabbyNames SET QUERY_STORE CLEAR;
GO


CREATE OR ALTER PROCEDURE dbo.NameCountByGender
    @gender CHAR(1),
    @firstnameid INT
AS
    SET NOCOUNT ON;
    SELECT
        Gender,
        SUM(NameCount) as SumNameCount
    INTO #foo
    FROM agg.FirstNameByYear AS fact
    WHERE
        (Gender = @gender or @gender IS NULL)
        AND
        (FirstNameId = @firstnameid or @firstnameid IS NULL)
    GROUP BY Gender;
GO


/* ~10 seconds */
DECLARE @garbageint INT, @garbagedt2 DATETIME2(0), @garbagemax NVARCHAR(MAX)
SELECT
    @garbageint=fnbd.FirstNameId,
    @garbagedt2=fnbd.FakeBirthDateStamp,
    @garbagemax=fnbd.InevitableLOBColumn,
    @garbagemax=fnbd.FakeCreatedByUser
FROM dbo.FirstNameByBirthDate_2000_2017 AS fnbd
JOIN ref.FirstName AS fn ON fnbd.FirstNameId=fn.FirstNameId
WHERE fn.FirstName = 'Kendrella';
GO 1001


BEGIN TRAN
    UPDATE dbo.FirstNameByBirthDate_2000_2017
    SET FakeSystemCreateDateTime = GETDATE()
    WHERE FirstNameId=100111
    AND Gender='F';

ROLLBACK TRAN
GO 12

BEGIN TRAN
    UPDATE dbo.FirstNameByBirthDate_2000_2017
    SET FakeSystemCreateDateTime = GETDATE()
    WHERE FirstNameId=100111
    AND Gender='M' OPTION (RECOMPILE);

ROLLBACK TRAN
GO 10

/* 15 seconds */
BEGIN TRAN
    UPDATE dbo.FirstNameByBirthDate_2000_2017
    SET FakeSystemCreateDateTime = GETDATE()
    WHERE FirstNameId=100111;

ROLLBACK TRAN
GO 13


EXEC dbo.NameCountByGender @gender='M', @firstnameid=NULL;
GO 60

EXEC dbo.NameCountByGender @gender='M', @firstnameid=91864;
GO 30

IF OBJECT_ID('tempdb..#byebye') IS NOT NULL
    DROP TABLE #byebye;

SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
INTO #byebye
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';

GO 22

DECLARE @int INT, @gender CHAR(1)
SELECT
    @int=fact.ReportYear,
    @gender=fact.Gender,
    @int=fact.NameCount
FROM agg.FirstNameByYear AS fact
JOIN ref.FirstName AS dim
    ON fact.FirstNameId=dim.FirstNameId
WHERE
    fact.Gender = 'M' AND
    dim.FirstName = 'Sue';
GO 15

DECLARE @bin INT
SELECT
    @bin=COUNT(*)
FROM agg.FirstNameByYear AS fact
JOIN ref.FirstName AS dim
    ON fact.FirstNameId=dim.FirstNameId
WHERE
    fact.Gender = 'M';
GO 42

DECLARE @int INT, @gender CHAR(1)
SELECT
	@int=fact.ReportYear,
	@gender=fact.Gender
FROM agg.FirstNameByYear AS fact
JOIN ref.FirstName AS dim
	ON fact.FirstNameId=dim.FirstNameId
WHERE
	fact.Gender = 'M';
GO 21

IF OBJECT_ID('tempdb..#abyss') IS NOT NULL
    DROP TABLE #abyss;
SELECT
    NameCount
INTO #abyss
FROM agg.FirstNameByYear
WHERE FirstNameId = 12663
GO 71


IF OBJECT_ID('tempdb..#frequentnames') IS NOT NULL
    DROP TABLE #frequentnames;

SELECT
    FirstNameId
INTO #frequentnames
FROM agg.FirstNameByYear
WHERE NameCount > 100
GO 56

IF OBJECT_ID('tempdb..#byebye') IS NOT NULL
    DROP TABLE #byebye;

SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
INTO #byebye
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO 172

exec sp_recompile 'agg.FirstNameByYear';
GO

EXEC dbo.NameCountByGender @gender='M', @firstnameid=91864;
GO 207

EXEC dbo.NameCountByGender @gender='M', @firstnameid=NULL;
GO 12

DECLARE @bin INT
SELECT
    @bin=COUNT(*)
FROM agg.FirstNameByYear AS fact
JOIN ref.FirstName AS dim
    ON fact.FirstNameId=dim.FirstNameId
WHERE
    fact.Gender = 'Z';
GO 65

DECLARE @int INT, @gender CHAR(1)
SELECT
	@int=fact.ReportYear,
	@gender=fact.Gender
FROM agg.FirstNameByYear AS fact
JOIN ref.FirstName AS dim
	ON fact.FirstNameId=dim.FirstNameId
WHERE
	fact.Gender = 'M';
GO 25

IF OBJECT_ID('tempdb..#abyss') IS NOT NULL
    DROP TABLE #abyss;
SELECT
    NameCount
INTO #abyss
FROM agg.FirstNameByYear
WHERE FirstNameId = -1
GO 101
