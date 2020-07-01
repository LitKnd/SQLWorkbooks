/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/indexing-for-windowing-functions/

Setup:
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.1
Then review and run the script below on a SQL Server 2016 dedicated test instance
    Developer Edition recommended (Enteprise and Evaluation Editions will work too)
	
*****************************************************************************/


RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
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

ALTER DATABASE BabbyNames SET QUERY_STORE = ON
GO
ALTER DATABASE BabbyNames SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO


EXEC sp_configure 'cost threshold for parallelism', 50;
GO
RECONFIGURE
GO


ALTER DATABASE BabbyNames SET COMPATIBILITY_LEVEL = 140;
GO



/****************************************************
Let's get window-y
****************************************************/


USE BabbyNames;
GO

/* This code is a mess. Like real code often is :)
For example, not all the predicates in this query are needed.
In this session we are trying to tune this with as few code
changes as possible, focusing on indexes primarily. */
DROP PROCEDURE IF EXISTS dbo.PopularNames
GO
CREATE PROCEDURE dbo.PopularNames
    @Threshold INT = NULL
AS
    WITH RunningTotal AS (
	    SELECT
		    fnby.FirstNameId,
            fnby.StateCode,
            fnby.Gender,
		    ReportYear,
		    SUM(NameCount) OVER (
                PARTITION BY fnby.FirstNameId, StateCode, Gender 
                ORDER BY fnby.ReportYear
              ) as TotalNamed
	    FROM agg.FirstNameByYearState as fnby
    ),
    RunningTotalPlusLag AS (
	    SELECT
		    FirstNameId,
            StateCode,
            Gender,
		    ReportYear,
		    TotalNamed,
		    LAG(TotalNamed, 1, 0) OVER (
                PARTITION BY FirstNameId, StateCode, Gender 
                ORDER BY ReportYear
               ) AS TotalNamedPriorYear
	    FROM RunningTotal
    )
    SELECT
	    fn.FirstName,
        RunningTotalPlusLag.StateCode,
        RunningTotalPlusLag.Gender,
	    RunningTotalPlusLag.ReportYear,
	    RunningTotalPlusLag.TotalNamed,
	    RunningTotalPlusLag.TotalNamedPriorYear
    FROM RunningTotalPlusLag
    JOIN ref.FirstName as fn on
        RunningTotalPlusLag.FirstNameId=fn.FirstNameId
    WHERE 
        (@Threshold is NULL
         and TotalNamed >= 100 
	     and (TotalNamedPriorYear < 100  OR TotalNamedPriorYear IS NULL)
        )
        OR
        (TotalNamed >= @Threshold 
	    and (TotalNamedPriorYear < @Threshold  OR TotalNamedPriorYear IS NULL)
        )
    ORDER BY ReportYear DESC, StateCode;
GO



--Run with actual plan
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO

--Look at the SORT operator
--Can you find what it's sorting by in the query?

--Look at the output list rfrom the SORT operator
--as well. What is NOT being sorted?




/* Indexing for a windowing function -- rowstore index...
Itzik Ben-Gan recommends remembering this with the acronym
    "POC" 
        Partitioning (key)
        Ordering (key)
        Covering (includes - that stuff that wasn't being sorted)

http://www.itprotoday.com/microsoft-sql-server/sql-server-2012-how-write-t-sql-window-functions-part-3


Our window function:
		    SUM(NameCount) OVER (PARTITION BY fnby.FirstNameId, StateCode, Gender ORDER BY fnby.ReportYear) as TotalNamed
        P = FirstNameId, StateCode, Gender (keys)
        O = ReportYear (key)
        C = NameCount (include)

*/
    
CREATE INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
        (FirstNameId, StateCode, Gender, ReportYear)
        INCLUDE (NameCount)
GO


/* Run with actual plan.*/
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO


/* 
Does it use the index? 

Is the SORT operator still there prior to the window spool? 

But this isn't super fast. 

Look at the actual time statistics in the operator properties in the actual execution plan. 
Where are we spending the time? */





/****************************************************
What about an indexed view?
****************************************************/

IF OBJECT_ID('dbo.indexedviewattempt') IS NULL
	EXEC('CREATE VIEW dbo.indexedviewattempt AS SELECT 1 AS COL1')
