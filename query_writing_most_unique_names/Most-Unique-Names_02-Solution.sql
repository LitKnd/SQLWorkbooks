/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/a-query-writing-sqlchallenge-the-most-unique-names/

SOLUTION FILE
	
*****************************************************************************/

USE BabbyNames;
GO


/*****************************************************************************
CHALLENGE 1

Write a query that returns
    The top 3 rows based upon
        The LOWEST "AvgUsePerName" for a given StateCode/ReportYear combo

Use only the agg.FirstNameByYearState table

Return the columns:
    StateCode
    ReportYear
    UniqueNames: the number of distinct names reported for that StateCode and ReportYear
    TotalNamed: the total number of babies reported named that for that StateCode and ReportYear
    AvgUsePerName: calculate as UniqueNames / TotalNamed
        Express result as NUMERIC (10,1) 

Order the results from LOWEST AvgUsePerNames to HIGHEST

Results should look like: 
StateCode	ReportYear	UniqueNames	TotalNamed	AvgUsePerName
----------------------------------------------------------------
NV	        1911	        13	        85	        6.5
NV	        1910	        10	        67	        6.7
AK	        1912	        20	        141	        7.1

*****************************************************************************/
SELECT TOP 3
       fnbys.StateCode,
       fnbys.ReportYear,
       COUNT(DISTINCT fnbys.FirstNameId) AS UniqueNames,
       SUM(fnbys.NameCount) AS TotalNamed,
       CAST( 1. *  SUM(fnbys.NameCount) / COUNT(DISTINCT fnbys.FirstNameId) AS NUMERIC(10, 1)) AS AvgUsePerName
FROM agg.FirstNameByYearState AS fnbys
GROUP BY fnbys.StateCode,
         fnbys.ReportYear
ORDER BY AvgUsePerName ASC;
GO




/*****************************************************************************
CHALLENGE 2
(This is similar to Challenge 1, but we don't care about ReportYear this time)

Write a query that returns
    The top 3 rows based upon
        The LOWEST "AvgUsePerName" for a given StateCode

Use only the agg.FirstNameByYearState table

Return the columns:
    StateCode
    UniqueNames: the number of distinct names reported for that StateCode over all years
    TotalNamed: the total number of babies reported named that for that StateCode over all years
    AvgUsePerName: calculate as UniqueNames / TotalNamed
        Express result as NUMERIC (10,1) 

Order the results from LOWEST AvgUsePerNames to HIGHEST

Results should look like: 
StateCode	UniqueNames	TotalNamed	AvgUsePerName
AK	            1620	    430161	    265.5
WY	            1559	    435016	    279.0
NV	            2976	    940408	    316.0

*****************************************************************************/

SELECT TOP 3
       fnbys.StateCode,
       COUNT(DISTINCT fnbys.FirstNameId) AS UniqueNames,
       SUM(fnbys.NameCount) AS TotalNamed,
       CAST(1. * SUM(fnbys.NameCount) / COUNT(DISTINCT fnbys.FirstNameId) AS NUMERIC(10, 1)) AS AvgUsePerName
FROM agg.FirstNameByYearState AS fnbys
GROUP BY fnbys.StateCode
ORDER BY AvgUsePerName ASC;
GO




/*****************************************************************************
CHALLENGE 3
(This builds on Challenge 2)

Write a query that returns
    For the ONE state with the LOWEST value for AvgUserPerName over ALL years
        One row for every name used in that state with the detail defined below

Use the agg.FirstNameByYearState table and ref.FirstName tables

Return the columns:
    StateCode: the StateCode who is detailed in the results
    TotalNamed: the total number of babies reported named that for that StateCode over all years
    FirstName

Order the results from 
    Lowest TotalNamed to highest
        Then alphabetically by FirstName from A to Z


Results should return 1620 rows total
The first three rows of the 1620 should look like:

StateCode	TotalNamed	FirstName
AK	            5	        Ace
AK	            5	        Ada
AK	            5	        Addyson
*****************************************************************************/


