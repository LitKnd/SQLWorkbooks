/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

Setup:
    Download BabbyNames.bak.zip (41 MB zipped database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/1.3

Then review and run the script below on a SQL Server 2017 dedicated test instance
    Developer Edition recommended (Enterprise and Evaluation Editions will work too)

The script
    Restores the database (edit the file locations for your instance)
    Expands and modifies the data
        8GB data files (multiple files in a couple of filegroups)
        2GB log file
    Duration on my test instance: ~6.5 minutes
    
This requires some tempdb space to do sorts, etc. I ran with 8x 2GB tempdb files.

*****************************************************************************/

SET XACT_ABORT, NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING ON;
GO

EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO

EXEC sp_configure 'max degree of parallelism', 4;
GO

EXEC sp_configure 'cost threshold for parallelism', 5
GO

EXEC sp_configure 'max server memory (MB)', 9000;
GO

RECONFIGURE
GO


/****************************************************
Restore small BabbyNames database
****************************************************/
use master;
GO

IF DB_ID('BabbyNames') IS NOT NULL 
BEGIN
    IF (SELECT state_desc FROM sys.databases WHERE name='BabbyNames') = 'ONLINE'
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

ALTER DATABASE BabbyNames SET RECOVERY SIMPLE;
GO


ALTER DATABASE BabbyNames
    ADD FILEGROUP fg_FirstNameByBirthDate;
GO


ALTER DATABASE BabbyNames ADD FILE 
(   NAME = fg_FirstNameByBirthDate_f1,
    FILENAME = 'S:\MSSQL\Data\BabbyNames_fg_FirstNameByBirthDate_f1.ndf',
    SIZE = 2GB,
    FILEGROWTH = 512MB
) TO FILEGROUP fg_FirstNameByBirthDate;
GO

ALTER DATABASE BabbyNames ADD FILE 
(   NAME = fg_FirstNameByBirthDate_f2,
    FILENAME = 'S:\MSSQL\Data\BabbyNames_fg_FirstNameByBirthDate_f2.ndf',
    SIZE = 2GB,
    FILEGROWTH = 512MB
) TO FILEGROUP fg_FirstNameByBirthDate;
GO

ALTER DATABASE BabbyNames ADD FILE 
(   NAME = fg_FirstNameByBirthDate_f3,
    FILENAME = 'S:\MSSQL\Data\BabbyNames_fg_FirstNameByBirthDate_f3.ndf',
    SIZE = 2GB,
    FILEGROWTH = 512MB
) TO FILEGROUP fg_FirstNameByBirthDate;
GO

ALTER DATABASE BabbyNames ADD FILE 
(   NAME = fg_FirstNameByBirthDate_f4,
    FILENAME = 'S:\MSSQL\Data\BabbyNames_fg_FirstNameByBirthDate_f4.ndf',
    SIZE = 2GB,
    FILEGROWTH = 512MB
) TO FILEGROUP fg_FirstNameByBirthDate;
GO

/* Make fg_FirstNameByBirthDate the default filegroup */
ALTER DATABASE BabbyNames MODIFY FILEGROUP fg_FirstNameByBirthDate DEFAULT;  
GO  

ALTER DATABASE BabbyNames MODIFY FILE (NAME='BabbyNames_log', SIZE=2GB, FILEGROWTH=512MB);
GO

/* just in case you want to play around with Hekaton... */
ALTER DATABASE BabbyNames ADD FILEGROUP MemoryOptimizedData CONTAINS MEMORY_OPTIMIZED_DATA;
GO

--ALTER DATABASE BabbyNames 
--    ADD FILE( NAME = 'MemoryOptimizedData' , FILENAME = 'S:\MSSQL\Data\BabbyNames_MemoryOptimizedData') 
--    TO FILEGROUP MemoryOptimizedData;  
--GO  


/****************************************************
Configure database and expand data
****************************************************/

SET STATISTICS IO, TIME OFF;
GO
SET XACT_ABORT, NOCOUNT ON;
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
GO
SET NUMERIC_ROUNDABORT OFF;
GO


ALTER DATABASE BabbyNames SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, 
    QUERY_CAPTURE_MODE = ALL, /* AUTO is often best!*/
    MAX_PLANS_PER_QUERY = 200,
    MAX_STORAGE_SIZE_MB = 2048,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    SIZE_BASED_CLEANUP_MODE = AUTO,
    DATA_FLUSH_INTERVAL_SECONDS = 15,
    INTERVAL_LENGTH_MINUTES = 30,
    WAIT_STATS_CAPTURE_MODE = ON /* 2017 gets wait stats! */
    );
