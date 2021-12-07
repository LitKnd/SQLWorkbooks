/*****************************************************************************
Copyright (c) 2021 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

Prereq: Download Contoso Data Warehouse sample database from:
https://www.microsoft.com/en-us/download/details.aspx?id=18279

Download file: ContosoBIdemoBAK.exe
Run the exe, doing so will unzip files to a directory of your choice
Unzipped, you will have the file ContosoRetailDW.bak

Modify the script below to restore it to a SQL Server instance
***********************************************************************/

RAISERROR ( 'Whoops, did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/**********************************
Instance configuration I tested with
**********************************/
exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
exec sp_configure 'cost threshold for parallelism', 50;
GO
exec sp_configure 'max degree of parallelism', 4;
GO
exec sp_configure 'max server memory (MB)', 4000;
GO
RECONFIGURE;
GO

/**********************************
Restore database 
**********************************/
SET XACT_ABORT, ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING ON;
GO
SET NOCOUNT OFF;
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
    FROM DISK = N'C:\MSSQL\BAK\ContosoRetailDW.bak'
    WITH
        MOVE N'ContosoRetailDW2.0' TO N'C:\MSSQL\Data\ContosoRetailDW.mdf',
        MOVE N'ContosoRetailDW2.0_log' TO N'C:\MSSQL\Data\ContosoRetailDW.ldf',
        REPLACE,
        RECOVERY;
GO

ALTER DATABASE ContosoRetailDW SET QUERY_STORE = ON
GO
ALTER DATABASE ContosoRetailDW SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO


/*********************************
SETTING UP AN XEVENTS TRACE
***********************************/

IF (SELECT COUNT(*) from sys.server_event_sessions where name = N'Deadlocks') > 0
	DROP EVENT SESSION [Deadlocks] ON SERVER; 
GO


CREATE EVENT SESSION [Deadlocks] ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename=N'Deadlocks')
WITH 
	(MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,
	MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION Deadlocks ON SERVER  
	STATE = start;  
GO 


/*********************************
DEADLOCK DEMO STARTS HERE
***********************************/



USE ContosoRetailDW;
GO
/* Session 1:
Run BEGIN TRAN and the first UPDATE */
BEGIN TRAN
    UPDATE dbo.DimProductCategory
    SET ProductCategoryName = N'Cellphones'
    WHERE ProductCategoryName = N'Cell phones';
/*
    UPDATE dbo.DimProductSubcategory
    SET ProductSubcategoryName = N'Cellphones Accessories'
    WHERE ProductSubcategoryName = N'Cell phones Accessories'
ROLLBACK
*/


/* Session 2:
Run this SELECT in a new session. 
Then return to Session 1
and run the commented out update
and ROLLBACK
*/
USE ContosoRetailDW;
GO
SELECT 
    COUNT(*) as OrderCount, 
    SUM(Amount) as TotalAmount
FROM dbo.V_CustomerOrders
WHERE ProductSubcategory like N'Cell%';
GO





/*************************************************************
 Solutions - Indexing
*************************************************************/
USE ContosoRetailDW;
GO

/***************************************
Door #1
***************************************/


exec sp_helpindex 'dbo.DimProductSubcategory';
GO

exec sp_BlitzIndex @SchemaName='dbo', @TableName='DimProductSubcategory';
GO

/* 
This nonclustered index defuses the deadlock, but does leave some blocking
I have chosen to "cover" the query for dbo.DimProductSubcategory
 */
CREATE INDEX ix_DimProductSubcategory_ProductSubcategoryName_INCLUDES
on dbo.DimProductSubcategory 
    (ProductSubcategoryName) INCLUDE (ProductSubcategoryKey, ProductCategoryKey);
GO

/* Clean up */
DROP INDEX ix_DimProductSubcategory_ProductSubcategoryName_INCLUDES on dbo.DimProductSubcategory;
GO




/***************************************
Door #2 
***************************************/

exec sp_helpindex 'dbo.DimProductCategory';
GO

exec sp_BlitzIndex @SchemaName='dbo', @TableName='DimProductCategory';
GO


/* This nonclustered index defuses the deadlock and removes blocking. */
CREATE INDEX ix_DimProductCategory
on dbo.DimProductCategory (ProductCategoryKey);
GO

/* Discuss: is this a "duplicate index? */


/* Clean up */
DROP INDEX ix_DimProductCategory on dbo.DimProductCategory;
GO




/*************************************************************
I don't recommend NOLOCK, but it does prevent the deadlock
*************************************************************/


USE ContosoRetailDW;
GO
/* Session 1:
Run BEGIN TRAN and the first UPDATE */
BEGIN TRAN
    UPDATE dbo.DimProductCategory
    SET ProductCategoryName = N'Cellphones'
    WHERE ProductCategoryName = N'Cell phones';
/*
    UPDATE dbo.DimProductSubcategory
    SET ProductSubcategoryName = N'Cellphones Accessories'
    WHERE ProductSubcategoryName = N'Cell phones Accessories'
ROLLBACK
*/


/* Session 2:
Run this SELECT in a new session. 
Then return to Session 1
and run the commented out update
and ROLLBACK
*/
USE ContosoRetailDW;
GO
SELECT 
    COUNT(*) as OrderCount, 
    SUM(Amount) as TotalAmount
FROM dbo.V_CustomerOrders (NOLOCK)
WHERE ProductSubcategory like N'Cell%';
GO



/*************************************************************
Snapshot isolation can be effective for existing databases
To enable this generally requires more testing and preparation than an index change

For new databases I prefer to start with Read Committed Snapshot Isolation (RCSI) enabled

https://www.littlekendra.com/2016/02/18/how-to-choose-rcsi-snapshot-isolation-levels/
*************************************************************/

ALTER DATABASE ContosoRetailDW SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SELECT 
	snapshot_isolation_state,
	snapshot_isolation_state_desc
FROM sys.databases
WHERE name= N'ContosoRetailDW';
GO


USE ContosoRetailDW;
GO
/* Session 1:
Run BEGIN TRAN and the first UPDATE */
BEGIN TRAN
    UPDATE dbo.DimProductCategory
    SET ProductCategoryName = N'Cellphones'
    WHERE ProductCategoryName = N'Cell phones';
/*
    UPDATE dbo.DimProductSubcategory
    SET ProductSubcategoryName = N'Cellphones Accessories'
    WHERE ProductSubcategoryName = N'Cell phones Accessories'
ROLLBACK
*/


/* Session 2:
Run this SELECT in a new session. 
Then return to Session 1
and run the commented out update
and ROLLBACK
*/
USE ContosoRetailDW;
GO
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
GO
SELECT 
    COUNT(*) as OrderCount, 
    SUM(Amount) as TotalAmount
FROM dbo.V_CustomerOrders (NOLOCK)
WHERE ProductSubcategory like N'Cell%';
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
