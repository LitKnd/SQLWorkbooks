/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-index-key-and-included-columns-work/

Prereq: Download Contoso Data Warehouse sample database from:
https://www.microsoft.com/en-us/download/details.aspx?id=18279

Download file: ContosoBIdemoBAK.exe
Run the exe, doing so will unzip files to a directory of your choice
Unzipped, you will have the file ContosoRetailDW.bak
Modify the script below to restore it to a SQL Server instance


Dependencies: sp_indexdetail installed in master database (optional)
    https://gist.github.com/LitKnd/c0c40bc32a41f318f824edba4237d888

***********************************************************************/

RAISERROR ( 'Whoops, did you mean to run the whole thing?', 20, 1) WITH LOG;
GO



/**********************************
Restore database 
**********************************/
SET XACT_ABORT, ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING ON;
GO
SET NOCOUNT ON;
GO
USE master;
GO

IF DB_ID('ContosoRetailDW') IS NOT NULL
BEGIN
	ALTER DATABASE ContosoRetailDW
	SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

	DROP DATABASE ContosoRetailDW;
END

RESTORE DATABASE ContosoRetailDW
    FROM DISK = N'S:\MSSQL\Backup\ContosoRetailDW.bak'
    WITH
        MOVE N'ContosoRetailDW2.0' TO N'S:\MSSQL\Data\ContosoRetailDW.mdf',
        MOVE N'ContosoRetailDW2.0_log' TO N'S:\MSSQL\Data\ContosoRetailDW.ldf',
        REPLACE,
        RECOVERY;
GO

/* Configure Query Store, in case it comes in handy.*/
USE master;
GO
ALTER DATABASE ContosoRetailDW SET QUERY_STORE = ON;
GO
ALTER DATABASE ContosoRetailDW SET QUERY_STORE 
    (OPERATION_MODE = READ_WRITE, DATA_FLUSH_INTERVAL_SECONDS = 300, INTERVAL_LENGTH_MINUTES = 10);
GO
ALTER DATABASE ContosoRetailDW SET RECOVERY SIMPLE;
GO


/*************************************************************
INDEX STRUCTURE DEMO
*************************************************************/

USE ContosoRetailDW;
GO

/* We'll be looking at the dbo.DimEmployee table */
SELECT 
    EmployeeKey, 
    ParentEmployeeKey, 
    FirstName, LastName, MiddleName, Title, 
    HireDate, BirthDate, EmailAddress, Phone, 
    MaritalStatus, EmergencyContactName, EmergencyContactPhone, 
    SalariedFlag, Gender, PayFrequency, BaseRate, 
    VacationHours, CurrentFlag, SalesPersonFlag,
    DepartmentName, StartDate, EndDate, 
    Status, ETLLoadID, LoadDate, UpdateDate
FROM dbo.DimEmployee;
GO


--sp_helpindex is far from perfect, it doesn't even give us
--included columns for nonclustered indexes.
--But it's an easy way to see the number of indexes on the table
exec sp_helpindex 'dbo.DimEmployee';
GO



/* Let's create a nonclustered index */
CREATE NONCLUSTERED INDEX ix_DimEmployee_LastName_FirstName_EmployeeKey_INCLUDES 
    ON dbo.DimEmployee (LastName, FirstName, EmployeeKey)  /* 3 key columns */
        INCLUDE (MiddleName, EmergencyContactName, [Status]) /* 3 included columns */

        /* DANGER DANGER!
        I am creating this with a very low fillfactor to allow a limited number
        of rows per page. This would be very bad for performance in the real world */
        WITH (FILLFACTOR=1);
GO



--Let's get fancier and look at the metadata this time.
--https://gist.github.com/LitKnd/c0c40bc32a41f318f824edba4237d888
--Get the index_id
EXEC sp_indexdetails @tablename='DimEmployee';
GO


/**********************************
View the index physical stats from sys.dm_db_index_physical_stats

Page space used is very low at level 0 because I told it to leave pages 99% empty...
    That was NOT a good thing to do for anything other than this demo
**********************************/
SELECT index_level,
	page_count, 
	cast(page_count*8./1024. as numeric (10,1)) as size_MB, 
	cast(avg_fragmentation_in_percent as numeric (4,1)) as avg_fragmentation_in_percent, 
	cast(avg_page_space_used_in_percent  as numeric (4,1)) as avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(
    DB_ID(), 
    OBJECT_ID('dbo.DimEmployee'),
    28 /* IndexId */,
    NULL /* PartitionId */, 
    'detailed' /* Mode */)
