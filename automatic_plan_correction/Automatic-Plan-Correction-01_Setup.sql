/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/automatic-plan-correction-in-query-store/

Setup:
    Download the database to restore from https://github.com/LitKnd/BabbyNames/releases/tag/v1.1
    You must download all four backup files with names like 'BabbyNames_Partitioning_1_of_4.bak.zip'.
    Unzip each file, then use them to restore the BabbyNames database.
    This database is 23GB after being restored.
    You must restore to SQL Server 2016 or a higher version.
*****************************************************************************/

--RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
--GO

exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO
exec sp_configure 'cost threshold for parallelism', 50;
GO
exec sp_configure 'max degree of parallelism', 4;
GO
RECONFIGURE
GO

/******************************************************/
/* Restore database                                   */
/******************************************************/

/****************************************************
Restore database and create and populate agg.FirstNameByYearStateWide
****************************************************/
SET NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
USE master;
GO

IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
        REPLACE,
        RECOVERY;
GO


USE master
GO
ALTER DATABASE BabbyNames SET COMPATIBILITY_LEVEL = 140
GO


/* Erin Stellato's recommendations for Query Store Settings are here: 
    https://www.sqlskills.com/blogs/erin/query-store-settings/ 
    Don't copy these settings, read Erin's post to understand how to set your own!
*/
ALTER DATABASE BabbyNames SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, 
    QUERY_CAPTURE_MODE = AUTO /* default is all, this ignores insignifiant queries */,
    MAX_PLANS_PER_QUERY = 200 /*default */,
    MAX_STORAGE_SIZE_MB = 2048 /* starter value */,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    SIZE_BASED_CLEANUP_MODE = AUTO,
    DATA_FLUSH_INTERVAL_SECONDS = 15,
    INTERVAL_LENGTH_MINUTES = 30 /* Available values: 1, 5, 10, 15, 30, 60, 1440 */,
    WAIT_STATS_CAPTURE_MODE = ON /* 2017 gets wait stats! */
    );
GO

ALTER DATABASE BabbyNames SET QUERY_STORE = ON
GO

ALTER DATABASE BabbyNames 
SET AUTOMATIC_TUNING 
    (FORCE_LAST_GOOD_PLAN = ON)
; 

USE BabbyNames;
GO
