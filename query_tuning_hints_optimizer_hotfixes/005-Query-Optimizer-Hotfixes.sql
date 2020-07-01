/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/query-tuning-with-hints-optimizer-hotfixes

*****************************************************************************/

--This is here for rerunnability, in case you cancel in the middle of a transaction
IF @@TRANCOUNT > 0
    ROLLBACK;
GO
SET NOCOUNT ON;
GO

USE master;
GO

--Let's create a new database for this test
IF DB_ID('QueryOptimizerHotfixes') IS NOT NULL
BEGIN
    ALTER DATABASE QueryOptimizerHotfixes SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QueryOptimizerHotfixes;
END

CREATE DATABASE QueryOptimizerHotfixes
GO

USE QueryOptimizerHotfixes
GO

--We're going to repro a bug. The fix for this bug requires enabling Query Optimizer Hotfixes.
--https://support.microsoft.com/en-us/help/3198775/fix-an-inefficient-query-plan-is-used-for-a-query-requiring-order-by-partitioning-column-of-a-table-with-single-partition

--The loneliest partition function
CREATE PARTITION FUNCTION pf (DATE)
    AS RANGE RIGHT
    FOR VALUES (   );
GO

CREATE PARTITION SCHEME ps
    AS PARTITION pf
    ALL TO ([PRIMARY]);
GO

CREATE TABLE dbo.LetsTalkAboutQueryOptimizerHotfixes (
	CXCol BIGINT IDENTITY NOT NULL,
	PartitioningCol DATE NOT NULL,
    CharCol CHAR(100) NOT NULL DEFAULT ('FOO'),
    IntCol INT NOT NULL DEFAULT (2)
) ON ps (PartitioningCol) 
GO

/* Insert 1 million rows */
BEGIN TRAN
    DECLARE @i int = 0;
    WHILE @i < 1000000
    BEGIN
        INSERT dbo.LetsTalkAboutQueryOptimizerHotfixes (PartitioningCol)
        SELECT DATEADD(dd,@i,'2017-01-01')

        SET @i=@i+1;
    END
COMMIT
GO 

/* Now let's index our table */
CREATE UNIQUE CLUSTERED INDEX cx_LetsTalkAboutQueryOptimizerHotfixes
    on dbo.LetsTalkAboutQueryOptimizerHotfixes (CXCol, PartitioningCol);
GO

CREATE NONCLUSTERED INDEX ix_LetsTalkAboutQueryOptimizerHotfixes_PartitioningCol_CharCol on
    dbo.LetsTalkAboutQueryOptimizerHotfixes (PartitioningCol, CharCol);
GO


/* We're starting at compat level 130 (latest and greatest), with optimizer hotfixes OFF */
ALTER DATABASE [QueryOptimizerHotfixes] SET COMPATIBILITY_LEVEL = 130
GO
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
GO

USE QueryOptimizerHotfixes;
GO

/* Now we need a low permission account for testing */

IF (SELECT COUNT(*) from sys.sql_logins where name='lowpermissionuser') = 0
    CREATE LOGIN lowpermissionuser with password='Password23';
GO

CREATE USER lowpermissionuser for login [lowpermissionuser];
GO

GRANT SELECT on OBJECT::dbo.LetsTalkAboutQueryOptimizerHotfixes TO [lowpermissionuser];
GO

GRANT SHOWPLAN TO [lowpermissionuser];
GO

EXECUTE AS USER = 'lowpermissionuser'; 
GO


/* Let's repro that bug. 
We have an index with keys PartitioningCol, CharCol
Look at the actual execution plan.
If you see a sort operator, we're seeing the bug.

Note: I'm using RECOMPILE hints ONLY to make it obvious that I'm
not getting a behavior because of plan re-use anywhere here.
 */
SELECT IntCol
FROM dbo.LetsTalkAboutQueryOptimizerHotfixes
WHERE PartitioningCol < '2017-10-02'
ORDER BY PartitioningCol DESC, CharCol DESC
    OPTION (RECOMPILE);
GO

SELECT IntCol
FROM dbo.LetsTalkAboutQueryOptimizerHotfixes
WHERE PartitioningCol < '2017-10-02'
ORDER BY PartitioningCol DESC, CharCol DESC
    OPTION (RECOMPILE, QUERYTRACEON 4199);
GO

REVERT

CREATE PROCEDURE dbo.Workaround 
AS
    SELECT IntCol
    FROM dbo.LetsTalkAboutQueryOptimizerHotfixes
    WHERE PartitioningCol < '2017-10-02'
    ORDER BY PartitioningCol DESC, CharCol DESC
        OPTION (RECOMPILE, QUERYTRACEON 4199);
GO

GRANT EXECUTE ON OBJECT::dbo.Workaround TO [lowpermissionuser];
GO

EXECUTE AS USER = 'lowpermissionuser'; 
GO

/* look at the plan... see the sort? */
exec dbo.Workaround;
GO

/* Check out 'Trace Flags' on properties of SELECT operator */

/* New syntax in 2016 SP1+ works for low permission users */
SELECT IntCol
FROM dbo.LetsTalkAboutQueryOptimizerHotfixes
WHERE PartitioningCol < '2017-10-02'
ORDER BY PartitioningCol DESC, CharCol DESC
    OPTION (RECOMPILE, USE HINT ('ENABLE_QUERY_OPTIMIZER_HOTFIXES') );
GO

REVERT;
GO

/* As of 2016 we can now 'bully' optimizer hotfixes at the DB level,
more granular than global trace flag */
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON;
GO

EXECUTE AS USER = 'lowpermissionuser'; 
GO

SELECT IntCol
FROM dbo.LetsTalkAboutQueryOptimizerHotfixes
WHERE PartitioningCol < '2017-10-02'
ORDER BY PartitioningCol DESC, CharCol DESC
    OPTION (RECOMPILE);
GO

/* What if I have OPTIMIZER HOTFIXES on at the DB level, and I'm working on a query.
And I want to know what plan it would have WITHOUT optimizer hotfixes on?
There's not hint to turn OFF optimizer hotfixes.
But you can do this... */
USE tempdb;
GO

SELECT IntCol
FROM QueryOptimizerHotfixes.dbo.LetsTalkAboutQueryOptimizerHotfixes
WHERE PartitioningCol < '2017-10-02'
ORDER BY PartitioningCol DESC, CharCol DESC
    OPTION (RECOMPILE);
GO