GO
/* SCHEMABINDING is required to index this after it is created */
ALTER VIEW dbo.indexedviewattempt
WITH SCHEMABINDING
AS
SELECT
    FirstNameId, 
    StateCode, 
    Gender, 
    ReportYear,
	SUM(NameCount) as TotalNamed,
    COUNT_BIG(*) as RequiredCountBig
FROM agg.FirstNameByYearState 
GROUP BY 
    FirstNameId, 
    StateCode, 
    Gender,
    ReportYear
GO

CREATE UNIQUE CLUSTERED INDEX cx_indexedviewattempt on
    dbo.indexedviewattempt (FirstNameId, StateCode, Gender, ReportYear);
GO



/* Look at estimated plan. Does it used the indexed view? */
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO



ALTER INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
    DISABLE;
GO


/* Run with actual plan enabled */
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO



/* Does it use the indexed view?
Note: automatic view matching is an Enterprise feature

Look at the actual time statistics in the operator properties in the actual execution plan. 
Where are we spending the time now?
*/


DROP INDEX IF EXISTS cx_indexedviewattempt on dbo.indexedviewattempt;
GO

DROP VIEW IF EXISTS dbo.indexedviewattempt;
GO



ALTER INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
    REBUILD;
GO



/****************************************************
Columnstore
****************************************************/


CREATE NONCLUSTERED COLUMNSTORE INDEX 
    nccx_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_NameCount
 on agg.FirstNameByYearState (FirstNameId, StateCode, Gender, ReportYear, NameCount);
GO


/* Run with actual plan.*/
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO
/* Look at the plan.
    Note that we get batch mode on SOME operators - the filter, hash match, sort.
    But we're still using the rowstore indexes and old window function operators
*/




/* What if I didn't have the nonclustered rowstore? */
DROP INDEX IF EXISTS ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState;
GO




/* Run with actual plan.
    Now this is different!
    The sort operator is back
    We have two Window Aggregate operators and they are parallel.*/
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO


/* Can we get the Window Aggregate operator without a "real" columnstore index? */
DROP INDEX IF EXISTS nccx_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_NameCount
    ON agg.FirstNameByYearState;
GO


/* Filtered NCCX so we can get batch mode & Window Aggregate operator,
no usable nonclustered indexes */
CREATE NONCLUSTERED COLUMNSTORE INDEX 
    nccx_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_NameCount
 on agg.FirstNameByYearState (FirstNameId, StateCode, Gender, ReportYear, NameCount)
 WHERE ( FirstNameId = -1 and FirstNameId = -2 );
GO


EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO


/* Recreate the covering rowstore index */
CREATE INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
        (FirstNameId, StateCode, Gender, ReportYear)
        INCLUDE (NameCount)
GO

/* Look at estimated plan */
EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO

/* No more window aggregate operator, we are back to row mode window spool. 
So much for my hack! */


/* What if I use a different threshold? */
EXEC dbo.PopularNames @Threshold = 1000 WITH RECOMPILE;
GO

/* Compare these two plans (estimate) */
EXEC dbo.PopularNames @Threshold = 689 WITH RECOMPILE;
GO

EXEC dbo.PopularNames @Threshold = 690 WITH RECOMPILE;
GO



/* Let's add a hint! */
DROP PROCEDURE IF EXISTS dbo.PopularNames
GO
CREATE PROCEDURE dbo.PopularNames
    @Threshold INT = NULL