ORDER BY 1 DESC;
GO




/**********************************
Let's get the page number of the root page, at index level 2
sys.dm_db_database_page_allocations was added in SQL Server 2012,
    it is not officially documented.
Be careful running it against large tables in production
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
    OBJECT_ID('dbo.DimEmployee'), 
    28 ,
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

/* ROOT PAGE */
/*         Database    File# Page# DumpStyle*/
DBCC PAGE ('ContosoRetailDW', 1, 158457, 3);
GO


/*INTERMEDIATE - first page (of two) 
Look at the sort order of the key columns
    for LastName = Alexander

There are 186 ChildPageIds
*/
DBCC PAGE ('ContosoRetailDW', 1, 158288, 3);
GO

/*INTERMEDIATE - second page (of two)
The root page had this key column listed with this page number,
do you see it? 
    LastName (key)	FirstName (key)	EmployeeKey (key)
    Sajjateerakool	Suriya	        38

This page has fewer child pages, only 58. 
*/
DBCC PAGE ('ContosoRetailDW', 1, 158456, 3);
GO


/* Let's move a row. 
Sajjateerakool,	Suriya is currently the first listing on the second
    page in index level 1*/

UPDATE dbo.DimEmployee
    SET LastName = 'Aaa-Sajjateerakool'
    WHERE EmployeeKey = 38;
GO

/* Explore:
    Does this change information on root and intermediate pages?
    Can you find the page for Aaa-Sajjateerakool, Suriya?
    Look at the page where Sajjateerakool, Suriya used to be.
*/

/*LEAF PAGE (level 0) - sample 1 
    Look, we have included columns on this page!
*/
DBCC PAGE ('ContosoRetailDW', 1, 158450, 3);
GO
--PageId 158449
-- 158450



/*Level 0 (leaf) - sample 2*/
DBCC PAGE ('ContosoRetailDW', 1, 158248, 3);
GO



/* What if we make this page empty, by moving Karolina?
    Run this, then scroll back up and look at the index structure again */
UPDATE dbo.DimEmployee
    SET LastName = 'Aaa-Salas-Szlejter'
    WHERE EmployeeKey = 64;
GO


/* What if I update an included column, such as middle name? 
Included columns are only on the leaf level, and are not sorted.
Note the Row Size = 108 for Karolina  */
UPDATE dbo.DimEmployee
    SET MiddleName = 'Arbitrary Middle Name'
    WHERE EmployeeKey = 64;
GO


/* Quick reminder:
    We have so many pages in the leaf in this case because
    I set a (crazy) fillfactor of 1%.
    Fillfactor only applies to the leaf.

    Yes, we do have more data in the leaf because there are included
        columns as well as key columns, but it would not require
        243 pages if I hadn't set such a low fillfactor.
*/



/* Let's rebuild the index and allow more rows per page.
This is useful for demos later, because SQL Server considers the page count
    when choosing indexes during optimization.
*/
ALTER INDEX ix_DimEmployee_LastName_FirstName_EmployeeKey_INCLUDES 
    ON dbo.DimEmployee
    REBUILD
        /* This is still a low fill. I'd leave this one at 100. */
        WITH (FILLFACTOR=80);
GO


/* Now what does my index structure look like? */
SELECT index_level,
	page_count, 
	cast(page_count*8./1024. as numeric (10,1)) as size_MB, 
	cast(avg_fragmentation_in_percent as numeric (4,1)) as avg_fragmentation_in_percent, 
	cast(avg_page_space_used_in_percent  as numeric (4,1)) as avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(
    DB_ID(), 
    OBJECT_ID('dbo.DimEmployee'),
    28 /* IndexId */,
    NULL /* PartitionId */, 
    'detailed' /* Mode */)
ORDER BY 1 DESC;
GO

SELECT 
    allocated_page_file_id,
    page_level, 
    page_type_desc,
    allocated_page_page_id,
    previous_page_page_id,
    next_page_page_id
FROM sys.dm_db_database_page_allocations(
    DB_ID(), 
    OBJECT_ID('dbo.DimEmployee'), 
    28 ,
    NULL, 
    'detailed')
