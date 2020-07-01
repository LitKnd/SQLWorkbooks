/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/why-table-partitioning-does-not-speed-up-query-performance-with-exception/

Note: This demo is designed for illustration purposes of some things that make
table partitioning tricky, NOT as best-practice design info for partitioning.

*****************************************************************************/


/*****************************************************************
Create DB
*****************************************************************/

IF DB_ID('SimplePartitionExample') IS NOT NULL
BEGIN
    use master;
    ALTER DATABASE SimplePartitionExample SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SimplePartitionExample;
END

CREATE DATABASE SimplePartitionExample
GO


/*****************************************************************
Configure some filegroups. As with EVERYTHING in this demo,
this isn't always the FG design you want
*****************************************************************/
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG0];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG1];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG2];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG3];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG4];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG5];
GO
ALTER DATABASE SimplePartitionExample add FILEGROUP [FG6];
GO

ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG0FILE1, FILENAME = 'S:\MSSQL\Data\FG0FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG0];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG1FILE1, FILENAME = 'S:\MSSQL\Data\FG1FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG1];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG2FILE1, FILENAME = 'S:\MSSQL\Data\FG2FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG2];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG3FILE1, FILENAME = 'S:\MSSQL\Data\FG3FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG3];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG4FILE1, FILENAME = 'S:\MSSQL\Data\FG4FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG4];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG5FILE1, FILENAME = 'S:\MSSQL\Data\FG5FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG5];
GO
ALTER DATABASE SimplePartitionExample add FILE (
	NAME = FG6FILE1, FILENAME = 'S:\MSSQL\Data\FG6FILE1.ndf', SIZE = 64MB, FILEGROWTH = 256MB  
) TO FILEGROUP [FG6];
GO

/*****************************************************************
Create a partitioned table
*****************************************************************/
USE SimplePartitionExample;
GO

/* Create the partition function defining our boundary points.
I am choosing range LEFT,
AKA upper boundary points: https://littlekendra.com/2017/02/07/understanding-left-vs-right-partition-functions-with-diagrams/
*/
CREATE PARTITION FUNCTION [pf_CustomerId](INT) 
	AS RANGE LEFT FOR VALUES 
	(99, 100, 101, 102, 103, 104)
GO

/* Create a parition scheme on the partition function */
CREATE PARTITION SCHEME [ps_CustomerId] AS PARTITION [pf_CustomerId] 
	TO (FG0, FG1 , FG2, FG3, FG4, FG5, FG6)
GO


/* Create the table on the partition scheme */
CREATE TABLE dbo.Keywords (
	KeywordId BIGINT IDENTITY,
	CustomerId INT NOT NULL,
	AdvertiserId INT NOT NULL,
    CampaignId INT NOT NULL,
    Keyword NVARCHAR(2000),
    CreateDate DATETIME2(0)
        CONSTRAINT df_keywords_createdate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0))),
    MoifiedDate DATETIME2(0)
        CONSTRAINT df_keywords_modifieddate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0)))
) on [ps_CustomerId](CustomerId);
GO




/*****************************************************************
Add some data
*****************************************************************/
--This query adapted from pattern attributed 
--to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e2 CROSS JOIN e2 as b), 
e4(n) AS (SELECT 0 FROM e3 CROSS JOIN e3 as b),
e5(num) AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) as num FROM e4)
INSERT dbo.Keywords (CustomerId, AdvertiserId, CampaignId, Keyword ) 
SELECT TOP (3100040) 
    CASE WHEN num between 0 and 1000000 THEN 100    
        WHEN num between 1000000 and 3000000 THEN 101
        WHEN num between 3000001 and 3100000 THEN 102
        WHEN num between 3100001 and 3100040 THEN 103
        ELSE 103 
        END AS CustomerId,
    CASE WHEN num between 0 and 1000000 THEN 1    
        WHEN num between 1000000 and 3000000 THEN 10
        WHEN num between 3000001 and 3100000 THEN 2
        WHEN num between 3100001 and 3100040 THEN 800
        ELSE 800 
        END AS AdvertiserId,
    CASE WHEN num between 0 and 100 THEN 400  
        WHEN num between 101 and 100000 THEN 430
        WHEN num between 100001 and 1000000 THEN 500
        WHEN num between 1000001 and 3000000 THEN 42120
        WHEN num between 3000001 and 3100000 THEN 30
        WHEN num between 3100001 and 3100040 THEN 300200
        ELSE 300200 
        END AS CampaignId,
    CASE WHEN num%7 = 0 THEN N'Unicorn'
        WHEN num%3 = 0 THEN N'Spam'
        WHEN num%5 = 0 THEN N'Granola'
        WHEN num%2 = 0 THEN N'Bunnies'
        ELSE 'Baloney' 
        END AS Keyword
