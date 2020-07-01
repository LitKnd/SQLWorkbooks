/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tuning-problem-queries-in-table-partitioning
*****************************************************************************/

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


USE BabbyNames;
GO

/* These are the two tables that we'll be using... */
exec sp_help 'dbo.FirstNameByBirthDate_1966_2015';
GO
exec sp_help 'pt.FirstNameByBirthDate_1966_2015';
GO

/********************************************************/
/* Problem Query: The aggregator                        */
/********************************************************/


/* Run these with actual plans enabled.
Compare the estimated cost
Compare the query time stats
Show why the columnstore index is drunk here.
*/
SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM dbo.FirstNameByBirthDate_1966_2015
WHERE BirthYear BETWEEN 2001 and 2015
GROUP BY BirthYear
ORDER BY COUNT(*) DESC;
GO

SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE BirthYear BETWEEN 2001 and 2015
GROUP BY BirthYear
ORDER BY COUNT(*) DESC;
GO

/* OK, let's just not use the columnstore.
Let's use the partitioned rowstore index on BirthYear. */
SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE BirthYear BETWEEN 2001 and 2015
GROUP BY BirthYear
ORDER BY COUNT(*) DESC
OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO

/* It's still a bit slower */
/* Head back to the slides to explain why the partitioned index is different */










/*************************************************************************
Fixes
*************************************************************************/

/***************************
FIX 1 - NONALIGNED INDEX
***************************/

/* We can create a "non-aligned", non-partitioned index on our partitioned 
table. Just specify a filegroup rather than a partition scheme */
/* I'm giving it a short (terrible) name just to make it easy to identify in the execution plan */
/* This takes 1.5 minutes to create. */
CREATE INDEX nonaligned
	on pt.FirstNameByBirthDate_1966_2015 (BirthYear)
	WITH (SORT_IN_TEMPDB = ON)
	ON [PRIMARY];
GO


/* Now we can get a stream aggregate .... */
SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE BirthYear BETWEEN 2001 and 2015
GROUP BY BirthYear
ORDER BY COUNT(*) DESC
    OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO

/* But we've lost the ability to do partition level operations:
	switch any partition in
	switch any partition out
	truncate any partition 

We have to drop or disable all non-aligned indexes to do ANY partition level operation.
*/

TRUNCATE TABLE pt.FirstNameByBirthDate_1966_2015
    WITH (PARTITIONS (1 TO 4));
GO

DROP INDEX IF EXISTS nonaligned 
    ON pt.FirstNameByBirthDate_1966_2015;
GO

/***************************
FIX 1 - NOT SO GREAT.
***************************/


/***************************
FIX 2 - QUERY REWRITE TO GET
PARTION ELIMINATION 
***************************/


/* We can rewrite the query to get partition elimination.
We're still going to have to do the hash aggregate, but we'll
do it for fewer partitions */

/* Run these with actual plans on.
Look at how many actual partitions were used in the plan.*/
SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE
    FakeBirthDateStamp >= CAST('2001-01-01' AS DATETIME2(0)) and 
    FakeBirthDateStamp < CAST('2016-01-01' AS DATETIME2(0))
GROUP BY BirthYear
ORDER BY COUNT(*) DESC
OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX);
GO

SELECT
	BirthYear,
	COUNT(*) as NameCount
FROM pt.FirstNameByBirthDate_1966_2015
WHERE
    FakeBirthDateStamp >= CAST('2001-01-01' AS DATETIME2(0)) and 
    FakeBirthDateStamp < CAST('2016-01-01' AS DATETIME2(0))
GROUP BY BirthYear
ORDER BY COUNT(*) DESC;
GO