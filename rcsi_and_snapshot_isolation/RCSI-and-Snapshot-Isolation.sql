/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/read-committed-snapshot-and-snapshot-isolation/

Setup:
    Download BabbyNames.bak.zip (41 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.2

Then review and run the script below on a SQL Server 2016 dedicated test instance
    Developer Edition recommended (Enteprise and Evaluation Editions will work too)
	
*****************************************************************************/

/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/****************************************************
Restore database
****************************************************/
SET NOCOUNT ON;
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


/****************************************************
Read committed lets us read rows twice, or miss rows entirely.
Snapshot isolation to the rescue!
****************************************************/
USE BabbyNames;
GO


SELECT name, 
    is_read_committed_snapshot_on,
    snapshot_isolation_state_desc
FROM sys.databases
WHERE DB_ID() = database_id;
GO


/* As soon as this is 'ON', versioning will begin - 
even if nothing is using it */
ALTER DATABASE BabbyNames SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SELECT name, 
    is_read_committed_snapshot_on,
    snapshot_isolation_state_desc
FROM sys.databases
WHERE DB_ID() = database_id;
GO

CREATE INDEX ix_FirstName_FirstName on ref.FirstName (FirstName);
GO


--We have 95,025 names
--We're going to move the first name, 'Aaban', to the end of the index
--by updating it to 'ZZZaaban' and back repeatedly.
SELECT FirstName
FROM ref.FirstName;
GO

--Look at the plan for this query. It's using just the NC index on FirstName
SELECT COUNT(*) AS NameCount
FROM ref.FirstName;
GO

/* Uncomment and run this in another session ... */
--USE BabbyNames;
--GO
--SET NOCOUNT ON;
--GO
--UPDATE ref.FirstName SET FirstName='ZZZaaban' WHERE FirstName='Aaban';

--UPDATE ref.FirstName SET FirstName='Aaban' WHERE FirstName='ZZZaaban';

--GO 100000


/* Now count the names 2K times. This takes ~10 seconds */
/* Make sure actual plans are off :) */
/* We have enabled snapshot isolation for the database, but we aren't using it...
we are in plain old Read Committed here */
DROP TABLE IF EXISTS dbo.NameCount;
GO
CREATE TABLE dbo.NameCount ( NameCount int);
GO

DECLARE @i int = 1
WHILE @i <= 2000
BEGIN
    INSERT dbo.NameCount (NameCount)
    SELECT COUNT(*) AS NameCount
    FROM ref.FirstName;

    SET @i = @i + 1;
END
GO

/* How many names did we count? 
Reminder: there were ALWAYS the same amount of names, we were just updating the name value*/
SELECT NameCount, 
    COUNT(*) as NumberCounted
FROM dbo.NameCount
GROUP BY NameCount
ORDER BY 1;
GO


/* Now do the same reads but under SNAPSHOT */
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
GO

DROP TABLE IF EXISTS dbo.NameCount;
GO
CREATE TABLE dbo.NameCount ( NameCount int);
GO

DECLARE @i int = 1
WHILE @i <= 2000
BEGIN
    INSERT dbo.NameCount (NameCount)
    SELECT COUNT(*) AS NameCount
    FROM ref.FirstName;

    SET @i = @i + 1;
END
GO

SELECT NameCount, 
    COUNT(*) as NumberCounted
FROM dbo.NameCount
GROUP BY NameCount
ORDER BY 1;
GO


/* Reset isolation level */
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
/* Stop the updates  */

