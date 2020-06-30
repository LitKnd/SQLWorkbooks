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
Note: I'm talking about a solution for SQL Server 2012 but testing on SQL Server 2016.
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









/*******************************************************************/
/*                        SOLUTION                                 */
/*                     ONE YEAR WONDERS                            */
/*******************************************************************/



/********************
What strategy did you come up with?


What does your testing plan include?


********************/













/*******************************************************************/
/*                  THE INDEXED VIEW SOLUTION                      */
/* AUTOMATIC INDEXED VIEW MATCHING FEATURE IS ENTERPRISE EDITION   */
/*******************************************************************/

USE BabbyNames;
GO

IF OBJECT_ID('dbo.FirstNameCountByYear_2000_2017') IS NULL
	EXEC('CREATE VIEW dbo.FirstNameCountByYear_2000_2017 AS SELECT 1 AS COL1')
GO

/* We MUST use SCHEMABINDING.
COUNT(*) is not allowed. COUNT_BIG(*) is required when using GROUP BY.
*/
CREATE OR ALTER VIEW dbo.FirstNameCountByYear_2000_2017
WITH SCHEMABINDING
AS
SELECT
	FirstName,
	YEAR(FakeBirthDateStamp) as YearReported,
	COUNT_BIG(*) AS NamedThatYear
FROM dbo.FirstNameByBirthDate_2000_2017 AS fnbd
GROUP BY
	FirstName,
	YEAR(FakeBirthDateStamp)
GO



/* To make it an indexed view, we have to create a unique clustered index. */
/* This persists the view to disk -- just like a table that will be auto-updated */
/* We can put nonclustered indexes on the view as well, but only AFTER it has a unique CX. */
CREATE UNIQUE CLUSTERED INDEX IX_FirstNameCountByYear_2000_2017
	ON dbo.FirstNameCountByYear_2000_2017 (FirstName, YearReported);
GO




/* After this point, any inserts, deletes (and possibly updates) to
FirstNameByBirthDate_2000_2017 will also have to modify the indexed view */








/* Look at the estimated execution plan for this insert */
/* Then run it and see how long it takes */
BEGIN TRAN
    SET STATISTICS IO, TIME ON;

	INSERT dbo.FirstNameByBirthDate_2000_2017 (FakeBirthDateStamp, FirstNameId, FirstName, Gender)
	VALUES ('2010-12-31', -100, 'Misteroo', 'M')

    SET STATISTICS IO, TIME OFF;
ROLLBACK
GO






/* Look at the actual execution plan */
/* Does our query use it automatically?
    (That's an EE feature) */
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



/* Tangent: Why are there two branches in the plan?*/
/* Top branch is COUNT(YearReported) and MAX(YearReported) GROUP BY FirstName
Bottom branch is SUM(NamedThatYear) GROUP BY FirstName
Hash join puts them together and computes the COUNT DISTINCT as Expression 1001
Filter is handling the HAVING against Expression 1001
*/


/* How is performance? */
/* Turn off actual execution plan */
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



/* Rewrite the query to use the indexed view directly            */
/* If we're using standard edition we need to reference the view
directly with NOEXPAND, which requires a query change, anyway.   */

/* Look at the plan */
SET STATISTICS IO, TIME ON;
GO
with index_view AS (
    SELECT 
    FirstName,
    YearReported,
    NamedThatYear
FROM dbo.FirstNameCountByYear_2000_2017 AS fnbd WITH (NOEXPAND)
)
SELECT TOP 100
	FirstName,
	SUM(NamedThatYear) as NamedThatYear,
	MAX(YearReported) as YearReported
FROM index_view
GROUP BY
	FirstName
HAVING COUNT(DISTINCT YearReported)=1
ORDER BY SUM(NamedThatYear) DESC, FirstName;
GO
SET STATISTICS IO, TIME OFF;
GO








DROP INDEX IF EXISTS IX_FirstNameCountByYear_2000_2017 on dbo.FirstNameCountByYear_2000_2017;
GO

DROP VIEW IF EXISTS dbo.FirstNameCountByYear_2000_2017;
GO




/*********************************Live Demo Ends Here*********************************/




/*******************************************************************/
/*                  THE COLUMNSTORE SOLUTION                       */
/*******************************************************************/

/* We're just going to dip our toe in here a little bit */

/* Nonclustered columnstore indexes are updatable as of SQL Server 2016!
    There are still risks with heavy modifications to columnstore indexes --
	it uses something called the Delta store and write performance may suffer given certain patterns

    Columnstore is available in non-$$$Enterprise$$$ production editions as of 
    SQL Server 2016 SP1 (with limits on resources)
*/
CREATE NONCLUSTERED COLUMNSTORE INDEX ncs_FirstNameByBirthDate_2000_2017
	ON dbo.FirstNameByBirthDate_2000_2017
	(FirstName, FakeBirthDateStamp);
GO


/* Look at our row_groups for the columnstore index. Are they all compressed? */
SELECT
	OBJECT_NAME(object_id) AS table_name,
	index_id,
	row_group_id,
	delta_store_hobt_id, /* NULL if row group is not in the delta store*/
	state_desc,
		/*INVISIBLE - A row group that is being built.
		OPEN - A deltastore row group that is accepting new rows. An open row group is still in rowstore format and has not been compressed to columnstore format.
		CLOSED - A row group in the delta store that contains the maximum number of rows, and is waiting for the tuple mover process to compress it into the columnstore.
		COMPRESSED - A row group that is compressed with columnstore compression and stored in the columnstore.
		TOMBSTONE - A row group that was formerly in the deltastore and is no longer used. */
	total_rows,
	trim_reason_desc, /* RESIDUAL ROW GROUP: Rows at the end of a bulk load were less than the maximum rows per row group. */
	transition_to_compressed_state_desc /* INDEX_BUILD � An index create or index rebuild compressed the rowgroup. */
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = object_id('FirstNameByBirthDate_2000_2017')
ORDER BY index_id, row_group_id;
GO



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


/* Look at the actual plan */
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
/* Hovering over the Columnstore Scan, Compute Scalar, Hash Match, and Filter operators
     you can see that it processed them in Batch execution mode */


DROP INDEX IF EXISTS ncs_FirstNameByBirthDate_2000_2017 ON dbo.FirstNameByBirthDate_2000_2017;
GO
