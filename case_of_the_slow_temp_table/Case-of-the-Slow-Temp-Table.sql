/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/the-case-of-the-slow-temp-table-a-performance-tuning-problem

***********************************************************************/

/* Doorstop*/
RAISERROR('Did you mean to run the whole thing?', 20,1) WITH LOG;
GO




/**********************************
Configure instance.
These aren't "best practice" settings- just appropriate for this small-scale demo
**********************************/
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

RECONFIGURE
GO

/**********************************
Recreate database 
**********************************/
USE master;
GO

IF DB_ID('ModTest') IS NOT NULL
BEGIN
	ALTER DATABASE ModTest
	SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

	DROP DATABASE ModTest;
END

CREATE DATABASE ModTest;
GO

USE master
GO
ALTER DATABASE ModTest SET QUERY_STORE = ON
GO
ALTER DATABASE ModTest SET QUERY_STORE (OPERATION_MODE = READ_WRITE, DATA_FLUSH_INTERVAL_SECONDS = 300, INTERVAL_LENGTH_MINUTES = 10)
GO

USE ModTest;
GO

/****************************************************
1. Set up test procedures 
Compare duration for each test ....
****************************************************/

/* dbo.UserDatabaseTableTest
        Creates a user table if it doesn't exists
        Adds 1 million rows
        Updates the number of rows specific in the parameter
        Prints the duration of that update to the messages tab
*/

