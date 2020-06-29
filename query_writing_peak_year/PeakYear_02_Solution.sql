/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tune-the-peak-years-procedure-sqlchallenge/


SOLUTION FILE: ⛰ Peak Year
*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR ( N'Did you mean to run the whole thing?', 20, 1 ) WITH LOG ;
GO

/*****************************************************************************
✨ SAMPLE SOLUTIONS✨

*****************************************************************************/

USE BabbyNames;
GO

SET STATISTICS IO, TIME ON;
GO


/*****************************************************************************
🔎 ORIGINAL SELECT QUERY - Analyze...
*****************************************************************************/

--How many key lookups is it doing, vs what it thinks it will do?

EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO


/*****************************************************************************
TEST : Make Gender, FirstNameId seekable
*****************************************************************************/

--Does this seek? ('M' only)
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycount AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    WHERE /* CHANGES BELOW HERE */
        fnbd.Gender = 'M' and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrank AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycount
)
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrank
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO

EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO



--Does this seek? ('M' or 'F')
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycount AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    WHERE /* CHANGES BELOW HERE */
        fnbd.Gender IN ('M','F') and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrank AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycount
)
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrank
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO


EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO



--Does this seek? ('M' or 'F'), FORCESEEK
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycount AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd WITH (FORCESEEK) /* CHANGE HERE */
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    WHERE /* CHANGES BELOW HERE */
        fnbd.Gender IN ('M','F') and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrank AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycount
)
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrank
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO

EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO


--Separate CTEs for each gender...
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycountm AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    WHERE /* CHANGES BELOW HERE */
        fnbd.Gender = 'M' and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrankm AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycountm
), mycountf AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    WHERE /* CHANGES BELOW HERE */
        fnbd.Gender = 'F' and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrankf AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycountf
)

SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrankm
WHERE YearRanked = 1
UNION ALL
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrankf
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO


EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO





/*****************************************************************************
SAMPLE SOLUTION : Make Gender, FirstNameId seekable in a different way
*****************************************************************************/

--Let's put the available gender values into a set using a value constructor
--Here's what that looks like by itself
SELECT * FROM  (VALUES ('M'), ('F') ) as v(g)
GO

--Now let's CROSS APPLY that
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycount AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    /* CHANGES BELOW HERE */
    CROSS APPLY ( VALUES ('M'), ('F') ) as v(g)
    WHERE 
        fnbd.Gender = v.g and
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrank AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycount
)
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrank
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO


EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO


--This could also be written with the table value constructor being used as a derived table
--With an inner join
CREATE OR ALTER PROC dbo.PeakYear 
    @FirstName1 VARCHAR(255),
    @FirstName2 VARCHAR(255),
    @FirstName3 VARCHAR(255)
AS

WITH mycount AS (
    SELECT
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear,
        COUNT_BIG(*) as NumberBorn
    FROM dbo.FirstNameByBirthDate_2002_2017 as fnbd
    JOIN ref.FirstName as fn on 
        fn.FirstNameId = fnbd.FirstNameId
    /* CHANGES BELOW HERE */
    JOIN (SELECT * FROM  (VALUES ('M'), ('F') ) as v(g) ) AS x ON 
        fnbd.Gender = x.g 
    WHERE 
        fn.FirstName IN ( @FirstName1, @FirstName2, @FirstName3 )
         /* CHANGES ABOVE HERE */
    GROUP BY
        fn.FirstName,
        fnbd.Gender,
        fnbd.BirthYear
), yearrank AS (
    SELECT
        FirstName,
        Gender,
        BirthYear as PeakYear,
        NumberBorn,
        RANK () OVER ( partition by FirstName, Gender ORDER BY NumberBorn desc ) as YearRanked
    FROM mycount
)
SELECT FirstName, Gender, PeakYear, NumberBorn
FROM yearrank
WHERE YearRanked = 1
ORDER BY FirstName, Gender;
GO

EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO





/*****************************************************************************
💦 CLEANUP
*****************************************************************************/


DROP INDEX ix_FirstNameByBirthDate_2002_2017_FirstNameId
    on dbo.FirstNameByBirthDate_2002_2017;
GO
DROP INDEX ix_FirstNameByBirthDate_2002_2017_Gender_FirstNameId 
     on dbo.FirstNameByBirthDate_2002_2017;
GO   

ALTER TABLE dbo.FirstNameByBirthDate_2002_2017 
    DROP CONSTRAINT ck_FirstNameByBirthDate_2002_2017_Gender;
GO

DROP PROC IF EXISTS dbo.PeakYear;
GO
