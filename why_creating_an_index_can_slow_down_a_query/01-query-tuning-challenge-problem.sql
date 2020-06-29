/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/why-creating-an-index-can-make-a-query-slower

This is only suitable for test environments.
******************************************************************************/


/****************************************************************
Query Tuning Challenge
This demo was tested on a VM with 4 cores and 6GB of memory
Max Dop = 4, Max Server Memory (MB) = 5000, cost threshold = 5
****************************************************************/

/* 
Restore the Large BabbyNames sample database (option 2): https://github.com/LitKnd/BabbyNames/releases/tag/v1.1

You will need a SQL Server 2016 instance to restore this to (Developer Edition is free)
Change file locations as needed in this script...
*/
use master;
GO
IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames FROM 
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_1_of_4.bak', 
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_2_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_3_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames_Partitioning_4_of_4.bak'
	WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
		REPLACE,
		RECOVERY;
GO

/* Before you get started, create an index on the small ref.FirstName table.
This is very fast to create. */
USE BabbyNames;
GO
CREATE INDEX ix_ref_FirstName_INCLUDES on ref.FirstName (FirstName) INCLUDE (FirstNameId);
GO



/* Here's one of our queries ... */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender
GO
CREATE PROCEDURE dbo.NameCountByGender
	@FirstName varchar(256)
AS
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
	JOIN ref.FirstName as fn on
	  fnbd.FirstNameId=fn.FirstNameId
	WHERE fn.FirstName = @FirstName
	GROUP BY Gender;
GO


/* This query runs against a table that usually isn't in memory.
We're simulating "cold cache" with DBCC DROPCLEANBUFFERS.
NOTE: Not suitable for production or shared environments-- this 
	clears out the entire buffer pool (data cache) for the SQL Server instance
*/
DBCC DROPCLEANBUFFERS;
GO
SET STATISTICS TIME, IO ON;
GO
exec dbo.NameCountByGender @FirstName='Matthew';
GO
SET STATISTICS TIME, IO OFF;
GO

--(2 row(s) affected)
--Table 'FirstName'. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'FirstNameByBirthDate_1966_2015'. Scan count 5, logical reads 487945, physical reads 589, read-ahead reads 479332, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- SQL Server Execution Times:
--   CPU time = 11483 ms,  elapsed time = 4697 ms.


/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
--Turn on actual execution plans and run the query
exec dbo.NameCountByGender @FirstName='Matthew';
GO

 --Look at the actual execution plan before you add this nonclustered index.
 --Find where the execution plan is scanning dbo.FirstNameByBirthDate_1966_2015


--OK, now we create this non-clustered index.
--This is primarily created for other queries, but it happens to be on our join column for this query.
--(This will take a couple of minutes to create.)
CREATE INDEX ix_dbo_FirstNameByBirthDate_1966_2015_FirstNameId 
	on dbo.FirstNameByBirthDate_1966_2015 
	(FirstNameId)
GO

/* Cold cache - do not use on production or shared environments */
CHECKPOINT
GO
DBCC DROPCLEANBUFFERS;
GO
--Turn on actual execution plans 
SET STATISTICS TIME, IO ON;
GO
exec dbo.NameCountByGender @FirstName='Matthew';
GO
SET STATISTICS TIME, IO OFF;
GO


 --Look at the actual execution plan 
 --Find how the plan is accessing dbo.FirstNameByBirthDate_1966_2015 now

--(2 row(s) affected)
--Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'FirstNameByBirthDate_1966_2015'. Scan count 1, logical reads 7590431, physical reads 7660, read-ahead reads 415236, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'FirstName'. Scan count 1, logical reads 2, physical reads 2, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

--(1 row(s) affected)

-- SQL Server Execution Times:
--   CPU time = 7750 ms,  elapsed time = 13068 ms.


/****************************************************************
Query Tuning Challenge

1) Why did adding the non-clustered index make the query slower? What is the problem with the query?

2) Can you speed up the query WITHOUT changing, adding, or dropping any indexes? (You can change the TSQL in the procedure only.)

3) What are the risks or downsides to your solution?


****************************************************************/