FROM e5
GO




/*****************************************************************
Let's index this!
*****************************************************************/

/* Try to create this. We will get an error if it is unique and we don't include the partitioning
key in the index definition */
--CREATE UNIQUE CLUSTERED INDEX cx_Keywords on dbo.Keywords (KeywordId);
--GO


/*Uniqueness is generally helpful in clustered indexes, so here we go... */
CREATE UNIQUE CLUSTERED INDEX cx_Keywords on dbo.Keywords (KeywordId, CustomerId);
GO



/*****************************************************************
Query 1: What is partition elimination?
*****************************************************************/

--Look at the actual plan,properties on the clustered index scan
--Actual partition count: 1
--Actual partitions accessed: 2 (this means partition #2)
SELECT Keyword
FROM dbo.Keywords
WHERE CustomerId = 100
    and CampaignId = 500
    OPTION (RECOMPILE);
GO

--Note: I used option recompile to prevent auto-parameterization, 
--just to simplify looking at the plan.



--Question: does this still work with parameterization?

CREATE OR ALTER PROCEDURE #testparams
    @CustomerId INT,
    @CampaignId INT
AS
    SELECT Keyword
    FROM dbo.Keywords
    WHERE CustomerId = @CustomerId
        and CampaignId = @CampaignId
GO

--Look at actual plan 
--Properties on the clustered index scan show same partition elimination
--Parameterization is A-OK
EXEC #testparams @CustomerId=100, @CampaignId=500;
GO

--We can even reuse the plan with different params and get it
EXEC #testparams @CustomerId=100, @CampaignId=400;
GO
EXEC #testparams @CustomerId=103, @CampaignId=300200;
GO



/*****************************************************************
Query 1: We want a seek!
*****************************************************************/

/* Oh, such a badly named index! Shameful.*/
CREATE INDEX ix_hi
on dbo.Keywords (CampaignId) INCLUDE (Keyword);
GO


/* This index is "aligned" because I didn't specify otherwise.
Super long query to review the metadata.
The main thing to notice is that your clustered & nonclustered indexes are both partitioned
We can also see the partition number, which is a logical # assigned behind the scenes
Note the index_id for the nonclustered index. */
SELECT
    sc.name + N'.' + so.name as [Schema.Table],
	si.index_id as [Index ID],
	si.type_desc as [Structure],
    si.name as [Index],
    stat.row_count AS [Rows],
    stat.in_row_reserved_page_count * 8./1024./1024. as [In-Row GB],
	stat.lob_reserved_page_count * 8./1024./1024. as [LOB GB],
    p.partition_number AS [Partition #],
    pf.name as [Partition Function],
    CASE pf.boundary_value_on_right
		WHEN 1 then 'Right / Lower'
		ELSE 'Left / Upper'
	END as [Boundary Type],
    prv.value as [Boundary Point],
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


/* What's really in that NC index? */

/**********************************
Let's get the page number of the root page, at index level 2
sys.dm_db_database_page_allocations was added in SQL Server 2012,
    it is not officially documented.
Be careful running it against large tables in production

Note the allocated_page_file_id and the allocated_page_page_id for the top line
**********************************/
SELECT 
    allocated_page_file_id,
    page_level, 
    page_type_desc,
    allocated_page_page_id,
    previous_page_page_id,
    next_page_page_id
FROM sys.dm_db_database_page_allocations(
    DB_ID(), 
    OBJECT_ID('dbo.Keywords'), 
    4 /* Index_id 4 -- get this from the prior query*/ ,
    NULL, 
    'detailed')
WHERE 
    is_allocated=1
    and page_type = 2 /* Index pages, not talking about IAM_PAGEs today*/
ORDER BY 1, 2 DESC, 3, 4
GO


/* DBCC PAGE is very well known,
but is also not officially documented. Handle with care. */
DBCC TRACEON(3604);
GO

/* Nonclustered index root page 
The column names tell us which columns are really in the key of the index*/
/*         Database                 File# Page# DumpStyle*/
DBCC PAGE ('SimplePartitionExample', 4, 10362, 3);
GO


--We defined the index as having one KEY (CampaignId) 
--The key of the index is actually 3 columns (CampaignId, KeywordId, CustomerId)

--The clustering key was added to the key of the index

--You may know that if we define a nonclustered index as UNIQUE, 
--the clustering key will be added to the INCLUDES, not the key.
--That is still true BUT the partitioning column cannot be in the key.
--So we can't do this:
CREATE UNIQUE NONCLUSTERED INDEX ix_oh_no on dbo.Keywords(KeywordId);
GO

--Msg 1908, Level 16, State 1, Line 333
--Column 'CustomerId' is partitioning column of the index 'ix_oh_no'. 
--Partition columns for a unique index must be a subset of the index key.

--If we really want to create that, we must make it non-aligned (not on this
--partition scheme). That has downsides, which we'll cover in a bit.



--Back to our query
--Run with actual plans
--You'll see an index seek, also with partition elimination 
--(1 partition accessed, it is partition #2)
SELECT Keyword
FROM dbo.Keywords
WHERE CustomerId = 100
    and CampaignId = 500
    OPTION (RECOMPILE);
GO

--Logical reads = 4,283
--CPU time = 187 ms
--Estimated cost = 3.8351


--Student question: what if I change the order of the parameters?
--Run with actual plans
--You'll see an index seek, also with partition elimination
--(1 partition accessed, it is partition #2)
SELECT Keyword
FROM dbo.Keywords
WHERE 
    CampaignId = 500
    and CustomerId = 100
    OPTION (RECOMPILE);
GO


/* But what if we hadn't partitioned the table?
We could still get great performance just by having good indexes.*/


/* Create the table, but not on the partition scheme */
CREATE TABLE dbo.KeywordsNotPartitioned (
	KeywordId BIGINT IDENTITY,
	CustomerId INT NOT NULL,
	AdvertiserId INT NOT NULL,
    CampaignId INT NOT NULL,
    Keyword NVARCHAR(2000),
    CreateDate DATETIME2(0)
        CONSTRAINT df_keywordsnotpartitioned_createdate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0))),
    MoifiedDate DATETIME2(0)
        CONSTRAINT df_keywordsnotpartitioned_modifieddate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0)))
) on [FG0];
GO
/* Add the same data */
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e2 CROSS JOIN e2 as b), 
e4(n) AS (SELECT 0 FROM e3 CROSS JOIN e3 as b),
e5(num) AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) as num FROM e4)
INSERT dbo.KeywordsNotPartitioned (CustomerId, AdvertiserId, CampaignId, Keyword ) 
SELECT TOP (3100040) 
    CASE WHEN num between 0 and 1000000 THEN 100    
        WHEN num between 1000000 and 3000000 THEN 101
        WHEN num between 3000001 and 3100000 THEN 102
        WHEN num between 3100001 and 3100040 THEN 103
        ELSE 103 
        END AS CustomerId,
    CASE WHEN num between 0 and 1000000 THEN 1    
        WHEN num between 1000000 and 3000000 THEN 10
        WHEN num between 3000001 and 3100000 THEN 2
        WHEN num between 3100001 and 3100040 THEN 800
        ELSE 800 
        END AS AdvertiserId,
    CASE WHEN num between 0 and 100 THEN 400  
        WHEN num between 101 and 100000 THEN 430
        WHEN num between 100001 and 1000000 THEN 500
        WHEN num between 1000001 and 3000000 THEN 42120
        WHEN num between 3000001 and 3100000 THEN 30
        WHEN num between 3100001 and 3100040 THEN 300200
        ELSE 300200 
        END AS CampaignId,
    CASE WHEN num%7 = 0 THEN N'Unicorn'
        WHEN num%3 = 0 THEN N'Spam'
        WHEN num%5 = 0 THEN N'Granola'
        WHEN num%2 = 0 THEN N'Bunnies'
        ELSE 'Baloney' 
        END AS Keyword