WHERE 
    is_allocated=1
    and page_type = 2 /* Index pages, not talking about IAM_PAGEs today*/
ORDER BY 1, 2 DESC, 3, 4
GO


/* ROOT PAGE - level 1 */
DBCC PAGE ('ContosoRetailDW', 1, 158584, 3);
GO

/* LEAF PAGE - level 0 */
DBCC PAGE ('ContosoRetailDW', 1, 158544, 3);
GO

DBCC PAGE ('ContosoRetailDW', 1, 158552, 3);
GO

DBCC PAGE ('ContosoRetailDW', 1, 158553, 3);
GO

DBCC PAGE ('ContosoRetailDW', 1, 158554, 3);
GO


/* Back to the slides for some quick diagrams */



/*************************************************************
SEEKS
*************************************************************/

--Reminder: our index keys and included columns are defined as:

--CREATE NONCLUSTERED INDEX ix_DimEmployee_LastName_FirstName_EmployeeKey_INCLUDES 
--    ON dbo.DimEmployee (LastName, FirstName, EmployeeKey) 
--        INCLUDE (MiddleName, EmergencyContactName, [Status])

/*
Turn on actual plans.
How many logical reads did we do on the seek?
*/

SELECT FirstName, MiddleName, LastName,
    EmergencyContactName, [Status]
FROM dbo.DimEmployee
WHERE LastName = N'Czernek';
GO




/* What were the pages?
Let's trace it!
Get your session id here... */
SELECT @@SPID as session_id;
GO

/* I'm using a 'debug' event.
Be careful... in anything other than a test environment,
this could spew out a ton of data and impact performance */
CREATE EVENT SESSION buf_latch_acquired ON SERVER 
ADD EVENT sqlserver.latch_acquired(
    ACTION(sqlserver.session_id,sqlserver.sql_text)
    WHERE (
        package0.equal_uint64(sqlserver.session_id,(52))  /* Set your SPID here */
        AND class=(28) /* Buffer latches only */
        AND [mode]=(2) /* mode = SH */
        )
      )
ADD TARGET package0.event_file(SET filename=N'S:\XEvents\debug-buf-latch-acquired.xel')
WITH (MAX_DISPATCH_LATENCY=3 SECONDS)  /* Lowered this just for demo purposes */
GO



ALTER EVENT SESSION buf_latch_acquired ON SERVER STATE = START;
GO

SELECT FirstName, MiddleName, LastName,
    EmergencyContactName, [Status]
FROM dbo.DimEmployee
WHERE LastName = N'Czernek';
GO

ALTER EVENT SESSION buf_latch_acquired ON SERVER STATE = STOP;
GO

/* Review the trace results */


/* Root page... 
    find the page for LastName = N'Czernek', does it match the trace? */
DBCC PAGE ('ContosoRetailDW', 1, 158584, 3);
GO
/* Leaf page */
DBCC PAGE ('ContosoRetailDW', 1, 158552, 3);
GO



/* 
What if we are trying to search on a key column that is not the leading column?
Everything is sorted primarily by LastName

Run this with actual plans on.
Look at the index, predicate, and logial reads. */
SELECT FirstName, MiddleName, LastName,
    EmergencyContactName, [Status]
FROM dbo.DimEmployee
WHERE FirstName = N'Pawel';
GO


/* What pages does it read? */
ALTER EVENT SESSION buf_latch_acquired ON SERVER STATE = START;
GO

SELECT FirstName, MiddleName, LastName,
    EmergencyContactName, [Status]
FROM dbo.DimEmployee
WHERE FirstName = N'Pawel';
GO

ALTER EVENT SESSION buf_latch_acquired ON SERVER STATE = STOP;
GO


/* Review the trace results */


/* Root page...  */
DBCC PAGE ('ContosoRetailDW', 1, 187, 2);
GO




/* Sometimes you may see a buffer latch page related to query store. */
DBCC PAGE ('ContosoRetailDW', 1, 93078, 3);
GO
DBCC PAGE ('ContosoRetailDW', 1, 158584, 3);
GO
select OBJECT_NAME (74);
GO



/*
What if we are trying to search on an included column?
It is only in the leaf of the index */
SELECT FirstName, MiddleName, LastName,
    EmergencyContactName, [Status]
FROM dbo.DimEmployee
WHERE [Status] <> 'Current'
GO



DROP EVENT SESSION buf_latch_acquired ON SERVER;
GO