DROP PROCEDURE IF EXISTS dbo.UserDatabaseTableTest;
GO
CREATE PROCEDURE dbo.UserDatabaseTableTest 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    DROP TABLE IF EXISTS dbo.UserDatabaseTable;

    CREATE TABLE dbo.UserDatabaseTable (
	RowID INT IDENTITY(1,1),
	CharColumn CHAR(500) NOT NULL,
    CONSTRAINT PK_UserDatabaseTablePK PRIMARY KEY CLUSTERED (RowID)
    );

    RAISERROR('Add one million rows to user table...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT dbo.UserDatabaseTable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows in user table...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    UPDATE dbo.UserDatabaseTable SET CharColumn = 'bar'
    WHERE RowID <= @RowID;

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of user table (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO



EXEC dbo.UserDatabaseTableTest @RowID = 800000;
GO






/* dbo.TempTableTest
        Creates a temp table
        Adds 1 million rows
        Updates the number of rows specified in the parameter
        Prints the duration of that update to the messages tab
*/
DROP PROCEDURE IF EXISTS dbo.TempTableTest;
GO
CREATE PROCEDURE dbo.TempTableTest 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    CREATE TABLE #TempTable (
	RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	CharColumn CHAR(500) NOT NULL
    );

    RAISERROR('Add one million rows to #TempTable...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT #TempTable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows #TempTablee...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    UPDATE #TempTable SET CharColumn = 'bar'
    WHERE RowID <= @RowID;

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of #TempTable (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO

EXEC dbo.TempTableTest @RowID = 800000;
GO





/* dbo.TableVariableTest
        Creates a table variable
        Adds 1 million rows
        Updates the number of rows specified in the parameter
        Prints the duration of that update to the messages tab
*/
DROP PROCEDURE IF EXISTS dbo.TableVariableTest;
GO
CREATE PROCEDURE dbo.TableVariableTest 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    DECLARE  @TableVariable TABLE (
	RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	CharColumn CHAR(500) NOT NULL
    );

    RAISERROR('Add one million rows to @TableVariable...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT @TableVariable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows in @TableVariable...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    UPDATE @TableVariable SET CharColumn = 'bar'
    WHERE RowID <= @RowID;

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of @TableVariable (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO

EXEC dbo.TableVariableTest @RowID = 800000;
GO





/* dbo.TableVariableTestRECOMPILE
        Creates a table variable
        Adds 1 million rows
        Updates the number of rows specified in the parameter with OPTION RECOMPILE
        Prints the duration of that update to the messages tab
*/

DROP PROCEDURE IF EXISTS dbo.TableVariableTestRECOMPILE;
GO
CREATE PROCEDURE dbo.TableVariableTestRECOMPILE 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    DECLARE  @TableVariable TABLE (
	RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	CharColumn CHAR(500) NOT NULL
    );

    RAISERROR('Add one million rows to @TableVariable...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT @TableVariable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows in @TableVariable...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    UPDATE @TableVariable SET CharColumn = 'bar'
    WHERE RowID <= @RowID OPTION (RECOMPILE);

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of @TableVariable (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO


EXEC dbo.TableVariableTestRECOMPILE @RowID = 800000;
GO



/****************************************************
2. Compare Statistics IO for each test ....
****************************************************/

SET STATISTICS IO ON;
GO

EXEC dbo.UserDatabaseTableTest @RowID = 800000;
GO

EXEC dbo.TempTableTest @RowID = 800000;
GO

EXEC dbo.TableVariableTest @RowID = 800000;
GO

EXEC dbo.TableVariableTestRECOMPILE @RowID = 800000;
GO

SET STATISTICS IO OFF;
GO



/**** Back to the slides ****/










/****************************************************
3. Compare the execution plans 
For each:
    Run with actual plan
    Look at Actual IO Statistics in the actual plan
****************************************************/


EXEC dbo.UserDatabaseTableTest @RowID = 800000 WITH RECOMPILE;
GO

EXEC dbo.TempTableTest @RowID = 800000 WITH RECOMPILE;
GO

EXEC dbo.TableVariableTest @RowID = 800000 WITH RECOMPILE;
GO

EXEC dbo.TableVariableTestRECOMPILE @RowID = 800000 WITH RECOMPILE;
GO






/* What if we update far fewer rows? Can we get the 'narrow' plan?
These are going to be faster because we're doing a MUCH smaller update.
What we're interested in is the plan differences (especially on the "slow" queries)
Run with actual plans */
EXEC dbo.UserDatabaseTableTest @RowID = 8000 WITH RECOMPILE;
GO

EXEC dbo.TempTableTest @RowID = 8000 WITH RECOMPILE;
GO

EXEC dbo.TableVariableTest @RowID = 8000 WITH RECOMPILE;
GO

EXEC dbo.TableVariableTestRECOMPILE @RowID = 8000 WITH RECOMPILE;
GO

/* phooey */
EXEC dbo.TableVariableTestRECOMPILE @RowID = 1 WITH RECOMPILE;
GO


/**** Back to the slides ****/






/****************************************************
4. What if it's a batch of TSQL, not a proc?
****************************************************/


--UserDatabaseTableTest
--Run once to look at duration and stats io (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
DECLARE @RowID INT = 800000;
DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

DROP TABLE IF EXISTS dbo.UserDatabaseTable;

CREATE TABLE dbo.UserDatabaseTable (
RowID INT IDENTITY(1,1),
CharColumn CHAR(500) NOT NULL,
CONSTRAINT PK_UserDatabaseTablePK PRIMARY KEY CLUSTERED (RowID)
);

RAISERROR('Add one million rows to user table...', 1, 1) WITH NOWAIT;
--This query adapted from pattern attributed 
--to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
INSERT dbo.UserDatabaseTable (CharColumn ) 
SELECT TOP (1000000) 'foo' FROM e6;

RAISERROR('Update rows in user table...', 1, 1) WITH NOWAIT;
SELECT @t1 = SYSDATETIME();

UPDATE dbo.UserDatabaseTable SET CharColumn = 'bar'
WHERE RowID <= @RowID;

SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

SET @msg = 'Duration of update of user table (ms): ' + CAST(@Durationms as nvarchar(10));
RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO
SET STATISTICS IO OFF;
GO


--TempTableTest
--Run once to look at duration (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
DECLARE @RowID INT = 800000;
DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

DROP TABLE IF EXISTS #TempTable;

CREATE TABLE #TempTable (
RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
CharColumn CHAR(500) NOT NULL
);

RAISERROR('Add one million rows to #TempTable...', 1, 1) WITH NOWAIT;
--This query adapted from pattern attributed 
--to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
INSERT #TempTable (CharColumn ) 
SELECT TOP (1000000) 'foo' FROM e6;

RAISERROR('Update rows #TempTablee...', 1, 1) WITH NOWAIT;
SELECT @t1 = SYSDATETIME();

UPDATE #TempTable SET CharColumn = 'bar'
WHERE RowID <= @RowID;

SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

SET @msg = 'Duration of update of #TempTable (ms): ' + CAST(@Durationms as nvarchar(10));
RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO
SET STATISTICS IO OFF;
GO



--TableVariableTest
--Run once to look at duration (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
DECLARE @RowID INT = 800000;
DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

DECLARE  @TableVariable TABLE (
RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
CharColumn CHAR(500) NOT NULL
);

RAISERROR('Add one million rows to @TableVariable...', 1, 1) WITH NOWAIT;
--This query adapted from pattern attributed 
--to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
INSERT @TableVariable (CharColumn ) 
SELECT TOP (1000000) 'foo' FROM e6;

RAISERROR('Update rows in @TableVariable...', 1, 1) WITH NOWAIT;
SELECT @t1 = SYSDATETIME();

UPDATE @TableVariable SET CharColumn = 'bar'
WHERE RowID <= @RowID;

SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

SET @msg = 'Duration of update of @TableVariable (ms): ' + CAST(@Durationms as nvarchar(10));
RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO
SET STATISTICS IO OFF;
GO


--TableVariableTestRECOMPILE
--Run once to look at duration (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
DECLARE @RowID INT = 800000;
DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

DECLARE  @TableVariable TABLE (
RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
CharColumn CHAR(500) NOT NULL
);

RAISERROR('Add one million rows to @TableVariable...', 1, 1) WITH NOWAIT;
--This query adapted from pattern attributed 
--to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
WITH e1(n) AS
(
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
), 
e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
INSERT @TableVariable (CharColumn ) 
SELECT TOP (1000000) 'foo' FROM e6;

RAISERROR('Update rows in @TableVariable...', 1, 1) WITH NOWAIT;
SELECT @t1 = SYSDATETIME();

UPDATE @TableVariable SET CharColumn = 'bar'
WHERE RowID <= @RowID OPTION (RECOMPILE);

SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

SET @msg = 'Duration of update of @TableVariable (ms): ' + CAST(@Durationms as nvarchar(10));
RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO
SET STATISTICS IO OFF;
GO



/**** Back to the slides ****/












/****************************************************
Extra: Fixes that don't work... Query Store forcing & Plan Guide Freezing
****************************************************/
--Note: the fact that this doesn't work isn't specific to a temp table.
--See: https://sqlworkbooks.com/2017/11/attempting-to-force-a-narrow-plan-on-an-update-with-query-store/

/* 1) Force the narrow plan with Query Store... (?) */

/* Open "Top Resources Consumers" built in report
Switch top left quadrant to grid format
Find the update query in TempTableTest
Freeze the "fast plan"
*/

/* Run with plans on
How can you tell it was forced in the plan? 
Did it work?*/
EXEC dbo.TempTableTest @RowID = 800000 WITH RECOMPILE;
GO


/* Note: you cannot enable Query Store for the tempdb database.*/
/* Remove the "force" */





/* 2. What about a plan guide? */
EXEC sp_recompile 'dbo.TempTableTest';
GO

EXEC dbo.TempTableTest @RowID = 8000;
GO

/* We need the plan_handle and the statement start offset for the query 
whose plan we want to freeze */
SELECT
    qs.plan_handle,
    qs.statement_start_offset,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END 
            - qs.statement_start_offset)/2) + 1) AS [query_text],
    qs.execution_count,
    qs.creation_time,
    qs.total_worker_time,
    qs.total_logical_reads,
    qs.total_elapsed_time,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text (plan_handle) as st
CROSS APPLY sys.dm_exec_query_plan (plan_handle) AS qp
WHERE st.text like '%UPDATE #TempTable%'
    OPTION (RECOMPILE);
GO

/* Create the plan guide to freeze the plan currently in cache */
exec sp_create_plan_guide_from_handle 
    @name = 'Freeze plan temp table update',
    @plan_handle=0x05000600B56A9938304AC1A10402000001000000000000000000000000000000000000000000000000000000,
    @statement_start_offset = 2352;
GO

/* Validate the plan guide. */
SELECT pg.name, val.*
FROM sys.plan_guides AS pg
OUTER APPLY sys.fn_validate_plan_guide (pg.plan_guide_id) as val;
GO

EXEC dbo.TempTableTest @RowID = 800000 WITH RECOMPILE;
GO

EXEC sp_control_plan_guide @operation = 'Drop',
    @name = 'Freeze plan temp table update';
GO






/****************************************************
Two fixes that DO work!
****************************************************/

/* OPTIMIZE FOR a narrow plan with the temp table  */

DROP PROCEDURE IF EXISTS dbo.TempTableOptimizeForTest;
GO
CREATE PROCEDURE dbo.TempTableOptimizeForTest 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    CREATE TABLE #TempTable (
	RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	CharColumn CHAR(500) NOT NULL
    );

    RAISERROR('Add one million rows to #TempTable...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT #TempTable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows #TempTablee...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    UPDATE #TempTable SET CharColumn = 'bar'
    WHERE RowID <= @RowID
        OPTION (OPTIMIZE FOR (@RowID = 8000)); /* <-------OPTIMIZE FOR hint */

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of #TempTable (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO



--Run once to look at duration (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
EXEC dbo.TempTableOptimizeForTest @RowID = 800000;
GO
SET STATISTICS IO OFF;
GO



/* Change the scope with Dynamic SQL */
DROP PROCEDURE IF EXISTS dbo.TempTableDSQLTest;
GO
CREATE PROCEDURE dbo.TempTableDSQLTest 
    @RowID INT
AS 
	SET NOCOUNT OFF;
    SET XACT_ABORT ON;

    DECLARE @dsql NVARCHAR(MAX);
	DECLARE @t1 DATETIME2(7), @Durationms INT, @msg nvarchar(1000);

    CREATE TABLE #TempTable (
	RowID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	CharColumn CHAR(500) NOT NULL
    );

    RAISERROR('Add one million rows to #TempTable...', 1, 1) WITH NOWAIT;
    --This query adapted from pattern attributed 
    --to Itzik Ben-Gan in https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1
    WITH e1(n) AS
    (
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL 
	    SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0 UNION ALL SELECT 0
    ), 
    e2(n) AS (SELECT 0 FROM e1 CROSS JOIN e1 AS b), 
    e3(n) AS (SELECT 0 FROM e1 CROSS JOIN e2), 
    e4(n) AS (SELECT 0 FROM e1 CROSS JOIN e3), 
    e5(n) AS (SELECT 0 FROM e1 CROSS JOIN e4), 
    e6(n) AS (SELECT 0 FROM e1 CROSS JOIN e5)
    INSERT #TempTable (CharColumn ) 
    SELECT TOP (1000000) 'foo' FROM e6;

    RAISERROR('Update rows #TempTablee...', 1, 1) WITH NOWAIT;
	SELECT @t1 = SYSDATETIME();

    SET @dsql = N'
    UPDATE #TempTable SET CharColumn = ''bar''
    WHERE RowID <= @RowID'

    EXEC sp_executesql @stmt = @dsql,
        @params = N'@RowID INT',
        @RowID = @RowID;

	SET @Durationms = DATEDIFF(ms, @t1, SYSDATETIME());

	SET @msg = 'Duration of update of #TempTable (ms): ' + CAST(@Durationms as nvarchar(10));
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
GO

--Run once to look at duration (plans off), then run with actual plans
SET STATISTICS IO ON;
GO
EXEC dbo.TempTableDSQLTest @RowID = 800000;
GO
SET STATISTICS IO OFF;
GO