FROM e5
GO

/* We would just do a one column unique CX or a clustered PK in this case */
CREATE UNIQUE CLUSTERED INDEX cx_KeywordsNotPartitioned on dbo.KeywordsNotPartitioned (KeywordId);
GO


/* Oh, STILL such a badly named index! Shameful.
This time I am doing the proper thing and specifying both columns with an equality
in the predicates as key columns in the index.
(I didn't do that on the partitioned one just to show you it got added even if I didn't specify.
It is not in the Clustering key anymore so it won't get added automatically.)
*/
CREATE INDEX ix_hi
on dbo.KeywordsNotPartitioned (CampaignId, CustomerId) INCLUDE (Keyword);
GO

SELECT Keyword
FROM dbo.KeywordsNotPartitioned
WHERE CustomerId = 100
    and CampaignId = 500
    OPTION (RECOMPILE);
GO


--Logical reads = 4,292 (was 4,283)
--CPU time = same range (sometimes a bit higher than 187 ms, sometimes lower)
--Estimated cost = 2.3848 (was 3.8351)



/**********************************
Takeaway: Rowstore indexes are very powerful.
If we don't have partition elimination, we can still index for seeks.
Partition elimination isn't magic fairy dust for our read queries.
**********************************/




/**********************************
What if we do have a case where we want to create a 
non-aligned index?
Could be to enforce uniqueness, or it could be for a query tuning problem
(like the top/max/min problem -- one way to solve that is a non-aligned index.
Not the BEST way in my opinion, but a way.
We can do this:
**********************************/
CREATE UNIQUE NONCLUSTERED INDEX ix_watch_this 
    on dbo.Keywords(KeywordId)
    ON [FG1];
