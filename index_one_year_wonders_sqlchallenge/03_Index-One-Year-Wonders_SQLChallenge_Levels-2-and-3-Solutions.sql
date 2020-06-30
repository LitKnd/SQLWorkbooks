/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/design-the-best-index-for-one-year-wonders-sqlchallenge/

Level 2 & 3 Solutions

I'm not going to use the compression trick in these demos,
but you are welcome to 😎
*****************************************************************************/

Use BabbyNames2017;
GO



/****************************************************
Indexed Computed Column Solutions
****************************************************/

--Add a computed column
--I don't have to persist it in order to index it, but I'm going to persist it anyway
ALTER TABLE ref.FirstName ADD FirstEqualLast 
    AS
        CASE WHEN FirstReportYear = LastReportYear
        THEN 1 
        ELSE 0
        END
    PERSISTED;
GO

CREATE INDEX ix_ref_FirstName_FirstEqualLast_TotalNameCount_INCLUDES
    on ref.FirstName (FirstEqualLast, TotalNameCount) INCLUDE (FirstName, FirstReportYear);
GO

/* Does it use it? */
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstReportYear = LastReportYear
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO
--Logical reads: 958  <--Went UP, query didn't even use the index

--What happened?
SELECT 
    index_level, page_count, avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('ref.FirstName'), 1, NULL, 'detailed');
GO

--As long as we have persisted the computed column, it will take up space
--But we don't have to have so much empty space on the pages!
ALTER INDEX pk_FirstName_FirstNameId on 
    ref.FirstName REBUILD;
GO

/* Changing the query to reference the computed column... */
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstEqualLast = 1 /* Changed predicate */
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO

DROP INDEX ix_ref_FirstName_FirstEqualLast_TotalNameCount_INCLUDES on ref.FirstName;
GO 

ALTER TABLE ref.FirstName DROP COLUMN FirstEqualLast;
GO

--Reset now that we've removed the computed column
ALTER INDEX pk_FirstName_FirstNameId on 
    ref.FirstName REBUILD;
GO


/****************************************************
Tweak:
A different computed column (probably more useful)
This time I won't persist it
****************************************************/

ALTER TABLE ref.FirstName ADD LastMinusFirst AS
    FirstReportYear - LastReportYear;
    --PERSISTED;
GO

CREATE INDEX ix_ref_FirstName_LastMinusFirst_INCLUDES
    on ref.FirstName (LastMinusFirst, TotalNameCount DESC) INCLUDE (FirstName, FirstReportYear);
GO



/* Does it use it? */
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstReportYear = LastReportYear
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO


SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstReportYear - LastReportYear = 0 /* Changed predicate */
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO


DROP INDEX ix_ref_FirstName_LastMinusFirst_INCLUDES on ref.FirstName;
GO 

ALTER TABLE ref.FirstName DROP COLUMN LastMinusFirst;
GO



/*  
Pros and Cons of this solution:

PROS
    Not a ton of overhead- added one column and nonclustered index
    Computed columns support statistics, which can be nice

CONS:
    If we have any SELECT * queries, something may break
    Optimization for computed columns is complex, and you can run into odd problems:
        https://sqlperformance.com/2017/05/sql-plan/properly-persisted-computed-columns
        by Paul White

Takeaway: If we really wanted to do this, computing the value ourselves and making this a
"real" column would be very attractive.
*/



/****************************************************
Indexed View Solution
****************************************************/

CREATE VIEW dbo.V_OneYearWonders
WITH SCHEMABINDING
AS
	SELECT 
		FirstName, 
		FirstReportYear,
		TotalNameCount
	FROM ref.FirstName
	WHERE 
		FirstReportYear = LastReportYear
		and TotalNameCount > 10;
GO

CREATE UNIQUE CLUSTERED INDEX cx_OneYearWonders
	on dbo.V_OneYearWonders (FirstName);
GO

--Does it auto-match at first?
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear as SoloReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstReportYear = LastReportYear
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO



--How about this?
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM dbo.V_OneYearWonders
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO


--In non-Enterprise Editions, we would need to use NOEXPAND
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM dbo.V_OneYearWonders WITH (NOEXPAND)
GO
SET STATISTICS IO OFF;
GO
-- 4 logical reads




--Cleanup
DROP INDEX IF EXISTS cx_OneYearWonders
	on dbo.V_OneYearWonders;
GO

DROP VIEW IF EXISTS dbo.V_OneYearWonders;
GO




/*  
Pros and Cons of this solution:

PROS:
    It worked

CONS:
    Storing another copy of the table (for only the rows that meet the predicates) 
    which must be maintained for every modification

*/




/****************************************************
Extra: What about filtered indexes?
****************************************************/

/* Sorry, this syntax is not allowed */
CREATE INDEX ix_ref_TotalNameCount_FILTERTEST on 
	ref.FirstName (TotalNameCount)
	INCLUDE (FirstName, FirstReportYear, LastReportYear)
	WHERE (FirstReportYear = LastReportYear);
GO

/* Nice try! */
CREATE INDEX ix_ref_TotalNameCount_HOWABOUTTHIS on 
	ref.FirstName (TotalNameCount)
	INCLUDE (FirstName, FirstReportYear, LastReportYear)
	WHERE (FirstReportYear - LastReportYear = 0);
GO


/* This syntax IS allowed */
CREATE INDEX ix_ref_TotalNameCount_FILTER_INCLUDES on 
	ref.FirstName (TotalNameCount DESC)
	INCLUDE (FirstName, FirstReportYear, LastReportYear)
	WHERE (TotalNameCount > 10 );
GO

/* Does it use it? */
SET STATISTICS IO ON;
GO
SELECT 
	FirstName, 
	FirstReportYear,
	TotalNameCount
FROM ref.FirstName
WHERE 
	FirstReportYear = LastReportYear
	and TotalNameCount > 10
ORDER BY TotalNameCount DESC;
GO
SET STATISTICS IO OFF;
GO

/* Not a huge savings, though */
DROP INDEX ix_ref_TotalNameCount_FILTER_INCLUDES on 
	ref.FirstName;
GO


