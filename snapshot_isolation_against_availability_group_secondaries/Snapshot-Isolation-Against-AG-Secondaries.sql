/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/snapshot-isolation-against-availability-group-secondaries/


This demo uses the free ContosoRetailDW sample database from Microsoft
Download it here:
https://www.microsoft.com/en-us/download/details.aspx?id=18279

This database has been restored, then configured in an Availability Group with
	a readable secondary.


WARNING: This script uses multiple anti-patterns and undocumented commands
which are not suitable, supported, or OK for production environments,
or anywhere you care about the data!
*****************************************************************************/

/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*****************************************************************************

--Basic restore 
--This script assumes the database has been removed from the AG
--You can add this to the AG using the GUI and the automatic seeding feature (not a huge database)
--There is an option in the GUI to script that out if you'd like to play around with it via scripting

--If it's your first time setting things up and seeding fails, check your SQL Server Error logs first --
--There may be something simple like a permissions issue against an endpoint you can resolve


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

ALTER DATABASE ContosoRetailDW SET RECOVERY FULL;
GO

BACKUP DATABASE ContosoRetailDW to disk = N'S:\MSSQL\Backup\ContosoFull_AGSetup.bak'
	WITH COMPRESSION, INIT;
GO

*****************************************************************************/

/******************************************************************************
--Preparation:
--Set the recovery model of ContosoRetailDW to 150
--Back up the log on ContosoRetailDW (the way I do it here is a huge antipattern)
--Shrink the log (approximate size is fine)


ALTER DATABASE ContosoRetailDW SET COMPATIBILITY_LEVEL = 140
GO

ALTER DATABASE ContosoRetailDW MODIFY FILE ( NAME = N'ContosoRetailDW2.0_log', FILEGROWTH = 256)
GO

--THIS IS A BAD LOG BACKUP COMMAND
--It writes over the same file with init, effectively breaking my log chain
BACKUP LOG ContosoRetailDW TO DISK = N'S:\MSSQL\BACKUP\ContosoRetailDW.trn' with INIT;
GO

USE ContosoRetailDW;
GO

--This may need to be run multiple times due to the nature of shrinkfile
DBCC SHRINKFILE ([ContosoRetailDW2.0_log], 1024)
GO

DBCC SQLPERF ('logspace');
GO
******************************************************************************/








/********************************************************************
*********************************************************************
DEMO 1:
AUTOMATIC ESCALATION TO SNAPSHOT ISOLATION ON READABLE SECONDARY

*********************************************************************
********************************************************************/



/********************************************************************
 RUN QUERIES IN THIS SECTION AGAINST THE SECONDARY REPLICA                         
 ********************************************************************/

/* What do things look like in sys.databases? 
Can we tell we'll be using snapshot isolation against
ContostoRetailDW? */
SELECT 
	name, 
	compatibility_level,
	user_access_desc,
	is_read_only,
	is_read_committed_snapshot_on,
	snapshot_isolation_state_desc,
	is_query_store_on,
	rs.is_local,
	rs.role_desc,
	rs.operational_state_desc,
	rs.synchronization_health_desc
FROM sys.databases AS db
LEFT JOIN sys.dm_hadr_availability_replica_states as rs on
	db.replica_id = rs.replica_id
WHERE database_id > 4
GO



USE ContosoRetailDW
GO

/* What does our isolation level look like here? 
We haven't explicitly set our isolation level.*/
DBCC USEROPTIONS;
GO


--In another session against the secondary...
--Open a transaction, and leave it open
USE ContosoRetailDW;
GO
BEGIN TRAN

	SELECT COUNT(*)
	FROM dbo.FactOnlineSales
	WHERE DateKey = '2007-01-01 00:00:00.000'

--COMMIT





-- Look at the isolation level here for that session
-- sp_WhoIsActive is a free diagnostic proc from Adam Machanic
-- Get it at whoisactive.com
exec sp_WhoIsActive @get_additional_info = 1;
GO



--Connect to the primary replica, and start this transaction
--This updates all the rows we counted in our open transaction on the secondary
USE ContosoRetailDW;
GO
BEGIN TRAN
	UPDATE dbo.FactOnlineSales
	SET DateKey = '2005-01-01 00:00:00.000'
	WHERE DateKey = '2007-01-01 00:00:00.000'

--COMMIT




--Rerun the count(*) query with the open transaction
--against the readable secondary
--What does it count?


--What if I count them here?
SELECT COUNT(*)
FROM dbo.FactOnlineSales
WHERE DateKey = '2007-01-01 00:00:00.000';
GO


--What if I use a NOLOCK hint?
SELECT COUNT(*)
FROM dbo.FactOnlineSales WITH (NOLOCK)
WHERE DateKey = '2007-01-01 00:00:00.000';
GO



--How many rows are in my version store?
--There can be a delay in seeing everything in this diagnostic view
--Eventually there will be 11,242 - 
--Check after you commit the UPDATE statement against the primary below
--Note: in a production environment, this may produce a LOT of rows
--and impact performance if you look at this level of detail
SELECT
	transaction_sequence_num,
	version_sequence_num
FROM sys.dm_tran_version_store
WHERE database_id = DB_ID('ContosoRetailDW')
ORDER BY version_sequence_num DESC;
GO



--Now commit the UPDATE against the primary replica
--Leave the transaction running against the secondary open