GO

ALTER DATABASE BabbyNames SET QUERY_STORE = ON
GO
ALTER DATABASE BabbyNames SET QUERY_STORE CLEAR ALL;
GO


ALTER DATABASE BabbyNames SET COMPATIBILITY_LEVEL=140;
GO

ALTER DATABASE BabbyNames SET TARGET_RECOVERY_TIME = 60 SECONDS;
GO

USE BabbyNames;
GO

EXEC evt.logme N'Restored small BabbyNames database';
GO

ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
GO

ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
GO



/******************************************************/
/* ref.Numbers                                        */
/******************************************************/

/* Create ref.Numbers. This is a helper "numbers" table just to help us in the next step.*/
IF SCHEMA_ID('ref') IS NULL
BEGIN
    EXEC evt.logme N'Create schema ref.';

    EXEC ('CREATE SCHEMA ref AUTHORIZATION dbo');
END
GO

EXEC evt.logme N'Create ref.Numbers.';
GO
IF OBJECT_ID('ref.Numbers','U') IS NOT NULL
BEGIN
    EXEC evt.logme N'Table ref.Numbers already exists, dropping.';

    DROP TABLE ref.Numbers;
END
GO

CREATE TABLE ref.Numbers (
    Num INT NOT NULL,
) on fg_FirstNameByBirthDate;
GO

EXEC evt.logme N'Load ref.Numbers.';
GO
INSERT ref.Numbers
    (Num)
SELECT TOP 10000000
    ROW_NUMBER() OVER (ORDER BY fn1.ReportYear)
FROM agg.FirstNameByYear AS fn1
CROSS JOIN agg.FirstNameByYear AS fn2;
GO

EXEC evt.logme N'Index and key ref.Numbers.';
GO

CREATE CLUSTERED COLUMNSTORE INDEX ccx_ref_Numbers on ref.Numbers;
GO

ALTER TABLE ref.Numbers
    ADD CONSTRAINT pk_refNumbers_Num
        PRIMARY KEY NONCLUSTERED (Num)
        ON fg_FirstNameByBirthDate;
GO


/******************************************************/
/* Helper index                                       */
/******************************************************/

EXEC evt.logme N'Create nccx_halp ON agg.FirstNameByYear.';
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_halp on agg.FirstNameByYear 
    (FirstNameId, ReportYear, NameCount, Gender)
    ON fg_FirstNameByBirthDate
GO



/******************************************************/
/* Create and load dbo.FirstNameByBirthDate           */
/******************************************************/

EXEC evt.logme N'Load dbo.FirstNameByBirthDateStage';
GO

/* This select into gets parallel insert plan, 20170906.
We set the default filegroup above so this will go into fg_FirstNameByBirthDate,
even though we can't explicitly direct it to do so until sql server 2017. */
SELECT
    ISNULL(CAST(ROW_NUMBER() OVER (ORDER BY (SELECT 'boop')) AS BIGINT),0) AS FirstNameByBirthDateId,
    DATEADD(mi,n.Num * 5.1,CAST('1/1/' + CAST(ReportYear AS CHAR(4)) AS datetime2(0))) as FakeBirthDateStamp,
    fn.StateCode,
    fn.FirstNameId,
    Gender,
    CAST(NULL AS TINYINT) as Flag1,
    CAST(NULL AS CHAR(1)) as Flag2
INTO dbo.FirstNameByBirthDateStage  ON fg_FirstNameByBirthDate /* This added in SQL Server 2017*/
FROM agg.FirstNameByYearState AS fn
CROSS APPLY (select Num from ref.Numbers where Num <= fn.NameCount) AS n
WHERE fn.ReportYear >= 1970 /* Limit size of dataset here */

    OPTION (RECOMPILE);
GO

EXEC evt.logme N'Add BirthYear computed column to  dbo.FirstNameByBirthDateStage';
GO

ALTER TABLE dbo.FirstNameByBirthDateStage
    ADD BirthYear as YEAR(FakeBirthDateStamp);
GO

EXEC evt.logme N'Create dbo.FirstNameByBirthDate, which has an identity property';
GO



