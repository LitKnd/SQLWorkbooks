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
/*                  Indexing for Group By                          */
/*******************************************************************/


/*
Problem:

The query below searches for names that occur in one year between 2006-2010
Outline the lowest cost strategy to speed up the query

Rules:
    You must use the FirstNameByBirthDate_2000_2017 table
    This is a system where name data is constantly being received
    It uses SQL Server 2012 Standard Edition (latest Service Pack)
    A large volume of names may come in at any time if hospitals are delayed reporting
    The query's results must be real-time
    You can modify the query, create objects, etc.

*/

/*
Note: I'm talking about a solution for SQL Server 2012 but testing on SQL Server 2017.
    That's a big no-no, they're NOT going to be the same, even if you tweak
        database compat level and cardinality estimation settings.
    In reality we'd need to also test this thoroughly on 2012.
*/



USE BabbyNames;
GO


/* Run with actual plan, it's going to take a while */
SET STATISTICS IO, TIME ON;
GO
SELECT TOP 100
	FirstName,
	COUNT(*) AS NamedThatYear,
	MAX(YEAR(FakeBirthDateStamp)) as YearReported
FROM dbo.FirstNameByBirthDate_2000_2017 AS fnbd
GROUP BY
	FirstName
HAVING COUNT(DISTINCT YEAR(FakeBirthDateStamp))=1
ORDER BY COUNT(*) DESC, FirstName;
GO
SET STATISTICS IO, TIME OFF;
GO



