/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/defuse-the-deadlock-sqlchallenge

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
    FROM DISK = N'S:\MSSQL\Backup\ContosoRetailDW.bak'
    WITH
        MOVE N'ContosoRetailDW2.0' TO N'S:\MSSQL\Data\ContosoRetailDW.mdf',
        MOVE N'ContosoRetailDW2.0_log' TO N'S:\MSSQL\Data\ContosoRetailDW.ldf',
        REPLACE,
        RECOVERY;
GO

ALTER DATABASE ContosoRetailDW SET QUERY_STORE = ON
GO
ALTER DATABASE ContosoRetailDW SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO



/*********************************
SQLChallenge starts here...

The challenge contains code to reproduce a deadlock.

Your challenge: 
    Create an index to prevent the deadlock from happening
    You cannot change any query text or isolation levels

Extra credit:
    Find more than one way to do it
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



