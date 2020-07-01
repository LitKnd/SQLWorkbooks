/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/query-tuning-with-hints-optimizer-hotfixes

*****************************************************************************/

/* We are using RANK with a simple CTE.
RANK gives ties the same ranking, like this: 1, 2, 2, 4, 5  
DENSE_RANK wouldn't skip ranking 3 in this example, it would give: 1, 2, 2, 3, 4
    That doesnt' matter in this example, because we just care about Rank 1 for each year/state/gender combo*/

USE BabbyNames;
GO

SET STATISTICS TIME ON;
GO

/* Run with actual execution plans on */
/* Check out a little bit of the data-- look at NV for 1910 to see a tie. */
/* Note that many of our reporting columns are completely fake data :)    */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1;
GO





/* What's the warning on the select? */
/* Look at the row estimate coming out of the filter.
The optimizer is having a hard time figuring out how many rows will come out of our windowing function.
It is OVER-estimating.
*/






/* ~~~ Time for a break ~~~ */







/* Look at CardinalityEstimationModelVersion on the select operator */
/* Let's play around with hints and see how different plans perform. */


/* We can use the QUERYTRACEON query hint to turn on a trace flag for our query.
This example turns on trace flag 9481. 
That has the optimizer use the "old" cardinality estimator -- 
    version 70, aka the SQL Server 2012 and prior estimator.*/
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
    OPTION (QUERYTRACEON 9481);
GO
/* Look at the estimates.
Look at CardinalityEstimationModelVersion on the select operator
*/


