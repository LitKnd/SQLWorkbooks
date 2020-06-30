/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/************************************************************ 
What should my cost threshold be?

Start with: What are my query costs, and how long do my queries take?
************************************************************/


/* The default value of 5 is SUPER low */
exec sp_configure 'cost threshold for parallelism', 50;
GO
RECONFIGURE
GO

/* 
We can view queries and plans for our top queries by CPU 
This queries the execution plan cache
*/
SELECT TOP 20
	(SELECT CAST(SUBSTRING(st.text, (qs.statement_start_offset/2)+1,   
		((CASE qs.statement_end_offset  
			WHEN -1 THEN DATALENGTH(st.text)  
			ELSE qs.statement_end_offset  
			END
		- qs.statement_start_offset)/2) + 1) AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    CAST(qs.total_worker_time/1000./1000. AS numeric(30,1)) AS [cpu sec],
    qs.execution_count AS [# executions],
    qs.last_dop /* 2016+ */,
    qs.min_dop /* 2016 + */,
    qs.max_dop /* 2016+ */,
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_worker_time / execution_count / 1000. / 1000. AS numeric(30,1))
		END AS [avg cpu sec],
    CAST(qs.total_elapsed_time/1000./1000. AS numeric(30,1)) AS [elapsed sec],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_elapsed_time / execution_count / 1000. / 1000. AS numeric(30,1))
		END AS [avg elapsed sec],
    qs.total_logical_reads as [logical reads],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_logical_reads / execution_count AS numeric(30,1))
	END AS [avg logical reads],
	qs.total_physical_reads as [physical reads],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_physical_reads / execution_count AS numeric(30,1))
	END AS [avg physical reads],
	qs.total_logical_writes as [writes],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_logical_writes / execution_count AS numeric(30,1))
	END AS [avg logical writes],
    qp.query_plan AS [query execution plan]
FROM sys.dm_exec_query_stats AS qs
OUTER APPLY sys.dm_exec_sql_text (plan_handle) as st
OUTER APPLY sys.dm_exec_query_plan (plan_handle) AS qp
ORDER BY qs.total_worker_time DESC
OPTION (RECOMPILE);
GO


/* 
More free queries for the plan cache for different versions of SQL Server are available from 
Glenn Berry of SQL Skills: https://www.sqlskills.com/blogs/glenn/category/dmv-queries/


Want to use procedures?
A free procedure to query the plan cache: sp_BlitzCache, from Brent Ozar Unlimited
https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/releases
*/


exec sp_BlitzCache;
GO


exec sp_BlitzCache @Help=1;
GO

exec sp_BlitzCache @HideSummary=1
GO


/* What about Query Store? 
You'd think we'd have a column in one of the Query Store DMVs for this, but we don't.

I thought I was crazy, but Grant Fritchey found the same thing --
    https://www.scarydba.com/2017/02/20/estimated-costs-queries/

*/


exec sp_BlitzQueryStore @Help = 1;
GO

exec sp_BlitzQueryStore @DatabaseName='BabbyNames';
GO