CREATE TABLE dbo.FirstNameByBirthDate (
    FirstNameByBirthDateId BIGINT IDENTITY(1,1),
    FakeBirthDateStamp DATETIME2(0),
    StateCode CHAR(2) NOT NULL,
    FirstNameId INT NOT NULL,
    Gender CHAR(1) NOT NULL,
    Flag1 TINYINT NULL,
    Flag2 CHAR(1) NULL,
    BirthYear AS YEAR(FakeBirthDateStamp)
) ON fg_FirstNameByBirthDate
GO



EXEC evt.logme N'Switch data from dbo.FirstNameByBirthDateStage to dbo.FirstNameByBirthDate';
GO

ALTER TABLE dbo.FirstNameByBirthDateStage SWITCH TO dbo.FirstNameByBirthDate;
GO


EXEC evt.logme N'dbcc checkident reseed for dbo.FirstNameByBirthDateStage';
GO

DBCC CHECKIDENT ('dbo.FirstNameByBirthDate', RESEED);
GO


EXEC evt.logme N'DROP TABLE FirstNameByBirthDateStage';
GO
DROP TABLE FirstNameByBirthDateStage;
GO

EXEC evt.logme N'Create clustered PK on dbo.FirstNameByBirthDate';
GO

ALTER TABLE dbo.FirstNameByBirthDate
    ADD CONSTRAINT pk_FirstNameByBirthDate_FirstNameByBirthDateId
        PRIMARY KEY CLUSTERED (FirstNameByBirthDateId)
	WITH (SORT_IN_TEMPDB = ON, 
        DATA_COMPRESSION = ROW)
    ON fg_FirstNameByBirthDate;
GO

EXEC evt.logme N'Clean up nccx_halp ON agg.FirstNameByYear.';
GO
DROP INDEX IF EXISTS nccx_halp ON agg.FirstNameByYear;
GO


/******************************************************/
/* Foreign key constraints                            */
/******************************************************/

EXEC evt.logme N'Create FK FK_FirstNameByBirthDate_FirstNameId';
GO

ALTER TABLE dbo.FirstNameByBirthDate WITH CHECK  
ADD CONSTRAINT FK_FirstNameByBirthDate_FirstNameId FOREIGN KEY (FirstNameId) 
    REFERENCES ref.FirstName (FirstNameId);
GO



EXEC evt.logme N'Create FK FK_FirstNameByBirthDate_StateCode';
GO

ALTER TABLE dbo.FirstNameByBirthDate WITH CHECK  
ADD CONSTRAINT FK_FirstNameByBirthDate_StateCode FOREIGN KEY (StateCode) 
    REFERENCES ref.State (StateCode);
GO


CREATE NONCLUSTERED INDEX ix_FirstNameByBirthDate_Gender
    ON dbo.FirstNameByBirthDate (Gender);
GO


/******************************************************/
/*  Backup                                            */
/******************************************************/

EXEC evt.logme N'Run a full backup';
GO


BACKUP DATABASE BabbyNames
    TO DISK=N'S:\MSSQL\Data\BabbyNames_1of4.bak',
    DISK=N'S:\MSSQL\Data\BabbyNames_2of4.bak',
    DISK=N'S:\MSSQL\Data\BabbyNames_3of4.bak',
    DISK=N'S:\MSSQL\BabbyNames_4of4.bak'
    WITH INIT, COMPRESSION, STATS=5;
GO


/* Restore command (for reference) */
--use master;
--GO

--IF DB_ID('BabbyNames') IS NOT NULL
--BEGIN
--    ALTER DATABASE BabbyNames
--        SET SINGLE_USER
--        WITH ROLLBACK IMMEDIATE;
--END
--GO

--RESTORE DATABASE BabbyNames
--    FROM DISK=N'S:\MSSQL\Data\BabbyNames_1of4.bak',
--    DISK=N'S:\MSSQL\Data\BabbyNames_2of4.bak',
--    DISK=N'S:\MSSQL\Data\BabbyNames_3of4.bak',
--    DISK=N'S:\MSSQL\Data\BabbyNames_4of4.bak'
--    WITH
--        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
--        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
--        REPLACE,
--        RECOVERY;
--GO



/******************************************************/
/* All done                                           */
/******************************************************/

EXEC evt.logme N'BEEP BOOP WE ARE DONE';
GO

