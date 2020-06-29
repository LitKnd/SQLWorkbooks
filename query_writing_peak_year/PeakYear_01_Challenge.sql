/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tune-the-peak-years-procedure-sqlchallenge/


CHALLENGE FILE: ⛰ Peak Year
*****************************************************************************/


USE BabbyNames;
GO

--Create these indexes and constraint
--This took 2.5 minutes on my test instance

CREATE INDEX ix_FirstNameByBirthDate_2002_2017_FirstNameId
    on dbo.FirstNameByBirthDate_2002_2017 (FirstNameId);
GO
CREATE INDEX ix_FirstNameByBirthDate_2002_2017_Gender_FirstNameId
    on dbo.FirstNameByBirthDate_2002_2017 (Gender, FirstNameId);
GO
ALTER TABLE dbo.FirstNameByBirthDate_2002_2017 WITH CHECK 
    ADD CONSTRAINT ck_FirstNameByBirthDate_2002_2017_Gender 
    CHECK (Gender In ('M','F'));
GO

--Create this procedure (super fast)
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
    WHERE 
        fn.FirstName = @FirstName1 or 
        fn.FirstName = @FirstName2 or 
        fn.FirstName = @FirstName3
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


/*****************************************************************************
✨ CHALLENGE ✨

Improve the performance of this query by changing the TSQL only

    * Do not change indexes
    * Measure the performance using the two sample execution statements below

*****************************************************************************/
SET STATISTICS IO, TIME ON;
GO

EXEC dbo.PeakYear 'John', 'Jacob', 'Mary' WITH RECOMPILE;
GO
/* 
  CPU time = 2656 ms,  elapsed time = 2655 ms.
*/


EXEC dbo.PeakYear 'Kendra', 'Mister', 'Stormy' WITH RECOMPILE;
GO

/* 
CPU time = 156 ms, elapsed time = 173 ms. 
 */