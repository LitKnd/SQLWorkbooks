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

/********************************************************/
/* Problem: MIN / MAX get slow                          */
/********************************************************/


/* Run these with actual plans enabled.
Note the differences between the plans.
It knows the query against the partitioned table will be more expensive. 
    Look at elapsed time in each plan.
    Query 1: look at the seek operator and explain why that was fast.
    Query 2: How many partitions were actually used?
*/
/* Why is the second query slower? */
SELECT MAX(FirstNameId) AS max_val
FROM dbo.FirstNameByBirthDate_1966_2015
GO

SELECT MAX(FirstNameId) AS max_val
FROM pt.FirstNameByBirthDate_1966_2015
OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX)
GO












/* MIN has the same issue (although of course a different resulting value) */
SELECT MIN(FirstNameId) AS min_val
FROM pt.FirstNameByBirthDate_1966_2015
OPTION (IGNORE_NONCLUSTERED_COLUMNSTORE_INDEX)
GO




/* To the slides, to talk this through! */




/*************************************************************************
Fixes
*************************************************************************/

/***************************
FIX 1 - Non-Aligned Index
***************************/

/* We can create a "non-aligned", non-partitioned index on our partitioned 
table. Just specify a filegroup rather than a partition scheme */
/* I'm giving it a short (terrible) name just to make it easy to identify in the execution plan */
/* This takes 1.5 minutes to create. */
CREATE INDEX nonaligned
	on pt.FirstNameByBirthDate_1966_2015 (FirstNameId)
	WITH (SORT_IN_TEMPDB = ON)
	ON [PRIMARY];
GO


/* Now we get the "non-partitioned" plan .... */
SELECT MAX(FirstNameId) AS max_val
FROM pt.FirstNameByBirthDate_1966_2015;
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
FIX 2 - Query rewrite
***************************/
/* OK, let's practice the recommended workaround from the Connect Item */

/* Our solution relies on the $partition function.
This computes which partition data is in... here's a simple example */
SELECT $partition.pf_fnbd(FakeBirthDateStamp) as partition_number, 
	FakeBirthDateStamp,
    FirstNameByBirthDateId,
    BirthYear,
    FirstNameId, 
    Gender
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp = CAST('1966-01-05 18:29:00' AS DATETIME2(0));
GO



/* Testing out the pattern in https://connect.microsoft.com/SQLServer/feedback/details/240968/partition-table-using-min-max-functions-and-top-n-index-selection-and-performance */
/* We're just looking at partition #s 41, 42, 43 here */
/* We can use the function in interesting ways.
Look at the plan for this query... it does a very efficient backward scan in each partition */
SELECT MAX(max_val)
FROM 
( VALUES (41), (42), (43) ) as partitiontable(num) /* 3 row table from table value constructor */
CROSS APPLY
     (SELECT MAX(FirstNameId) as max_val
        FROM pt.FirstNameByBirthDate_1966_2015
        /* CROSS APPLY lets us join to the table value constructor in here */
        WHERE $partition.pf_fnbd(FakeBirthDateStamp) = partitiontable.num
	) AS o;
GO



/* What if we have a changing number of partitions over time? */

/* We can use the partition function "fanout" and a numbers
table to construct a table with one row for each partition number, like this */
SELECT n.Num
FROM sys.partition_functions AS pf
JOIN ref.Numbers as n on n.Num <= pf.fanout
WHERE 
	pf.name='pf_fnbd';
GO


/* So we can get an automatic peek into each partition which has rows using this... */
/* Note: joining to a system table prevents parallelism, so I'm doing this as a two-step
	query and putting the value for @fanout into a variable */
DECLARE @fanout int
SELECT @fanout = fanout
FROM sys.partition_functions pf
WHERE pf.name='pf_fnbd'

SELECT MAX(max_val)
FROM ( 
	SELECT Num
	FROM ref.Numbers
	WHERE Num <= @fanout
	) as partitiontable(num) 
CROSS APPLY
     (select MAX(FirstNameId) as max_val
        from pt.FirstNameByBirthDate_1966_2015
        where $partition.pf_fnbd(FakeBirthDateStamp) = partitiontable.num
	) as o;
GO


/* It's not pretty. 
Don't like it? 
Vote up the bug! 
https://connect.microsoft.com/SQLServer/feedback/details/240968/partition-table-using-min-max-functions-and-top-n-index-selection-and-performance 
*/


/***************************
FIX 3 - Columnstore
***************************/


SELECT MAX(FirstNameId) AS max_val
FROM pt.FirstNameByBirthDate_1966_2015;
GO
