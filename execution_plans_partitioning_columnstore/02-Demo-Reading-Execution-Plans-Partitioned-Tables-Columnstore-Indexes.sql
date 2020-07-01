/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: 
https://littlekendra.com/course/the-weird-wonderful-world-of-execution-plans-partitioned-tables-columnstore-indexes

*****************************************************************************/


RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/*******************************************************************
How many partitions have been accessed by a query? 
*******************************************************************/
USE BabbyNames;
GO
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO 


--pt.FirstNameByBirthDate_1966_2015
--Clustered Index: FirstNameByBirthDateId, FakeBirthDateStamp
--Partitioning Column: FakeBirthDateStamp (DATETIME2(0))
/* Partitions and size */
SELECT
    sc.name + N'.' + so.name as [Schema.Table],
	si.index_id as [Index ID],
	si.type_desc as [Structure],
    si.name as [Index],
    p.partition_number AS [Partition #],
    prv.value as [Boundary Point],
    stat.row_count AS [Rows],
    stat.in_row_reserved_page_count * 8./1024./1024. as [In-Row GB],
	stat.lob_reserved_page_count * 8./1024./1024. as [LOB GB],
    pf.name as [Partition Function],
    CASE pf.boundary_value_on_right
		WHEN 1 then 'Right / Lower'
		ELSE 'Left / Upper'
	END as [Boundary Type],
	fg.name as [Filegroup]
FROM sys.partition_functions AS pf
JOIN sys.partition_schemes as ps on ps.function_id=pf.function_id
JOIN sys.indexes as si on si.data_space_id=ps.data_space_id
JOIN sys.objects as so on si.object_id = so.object_id
JOIN sys.schemas as sc on so.schema_id = sc.schema_id
JOIN sys.partitions as p on 
    si.object_id=p.object_id 
    and si.index_id=p.index_id
LEFT JOIN sys.partition_range_values as prv on prv.function_id=pf.function_id
    and p.partition_number= 
		CASE pf.boundary_value_on_right WHEN 1
			THEN prv.boundary_id + 1
		ELSE prv.boundary_id
		END
		/* For left-based functions, partition_number = boundary_id, 
		   for right-based functions we need to add 1 */
JOIN sys.dm_db_partition_stats as stat on stat.object_id=p.object_id
    and stat.index_id=p.index_id
    and stat.index_id=p.index_id and stat.partition_id=p.partition_id
    and stat.partition_number=p.partition_number
JOIN sys.allocation_units as au on au.container_id = p.hobt_id
	and au.type_desc ='IN_ROW_DATA' 
		/* Avoiding double rows for columnstore indexes. */
		/* We can pick up LOB page count from partition_stats */
JOIN sys.filegroups as fg on fg.data_space_id = au.data_space_id
ORDER BY [Schema.Table], [Index ID], [Partition Function], [Partition #];
GO



--Run with actual plans on
--How many partitions were accessed? Why?
DECLARE @ds DATETIME2 = '2015-01-01';
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= @ds
    OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO






--Run with actual plans on
--How many partitions were accessed? Why?
DECLARE @ds DATETIME2(0) = '2015-01-01';
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= @ds
    OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO


--Look at the cached execution plans.
--Can you tell how many partitions were accessed? Why?
--(Make sure to look at the seek predicate on the CX scan)
SELECT
	(SELECT CAST(SUBSTRING(st.text, (qs.statement_start_offset/2)+1,   
		((CASE qs.statement_end_offset  
			WHEN -1 THEN DATALENGTH(st.text)  
			ELSE qs.statement_end_offset  
			END
		- qs.statement_start_offset)/2) + 1) AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    qs.execution_count AS [#],
    CAST(qs.total_worker_time/1000./1000. AS numeric(30,1)) AS [cpu sec],
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
	END AS [avg writes],
    qp.query_plan AS [plan]
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text (plan_handle) as st
OUTER APPLY sys.dm_exec_query_plan (plan_handle) AS qp
WHERE st.text like '%SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015%'
    OPTION (RECOMPILE);
GO


/* Bonus: Can you find them in Query Store's Top Resource Consumers?
What do they look like in there? 
*/






/*  END  */

/*******************************************************************
When SQL Server "lies" about the partition count
        (and why it's not really a lie)
*******************************************************************/

/* Let SQL Server use the Nonclustered Columnstore Index... */
--Run with actual plans on
--How many partitions were accessed? What's up with that?
DECLARE @ds DATETIME2 = '2015-01-01';
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= @ds;
GO
--Note that:
--Actual Number of Locally Aggregated Rows = 3,110,413
--The number of rows flowing into the Hash Match is 819,192
--We'll come back to these numbers shortly

--First, what can we see from STATISTICS IO that we couldn't see from the plan?
SET STATISTICS IO, TIME ON;
GO
DECLARE @ds DATETIME2 = '2015-01-01';
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= @ds;
GO
SET STATISTICS IO, TIME OFF;
GO


/*******************************************************************
    Rowgroup, aka segment, elimination!
*******************************************************************/
/*
Table 'FirstNameByBirthDate_1966_2015'. Scan count 9, logical reads 2757, physical reads 0, read-ahead reads 0, lob logical reads 2493, lob physical reads 1, lob read-ahead reads 7838.
Table 'FirstNameByBirthDate_1966_2015'. Segment reads 4, segment skipped 219.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 235 ms,  elapsed time = 235 ms.
*/

--Segment reads 4. This is the # of rowgroups read. 
--A rowgroup contains multiple "segments" (one per column)
--This was mislabeled / mistermed in statistics io early on when the feature was added




/*******************************************************************
How much is in the deltastore?
    "OPEN" rowgroup is the deltastore (stored in a rowstore format)
Remember: The number of rows flowing into the Hash Match is 819,192
*******************************************************************/
SELECT 
    si.name AS index_name, 
    rg.state_description, 
    rg.partition_number,
    rg.row_group_id,
    rg.total_rows,
    rg.deleted_rows,
    CAST(rg.size_in_bytes/1024./1024. AS MONEY) AS size_in_MB,
    si.type_desc as index_type_desc
FROM sys.indexes AS si  
JOIN sys.column_store_row_groups AS rg  
    ON si.object_id = rg.object_id  
    AND si.index_id = rg.index_id   
JOIN sys.objects as so on 
    si.object_id = so.object_id
JOIN sys.schemas as sc on 
    so.schema_id = sc.schema_id
WHERE 
    sc.name = 'pt' and so.name = 'FirstNameByBirthDate_1966_2015'
ORDER BY 1 ASC, 2 DESC, 3 DESC;
GO

--How many rows are in the compressed rowgroups for partition 51?
--Remember: Actual Number of Locally Aggregated Rows on the 
--columnstore index scan = 3,110,413
SELECT 
   SUM(total_rows) as rows_in_partition_51
FROM sys.indexes AS si  
JOIN sys.column_store_row_groups AS rg  
    ON si.object_id = rg.object_id  
    AND si.index_id = rg.index_id   
JOIN sys.objects as so on 
    si.object_id = so.object_id
JOIN sys.schemas as sc on 
    so.schema_id = sc.schema_id
WHERE 
    sc.name = 'pt' and so.name = 'FirstNameByBirthDate_1966_2015'
    and rg.partition_number = 51
GO





/*  END  */



/*******************************************************************
What does rowgroup elimination look like if we DO get partition elimination?
*******************************************************************/
--What does the plan look like if we fix the implicit conversion?
SET STATISTICS IO, TIME ON;
GO
DECLARE @ds DATETIME2(0) = '2015-01-01';
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= @ds;
GO
SET STATISTICS IO, TIME OFF;
GO

/*
(1 row(s) affected)
Table 'FirstNameByBirthDate_1966_2015'. Scan count 3, logical reads 2758, physical reads 0, read-ahead reads 0, lob logical reads 2484, lob physical reads 0, lob read-ahead reads 0.
Table 'FirstNameByBirthDate_1966_2015'. Segment reads 4, segment skipped 0.

(1 row(s) affected)

 SQL Server Execution Times:
   CPU time = 140 ms,  elapsed time = 138 ms.
*/
 --Segment skipped = 0 because we DID get partition elimination this time!
 --Rowgroups (segments) eliminated by partition elimination don't get listed.


 

/*******************************************************************
Can we get rowgroup elimination on FirstNameId? This column is an INT.
    Also: When �0 rows� is really more than 0 rows 
*******************************************************************/
SET STATISTICS IO, TIME ON;
GO
SELECT COUNT(*) AS BabbyCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FirstNameId = 4
ORDER BY COUNT(*) DESC
GO
SET STATISTICS IO, TIME OFF;
GO




/*******************************************************************
Can we get rowgroup elimination on StateCode?
    Spoiler: no rowgroup elimination on string columns
    http://www.nikoport.com/2017/02/01/columnstore-indexes-part-97-working-with-strings/
*******************************************************************/
SET STATISTICS IO, TIME ON;
GO
SELECT COUNT(*) AS BabbyCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE StateCode = 'OR';
GO
SET STATISTICS IO, TIME OFF;
GO

--Table 'FirstNameByBirthDate_1966_2015'. Segment reads 219, segment skipped 0.


--Let's try another
SET STATISTICS IO, TIME ON;
GO
SELECT COUNT(*) AS BabbyCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE Gender = 'M';
GO
SET STATISTICS IO, TIME OFF;
GO

--Table 'FirstNameByBirthDate_1966_2015'. Segment reads 219, segment skipped 0.


/*  END  */

/*******************************************************************
Query Time Stats on batch mode vs row mode operators

Sometimes doing more takes less CPU ... ??!?!
    Compare the Query Time Stats for these queries
    Walk up the chain for each:
        Colstore scan (batch mode, time stats are per operator)
        Number of rows that flow to the hash match
        Hash match (batch mode, time stats are per operator)
        Parallelism operators (row mode, time stats include "children")
        SELECT operator
*******************************************************************/

SET STATISTICS IO, TIME ON;
GO
DECLARE @StateCode char(2);
SELECT @StateCode=StateCode FROM pt.FirstNameByBirthDate_1966_2015 GROUP BY StateCode
GO
DECLARE @StateCode char(2), @ct INT;
SELECT @StateCode=StateCode, @ct=COUNT(*) FROM pt.FirstNameByBirthDate_1966_2015 GROUP BY StateCode
GO
SET STATISTICS IO, TIME OFF;
GO

--Query 1
   --CPU time = 937 ms,  elapsed time = 367 ms.

--Query 2
   --CPU time = 548 ms,  elapsed time = 258 ms.




