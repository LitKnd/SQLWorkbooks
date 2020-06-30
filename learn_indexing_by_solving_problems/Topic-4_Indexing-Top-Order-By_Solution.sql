/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




/*******************************************************************
                          PROBLEM                                  

Run through the steps here to create the procedure and ExistingIndex, if you
didn't just step through the problem...
********************************************************************/


/* Your Junior DBA is testing a new stored procedure
It's scanning the index
But it's really fast!
exec dbo.TopBirthDateStampsByName @FirstName='Jacob'
*/

USE BabbyNames;
GO

/* Here's the existing index used by the query ... */
/* This takes 60-90 seconds to create */
CREATE INDEX ExistingIndex
	ON dbo.FirstNameByBirthDate_2000_2017
	( FakeBirthDateStamp, FirstName );
GO


/* Here's the procedure */
CREATE OR ALTER PROCEDURE dbo.TopBirthDateStampsByName
    @FirstName VARCHAR(256)
AS
    SELECT TOP 150
	    FakeBirthDateStamp
    FROM dbo.FirstNameByBirthDate_2000_2017
    WHERE
	    FirstName = @FirstName
    ORDER BY FakeBirthDateStamp DESC;
GO


/* Here's how she's testing it */
/* Jacob is the most popular name given between 2001 and 2005
She wanted to make sure it would use the index if it found a lot of rows */
SET STATISTICS TIME, IO ON;
GO
exec dbo.TopBirthDateStampsByName @FirstName='Jacob';
GO
SET STATISTICS TIME, IO OFF;
GO



/* Get the actual execution plan */
exec dbo.TopBirthDateStampsByName @FirstName='Jacob';
GO



/* You have a goal to tune queries like this so they consistently
execute in a few hundred milliseconds or less.

What should you tell your Junior DBA about this one? */













/*******************************************************************/
/*                        SOLUTION                                 */
/*          Indexing a proc for top and order by                   */
/*******************************************************************/



/* How is the scan working?
Look at the actual plan.
Look at the properties pane of the scan.
Find the scan direction.*/
exec dbo.TopBirthDateStampsByName @FirstName='Jacob';
GO







/* What if we're looking for a name that's much more rare? */
/* Run with actual plans */
/* Look at the plan and look at number of rows read.*/
exec dbo.TopBirthDateStampsByName @FirstName='Bing';
GO


/* It had to read all 67 million rows - every page in the index, because
there's only 5 of these names.
It never met the TOP requirement, so it had
to read every page before it could stop.*/



/* This should be consistent... all the pages */
SET STATISTICS TIME, IO ON;
GO
exec dbo.TopBirthDateStampsByName @FirstName='Bing';
GO
SET STATISTICS TIME, IO OFF;
GO



/* Run with actual plans. Why are the estimated costs the same? */
exec dbo.TopBirthDateStampsByName @FirstName='Jacob';
GO
exec dbo.TopBirthDateStampsByName @FirstName='Bing';
GO



/* Compiling execution plans is expensive.
SQL Server reuses them unless it has a good reason not to. */



/* EXEC WITH RECOMPILE tells SQL Server not to cache the plan,
and not to reuse a plan if it is in cache */
exec dbo.TopBirthDateStampsByName @FirstName='Jacob' WITH RECOMPILE;
GO
exec dbo.TopBirthDateStampsByName @FirstName='Bing' WITH RECOMPILE;
GO


/* Now this is different!
SQL thinks an index could reduce the cost of the 'Bing' plan by 99% */

/*
Missing Index Details from Topic-4_Indexing-Top-Order-By.sql - BEEPBEEP\DEV
The Query Processor estimates that implementing the following index could improve the query cost by 99.9672%.
*/

/*
USE [BabbyNames]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[FirstNameByBirthDate_2000_2017] ([FirstName])
INCLUDE ([FakeBirthDateStamp])
GO
*/



/* 
    Is this the best index? Create it. 
    We're using row compression just for fun.
    Data compression is available in Standard Edition in SQL Server 2016 SP1+
*/
CREATE NONCLUSTERED INDEX ix_FirstNameByBirthDate_2000_2017_FirstName_INCLUDES
    ON dbo.FirstNameByBirthDate_2000_2017 (FirstName)
    INCLUDE (FakeBirthDateStamp)
    WITH (DATA_COMPRESSION = ROW);
GO

/* Does it use it for Jacob? */
exec dbo.TopBirthDateStampsByName @FirstName='Jacob' WITH RECOMPILE;
GO




/* Does it use it for Bing? */
exec dbo.TopBirthDateStampsByName @FirstName='Bing' WITH RECOMPILE;
GO







/* If we move FakeBirthDateStamp to the key, we will presort by that column */
CREATE NONCLUSTERED INDEX ix_FirstNameByBirthDate_2000_2017_FirstName_INCLUDES
    ON dbo.FirstNameByBirthDate_2000_2017 (FirstName, FakeBirthDateStamp)
    WITH (DATA_COMPRESSION = ROW,
        DROP_EXISTING=ON);
GO

exec sp_rename 
    'dbo.FirstNameByBirthDate_2000_2017.ix_FirstNameByBirthDate_2000_2017_FirstName_INCLUDES',
    'ix_FirstNameByBirthDate_2000_2017_FirstName_FakeBirthDateStamp';
GO



/* Does it use this new index for each name? */
exec dbo.TopBirthDateStampsByName @FirstName='Jacob' WITH RECOMPILE;
GO
exec dbo.TopBirthDateStampsByName @FirstName='Bing' WITH RECOMPILE;
GO



/* Clean up */
DROP INDEX IF EXISTS ix_FirstNameByBirthDate_2000_2017_FirstName_FakeBirthDateStamp
    ON dbo.FirstNameByBirthDate_2000_2017;
GO

DROP INDEX IF EXISTS ix_FirstNameByBirthDate_2000_2017_FirstName_INCLUDES
    ON dbo.FirstNameByBirthDate_2000_2017;
GO

DROP INDEX IF EXISTS ExistingIndex
    ON dbo.FirstNameByBirthDate_2000_2017;
GO
