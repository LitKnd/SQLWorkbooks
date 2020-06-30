/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




/*******************************************************************/
/*                        PROBLEM                                  */
/*          Indexing a procedure for top and order by              */
/*******************************************************************/


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
