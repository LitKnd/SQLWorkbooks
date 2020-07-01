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
/* Problem: Unexpected blocking                         */
/********************************************************/


/* Start this query in another session. 
This will take out a lock on the partition holding 2015 data */
USE BabbyNames;
GO
BEGIN TRAN
DECLARE @updateval DATETIME2(0)='2010-01-01 03:49:00'

	UPDATE pt.FirstNameByBirthDate_1966_2015
	SET StateCode = 'ZZ'
	WHERE FakeBirthDateStamp=@updateval
	and FirstNameId = 67092;




/* This query should only need to read from one partition.
Start it up in this session. */
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp >= '2000-01-01 00:00:00.0'
	AND FakeBirthDateStamp < '2000-01-02 00:00:00.0';
GO


/* Confirm that it is blocked in a third session.
Why?
*/
exec sp_WhoIsActive @get_plans=1;
GO

/* Look at the predicate on the columnstore operator in the plan
    There's a convert_implicit
    And there's @1 and @1

Cancel the blocked query
*/



/* This is a simple query, so SQL Server is automatically parameterizing those dates.
It sees it needs to make them a DATETIME2, but it defaults to making them DATETIME2(7)
The column in the table is a DATETIME2(0).
When you compare a more precise value to a less precise value, SQL Server has to down-sample the less-precise value
So it's having to check every partition to see if the dates we want could be in there.
*/





/* Get an estimated plan for this corrected query. 
	Look at the seek predicate which magically appeared.
Then run the query and look at the actual plan / 
    actual partitions accessed.                         */
SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp > CAST('2000-01-01 00:00:00.0' AS DATETIME2(0))
	AND FakeBirthDateStamp <= CAST('2000-01-02 00:00:00.0' AS DATETIME2(0))
GO









/* This also works fine */
DECLARE @FakeBirthDateStampStart DATETIME2(0) = '2000-01-01 00:00:00.0',
	@FakeBirthDateStampEnd DATETIME2(0) = '2000-01-02 00:00:00.0';

SELECT COUNT(*)
FROM pt.FirstNameByBirthDate_1966_2015
WHERE FakeBirthDateStamp > @FakeBirthDateStampStart
	AND FakeBirthDateStamp <= @FakeBirthDateStampEnd
GO



