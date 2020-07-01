/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tuning-problem-queries-in-table-partitioning

Setup:
    Download the database to restore from https://github.com/LitKnd/BabbyNames/releases/tag/v1.1
    You must download all four backup files with names like 'BabbyNames_Partitioning_1_of_4.bak.zip'.
    Unzip each file, then use them to restore the BabbyNames database.
    This database is 23GB after being restored.
    You must restore to SQL Server 2016 or a higher version.
*****************************************************************************/

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
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
WITH REPLACE;
GO

/******************************************************/
/* Create indexes for demos                           */
/******************************************************/
use BabbyNames;
GO

/* nonclustered rowstore... */
EXEC evt.logme N'Create index ix_dbo_FirstNameByBirthDate_1976_2015_BirthYear.';
GO
CREATE INDEX ix_dbo_FirstNameByBirthDate_1966_2015_BirthYear
	on dbo.FirstNameByBirthDate_1966_2015 (BirthYear)
	WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION=ROW);
GO

EXEC evt.logme N'Create index ix_pt_FirstNameByBirthDate_1976_2015_BirthYear.';
GO
CREATE INDEX ix_pt_FirstNameByBirthDate_1966_2015_BirthYear
	on pt.FirstNameByBirthDate_1966_2015 (BirthYear)
	WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION=ROW);
GO

EXEC evt.logme N'Create index ix_dbo_FirstNameByBirthDate_1966_2015_FirstNameId.';
GO

CREATE INDEX ix_dbo_FirstNameByBirthDate_1966_2015_FirstNameId
    on dbo.FirstNameByBirthDate_1966_2015 (FirstNameId)
	WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION=ROW);
GO

EXEC evt.logme N'Create index ix_pt_FirstNameByBirthDate_1966_2015_FirstNameId.';
GO

CREATE INDEX ix_pt_FirstNameByBirthDate_1966_2015_FirstNameId
    on pt.FirstNameByBirthDate_1966_2015 (FirstNameId)
	WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION=ROW);
GO



EXEC evt.logme N'Create index col_pt_FirstNameByBirthDate_1966_2015.';
GO
CREATE NONCLUSTERED COLUMNSTORE INDEX col_pt_FirstNameByBirthDate_1966_2015
	on pt.FirstNameByBirthDate_1966_2015 
	( FakeBirthDateStamp, FirstNameByBirthDateId, StateCode, FirstNameId, Gender);
GO