GO
/* By specifying a filegroup, I am saying NOT to create it on the
partition scheme (the default).
This makes it only a single partition.
You can run the super-long metadata query above to prove that.
*/

/* While I have a non-aligned index, this doesn't work.
I also can't switch in or out.*/
TRUNCATE TABLE dbo.Keywords 
WITH (PARTITIONS (2,3,4));
GO

--Msg 3756, Level 16, State 1, Line 472
--TRUNCATE TABLE statement failed. Index 'ix_watch_this' is not partitioned, 
--but table 'Keywords' uses partition function 'pf_CustomerId'. 
--Index and table must use an equivalent partition function.


DROP INDEX ix_watch_this on dbo.Keywords;
GO



/**********************************
What if we don't have a predicate on the partitioning key?
**********************************/

--Run with actual plans on 
--Partitions accessed 1..7 -- that's all of them! No partition elimination.
SELECT COUNT(*) 
FROM dbo.Keywords
WHERE Keyword = N'Unicorn';
GO


--Create an index on Keyword, this is aligned by default
CREATE INDEX ix_hi_again
on dbo.Keywords (Keyword);
GO


--Run with actual plans on 
--We get a SEEK!
--It's faster, but partitions accessed 1..7 -- that's all of them! No partition elimination.
SELECT COUNT(*) 
FROM dbo.Keywords
WHERE Keyword = N'Unicorn';
GO
--Logical reads: 2,007

--If we make it non-aligned...
CREATE INDEX ix_hi_again
on dbo.Keywords (Keyword)
WITH (DROP_EXISTING = ON)
ON [FG0];
GO

SELECT COUNT(*) 
FROM dbo.Keywords
WHERE Keyword = N'Unicorn';
GO
--Logical reads: 2,004
--If I have thousands of partitions, this gap widens.
--It's not necessarily terrible, just a complexity to be aware of.


/********************************************************************
For demos on partitioning making some queries 
harder to optimize, check out the course: 
Tuning Problem Queries in Table Partitioning.

It is literally full of them :)

********************************************************************/



/********************************************************************
Where partitioning shines:
Managing large tables
********************************************************************/


/* Loading with switching 
Partition #6 with upper boundary point 104,
residing on FG5 is empty.
How do I know? 
The return of super long metadata query:
*/
SELECT
    sc.name + N'.' + so.name as [Schema.Table],
	si.index_id as [Index ID],
	si.type_desc as [Structure],
    si.name as [Index],
    stat.row_count AS [Rows],
    stat.in_row_reserved_page_count * 8./1024./1024. as [In-Row GB],
	stat.lob_reserved_page_count * 8./1024./1024. as [LOB GB],
    p.partition_number AS [Partition #],
    pf.name as [Partition Function],
    CASE pf.boundary_value_on_right
		WHEN 1 then 'Right / Lower'
		ELSE 'Left / Upper'
	END as [Boundary Type],
    prv.value as [Boundary Point],
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


/* Create a staging table for the data we want to load.
Put it on FG5*/
CREATE TABLE dbo.KeywordsStaging (
	KeywordId BIGINT IDENTITY,
	CustomerId INT NOT NULL,
	AdvertiserId INT NOT NULL,
    CampaignId INT NOT NULL,
    Keyword NVARCHAR(2000),
    CreateDate DATETIME2(0)
        CONSTRAINT df_keywordsstaging_createdate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0))),
    MoifiedDate DATETIME2(0)
        CONSTRAINT df_keywordsstaging_modifieddate DEFAULT(CAST(SYSDATETIME() AS DATETIME2(0)))
) on [FG5];
GO