WITH mu
AS (SELECT TOP 1
           fnbys1.StateCode,
           /*
           COUNT(DISTINCT fnbys.FirstNameId) AS UniqueNames,
           SUM(fnbys.NameCount) AS TotalNamed,
           */
           CAST(1. * SUM(fnbys1.NameCount) / COUNT(DISTINCT fnbys1.FirstNameId) AS NUMERIC(10, 1)) AS AvgUsePerName
    FROM agg.FirstNameByYearState AS fnbys1
    GROUP BY fnbys1.StateCode
    ORDER BY AvgUsePerName ASC)
SELECT mu.StateCode,
       SUM(fnbys2.NameCount) AS TotalNamed,
       fn.FirstName
FROM mu
    JOIN agg.FirstNameByYearState AS fnbys2
        ON mu.StateCode = fnbys2.StateCode
    JOIN ref.FirstName AS fn
        ON fnbys2.FirstNameId = fn.FirstNameId
GROUP BY mu.StateCode,
         fn.FirstName
ORDER BY TotalNamed ASC,
         fn.FirstName ASC;
GO


/*****************************************************************************
CHALLENGE 4
(This is similar to Challenge 3, but instead of returning rows for the TOP 1 state, now
    you need to write a procedure that lets the user specified the desired dense_rank as a parameter)

Write a stored procedure named dbo.ChallengeFour
    Which takes a parameter, @denserank, a TINYINT

dbo.ChallengeFour calculates DENSE_RANK for each state
    Based on AvgUserPerName over ALL years for that state
        Lowest AvgUsePerName for a state has rank 1
        Next lowest has rank 2, etc
         Return one row for every name used in that state with the detail defined below
    DENSE_RANK documentation: https://docs.microsoft.com/en-us/sql/t-sql/functions/dense-rank-transact-sql

Use the agg.FirstNameByYearState table and ref.FirstName tables

Return the columns:
    StateCode: the StateCode who is detailed in the results
    TotalNamed: the total number of babies reported named that for that StateCode over all years
    FirstName

Order the results from 
    Lowest TotalNamed to highest
        Then alphabetically by FirstName from A to Z


When executed with...
    EXEC dbo.ChallengeFour @denserank = 2;

Results should return 1559 rows total
The first three rows of the 1559 rows should look like:

StateCode	TotalNamed	FirstName
WY	            5	    Abigale
WY	            5	    Abigayle
WY	            5	    Abraham

*****************************************************************************/
CREATE OR ALTER PROCEDURE dbo.ChallengeFour @denserank TINYINT
AS
BEGIN;

    WITH mu
    AS (SELECT fnbys.StateCode,
               CAST(1. * SUM(fnbys.NameCount) / COUNT(DISTINCT fnbys.FirstNameId) AS NUMERIC(10, 1)) AS AvgUsePerName
        FROM agg.FirstNameByYearState AS fnbys
        GROUP BY fnbys.StateCode),
         rk
    AS (SELECT StateCode,
               mu.AvgUsePerName,
               DENSE_RANK() OVER (ORDER BY mu.AvgUsePerName ASC) AS denserank
        FROM mu)
    SELECT rk.StateCode,
           SUM(fnbys.NameCount) AS TotalNamed,
           fn.FirstName
    FROM rk
        JOIN agg.FirstNameByYearState AS fnbys
            ON rk.StateCode = fnbys.StateCode
        JOIN ref.FirstName AS fn
            ON fnbys.FirstNameId = fn.FirstNameId
    WHERE   rk.denserank = @denserank
    GROUP BY rk.StateCode,
             fn.FirstName
    ORDER BY TotalNamed ASC,
             fn.FirstName ASC;

END;
GO

--Call for testing
EXEC dbo.ChallengeFour @denserank = 2;
GO
