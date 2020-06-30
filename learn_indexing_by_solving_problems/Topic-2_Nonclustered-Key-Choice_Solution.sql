/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*******************************************************************/
/*                       SOLUTION                                  */
/*                 Nonclustered Key Choice                         */
/*******************************************************************/


/* Problem recap:
You need to make this query use the fewest logical reads possible.
You must create one single-column nonclustered index to do this.

	(No filters, compression, etc. No changing the query. Only one index.)
	(No deleting rows or truncating the table.)
*/


/* What were your ideas for the index? */
/* Table:                    Key:                      








*/








/* 
If we can only create one index and the query uses two tables...
which table is a better candidate to get the index?
To find out, let's baseline the logical reads with statistics IO 
*/

USE BabbyNames;
GO
SET STATISTICS IO ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO
SET STATISTICS IO OFF;
GO




/* Another way...*/
/* Enable actual execution plans */
/* Run the query and find the operator that's causing the reads 
against agg.FirstNameByYear.
Show Actual IO Statistics (SQL Server 2016 and 2014 SP2 and higher) */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'	and fnby.Gender='F';
GO





/* We can only pick one column for the index for this problem.
    How do we choose the most important column? */
/* Review the query */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId  /* <---- JOIN COLUMN IS AN OPTION */
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F' /* <---- PREDICATE COLUMN IS AN OPTION */
;
GO







/* Thinking through this like the optimizer:
Which is likely to narrow down the results to a SMALLER list?

	1) Babies named Taylor
	2) Female babies

Whatever narrows down the list the most will
help us find the rows fastest

*/




/* Run the query with actual plans and script out the index hint */
/* Do a quick peek in the properties to see if there's another index request */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO




--We can see the same missing index requests in
--the dynamic management views
SELECT 
    d.[statement] as table_name,
    d.equality_columns,
    d.inequality_columns,
    d.included_columns,
    s.avg_total_user_cost as avg_est_plan_cost,
    s.avg_user_impact as avg_est_cost_reduction,
    s.user_scans + s.user_seeks as times_requested
FROM sys.dm_db_missing_index_groups AS g
JOIN sys.dm_db_missing_index_group_stats as s on
    g.index_group_handle=s.group_handle
JOIN sys.dm_db_missing_index_details as d on
    g.index_handle=d.index_handle
JOIN sys.databases as db on 
    d.database_id=db.database_id
WHERE db.database_id=DB_ID();
GO



/* 
This is the index that was showing in the green hint on the plan:
*/

/*
Missing Index Details from Topic-2_Nonclustered-Key-Choice_Solution.sql - BEEPBEEP\DEV
The Query Processor estimates that implementing the following index could improve the query cost by 38.5089%.
*/

/*
USE [BabbyNames]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [agg].[FirstNameByYear] ([Gender])
INCLUDE ([NameCount])
GO
*/







/* Does an index on Gender really make sense? */
/* OK, let's cheat. Let's create the index exactly as it asks for --
	more than one column, totally cheating
And see if we can beat it. */

CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [agg].[FirstNameByYear] ([Gender])
INCLUDE ([NameCount])
GO

SET STATISTICS IO ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO
SET STATISTICS IO OFF;
GO




/* Look at the execution plan.
What do we have instead of a clustered index scan against agg.FirstNameByYear?
Is it still asking for another index?
*/
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO



--We can beat that, with only one column
DROP INDEX [<Name of Missing Index, sysname,>] ON [agg].[FirstNameByYear];
GO



/* Create this: */
CREATE INDEX ix_onecolumn
	ON agg.FirstNameByYear  /* tablename */
	( FirstNameId ) /* columname */ ;
GO







/* Look at the statistics IO now */
SET STATISTICS IO ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO
SET STATISTICS IO OFF;
GO






/* Look at the plan. Now we have a key lookup */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO


/* Hover over the key lookup operator
Look at the predicates and output list.
Our single-column index is more complicated than we thought.
We'll get back to this in a bit.
*/




DROP INDEX ix_onecolumn ON agg.FirstNameByYear;
GO





/*******************************************************************
DEMO END
/*******************************************************************/
