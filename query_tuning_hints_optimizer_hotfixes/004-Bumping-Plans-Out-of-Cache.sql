/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/query-tuning-with-hints-optimizer-hotfixes

*****************************************************************************/


RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO

/**********************************************************
Setup 
**********************************************************/
USE BabbyNames;
GO

DROP PROCEDURE IF EXISTS dbo.MostPopularYearByName
GO
CREATE PROCEDURE dbo.MostPopularYearByName
    @FirstName  varchar(255)
AS
    SET NOCOUNT ON;

    SELECT TOP 1 
        NameCount
    FROM agg.FirstNameByYear AS fnby
    JOIN ref.FirstName AS fn on 
        fnby.FirstNameId = fn.FirstNameId
    WHERE fn.FirstName = @FirstName
    ORDER BY NameCount DESC;
GO

EXEC dbo.MostPopularYearByName @FirstName = 'Kendra';
GO 10




/**********************************************************
Demo
**********************************************************/

/* Bump a plan for an individual query. 
You can give this a plan_handle or a sql_handle  */
SELECT
    qs.plan_handle,
    qs.sql_handle,
    (SELECT SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END 
            - qs.statement_start_offset)/2) + 1) FOR XML PATH(''),TYPE) AS [query_text],
    qs.execution_count,
    qs.total_worker_time,
    qs.total_logical_reads,
    qs.total_elapsed_time,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text (plan_handle) as st
CROSS APPLY sys.dm_exec_query_plan (plan_handle) AS qp
WHERE st.text like '%fnby.FirstNameId = fn.FirstNameId
    WHERE fn.FirstName = @FirstName
    ORDER BY NameCount DESC;%'
    OPTION (RECOMPILE);
GO

DBCC FREEPROCCACHE (0x0500070012A0AF62C082800B2800000001000000000000000000000000000000000000000000000000000000);
GO

/* Now re-run the query: poof! */




/* You can use the sp_recompile procedure to clear multiple plans from the cache
Warning: this requires a lock on the object you're running against!
    I've caused blocking by running this against a table.
*/
EXEC sp_recompile 'dbo.MostPopularYearByName'
GO





/* You can clear plan from a resource governor pool */
SELECT * 
FROM sys.dm_resource_governor_resource_pools;
GO
/* I don't have any configured, and default is pretty big... */
DBCC FREEPROCCACHE ('default');
GO




/* You can neatly clear the cache for the current database in 2016+ */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO





/* On older versions of SQL Server, you can do this with a DBCC command, but
you have to look up the database id. */
SELECT DB_ID();
GO
DBCC FLUSHPROCINDB(7);
GO 





/* The "nuclear" option.
This clears the whole cache for the instance */
DBCC FREEPROCCACHE;
GO




/* There's even more ways to do this out there like DBCC FREESYSTEMCACHE,
but what I've shown here is usually more than enough for me! */