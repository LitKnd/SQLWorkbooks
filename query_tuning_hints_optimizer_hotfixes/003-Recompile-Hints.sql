/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/query-tuning-with-hints-optimizer-hotfixes

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO

USE BabbyNames;
GO

/* Setup................................................ */
/* WARNING: this clears the ENTIRE execution plan cache  */
DBCC FREEPROCCACHE;
GO
/* ..................................................... */



/* We're going to watch the performance of the same code:
    1) With a RECOMPILE hint on a statement
    2) With a RECOMPILE hint in the header of the procedure
    3) With no RECOMPILE hint
*/


DROP PROCEDURE IF EXISTS dbo.MostPopularYearByNameRecompileHint
GO
CREATE PROCEDURE dbo.MostPopularYearByNameRecompileHint
    @FirstName  varchar(255)
AS
    SET NOCOUNT ON;

    SELECT TOP 1 
        NameCount
    FROM agg.FirstNameByYear AS fnby
    JOIN ref.FirstName AS fn on 
        fnby.FirstNameId = fn.FirstNameId
    WHERE fn.FirstName = @FirstName
    ORDER BY NameCount DESC
        OPTION (RECOMPILE);
GO

DROP PROCEDURE IF EXISTS dbo.MostPopularYearByNameRecompileInHeader
GO
CREATE PROCEDURE dbo.MostPopularYearByNameRecompileInHeader
    @FirstName  varchar(255)
    WITH RECOMPILE
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



/* 
We're going to run each procedure from powershell 500 times from one thread.
    The posh script doesn't do anything with the procedure results, just measures
    the time it takes to run the procedure 500 times.

Open perfmon.exe and show the following counters:
    SQL Server: SQL Statistics  Batch Requests/sec
    SQL Server: SQL Statistics  SQL Compilations/sec
    SQL Server: SQL Statistics  SQL Re-Compilations/sec

In powershell, run 005-Recompile-Hints.ps1
*/

/* What can we see about performance in SQL Server's DMVs? */
/* sys.dm_exec_query_stats has info on performance for queries that
are currently in the execution plan cache. */
SELECT
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
WHERE st.text like '%MostPopularYearByName%'
    OPTION (RECOMPILE);
GO


/* sys.dm_exec_procedure_stats has information for performance
on stored procedures that are currently in the execution plan cache */
SELECT
    st.text as procedure_text,
    ps.execution_count,
    ps.total_worker_time,
    ps.total_logical_reads,
    ps.total_elapsed_time,
    qp.query_plan
FROM sys.dm_exec_procedure_stats AS ps
CROSS APPLY sys.dm_exec_sql_text (plan_handle) as st
CROSS APPLY sys.dm_exec_query_plan (plan_handle) AS qp
JOIN sys.objects as so on ps.object_id = so.object_id
WHERE so.name like 'MostPopularYearByName%'
    OPTION (RECOMPILE);
GO