--Rerun the count against the open transaction


--What count do we see here?
--We don't have an open transaction, so we should see the CURRENT committed deletes
SELECT COUNT(*)
FROM dbo.FactOnlineSales
WHERE DateKey = '2007-01-01 00:00:00.000';
GO



--What does my old friend DBCC OPENTRAN have to say about open 
--transactions in this readable secondary?
DBCC OPENTRAN;
GO


/* How about sys.dm_tran_database_transactions?*/
select transaction_id,
	database_transaction_begin_time,
	database_transaction_type,
	database_transaction_state
FROM sys.dm_tran_database_transactions 
WHERE database_id = DB_ID('ContosoRetailDW');
GO

/* database_transaction_begin_time 
	"Time at which the database became involved in the transaction. 
	Specifically, it is the time of the first log record in the database for the transaction."

database_transaction_type - "1 = Read/write transaction"

database_transaction_state "
	3 = The transaction has been initialized but has not generated any log records
	4 = The transaction has generated log records."

https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-database-transactions-transact-sql?view=sql-server-2017
*/


/* How about sys.dm_tran_active_snapshot_database_transactions? */
select 
	transaction_id,
	session_id,
	is_snapshot,
	elapsed_time_seconds
from sys.dm_tran_active_snapshot_database_transactions;
GO

/* Whew! OK, that makes sense.
Queries against readable secondaries are automatically escalated to snapshot isolation

We can see active snapshot transactions against a readable secondary,
including their duration with sys.dm_tran_active_snapshot_database_transactions;

*/

/* We also have performance counters to help with this
'Longest Transaction Running Time' typically updates every ~60 seconds
*/
SELECT *
FROM sys.dm_os_performance_counters
WHERE object_name like 'MSSQL$DEV:Transactions%';
GO





/********************************************************************
*********************************************************************
DEMO:
Watermark for ghosts

*********************************************************************
********************************************************************/

--Run in another session against the secondary
USE ContosoRetailDW;
GO
BEGIN TRAN
	SELECT COUNT(*)
	FROM dbo.FactOnlineSales
	WHERE DateKey in ( '2007-01-01 00:00:00.000',  '2005-01-01 00:00:00.000');
--COMMIT



/*****************************************************
This section run against the primary 
*****************************************************/
USE ContosoRetailDW;
GO

INSERT dbo.FactOnlineSales (DateKey, StoreKey, ProductKey, PromotionKey, CurrencyKey, CustomerKey, SalesOrderNumber, SalesOrderLineNumber, SalesQuantity, SalesAmount, ReturnQuantity, ReturnAmount, DiscountQuantity, DiscountAmount, TotalCost, UnitCost, UnitPrice, ETLLoadID, LoadDate, UpdateDate)
SELECT '2005-02-01 00:00:00.000' as DateKey, 
	StoreKey, ProductKey, PromotionKey, CurrencyKey, CustomerKey, SalesOrderNumber, SalesOrderLineNumber, SalesQuantity, SalesAmount, ReturnQuantity, ReturnAmount, DiscountQuantity, DiscountAmount, TotalCost, UnitCost, UnitPrice, ETLLoadID, LoadDate, UpdateDate
FROM dbo.FactOnlineSales
WHERE DateKey = '2009-01-29 00:00:00.000';
GO

--Generate some ghosts
DELETE dbo.FactOnlineSales
WHERE DateKey = '2005-02-01 00:00:00.000';
GO


/* low_water_mark_for_ghosts = "A monotonically increasing number for the database indicating a low water mark used by ghost cleanup on the primary database. 
	If this number is not increasing over time, it implies that ghost cleanup might not happen. 
	To decide which ghost rows to clean up, the primary replica uses the minimum value of this column 
	for this database across all availability replicas (including the primary replica).

https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-hadr-database-replica-states-transact-sql?view=sql-server-2017
*/
SELECT 
	db.[name] as database_name,
	r.replica_server_name,
	drs.low_water_mark_for_ghosts,
	drs.is_primary_replica,
	drs.is_local,
	drs.synchronization_state_desc,
	drs.last_hardened_lsn,
	drs.last_commit_lsn,
	drs.last_commit_time,
	drs.secondary_lag_seconds
FROM sys.dm_hadr_database_replica_states as drs
JOIN sys.databases as db on drs.database_id=db.database_id
JOIN sys.availability_replicas as r on drs.replica_id = r.replica_id
ORDER BY drs.is_primary_replica DESC;
GO



/* 
Now commit the open read transaction against the readable secondary
Check the low watermark again
*/



/********************************************************************
CLEANUP                      
 ********************************************************************/

/* Run this against the primary to reset back to the original data and schema.*/
USE ContosoRetailDW;
GO
UPDATE dbo.FactOnlineSales
SET DateKey = '2007-01-01 00:00:00.000'
WHERE DateKey = '2005-01-01 00:00:00.000';
GO

DROP INDEX IF EXISTS ix_FactOnlineSales_DateKey
on dbo.FactOnlineSales;
GO

--THIS IS A BAD LOG BACKUP COMMAND
--It writes over the same file with init, effectively breaking my log chain
BACKUP LOG ContosoRetailDW TO DISK = N'S:\MSSQL\BACKUP\ContosoRetailDW.trn' with INIT;
GO