/* Starting with SQL Server 2016 SP1, we have USE HINT syntax instead of 
having to use a trace flag (which requires higher permissions). Here's what that looks like: */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
    OPTION (USE HINT ('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
GO

/* Another thing that's nice about USE HINT is this... 
THERE'S AN EASY TO FIND LIST! YAYYYY!!!!*/
SELECT *
FROM sys.dm_exec_valid_use_hints;
GO


/* Hmm. But should we stop here? 
Being stuck on the old estimator might not be the best thing.
And potentially we could make this faster.
*/

/* FAST number_rows Query Hint
This sets a "row goal" for the optimizer to be biased towards plans that
can return the number of rows specified quickly.
Row goals can be set based on TSQL syntax as well, by using TOP, IN, or EXISTS keywords */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
OPTION (FAST  1)
GO

/* We have a nested loop plan now, and it's faster*/

/* What if we set the row goal to the number of rows that come back?*/
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
OPTION (FAST 10903)
GO

/* Still a nested loop plan, but no better.*/

/* What if I set it to the largest int value? */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
OPTION (FAST 2147483647)
GO


/* Our query hint sets the row goal for the WHOLE plan.
We can't put the row goal just in the CTE. The hint is broad and
inflexible. 
There are rewrite options with TSQL that will let you be much more
targeted with row goals.
*/




/* ~~~ Time for a break ~~~ */






/* Force a hash join: Compare these two plans */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
INNER HASH JOIN agg.FirstNameByYearStateWide AS fnby on /* Table hint */
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1;
GO

with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1 
	OPTION (HASH JOIN) /* Query hint */;
GO

/* Our plan went parallel now, but it's slow*/


/* Force a loop join with a table hint.
We had a nested loop plan when we set the row goal, but now we're forcing a loop on one join */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
INNER LOOP JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1;
GO
/* Not slower than the FAST row goal-- but not faster */


/* What if we use a temp table? (No hints.) */
DROP TABLE IF EXISTS #NameRank;
WITH NameRank AS (
    SELECT
        Id,
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT Id
INTO #NameRank
FROM NameRank
WHERE RankByGenderAndRow = 1;

SELECT 
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM #NameRank AS NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id=NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO
/* This got rid of the excessive grant problem, because we're materializing the rows
in the temp table before we use it. 
Temp tables support statistics so SQL Server understands how many rows are in there.*/


/* Table variable */
DECLARE @NameRank AS TABLE (
    Id BIGINT NOT NULL
);
WITH NameRank AS (
    SELECT
        Id,
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow
    FROM agg.FirstNameByYearStateWide AS fnby
)
INSERT @NameRank
SELECT Id
FROM NameRank
WHERE RankByGenderAndRow = 1;

SELECT 
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM @NameRank AS NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id=NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO

/* Look at the estimated rows coming out of the table variable.
It's off, but it performs pretty well in this case!
Table variables don't support statistics.
*/


/* Let's do the table variable + trace flag 2453 
We can't use the QUERYTRACEON query hint for this trace flag -- it's not supported.
This trace flag helps the optimizer see the number of rows in the table variable.
*/
DBCC TRACEON(2453);
GO
DECLARE @NameRank AS TABLE (
    Id BIGINT NOT NULL
);
WITH NameRank AS (
    SELECT
        Id,
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow
    FROM agg.FirstNameByYearStateWide AS fnby
)
INSERT @NameRank
SELECT Id
FROM NameRank
WHERE RankByGenderAndRow = 1;
SELECT 
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM @NameRank AS NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id=NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
	--OPTION (QUERYTRACEON 2453) /*-- this syntax not supported for this trace flag, does not work.*/
GO
DBCC TRACEOFF(2453);
GO


/* We do get a different plan but it's not a life-changing improvement. */
/* Look at QueryTimeStats to see which statement is taking the most time. */




/* ~~~ Time for a break ~~~ */




/* Why don't you use columnstore? it's the best for everything... right? */
/* This query uses a table hint to force the columnstore index on the first statement---
    that's the one that's taking the most time. */
DECLARE @NameRank AS TABLE (
    Id BIGINT NOT NULL
);
WITH NameRank AS (
    SELECT
        Id,
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow
    FROM agg.FirstNameByYearStateWide AS fnby WITH ( INDEX (ccx_agg_FirstNameByYearStateWide))
)
INSERT @NameRank
SELECT Id
FROM NameRank
WHERE RankByGenderAndRow = 1;

SELECT 
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM @NameRank AS NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id=NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO

/* Hmm, you're doing the sort as an independent operator.
I want to push that down INTO the columnstore. You just aren't figuring it out
for RANK windowing function syntax. */



/* Let's rewrite the query to try to leverage columnstore as best we can We aren't going to use RANK this time.
    * Our query doesn't return rank-- it returns the NameCount for the query with the highest NameCount
        in a given state and year
    * This rewrite uses GROUP BY and MAX()
Columnstore index can locally aggregates rows in the columnstore scan on Enterprise Edition.
There's NO table hint here to force using the nonclustered columnstore.
*/
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM agg.FirstNameByYearStateWide AS fnby 
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
JOIN
    (SELECT
        ReportYear,
        StateCode,
        Gender,
        MAX(NameCount) as max_namecount
    FROM agg.FirstNameByYearStateWide AS fnby
    GROUP BY ReportYear, StateCode, Gender
    ) as max_counts on
        fnby.ReportYear = max_counts.ReportYear and
        fnby.StateCode = max_counts.StateCode and
        fnby.Gender= max_counts.Gender and
        fnby.NameCount=max_namecount;
GO
/* Look at the locally aggregated rows. */


/* How does our re-write do without columnstore?
We can use the query hint IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX to get that plan */
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM agg.FirstNameByYearStateWide AS fnby 
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
JOIN
    (SELECT
        ReportYear,
        StateCode,
        Gender,
        MAX(NameCount) as max_namecount
    FROM agg.FirstNameByYearStateWide AS fnby
    GROUP BY ReportYear, StateCode, Gender
    ) as max_counts on
        fnby.ReportYear = max_counts.ReportYear and
        fnby.StateCode = max_counts.StateCode and
        fnby.Gender= max_counts.Gender and
        fnby.NameCount=max_namecount
OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO


/* So.... am I really getting the same results back with this rewrite? */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
INTO #originalquery
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1;

SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
INTO #maxrewrite
FROM agg.FirstNameByYearStateWide AS fnby 
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
JOIN
    (SELECT
        ReportYear,
        StateCode,
        Gender,
        MAX(NameCount) as max_namecount
    FROM agg.FirstNameByYearStateWide AS fnby
    GROUP BY ReportYear, StateCode, Gender
    ) as max_counts on
        fnby.ReportYear = max_counts.ReportYear and
        fnby.StateCode = max_counts.StateCode and
        fnby.Gender= max_counts.Gender and
        fnby.NameCount=max_namecount;
GO

SELECT * FROM #originalquery
EXCEPT
SELECT * FROM #maxrewrite;
GO
SELECT * FROM #maxrewrite
EXCEPT
SELECT * FROM #originalquery;
GO



/* ~~~ Time for a break ~~~ */





/*****************************************
Can I get similar performance to the MAX query with different TSQL?
Just as a query tuning exercise!
We're getting out of HINTS-ville here and getting more into TSQL fun.
******************************************/


/* 
I might try to move the row goal into the CTE itself.
But if we do that, we need to make sure we set the goal AFTER the limitation to 
	Rank = 1 is applied
We can't do this...
	Msg 4108, Level 15, State 1, Line 10
	Windowed functions can only appear in the SELECT or ORDER BY clauses.
*/ 
with NameRank AS (
    SELECT TOP (10903)
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby
	WHERE 
		RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) = 1
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = NameRank.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO

/* We can "fix" the estimate with a rowgoal like this, but it doesn't
end up super fast (and obviously has risks as our data grows because
TOP limits rows).

This is an interesting approach, and if you want to learn more about this, check
out Adam Machanic's great presentation on row goals: 
https://sqlbits.com/Sessions/Event14/Query_Tuning_Mastery_Clash_of_the_Row_Goals
 */
with NameRank AS (
    SELECT
        RANK () OVER (PARTITION BY ReportYear, StateCode, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        Id
    FROM agg.FirstNameByYearStateWide AS fnby),
RowGoal AS (
	SELECT TOP (10903 * 2)
		Id
	FROM NameRank
	WHERE RankByGenderAndRow = 1
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM RowGoal
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby.Id = RowGoal.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO

/* We're doing most of the time applying the windowing function
to figure out ALL the ranks and still applying the filter to get the #1 names at the end 
	-- that's a lot of extra work */


/* Moving the windowing function to the order by doesn't change that pattern
(simplified query) */
SELECT TOP (1) WITH TIES
	Id
FROM agg.FirstNameByYearStateWide AS fnby 
ORDER BY
    RANK() OVER (PARTITION BY ReportYear, StateCode, Gender
        ORDER BY NameCount DESC);
GO


/* Here is an interesting approach, but it doesn't perform well. 
This rewrite inspired by Paul White's article and example query: 
http://sqlblog.com/blogs/paul_white/archive/2010/07/28/the-segment-top-query-optimisation.aspx
*/
WITH GroupityGroup AS
(
SELECT DISTINCT
    ReportYear,
    StateCode,
	Gender
FROM agg.FirstNameByYearStateWide
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM GroupityGroup gg
CROSS APPLY
(
    -- Find the first row(s) for each group
    SELECT TOP (1) WITH TIES
        fnby.*
    FROM agg.FirstNameByYearStateWide AS fnby
    WHERE
        fnby.ReportYear = gg.ReportYear 
		and fnby.StateCode = gg.StateCode
		and fnby.Gender = gg.Gender
    ORDER BY
        fnby.NameCount DESC
) AS fnby
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId;
GO

/* But the heart of the approach is actually quite good...
(simplified query) */
WITH GroupityGroup AS
(
SELECT DISTINCT
    ReportYear,
    StateCode,
	Gender
FROM agg.FirstNameByYearStateWide
)
SELECT Id
FROM GroupityGroup gg
CROSS APPLY
(   /* Find the first row(s) for each group */
    SELECT TOP (1) WITH TIES
        fnby.Id
    FROM agg.FirstNameByYearStateWide AS fnby
    WHERE
        fnby.ReportYear = gg.ReportYear 
		and fnby.StateCode = gg.StateCode
		and fnby.Gender = gg.Gender
    ORDER BY
        fnby.NameCount DESC
) AS fnby
GO

/* So instead of pulling back all those reporting columns inside the
cross apply, what if I rejoin back to get them? */
WITH GroupityGroup AS
(
SELECT DISTINCT
    ReportYear,
    StateCode,
	Gender
FROM agg.FirstNameByYearStateWide
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM GroupityGroup gg
CROSS APPLY
(   /* Find the first row(s) for each group */
    SELECT TOP (1) WITH TIES
        fnby.Id
    FROM agg.FirstNameByYearStateWide AS fnby
    WHERE
        fnby.ReportYear = gg.ReportYear 
		and fnby.StateCode = gg.StateCode
		and fnby.Gender = gg.Gender
    ORDER BY
        fnby.NameCount DESC
) AS fnby1
/* Joining again to pick up the reporting columns */
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby1.Id = fnby.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
GO


/* What if I don't let it use the columnstore with this approach? */
WITH GroupityGroup AS
(
SELECT DISTINCT
    ReportYear,
    StateCode,
	Gender
FROM agg.FirstNameByYearStateWide
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
FROM GroupityGroup gg
CROSS APPLY
(   /* Find the first row(s) for each group */
    SELECT TOP (1) WITH TIES
        fnby.Id
    FROM agg.FirstNameByYearStateWide AS fnby
    WHERE
        fnby.ReportYear = gg.ReportYear 
		and fnby.StateCode = gg.StateCode
		and fnby.Gender = gg.Gender
    ORDER BY
        fnby.NameCount DESC
) AS fnby1
/* Joining again to pick up the reporting columns */
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby1.Id = fnby.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
	OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO



/* So.... am I really getting the same results back with this rewrite? */
/* Let's dump these results into a temp table... */
WITH GroupityGroup AS
(
SELECT DISTINCT
    ReportYear,
    StateCode,
	Gender
FROM agg.FirstNameByYearStateWide
)
SELECT
    fnby.ReportYear, fnby.StateCode, fnby.Gender, fn.FirstName,  fnby.NameCount,
    fnby.ReportColumn1, fnby.ReportColumn2, fnby.ReportColumn3, fnby.ReportColumn4, fnby.ReportColumn5, fnby.ReportColumn6,
    fnby.ReportColumn7, fnby.ReportColumn8, fnby.ReportColumn9, fnby.ReportColumn10, fnby.ReportColumn11, fnby.ReportColumn12,
    fnby.ReportColumn13, fnby.ReportColumn14, fnby.ReportColumn15, fnby.ReportColumn16, fnby.ReportColumn17, fnby.ReportColumn18,
    fnby.ReportColumn19, fnby.ReportColumn20
INTO #distinctapplyrewrite
FROM GroupityGroup gg
CROSS APPLY
(   /* Find the first row(s) for each group */
    SELECT TOP (1) WITH TIES
        fnby.Id
    FROM agg.FirstNameByYearStateWide AS fnby
    WHERE
        fnby.ReportYear = gg.ReportYear 
		and fnby.StateCode = gg.StateCode
		and fnby.Gender = gg.Gender
    ORDER BY
        fnby.NameCount DESC
) AS fnby1
/* Joining again to pick up the reporting columns */
JOIN agg.FirstNameByYearStateWide AS fnby on
    fnby1.Id = fnby.Id
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
	OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO

/* Now compare to the results of #orginalquery which 
we put into a temp table earlier */
SELECT * FROM #originalquery
EXCEPT
SELECT * FROM #distinctapplyrewrite;
GO
SELECT * FROM #distinctapplyrewrite
EXCEPT
SELECT * FROM #originalquery;
GO


