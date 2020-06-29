/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/?post_type=course&p=66294

Setup:
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.1

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

USE BabbyNames;
GO

/****************************************************
Read committed lets us read rows twice, or miss rows entirely         
****************************************************/

/* Pages and rows in the clustered index */
SELECT index_type_desc, 
    alloc_unit_type_desc, 
    index_level, 
    page_count, 
    record_count
FROM sys.dm_db_index_physical_stats 
    (DB_ID(),OBJECT_ID('ref.FirstName'), 1, NULL, 'detailed')
ORDER BY 1, 2, 3 DESC;
GO

CREATE INDEX ix_FirstName_FirstName on ref.FirstName (FirstName);
GO


/* Pages and rows in this non-clustered index */
SELECT index_type_desc, 
    alloc_unit_type_desc, 
    index_level, 
    page_count, 
    record_count
FROM sys.dm_db_index_physical_stats 
    (DB_ID(),
    OBJECT_ID('ref.FirstName'), 
    (select index_id from sys.indexes where object_id=OBJECT_ID('ref.FirstName') and name = 'ix_FirstName_FirstName'), 
    NULL, 
    'detailed')
ORDER BY 1, 2, 3 DESC;
GO


--How many names do we have?
--We're going to move the first name, 'Aaban', to the end of the index
--by updating it to 'ZZZaaban' and back repeatedly.
SELECT FirstName
FROM ref.FirstName;
GO

--Look at the plan for this query. It's using just the NC index on FirstName
SELECT COUNT(*) AS NameCount
FROM ref.FirstName;
GO

/* Which page has the row before we change the name? */
SELECT 
    sys.fn_PhysLocFormatter (%%physloc%%) as [File:Page:Slot],
    FirstName
FROM ref.FirstName WITH (INDEX(ix_FirstName_FirstName)) 
WHERE FirstName in ('Aaban', 'ZZZaaban')
GO

--File:Page:Slot	FirstName
--(1:9864:0)	Aaban


/* Update the row */
UPDATE ref.FirstName SET FirstName='ZZZaaban' WHERE FirstName='Aaban';
GO

/* Which page has the row now? */
SELECT 
    sys.fn_PhysLocFormatter (%%physloc%%) as [File:Page:Slot],
    FirstName
FROM ref.FirstName WITH (INDEX(ix_FirstName_FirstName)) 
WHERE FirstName in ('Aaban', 'ZZZaaban')
GO

--File:Page:Slot	FirstName
--(1:10115:12)	ZZZaaban


/* Update the row again */
UPDATE ref.FirstName SET FirstName='Aaban' WHERE FirstName='ZZZaaban';
GO


/* Which page has the row now? */
SELECT 
    sys.fn_PhysLocFormatter (%%physloc%%) as [File:Page:Slot],
    FirstName
FROM ref.FirstName WITH (INDEX(ix_FirstName_FirstName)) 
WHERE FirstName in ('Aaban', 'ZZZaaban')
GO


/* Uncomment and run this in another session ... */
--USE BabbyNames;
--GO
--SET NOCOUNT ON;
--GO
--UPDATE ref.FirstName SET FirstName='ZZZaaban' WHERE FirstName='Aaban';

--UPDATE ref.FirstName SET FirstName='Aaban' WHERE FirstName='ZZZaaban';

--GO 100000


/* Now count the names 10K times. This takes around a minute */
/* Make sure actual plans are off :) */
DROP TABLE IF EXISTS dbo.NameCount;
GO
CREATE TABLE dbo.NameCount ( NameCount int);
GO

DECLARE @i int = 1
WHILE @i <= 10000
BEGIN
    INSERT dbo.NameCount (NameCount)
    SELECT COUNT(*) AS NameCount
    FROM ref.FirstName;

    SET @i = @i + 1;
END
GO


/* How many names did we count? 
Reminder: there were ALWAYS the same amount names, we were just updating the name value*/
SELECT NameCount, 
    COUNT(*) as NumberCounted
FROM dbo.NameCount
GROUP BY NameCount
ORDER BY 1;
GO


/* 
Stop the updates in the other session,
Head back to the slides 
*/

