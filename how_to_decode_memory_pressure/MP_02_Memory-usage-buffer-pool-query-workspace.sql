/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decode-memory-pressure/


NOTE: This script is suitable only for dedicated test instances
Commands in this script will cause havoc and hurt performance
*****************************************************************************/


/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
SETUP: Create and key agg.FirstNameByYearWide_Natural
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

SET STATISTICS IO, TIME OFF;
GO
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO

use BabbyNames
GO

ALTER DATABASE current SET QUERY_STORE = ON
GO
ALTER DATABASE current SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO

SELECT
    ReportYear,
    Gender,
    FirstNameId,
    NameCount,
    REPLICATE ('foo',3) AS ReportColumn1,
    REPLICATE ('fo',3) AS ReportColumn2,
    REPLICATE ('fo',3) AS ReportColumn3,
    1014 AS ReportColumn4,
    REPLICATE ('moo',3) AS ReportColumn5,
    REPLICATE ('mo',3) AS ReportColumn6,
    REPLICATE ('m',300) AS ReportColumn7,
    1 AS ReportColumn8,
    15060902002 AS ReportColumn9,
    REPLICATE ('boo',300) AS ReportColumn10,
    REPLICATE ('bo',3) AS ReportColumn11,
    REPLICATE ('b',30) AS ReportColumn12,
    CAST('true' AS BIT) AS ReportColumn13,
    2000000000000 AS ReportColumn14,
    CAST ('2016-01-01' AS DATETIME2(7))  AS ReportColumn15,
    CAST ('2015-01-01' AS DATETIME2(7)) AS ReportColumn16,
    CAST ('2014-01-01' AS DATETIME2(7)) AS ReportColumn17,
    CAST ('2013-01-01' AS DATETIME2(7)) AS ReportColumn18,
    14 AS ReportColumn19,
    CAST ('You are such a creep to add a LOB column, Kendra' AS NVARCHAR(MAX)) AS ReportColumn20
INTO agg.FirstNameByYearWide_Natural
FROM agg.FirstNameByYear;
GO
 
CREATE UNIQUE CLUSTERED INDEX cx_agg_FirstNameByYearWide_Natural
    ON agg.FirstNameByYearWide_Natural ( ReportYear ASC, Gender ASC, FirstNameId ASC );
GO



/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
BUFFER POOL MEMORY
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

exec sp_configure 'min server memory (MB)', 256;
GO
RECONFIGURE
GO
--We're setting this to ~4GB for this demo
exec sp_configure 'max server memory (MB)', 4000;
GO
RECONFIGURE
GO

--And we're clearing out all our buffers
CHECKPOINT;
GO
DBCC DROPCLEANBUFFERS
GO

--Undocumented DMV, SQL Server 2012+
SELECT 
    cast(total_kb/1024. as numeric(10,1)) as total_mb,
    clerk_name
FROM sys.dm_os_memory_broker_clerks;
GO

--Documented, SQL Server 2008+
SELECT TOP 5
    cast(pages_kb/1024.  as numeric(10,1)) as pages_mb,
    type,
    name
FROM sys.dm_os_memory_clerks
--WHERE pages_kb > (50 * 1024) 
ORDER BY pages_mb DESC;
GO


CREATE OR ALTER PROCEDURE dbo.MemoryTest
    @Rank INT = 1
AS
SET NOCOUNT ON;

with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
INTO #foo
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = @Rank;
GO

--Look at the estimated execution plan.
--What is it scanning?
--Run the procedure
exec dbo.MemoryTest;
GO


--Undocumented DMV, SQL Server 2012+
SELECT 
    cast(total_kb/1024. AS NUMERIC(10,1)) as total_mb,
    clerk_name
FROM sys.dm_os_memory_broker_clerks;
GO

--Documented, SQL Server 2008+
SELECT TOP 5
    cast(pages_kb/1024.  AS NUMERIC(10,1)) as pages_mb,
    type,
    name
FROM sys.dm_os_memory_clerks
WHERE pages_kb > (50 * 1024) 
ORDER BY pages_mb DESC;
GO

--These pages can be shared by different queries

--This query modified slightly from
--https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-buffer-descriptors-transact-sql
SELECT 
    name ,
    index_id, 
    CAST(COUNT(*) * 8./1024. AS NUMERIC(10,1)) AS buffer_pool_mb  
FROM sys.dm_os_buffer_descriptors AS bd   
    INNER JOIN   
    (  
        SELECT object_name(object_id) AS name   
            ,index_id ,allocation_unit_id  
        FROM sys.allocation_units AS au  
            INNER JOIN sys.partitions AS p   
                ON au.container_id = p.hobt_id   
                    AND (au.type = 1 OR au.type = 3)  
        UNION ALL  
        SELECT object_name(object_id) AS name     
            ,index_id, allocation_unit_id  
        FROM sys.allocation_units AS au  
            INNER JOIN sys.partitions AS p   
                ON au.container_id = p.partition_id   
                    AND au.type = 2  
    ) AS obj   
        ON bd.allocation_unit_id = obj.allocation_unit_id  
