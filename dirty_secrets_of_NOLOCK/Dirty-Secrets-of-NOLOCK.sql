/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

Setup:
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.1

Then review and run the script below on a SQL Server 2016 dedicated test instance
    Developer Edition recommended (Enteprise and Evaluation Editions will work too)

Note: Before live demo, set up the temp tables for the Allocation Order Scans demo 
    (#readcommitted, #tablock, and #dirty)
	
*****************************************************************************/

/* Doorstop */
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

USE BabbyNames;
GO




/****************************************************
PART I: DIRTY SECRETS

1st rule of NOLOCK: Dirty reads      
****************************************************/


/*
--Our application is going haywire
--It's attempting some updates but they're getting rolled back
--Uncomment this and run it in another session
*/

--USE BabbyNames;
--GO
--SET NOCOUNT ON;
--GO

--BEGIN TRAN

--UPDATE ref.FirstName SET TotalNameCount = TotalNameCount + 200 WHERE FirstName='Kendra';
--UPDATE ref.FirstName SET TotalNameCount = TotalNameCount + 25 WHERE FirstName='Stormy';
--UPDATE ref.FirstName SET TotalNameCount = TotalNameCount + 4 WHERE FirstName='Mister';

--ROLLBACK

--GO 100000


/* Now sum the TotalNameCount repeatedly */
/* Make sure actual plans are off :) */
DROP TABLE IF EXISTS #NameCount;
GO
CREATE TABLE #NameCount ( SumTotalNameCount int);
GO
DECLARE @start datetime2(7) = SYSDATETIME();
DECLARE @i int = 1
WHILE @i <= 200
BEGIN
    INSERT #NameCount (SumTotalNameCount)
    SELECT SUM(TotalNameCount) AS SumTotalNameCount
    FROM ref.FirstName;

    SET @i = @i + 1;
END
DECLARE @end datetime2(7) = SYSDATETIME();
SELECT DATEDIFF(ss,@start, @end) as duration_seconds;
GO


--Look at Resource Waits in activity monitor while it's running
--How long did it take to do the counts? 
    --Sample time: 16 to 17 seconds

--What data did we get?
SELECT SumTotalNameCount, COUNT(*) as counted
FROM #NameCount 
GROUP BY SumTotalNameCount;
GO


/* Someone suggests we hint our count to get rid of that wait */
DROP TABLE IF EXISTS #NameCount;
GO
CREATE TABLE #NameCount ( SumTotalNameCount int);
GO
DECLARE @start datetime2(7) = SYSDATETIME();
DECLARE @i int = 1
WHILE @i <= 200
BEGIN
    INSERT #NameCount (SumTotalNameCount)
    SELECT SUM(TotalNameCount) AS SumTotalNameCount
    FROM ref.FirstName WITH (NOLOCK) /* NOLOCK! */ ;

    SET @i = @i + 1;
END
DECLARE @end datetime2(7) = SYSDATETIME();
SELECT DATEDIFF(ss,@start, @end) as duration_seconds;
GO

--What do those waits look like again?
--How long did it take to do the count?
    --Sample time: 6 to 7 seconds


--What data did we get?
SELECT SumTotalNameCount, COUNT(*) as counted
FROM #NameCount 
GROUP BY SumTotalNameCount;
GO




/* What's an alternative? */
/* Look at the query execution plan */
SELECT SUM(TotalNameCount) AS SumTotalNameCount
FROM ref.FirstName;
GO






CREATE INDEX ix_FirstName_TotalNameCount
    on ref.FirstName (TotalNameCount);
GO


/*Review the plan change */
SELECT SUM(TotalNameCount) AS SumTotalNameCount
FROM ref.FirstName;
GO



/* The NOLOCK hint is GONE */
DROP TABLE IF EXISTS #NameCount;
GO
CREATE TABLE #NameCount ( SumTotalNameCount int);
GO
DECLARE @start datetime2(7) = SYSDATETIME();
DECLARE @i int = 1
WHILE @i <= 200
BEGIN
    INSERT #NameCount (SumTotalNameCount)
    SELECT SUM(TotalNameCount) AS SumTotalNameCount
    FROM ref.FirstName; /* <--- no hint here */

    SET @i = @i + 1;
END
DECLARE @end datetime2(7) = SYSDATETIME();
SELECT DATEDIFF(ss,@start, @end) as duration_seconds;
GO


--What do those waits look like?
--How long did it take to do the count?
    --Sample time: 7 seconds

--What data did we get?
SELECT SumTotalNameCount, COUNT(*) as counted
FROM #NameCount 
GROUP BY SumTotalNameCount;
GO



--Full disclosure: if we have the index AND use the NOLOCK hint:
--Duration is around 5 seconds
--BUT in that case our counts include data that never committed




/* Stop the updates... */





/****************************************************
PART I: DIRTY SECRETS

2nd secret of NOLOCK: 
    It can still be blocked and cause blocking.
    Even NOLOCK says YES to *some* locks!
****************************************************/

--Uncomment this and run it in another session

--BEGIN TRAN
--    ALTER INDEX ix_FirstName_TotalNameCount 
--    on ref.FirstName 
--    REBUILD
--    WITH (ONLINE=ON);

----ROLLBACK

SELECT TOP 1 *
FROM ref.FirstName WITH (NOLOCK);
GO


--In Activity Monitor, look at processes. What can you see?

--We can get more detail with Adam Machanic's free sp_WhoIsActive
--Download it at whoisactive.com
--In a third session, run:
exec sp_WhoIsActive @get_locks=1;
GO


--Roll back the index rebuild

--Back to the slides!











/****************************************************
PART II: POTENTIAL USES OF NOLOCK

****************************************************/


/* 
1. What queries in the plan cache use NOLOCK or READUNCOMMITTED? 
*/
with queries AS (
SELECT 
    qs.execution_count AS [# executions],
    total_worker_time as [worker time],   
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_worker_time / execution_count / 1000. / 1000. AS numeric(30,3))
		END AS [avg cpu sec],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_logical_reads / execution_count AS numeric(30,3))
	END AS [avg logical reads],
	qs.creation_time,
	LOWER(SUBSTRING(st.text, (qs.statement_start_offset/2)+1,   
		((CASE qs.statement_end_offset  
			WHEN -1 THEN DATALENGTH(st.text)  
			ELSE qs.statement_end_offset  
			END
		- qs.statement_start_offset)/2) + 1))  as query_text,
    qp.query_plan AS [plan]
FROM sys.dm_exec_query_stats AS qs
OUTER APPLY sys.dm_exec_sql_text (plan_handle) as st
OUTER APPLY sys.dm_exec_query_plan (plan_handle) AS qp
)
SELECT 
    (SELECT query_text  FOR XML PATH(''),TYPE) as [query],
    [# executions],
    [worker time],
    [avg cpu sec],
    [avg logical reads],
    creation_time,
    [plan]
FROM queries
WHERE query_text like '%nolock%'
    or query_text like '%uncommitted%'
ORDER BY [worker time] DESC
OPTION (RECOMPILE);
GO


/* I also use NOLOCK on administrative queries at times.

If it's OK if the data is wrong,
and it's important for me to lessen my impact,
I consider NOLOCK.

*/




/* 
2.  Allocation order scans

Allocation order scans are available for unordered scans under certain conditions

Note: this demo doesn't "prove" I used allocation scans - it just indicates it
I like the demo because it reminds us of something important:
    Order of results is not guaranteed unless you use an ORDER BY
*/


--This table has data going back to 1910
SELECT MIN(ReportYear) AS min_year
FROM agg.FirstNameByYearState;
GO

--The clustered index of the table leads on ReportYear
--In other words, the table is ordered by ReportYear first
exec sp_helpindex 'agg.FirstNameByYearState';
GO



--We're going to populate three temp tables with the data from the table
--I'm forcing them all to use just one thread to simplify things
--Note that NONE of the queries use an ORDER BY to populate


--This must follow the index b-tree
--That's because it's in READ COMMITTED, and does NOT have a TABLOCK hint
SELECT 
    ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as RowNum , 
    sys.fn_PhysLocFormatter (%%physloc%%) as physloc /* This is an undocumented command, it is SLOW and can BLOCK */,
    *
INTO #readcommitted
FROM agg.FirstNameByYearState
OPTION (MAXDOP 1)
GO


--This can use IAM (index allocation maps) to locate the pages
--That's because the TABLOCK hint prevents rows from moving around while we scan
SELECT 
    ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as RowNum , 
    sys.fn_PhysLocFormatter (%%physloc%%) as physloc /* This is an undocumented command, it is SLOW */, 
    *
INTO #tablock
FROM agg.FirstNameByYearState (TABLOCK)
OPTION (MAXDOP 1)
GO


--This can also use IAM (index allocation maps) to locate the pages
--That's because we've said we don't care if the data is garbage (in case things move)
SELECT 
    ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as RowNum , 
    sys.fn_PhysLocFormatter (%%physloc%%) as physloc /* This is an undocumented command, it is SLOW */,
    *
INTO #dirty
FROM agg.FirstNameByYearState (NOLOCK)
OPTION (MAXDOP 1)
GO




/* This returns distinct ReportYear and pagenum, ordered by RowNum.
This STRING_SPLIT hack is shameful, sorry ¯\_(ツ)_/¯ 
*/
SELECT  
    ReportYear, 
    value as pagenum, 
    MIN(RowNum) as RowNum
FROM #readcommitted
CROSS APPLY STRING_SPLIT (physloc, ':') 
WHERE value not like '(%' and value not like '%)'
GROUP BY ReportYear, value
ORDER BY MIN(RowNum);
GO
/* Read committed got pagenum 100800 first */


SELECT  
    ReportYear, 
    value as pagenum, 
    MIN(RowNum) as RowNum
FROM #tablock
CROSS APPLY STRING_SPLIT (physloc, ':') 
WHERE value not like '(%' and value not like '%)'
GROUP BY ReportYear, value
ORDER BY MIN(RowNum);
GO
/* TABLOCK got page 100768 first */


SELECT  
    ReportYear, 
    value as pagenum, 
    MIN(RowNum) as RowNum
FROM #dirty
CROSS APPLY STRING_SPLIT (physloc, ':') 
WHERE value not like '(%' and value not like '%)'
GROUP BY ReportYear, value
ORDER BY MIN(RowNum);
GO
/* NOLOCK got page 100768 first */



--TABLOCK and NOLOCK queries started here:
--(1:100768:0)

/* What are the IAM (index allocation map) pages for this CX? */
SELECT 
    allocated_page_file_id,
    page_level, 
    page_type,
    page_type_desc,
    allocated_page_page_id,
    previous_page_page_id,
    next_page_page_id
FROM sys.dm_db_database_page_allocations(
    DB_ID(), 
    OBJECT_ID('agg.FirstNameByYearState'), 
    1 ,
    NULL, 
    'detailed')
WHERE 
    is_allocated=1
    and page_type = 10 /* IAM pages */
ORDER BY 1, 2 DESC, 3, 4
GO


/* DBCC PAGE is very well known,
but is also not officially documented. Handle with care. */
DBCC TRACEON(3604);
GO

/*         Database    File# Page# DumpStyle*/
DBCC PAGE ('BabbyNames', 1, 522, 3);
GO



/* Want more details on Allocation Order Scans?
See Paul White's excellent article here:
https://sqlperformance.com/2015/01/t-sql-queries/allocation-order-scans
*/

DROP TABLE IF EXISTS #readcommitted;
GO
DROP TABLE IF EXISTS #tablock;
GO
DROP TABLE IF EXISTS #dirty;
GO