AS
    with RunningTotal AS (
	    SELECT
		    fnby.FirstNameId,
            fnby.StateCode,
            fnby.Gender,
		    ReportYear,
		    SUM(NameCount) OVER (PARTITION BY fnby.FirstNameId, StateCode, Gender ORDER BY fnby.ReportYear) as TotalNamed
	    FROM agg.FirstNameByYearState as fnby
    ),
    RunningTotalPlusLag AS (
	    SELECT
		    FirstNameId,
            StateCode,
            Gender,
		    ReportYear,
		    TotalNamed,
		    LAG(TotalNamed, 1, 0) OVER (PARTITION BY FirstNameId, StateCode, Gender ORDER BY ReportYear) AS TotalNamedPriorYear
	    FROM RunningTotal
    )
    SELECT
	    fn.FirstName,
        RunningTotalPlusLag.StateCode,
        RunningTotalPlusLag.Gender,
	    RunningTotalPlusLag.ReportYear,
	    RunningTotalPlusLag.TotalNamed,
	    RunningTotalPlusLag.TotalNamedPriorYear
    FROM RunningTotalPlusLag
    JOIN ref.FirstName as fn on
        RunningTotalPlusLag.FirstNameId=fn.FirstNameId
    WHERE 
        (@Threshold is NULL
         and TotalNamed >= 100 
	     and (TotalNamedPriorYear < 100  OR TotalNamedPriorYear IS NULL)
        )
        OR
        (TotalNamed >= @Threshold 
	    and (TotalNamedPriorYear < @Threshold  OR TotalNamedPriorYear IS NULL)
        )
    ORDER BY ReportYear DESC, StateCode
    OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION')) 
    /* MAXDOP 1 gets the Window Aggregate operator in this case, but you lose parallelism of course */;
GO


SELECT * FROM sys.dm_exec_valid_use_hints;
GO


EXEC dbo.PopularNames @Threshold = 500 WITH RECOMPILE;
GO

EXEC dbo.PopularNames @Threshold = 1 WITH RECOMPILE;
GO

EXEC dbo.PopularNames @Threshold = 1000 WITH RECOMPILE;
GO


/****************************************************
Cleanup
****************************************************/
DROP INDEX IF EXISTS ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState;
GO

DROP INDEX IF EXISTS nccx_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_NameCount
    ON agg.FirstNameByYearState;
GO








/*****************************************************
EXTRA
*****************************************************/

--Someone always asks why RunningTotalPlusLag is its own CTE
--It's natural to be suspicious of the second CTE and blame it for being slow

--Simplified code, removed from procedure

-- Many people want to move LAG up into the first CTE...
-- But there's a problem! We're SUMming name count
-- And we want the LAG of the SUM
-- Try to run this and you get...
-- Invalid column name 'TotalNamed'.
WITH RunningTotal AS (
	SELECT
		fnby.FirstNameId,
        fnby.StateCode,
        fnby.Gender,
		ReportYear,
		SUM(NameCount) OVER (
            PARTITION BY fnby.FirstNameId, StateCode, Gender 
            ORDER BY fnby.ReportYear
            ) as TotalNamed,
		LAG(TotalNamed, 1, 0) OVER (
            PARTITION BY FirstNameId, StateCode, Gender 
            ORDER BY ReportYear
            ) AS TotalNamedPriorYear
	FROM agg.FirstNameByYearState as fnby
)
SELECT TOP 10 *
FROM RunningTotal;
GO

--If you try to nest the windowing function, then you get...
--Windowed functions cannot be used in the context of another windowed function or aggregate.
--(Not that this would be more readable, I think the CTEs are more clear, personally)
WITH RunningTotal AS (
	SELECT
		fnby.FirstNameId,
        fnby.StateCode,
        fnby.Gender,
		ReportYear,
		SUM(NameCount) OVER (
            PARTITION BY fnby.FirstNameId, StateCode, Gender 
            ORDER BY fnby.ReportYear
            ) as TotalNamed,
		LAG(
            	SUM(NameCount) OVER (
                PARTITION BY fnby.FirstNameId, StateCode, Gender 
                ORDER BY fnby.ReportYear
                )
                , 1, 0) OVER (
            PARTITION BY FirstNameId, StateCode, Gender 
            ORDER BY ReportYear
            ) AS TotalNamedPriorYear
	FROM agg.FirstNameByYearState as fnby
)
SELECT TOP 10 *
FROM RunningTotal;
GO

--Is it really LAG slowing us down?
--Run with actual plans
--And even without the lag, by the Window Spool operator
--here, we're already at ~18 seconds elapsed

SELECT * 
FROM (
    SELECT
	    fnby.FirstNameId,
        fnby.StateCode,
        fnby.Gender,
	    ReportYear,
	    SUM(NameCount) OVER (
            PARTITION BY fnby.FirstNameId, StateCode, Gender 
            ORDER BY fnby.ReportYear
            ) as TotalNamed
    FROM agg.FirstNameByYearState as fnby
) as x
WHERE TotalNamed > 300000;
GO