WHERE database_id = DB_ID()  
GROUP BY name, index_id 
HAVING COUNT(*) > 10
ORDER BY buffer_pool_mb DESC;
GO


--Let's create an index to help with our query
CREATE INDEX ix_memorytest on agg.FirstNameByYearWide_Natural
    (ReportYear, Gender, NameCount) INCLUDE (FirstNameId);
GO


--Compare the size to the clustered index
SELECT 
    ps.index_id,
    row_count,
    cast(in_row_reserved_page_count * 8./1024.  AS NUMERIC(10,1)) as reserved_mb
FROM sys.dm_db_partition_stats as ps
JOIN sys.indexes as si on
    ps.object_id=si.object_id
    and ps.index_id=si.index_id
WHERE si.object_id = OBJECT_ID('agg.FirstNameByYearWide_Natural');
GO


--Run with actual plans on. 
--Does our query use it?
exec dbo.MemoryTest;
GO


--Has this changed? Why?
SELECT TOP 5
    cast(pages_kb/1024.  AS NUMERIC(10,1)) as pages_mb,
    type,
    name
FROM sys.dm_os_memory_clerks
WHERE pages_kb > (50 * 1024) 
ORDER BY pages_mb DESC;
GO

--Clear out our buffers again...
CHECKPOINT;
GO
DBCC DROPCLEANBUFFERS
GO


--Run the query
exec dbo.MemoryTest;
GO


--Now what do we have?
SELECT TOP 5
    cast(pages_kb/1024.  AS NUMERIC(10,1)) as pages_mb,
    type,
    name
FROM sys.dm_os_memory_clerks
WHERE pages_kb > (50 * 1024) 
ORDER BY pages_mb DESC;
GO



--Drop the index for now
DROP INDEX ix_memorytest on agg.FirstNameByYearWide_Natural;
GO



--Back to the slides for a quick recap





/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
QUERY WORKSPACE MEMORY
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */


--We're setting this low for this demo
exec sp_configure 'max server memory (MB)', 4096;
GO
exec sp_configure 'cost threshold for parallelism', 50;
GO
exec sp_configure 'max degree of parallelism', 8;
GO
RECONFIGURE
GO

USE BabbyNames;
GO


/*Enable actual execution plans. 
Run the query.
How much of a memory grant did we get?*/

EXEC dbo.MemoryTest @Rank=1;
GO


/*
cd S:\RMLUtils

.\ostress.exe -S"DERPDERP\DEV" -Q"exec BabbyNames.dbo.MemoryTest" -n8 -r2 -o"S:\ostressoutput"
*/

--sys.dm_exec_query_memory_grants
SELECT 
    session_id,
    request_time,
    grant_time,
    requested_memory_kb,
    granted_memory_kb,
    required_memory_kb,
    used_memory_kb,
    max_used_memory_kb,
    query_cost,
    queue_id,
    wait_order,
    wait_time_ms
FROM sys.dm_exec_query_memory_grants
ORDER BY session_id;
GO

--sys.dm_os_waiting_tasks
SELECT session_id,
    wait_duration_ms, 
    wait_type,
    blocking_session_id,
    resource_description
FROM sys.dm_os_waiting_tasks
WHERE session_id IS NOT NULL
    and resource_description IS NOT NULL
ORDER BY session_id;
GO



--sys.dm_exec_query_memory_grants
SELECT 
    SUM(granted_memory_kb)/1024. as granted_mem_mb
FROM sys.dm_exec_query_memory_grants;
GO


SELECT
    mem.granted_mem_mb,
    cast(100 * mem.granted_mem_mb / (physical_memory_in_use_kb/1024.) as numeric(5,1)) as percent_mem_for_workspace_grants,
    physical_memory_in_use_kb/1024. as physical_mem_in_use_mb
FROM sys.dm_os_process_memory
CROSS APPLY (SELECT SUM(granted_memory_kb)/1024. as granted_mem_mb FROM sys.dm_exec_query_memory_grants ) as mem;
GO

/* Total workspace memory <= 75% of buffer pool size
Individual query memory, <= 25% of workspace memory, but can be raised using resource governor or hints 

Information found in: Pro SQL Server Internals, By Dmitri Korotkevitch
*/

select requested_memory_kb, granted_memory_kb, required_memory_kb
FROM sys.dm_exec_query_memory_grants;

--For our query, required memory = 30088
--https://support.microsoft.com/en-us/help/3107401/new-query-memory-grant-options-are-available-min-grant-percent-and-max
--MAX_GRANT_PERCENT - "if the size of this max memory limit is smaller than the required 
--memory to run a query, the required memory is granted to the query."


CREATE OR ALTER PROCEDURE dbo.MemoryTest
    @Rank INT = 1
AS
SET NOCOUNT ON;

with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
INTO #foo
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = @Rank
    OPTION (MAX_GRANT_PERCENT = 1) ;
