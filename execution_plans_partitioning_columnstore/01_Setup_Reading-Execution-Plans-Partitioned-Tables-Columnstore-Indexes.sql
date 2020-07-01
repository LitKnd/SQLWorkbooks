/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: 
https://littlekendra.com/course/the-weird-wonderful-world-of-execution-plans-partitioned-tables-columnstore-indexes

Setup:
    Download the database to restore from https://github.com/LitKnd/BabbyNames/releases/tag/v1.1
    You must download all four backup files with names like 'BabbyNames_Partitioning_1_of_4.bak.zip'.
    Unzip each file, then use them to restore the BabbyNames database (edit the restore command below).
    This database is 23GB after being restored.
    You must restore to SQL Server 2016 or a higher version.
*****************************************************************************/

SET STATISTICS IO, TIME OFF;
GO
SET XACT_ABORT, NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING ON;
GO

/******************************************************/
/* Restore database                                   */
/******************************************************/
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

/* Enable Query Store */
ALTER DATABASE [BabbyNames] SET QUERY_STORE = ON
GO
ALTER DATABASE [BabbyNames] SET QUERY_STORE 
    (OPERATION_MODE = READ_WRITE, 
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 180), 
    MAX_STORAGE_SIZE_MB = 1024
    )
GO

USE BabbyNames;
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_pt_FirstNameByBirthDate_1966_2015
    ON pt.FirstNameByBirthDate_1966_2015
    (FakeBirthDateStamp, FirstNameByBirthDateId, StateCode, FirstNameId, Gender);
GO

/* Insert some fake data for 2016 in batches under the "auto compress" limit */
INSERT pt.FirstNameByBirthDate_1966_2015 (FakeBirthDateStamp, StateCode, FirstNameId, Gender)
    SELECT TOP (102399) 
        DATEADD(year,1,FakeBirthDateStamp), StateCode, FirstNameId, Gender
    FROM pt.FirstNameByBirthDate_1966_2015
    WHERE FakeBirthDateStamp >= '2015-01-01' and FakeBirthDateStamp < '2016-01-01'
GO 8

