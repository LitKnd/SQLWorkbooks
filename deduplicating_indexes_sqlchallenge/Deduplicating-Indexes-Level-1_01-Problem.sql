/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-deduplicate-indexes-level-1

SQLChallenge
Deduplicate Indexes: Level 1


Prereq: Download Contoso Data Warehouse sample database from:
https://www.microsoft.com/en-us/download/details.aspx?id=18279

    Download file: ContosoBIdemoBAK.exe

    Run the exe, doing so will unzip files to a directory of your choice
    Unzipped, you will have the file ContosoRetailDW.bak
    Modify the script below to restore it to a SQL Server instance


*****************************************************************************/

RAISERROR (N'🛑 Did you mean to run the whole thing? 🛑', 20, 1) WITH LOG;
GO


/****************************************************
Restore database 
****************************************************/

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

--Just to save on log size
ALTER DATABASE ContosoRetailDW SET RECOVERY SIMPLE;
GO


ALTER DATABASE ContosoRetailDW SET COMPATIBILITY_LEVEL = 140;
GO



/*****************************************************************************

CHALLENGE: DEDUPLICATING INDEXES (LEVEL 1)
🔧 SETUP 🔧

*****************************************************************************/

USE ContosoRetailDW;
GO

CREATE INDEX ix_FactInventory_InventoryKey
ON dbo.FactInventory(InventoryKey);
GO

CREATE INDEX ix_FactInventory_InventoryKey_INCLUDES
ON dbo.FactInventory(InventoryKey)
INCLUDE(MinDayInStock, MaxDayInStock);
GO

CREATE INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES
ON dbo.FactInventory(DateKey)
INCLUDE(InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost);
GO

CREATE INDEX ix_FactInventory_DateKey_INCLUDES
ON dbo.FactInventory(DateKey, InventoryKey)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);
GO

CREATE INDEX ix_FactInventory_DateKey_LoadDate_UnitCost
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity);
GO

CREATE INDEX ix_FactInventory_DateKey_LoadDate
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_LoadDate_DateKey_UnitCost
ON dbo.FactInventory(LoadDate, DateKey, UnitCost)
INCLUDE(Aging);
GO


CREATE INDEX ix_FactInventory_UnitCost_LoadDate_DateKey
ON dbo.FactInventory(UnitCost, LoadDate, DateKey)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_CurrencyKey
ON dbo.FactInventory(CurrencyKey);
GO




/*****************************************************************************

💼 CHALLENGE: DEDUPLICATE INDEXES 💼

Your task is to de-duplicate the indexes on the dbo.FactInventory table
based on their definitions only -- there's no index "usage" stats to 
consider this time.

Consider the indexes created above, along with any indexes on the table that
are restored with the database.

For indexes you choose to drop:

* List the drop command for the index
* Note any risks that are associated with dropping the index

*****************************************************************************/
