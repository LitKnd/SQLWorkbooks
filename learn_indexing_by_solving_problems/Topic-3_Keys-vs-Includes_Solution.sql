/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/*******************************************************************/
/*                        SOLUTION                                 */
/*******************************************************************/

/* Create these two single column indexes */
USE BabbyNames;
GO

--Make sure these indexes exist 
--(Create statements were in the problem file)
CREATE INDEX ix_ref_FirstName_FirstName
	on ref.FirstName (FirstName);
GO

CREATE INDEX ix_agg_FirstNameByYear_FirstNameId
	ON agg.FirstNameByYear
	( FirstNameId );
GO


/* Look at the actual plan
Is it using ix_agg_FirstNameByYear_FirstNameId?
What is it doing instead? */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO


/*
This is a hash match plan
	The outer/upper branch is the build input, it runs first
		See the bitmap create there? It has to create that for the hash match anyway.
	The lower branch is the probe input
Hover over the clustered index scan
Look at the predicate-- this is a hidden filter
	It's using the bitmap created in the build input to do a filter!
		This optimization pre-filters the data
			Less passed out of the scan
				Less to go into that hash join in tempdb
	See where it says "in row" on the filter?
		That's a further optimization
			It's passing off the work of checking the bitmap to the storage engine
				Single column predicates on an INT or BIGINT data type are eligible for INROW optimiziation

Read more in Paul White's post on Bitmap Magic: http://sqlblog.com/blogs/paul_white/archive/2011/07/07/bitmap-magic.aspx
*/


/* Baseline performance with it scanning agg.FirstNameByYear */
SET STATISTICS IO, TIME ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO
SET STATISTICS IO, TIME OFF;
GO



/* How much of this elapsed time due to the overhead of displaying 20K rows in SSMS?*/

/* One option in SQL Server 2014+ is to look at CPU time in the plan.
Turn on actual plans...*/
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO



/* If you really care about measuring duration, you 
may want to run the query from SQL Sentry Plan Explorer */



/* Baseline performance forcing it to use our index */
SET STATISTICS IO, TIME ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby WITH (INDEX(ix_agg_FirstNameByYear_FirstNameId))
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO
SET STATISTICS IO, TIME OFF;
GO



/* CPU time and elapsed time both went up.
These fluctuate a bit for each query-- they're not terribly different.
But Logical reads on agg.FirstNameByYear went from ~5K (scan plan) to 70K+! (forced index use) */



/* Look at the actual execution plan */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby WITH (INDEX(ix_agg_FirstNameByYear_FirstNameId))
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO

/* The highest cost operator is the Key Lookup.
Hover over the Key Lookup to see what it's doing.
	It's just outputting NameCount
Estimated number of executions shows that it estimated it was going to have to do this 23K times
	In addition to having to do 2k seeks into agg.FirstNameByYear before this

SQL Server doesn't like to have to do tons of nested loops and key lookups into the same table
So it ignored our narrow NC index and did a CX scan.
*/



/*******************************************************************/
/*  Can we beat the bitmap probe with a covering index?            */
/*  Test: SQL Server's missing index request                       */
/*******************************************************************/

/* Get the actual plan of the query (without forcing it to use our index) */
/* The bitmap probe plan has a missing index request */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO



/* Here's the index that it's asking for .... */

/*
USE [BabbyNames]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [agg].[FirstNameByYear] ([Gender])
INCLUDE ([NameCount])
GO
*/


/* Create the index. I just gave it a nicer name */
CREATE INDEX ix_agg_FirstNameByYear_Gender_INCLUDES
	ON agg.FirstNameByYear
	( Gender )           /* One or more keys */
	INCLUDE ( NameCount );  /* One or more includes (optional) */
GO

/* Look at the actual plan. Does it use it?*/
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO


/* It's a seek but...
hmm, that predicate (aka FILTER) with the bitmap probe is still there.
And it's still parallel.
And it's still doing a hash match.
Those require memory.
Look at the memory grant on the select operator*/


SET STATISTICS TIME, IO ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO
SET STATISTICS TIME, IO OFF;
GO



/* We cut the logical reads in half (ish) but... is this as good as it gets? */




/*******************************************************************/
/*  Test: Promote FirstNameId into the key                         */
/*  Reasoning: they are both seekable predicates!                  */
/*******************************************************************/

CREATE INDEX ix_agg_FirstNameByYear_Gender_FirstNameId_INCLUDES
	ON agg.FirstNameByYear
	( Gender, FirstNameId )           /* One or more keys */
	INCLUDE ( ReportYear, NameCount );  /* One or more includes (optional) */
GO



/* Look at the actual plan. Does it use it?*/
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO

/* Look at the index seek. Is there a hidden filter? */
/* How is it doing the seek?

Look at the memory grant.
*/


/* Is this index faster? */
SET STATISTICS TIME, IO ON;
GO
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO
SET STATISTICS TIME, IO OFF;
GO



/*
	Our execution plan is single threaded and has a nested loop (no hash join, no bitmap probe)
	Our CPU time is lower
	Our logical reads is slightly HIGHER
	Our elapsed time is about the same
    We have no memory grant (it was there due to parallelism and the hash join)

*/





/* Cleanup */

DROP INDEX ix_agg_FirstNameByYear_Gender_INCLUDES on agg.FirstNameByYear;
GO
DROP INDEX ix_agg_FirstNameByYear_Gender_FirstNameId_INCLUDES ON agg.FirstNameByYear;
GO
DROP INDEX ix_agg_FirstNameByYear_FirstNameId on agg.FirstNameByYear;
GO
DROP INDEX ix_ref_FirstName_FirstName on ref.FirstName;
GO



/****************************************************************************/
/* LIVE DEMO END          */
/****************************************************************************/

