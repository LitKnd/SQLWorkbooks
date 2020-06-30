/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decode-memory-pressure/


NOTE: This script is suitable only for dedicated test instances
Commands in this script will cause havoc and hurt performance
*****************************************************************************/

exec sp_configure 'optimize for ad hoc workloads', 0;
GO

RECONFIGURE
GO

exec sp_configure 'max server memory (MB)', 8000;
GO
RECONFIGURE
GO


DBCC FREEPROCCACHE;
GO


/* Size of single use adhoc plans in execution plan cache */
SELECT 
    objtype, 
    cacheobjtype, 
    COUNT(*) as number_plans,
    SUM(size_in_bytes)/1024./1024. as [MB] 
FROM sys.dm_exec_cached_plans   
WHERE usecounts = 1
    and objtype = 'Adhoc'
GROUP BY objtype, cacheobjtype;
GO


/* Memory clerks view */
select 
    type,
    name,
    pages_kb,
    pages_kb /1024. as page_size_mb
from sys.dm_os_memory_clerks
where type in ( 'CACHESTORE_SQLCP', 'CACHESTORE_OBJCP', 'CACHESTORE_OBJCP', 'CACHESTORE_OBJCP')
GO

/*  https://msdn.microsoft.com/en-us/library/cc293624.aspx
Object Plans (CACHESTORE_OBJCP)
Object Plans include plans for stored procedures, functions, and triggers

SQL Plans (CACHESTORE_SQLCP)
SQL Plans include the plans for adhoc cached plans, autoparameterized plans, and prepared plans.

Bound Trees (CACHESTORE_OBJCP)
Bound Trees are the structures produced by SQL Server�s algebrizer for views, constraints, and defaults.

Extended Stored Procedures (CACHESTORE_OBJCP)
Extended Procs (Xprocs) are predefined system procedures, like sp_executeSql and sp_tracecreate, that are defined using a DLL, not using Transact-SQL statements. The cached structure contains only the function name and the DLL name in which the procedure is implemented.

*/


--Let's run some non-parameterized queries.
--While this is running, run the queries above in another session
DECLARE 
    @dsql NVARCHAR(2000),
    @dsql2 NVARCHAR(2000),
    @i int = 1;
SET @dsql = N'DECLARE @foo varchar(256)
    SELECT @foo = FirstName
    FROM ref.FirstName
    WHERE FirstNameId = #x#';
WHILE @i <= 97310
BEGIN
    set @dsql2 = REPLACE (@dsql, '#x#', CAST(@i as nvarchar(5)));
    EXEC (@dsql2);
    SET @i += 1;
END

--How many plans ended up in cache?


/* Explore the queries generating the single use adhoc plans */
/* In some cases, I have found single use adhoc plans to all come from one or two bits of code.
In those cases, it can be more effective in the long term to fix the code and make it reuse plans
(it's usually an accident that it wasn't properly parameterized that way). */
SELECT TOP 100 
    cacheobjtype, 
    [text] as [sql text], 
    size_in_bytes/1024. as [KB] 
FROM sys.dm_exec_cached_plans   
CROSS APPLY sys.dm_exec_sql_text(plan_handle)   
WHERE 
    usecounts = 1
    and objtype = 'Adhoc'
ORDER BY [KB] DESC;  
GO  


/* Put single use adhoc plans into context of the whole plan cache */
/* When 'Optimize for Adhoc Workloads' is enabled, you'll see a row in 
    this list with objtype=Adhoc, cacheobjtype=Compiled Plan Stub.
    Those are the number and size used by the plan "stubs" of queries
    that have just run once since the setting was enabled / instance
    restart
*/
SELECT 
    objtype, 
    cacheobjtype, 
    SUM(CASE usecounts WHEN 1 THEN
        1 
    ELSE 0 END ) AS [Count: Single Use Plans],
    SUM(CASE usecounts WHEN 1 THEN
        size_in_bytes 
    ELSE 0 END )/1024./1024. AS [MB: Single Use Plans],
    COUNT_BIG(*) as [Count: All Plans],
    SUM(size_in_bytes)/1024./1024. AS [MB - All Plans] 
FROM sys.dm_exec_cached_plans   
GROUP BY objtype, cacheobjtype;
GO


--Enable this...
exec sp_configure 'optimize for ad hoc workloads', 1;
GO

RECONFIGURE
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO


--Let's run those non-parameterized queries again
--While this is running, run the query above that summarizes the plan cache
DECLARE 
    @dsql NVARCHAR(2000),
    @dsql2 NVARCHAR(2000),
    @i int = 1;
SET @dsql = N'DECLARE @foo varchar(256)
    SELECT @foo = FirstName
    FROM ref.FirstName
    WHERE FirstNameId = #x#';
WHILE @i <= 97310
BEGIN
    set @dsql2 = REPLACE (@dsql, '#x#', CAST(@i as nvarchar(5)));
    EXEC (@dsql2);
    SET @i += 1;
END
GO

--What if I parameterized my query?



--Enable this...
exec sp_configure 'optimize for ad hoc workloads', 0;
GO

RECONFIGURE
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

--This is parameterized dynamic sql
DECLARE 
    @dsql NVARCHAR(2000),
    @i int = 1;
SET @dsql = N'DECLARE @foo varchar(256)
    SELECT @foo = FirstName
    FROM ref.FirstName
    WHERE FirstNameId = @i';
WHILE @i <= 97310
BEGIN
    EXEC sp_executesql @dsql, N'@i INT', @i = @i;
    SET @i += 1;
END

--How many times was the plan for this used?
SELECT TOP 10 
    cacheobjtype, 
    [text] as [sql text], 
    size_in_bytes/1024. as [KB] ,
    usecounts
FROM sys.dm_exec_cached_plans   
CROSS APPLY sys.dm_exec_sql_text(plan_handle)   
ORDER BY usecounts DESC;  
GO  
