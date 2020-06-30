/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-create-an-extended-events-trace/

Setup:
    Download BabbyNames.bak.zip (42 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/1.3

This database can be restored to SQL Server 2008R2 or higher, BUT this challenge is 
SQL Server 2016+

This is the CHALLENGE File
*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/****************************************************
Restore database 
****************************************************/
SET NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER ON
GO


--Adjust drive / folder locations for the restore
USE master;
GO
IF DB_ID('BabbyNames2017') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames2017
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames2017
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames2017.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames2017_log.ldf',
        REPLACE,
        RECOVERY;
GO

ALTER DATABASE BabbyNames2017 SET QUERY_STORE = ON
GO
ALTER DATABASE BabbyNames2017 SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO
ALTER DATABASE BabbyNames2017 SET COMPATIBILITY_LEVEL = 140;
GO


/****************************************************
Set up the condition we will trace for 
****************************************************/
USE BabbyNames2017;
GO

CREATE OR ALTER PROCEDURE dbo.FreezeMe 
    @TotalNameCountLimit INT
AS
    SELECT 
	    FirstName, 
	    FirstReportYear as SoloReportYear,
	    TotalNameCount
    FROM ref.FirstName
    WHERE 
	    FirstReportYear = LastReportYear
	    and TotalNameCount > @TotalNameCountLimit
    ORDER BY TotalNameCount DESC;
GO

CREATE INDEX ix_hereandthengone on ref.FirstName (TotalNameCount) 
    INCLUDE ( FirstReportYear, LastReportYear, FirstName)
GO

EXEC dbo.FreezeMe @TotalNameCountLimit = 30;
GO

declare @qid INT, @pid INT;

SELECT TOP (1) 
    @qid = qsp.query_id, 
    @pid = qsp.plan_id
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qsq on qsp.query_id=qsq.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.FreezeMe')
    and qsp.last_force_failure_reason = 0
ORDER BY qsp.last_compile_start_time DESC;

EXEC sys.sp_query_store_force_plan @query_id=@qid, @plan_id=@pid;
GO

ALTER INDEX ix_hereandthengone on ref.FirstName DISABLE;
GO


EXEC dbo.FreezeMe @TotalNameCountLimit = 40;
GO



/****************************************************
SQLChallenge!
****************************************************/

/* We should see that one of the query plans for this object has a 
"last_force_failure_reason_desc" of NO_INDEX after the setup script.
This is what we want to get more information about. */
SELECT 
    qsp.query_id,
    qsp.plan_id,
    qsp.is_trivial_plan,
    qsp.is_forced_plan,
    qsp.last_execution_time,
    qsp.last_force_failure_reason_desc,
    cast(qsp.query_plan AS XML) as query_plan
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qsq on qsp.query_id=qsq.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.FreezeMe')
ORDER BY qsp.last_compile_start_time DESC;
GO

/* SQL Challenge: 

Set up an Extended Events trace to capture failed forced plans. 
After you have the trace running, run this command to reproduce the failed
forced plan, then review the trace to make sure it caught the incident.

Also collect the global fields: session_id, sql_text
Use an event_file target

*/


--Test your trace using these queries. 
--What appears in the trace, and what does not?
EXEC dbo.FreezeMe @TotalNameCountLimit = 10000;
GO

EXEC dbo.FreezeMe @TotalNameCountLimit = 100 WITH RECOMPILE;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;

EXEC dbo.FreezeMe @TotalNameCountLimit = 150;
GO

EXEC dbo.FreezeMe @TotalNameCountLimit = 500;
GO
