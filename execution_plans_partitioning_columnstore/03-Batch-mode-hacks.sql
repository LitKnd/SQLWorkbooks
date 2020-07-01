/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: 
https://littlekendra.com/course/the-weird-wonderful-world-of-execution-plans-partitioned-tables-columnstore-indexes

*****************************************************************************/


RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

use BabbyNames;
GO

/* We have a nonclustered index on agg.FirstNameByYearState */
IF 0 = (SELECT COUNT(*) FROM 
    sys.indexes 
    WHERE name='ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES') 

CREATE INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
        (FirstNameId, StateCode, Gender, ReportYear)
        INCLUDE (NameCount)
GO


/* Create this procedure.
I'm not saying this is great code. It was written purposefully to have some issues :) */
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
    ORDER BY ReportYear DESC, StateCode;
GO


/*****************************************************
Run this with actual execution plans on. Save the plan.
*****************************************************/
SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNames @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO
/* Even when the data is in memory, this takes about a minute:
	(191 row(s) affected)
	Table 'FirstName'. Scan count 0, logical reads 382, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
	Table 'Worktable'. Scan count 6052350, logical reads 34458102, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
	Table 'FirstNameByYearState'. Scan count 1, logical reads 14960, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
	 SQL Server Execution Times:
	   CPU time = 58296 ms,  elapsed time = 60087 ms.
*/


/* Now create this columnstore index. Yes, this is goofy. */
CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_agg_FirstNameByYearState 
ON agg.FirstNameByYearState
    (StateCode);
GO


/* Run this with actual execution plans on. Save the plan and compare */
SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNames @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO

/*
(191 row(s) affected)
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
Table 'FirstName'. Scan count 0, logical reads 382, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
Table 'FirstNameByYearState'. Scan count 1, logical reads 14960, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
 SQL Server Execution Times:
   CPU time = 2157 ms,  elapsed time = 2164 ms.
*/


/* Why is it so much faster even though it's NOT USING THE COLUMNSTORE INDEX? */



/* The query isn't using the columnstore index. What if we use the same query, but
add a hint to make sure it CAN'T use the columnstore? */
DROP PROCEDURE IF EXISTS dbo.PopularNamesWithAHint
GO
CREATE PROCEDURE dbo.PopularNamesWithAHint
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
		OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO

SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNamesWithAHint @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO


/* Niko Neugebauer points out that in some cases this is a regression from behavior in 2014, if 
you were using an index hint. 
He points out that you can get the old functionality back if you're using hints in some cases by
lowering the compat level on the database to 120, but he also warns that will make you miss out on 
many IMPROVEMENTS in batch mode execution that you get from 2016/compat mode 130.
In our case the batch mode windowing function that is part of what makes this fast is specific to 2016.
*/


/* Drop our goofy columnstore */
DROP INDEX nccx_agg_FirstNameByYearState ON agg.FirstNameByYearState;
GO

/* Create an even GOOFIER columnstore */
/* I learned about this hack from Itzik Ben-Gan */
/* Filtered columnstore indexes are 2016+ */
CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_agg_FirstNameByYearState 
ON agg.FirstNameByYearState
    (FirstNameId)
WHERE FirstNameId = -1 and FirstNameId = -2;
GO

/* It's really empty */
select  ips.row_count, ips.reserved_page_count
from sys.dm_db_partition_stats ips
join sys.indexes as si on
	ips.object_id=si.object_id and
	ips.index_id = si.index_id
join sys.objects as so on 
	ips.object_id=so.object_id
where so.name='FirstNameByYearState'
and si.name='nccx_agg_FirstNameByYearState';
GO

SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNames @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO
/* Yep, that worked all right. */
DROP INDEX nccx_agg_FirstNameByYearState ON agg.FirstNameByYearState
GO


/* Here's another hack: a bogus join to a table with columnstore. 
Itzik Ben-Gan wrote that he learned about this from Niko Neugebauer.
I've also seen Paul White use this in a Stack Overflow answer from 2014.
This method doesn't require SQL Server 2016.
*/

CREATE TABLE dbo.hack (i int identity);
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_hack on dbo.hack(i);
GO


DROP PROCEDURE IF EXISTS dbo.PopularNamesWithABogusJoin
GO
CREATE PROCEDURE dbo.PopularNamesWithABogusJoin
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

	/* LOL */
	LEFT JOIN dbo.hack on 1=0
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
GO

SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNamesWithABogusJoin @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO



/* Can we use the bogus join method with a temp table?
*/
CREATE TABLE #hack (i int identity);
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_hack on #hack(i);
GO

DROP PROCEDURE IF EXISTS dbo.PopularNamesWithABogusJoinToATempTable
GO
CREATE PROCEDURE dbo.PopularNamesWithABogusJoinToATempTable
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

	/* LOL */
	LEFT JOIN #hack on 1=0
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
GO

SET STATISTICS TIME, IO ON;
GO
EXEC dbo.PopularNamesWithABogusJoinToATempTable @Threshold = 100000
GO
SET STATISTICS TIME, IO OFF;
GO