/* Add some data for boundary point 104 into KeywordsStaging
(that's the one mapped to the partition on this FG) */
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e2 CROSS JOIN e2 as b), 
e4(n) AS (SELECT 0 FROM e3 CROSS JOIN e3 as b),
e5(num) AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) as num FROM e4)
INSERT dbo.KeywordsStaging (CustomerId, AdvertiserId, CampaignId, Keyword ) 
SELECT TOP (1000001) 
    104 CustomerId,
    CASE WHEN num between 0 and 1000000 THEN 2010
        WHEN num between 1000001 and 1000001 THEN 302002
        ELSE 302002 
        END AS AdvertiserId,
    CASE WHEN num between 0 and 1000000 THEN 2910
        WHEN num between 1000001 and 1000001 THEN 4002
        ELSE 4002 
        END AS CampaignId,
    CASE WHEN num%7 = 0 THEN N'Bears'
        WHEN num%3 = 0 THEN N'Gummies'
        WHEN num%5 = 0 THEN N'Carrots'
        WHEN num%2 = 0 THEN N'Giraffes'
        ELSE 'Baloney' 
        END AS Keyword
FROM e5
GO

/* Index to match the partitioned table */
CREATE UNIQUE CLUSTERED INDEX cx_KeywordsStaging on dbo.KeywordsStaging (KeywordId, CustomerId);
GO

/* Oh, such a badly named index! STILL SO shameful.*/
CREATE INDEX ix_hi
on dbo.KeywordsStaging (CampaignId) INCLUDE (Keyword);
GO

ALTER TABLE dbo.KeywordsStaging SWITCH  TO
    dbo.Keywords PARTITION 6;
GO


--Msg 7733, Level 16, State 4, Line 660
--'ALTER TABLE SWITCH' statement failed. The table 'SimplePartitionExample.dbo.Keywords' is partitioned while index 'ix_hi_again' is not partitioned.


--Whups, I left that non-aligned index there.
--Like I said, no switching.

DROP INDEX IF EXISTS ix_hi_again on dbo.Keywords;
GO

ALTER TABLE dbo.KeywordsStaging SWITCH TO
    dbo.Keywords PARTITION 6;
GO

--Msg 4982, Level 16, State 1, Line 675
--ALTER TABLE SWITCH statement failed. Check constraints of source table 'SimplePartitionExample.dbo.KeywordsStaging' allow values that are not allowed by range defined by partition 6 on target table 'SimplePartitionExample.dbo.Keywords'.


--I have matching indexes, but I haven't given SQL Server
--any evidence that the data in dbo.KeyWordsStaging belongs in partition #6.
--I need to create a constraint to do that


ALTER TABLE dbo.KeywordsStaging
ADD  CONSTRAINT cs_Keywords_CustomerId
    CHECK  ( CustomerId = 104 );
GO

--MY BIG MOMENT!
--Notice that I can use WAIT_AT_LOW_PRIORITY to control what happens if I am blocked
--Switching requires brief exclusive access to the table
ALTER TABLE dbo.KeywordsStaging SWITCH TO
    dbo.Keywords PARTITION 6
    WITH ( WAIT_AT_LOW_PRIORITY ( MAX_DURATION = 2 minutes, ABORT_AFTER_WAIT = NONE) );
GO

/* Admire our data */
SELECT COUNT(*) as newrows
FROM dbo.Keywords
WHERE CustomerId = 104;
GO


/* Deleting data: we could switch out, but...
LET'S PLAY WITH TRUNCATE! (SQL Server 2016+) */

TRUNCATE TABLE dbo.Keywords 
WITH (PARTITIONS (6));
GO

/* ALL GONE! */
SELECT COUNT(*) as newrows
FROM dbo.Keywords
WHERE CustomerId = 104;
GO



/* Online Partition level rebuild (online available SQL Server 2014+) */
--The syntax for this drives me nuts, but OK.
ALTER INDEX ix_hi on dbo.Keywords REBUILD PARTITION = 4
    WITH (ONLINE = ON
            (WAIT_AT_LOW_PRIORITY ( MAX_DURATION = 2 minutes, ABORT_AFTER_WAIT = NONE)
         )
     );
GO

/* Checking a filegroup which only holds a given partition (not the whole table) */

DBCC CHECKFILEGROUP (FG3);
GO


/* For partitioned colunnstore examples, 
check out the course "Execution Plans: Partitioned Tables & Columnstore Indexes".

It is full of demos on partition elimination, and also goes into 
rowgroup elimination for columnstore indexes and how it combines with partition
elimination 
*/