GO


/*
.\ostress.exe -S"DERPDERP\DEV" -Q"exec BabbyNames.dbo.MemoryTest" -n8 -r10 -o"S:\ostressoutput"


*/


--sys.dm_exec_query_memory_grants
SELECT 
    session_id,
    request_time,
    grant_time,
    requested_memory_kb,
    granted_memory_kb,
    required_memory_kb,
    used_memory_kb,
    max_used_memory_kb,
    query_cost,
    queue_id,
    wait_order,
    wait_time_ms
FROM sys.dm_exec_query_memory_grants;
GO

--sys.dm_os_waiting_tasks
SELECT session_id,
    wait_duration_ms, 
    wait_type,
    blocking_session_id,
    resource_description
FROM sys.dm_os_waiting_tasks
WHERE session_id IS NOT NULL
    and resource_description IS NOT NULL
ORDER BY session_id;
GO

/*
But... maybe having the lowest memory grant 
isn't great for my query all the time

Sample completion time:
     Creating 8 thread(s) to process queries
     Worker threads created, beginning execution...
     Total IO waits: 0, Total IO wait time: 0 (ms)
     OSTRESS exiting normally, elapsed time: 00:03:36.922

*/


--Let's create that index again
CREATE INDEX ix_memorytest on agg.FirstNameByYearWide_Natural
    (ReportYear, Gender, NameCount) INCLUDE (FirstNameId);
GO

--Remove the hint regarding the memory grant
CREATE OR ALTER PROCEDURE dbo.MemoryTest
    @Rank INT = 1
AS
SET NOCOUNT ON;

with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
INTO #foo
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = @Rank;
GO


--Run with actual plans
--Has our nonclustered index changed the memory grant? Why?
EXEC dbo.MemoryTest @Rank=1;
GO



--What's that sort doing?
--Why?



--Er, I didn't index that quite right!
--This is what I indexed:
--CREATE INDEX ix_memorytest on agg.FirstNameByYearWide_Natural
--    (ReportYear, Gender, NameCount) INCLUDE (FirstNameId);
--GO
--Let's fix that
CREATE INDEX ix_memorytest on agg.FirstNameByYearWide_Natural
    (ReportYear, Gender, NameCount DESC) INCLUDE (FirstNameId)
WITH (DROP_EXISTING = ON);
GO

EXEC dbo.MemoryTest @Rank=1;
GO

--Why is it doing the hash join and merge joins? Look at the estimates coming in off the top branch.


--I'm adding a physical join hint
--Pros? Cons?
CREATE OR ALTER PROCEDURE dbo.MemoryTest
    @Rank INT = 1
AS
SET NOCOUNT ON;

with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
INTO #foo
FROM NameRank
INNER LOOP JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = @Rank;
GO

--What is my memory grant now?
EXEC dbo.MemoryTest @Rank=1;
GO



/*
.\ostress.exe -S"DERPDERP\DEV" -Q"exec BabbyNames.dbo.MemoryTest" -n8 -r10 -o"S:\ostressoutput"

Sample completion time:
     Creating 8 thread(s) to process queries
     Worker threads created, beginning execution...
     Total IO waits: 0, Total IO wait time: 0 (ms)
     OSTRESS exiting normally, elapsed time: 00:00:14.940
*/


--sys.dm_exec_query_memory_grants
SELECT 
    session_id,
    request_time,
    grant_time,
    requested_memory_kb,
    granted_memory_kb,
    required_memory_kb,
    used_memory_kb,
    max_used_memory_kb,
    query_cost,
    queue_id,
    wait_order,
    wait_time_ms
FROM sys.dm_exec_query_memory_grants;
GO

--sys.dm_os_waiting_tasks
SELECT session_id,
    wait_duration_ms, 
    wait_type,
    blocking_session_id,
    resource_description
FROM sys.dm_os_waiting_tasks
WHERE session_id IS NOT NULL
    and resource_description IS NOT NULL
ORDER BY session_id;
GO



--What about using a temp table?
--Pros? Cons?
CREATE OR ALTER PROCEDURE dbo.MemoryTest
    @Rank INT = 1
AS
SET NOCOUNT ON;

SELECT
    ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
    ReportYear,
    Gender,
    FirstNameId,
    NameCount
INTO #namerank
FROM agg.FirstNameByYearWide_Natural AS fnby;

SELECT
    nr.ReportYear, nr.Gender, fn.FirstName,  nr.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
INTO #foo
FROM #namerank AS nr
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=nr.FirstNameId and
    fnby.Gender=nr.Gender and
    fnby.ReportYear=nr.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = @Rank;
GO

--What is my memory grant now?
EXEC dbo.MemoryTest @Rank=1;
GO



/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
CLEANUP
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

DROP INDEX IF EXISTS ix_memorytest on agg.FirstNameByYearWide_Natural;
GO

DROP PROCEDURE IF EXISTS MemoryTest;
GO

