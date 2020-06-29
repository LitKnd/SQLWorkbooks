/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/why-creating-an-index-can-make-a-query-slower

This is only suitable for test environments.
*****************************************************************************/

use BabbyNames;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/* Run this with actual execution plans enabled */
exec dbo.NameCountByGender @FirstName='Matthew';
GO


/*
Compare estimates vs actuals on  the index seek and key lookup into dbo.FirstNameByBirthDate_1966_2015

SQL Server is underestimating the number of Matthews by a lot
This table has a row for every baby named Matthew in the United States between 1966 and 2015. 
There are a lot more Matthews than 6K. Our estimate is off by around 1.4 million.


Look at actual time statistics in the plan properties to see where we are spending so much time.
*/


/* Why is the estimate so low?
Let's look at the stats in the table
*/
SELECT 
    stat.stats_id,
    stat.name as stats_name,
    STUFF((SELECT ', ' + cols.name
        FROM sys.stats_columns AS statcols
        JOIN sys.columns AS cols ON
            statcols.column_id=cols.column_id
            AND statcols.object_id=cols.object_id
        WHERE statcols.stats_id = stat.stats_id and
            statcols.object_id=stat.object_id
        ORDER BY statcols.stats_column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')  as stat_cols,
    stat.filter_definition,
    stat.is_temporary,
    stat.no_recompute,
    sp.last_updated,
    sp.modification_counter,
    sp.rows,
    sp.rows_sampled
FROM sys.stats as stat
CROSS APPLY sys.dm_db_stats_properties (stat.object_id, stat.stats_id) AS sp
JOIN sys.objects as so on 
    stat.object_id=so.object_id
JOIN sys.schemas as sc on
    so.schema_id=sc.schema_id
WHERE 
    sc.name= 'dbo'
    and so.name='FirstNameByBirthDate_1966_2015'
ORDER BY 1, 2;
GO


/* Look at rows and rows sampled for the statistic related to the index
ix_dbo_FirstNameByBirthDate_1966_2015_FirstNameId. Looks pretty good, right?

Let's look at the info on that statistic...
 */

DBCC SHOW_STATISTICS (FirstNameByBirthDate_1966_2015, ix_dbo_FirstNameByBirthDate_1966_2015_FirstNameId);
GO

/*

1) The FirstNameId for �Matthew� is 28,073. Find it in the histogram.
	Estimate looks pretty good, right?


2) Find the 'All density' number in the Density Vector
	3.774155E-05

3) Find the number of rows in the header
	159,405,121

SELECT 159405121 * 3.774155E-05
	= 6016.19634447755
*/


/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/* We get the EXACT same estimate for a name with a much smaller count...
and this plan is much faster when it doesn't have to do so many lookups */
exec dbo.NameCountByGender @FirstName='Fay' WITH RECOMPILE;
GO



/* Compare the estimated plans for these queries */
/* This is our original query (rewritten without the procedure) */
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
JOIN ref.FirstName as fn on
	fnbd.FirstNameId=fn.FirstNameId
WHERE fn.FirstName='Matthew'
GROUP BY Gender;
GO


/* What if we specify the FirstNameId for Matthew? */
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
JOIN ref.FirstName as fn on
  fnbd.FirstNameId=fn.FirstNameId
where fn.FirstNameId=28073
GROUP BY Gender;
GO



/* Summing it up... why is it slow?

	We wrote our query putting a predicate on FirstName on the dimension table, ref.FirstName, 
	then joined over to dbo.FirstNameByBirthDate_1966_2015. SQL Server has to generate the execution 
	plan for the query before it runs. 
	
	SQL Server can�t query ref.FirstName and find out what the FirstNameId is for Matthew, 
	then use that to figure out what kind of join to use.

	(At least not yet. Plans like this can potentially be fixed by the Adaptive Join feature 
	in future releases, but it doesn�t cover this in the initial SQL Server 2017 release. 
	They can�t tackle everything at once.)

	Instead, SQL Server has to say, �For any given name that I join on, what looks like the best bet?�

	And that�s why it uses the density vector on the statistic multiplied by the rowcount. 
	There�s nothing wrong with the statistics.

	But there are SO MANY Matthews that doing all the lookups in this plan is slow.

*/




/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO

/* Moving the where clause up into the join does not solve the problem.*/
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
JOIN ref.FirstName as fn on
	fnbd.FirstNameId=fn.FirstNameId
	and fn.FirstName='Matthew'
GROUP BY Gender;
GO


/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/*
Rewriting the query like this does not solve the problem.
It's still normalized and executed as a single query operation.
*/
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
WHERE FirstNameId=(select FirstNameId from ref.FirstName where FirstName = 'Matthew')
GROUP BY Gender
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/*
Same thing for a CTE
*/
WITH FirstNameId AS
	(SELECT FirstNameId FROM ref.FirstName WHERE FirstName = 'Matthew')
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
JOIN FirstNameId fn on 
	fnbd.FirstNameId= fn.FirstNameId 
GROUP BY Gender;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/*
Adding a recompile hint changes nothing 
*/
SELECT Gender, COUNT(*)
FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
JOIN ref.FirstName as fn on
  fnbd.FirstNameId=fn.FirstNameId
where fn.FirstName='Matthew'
GROUP BY Gender
	OPTION (RECOMPILE);
GO



/********************************************************************
SAMPLE SOLUTIONS (Not all are created equal! Some are bad.)
*********************************************************************/


/*  index hint by name */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_indexhint;
GO
CREATE PROCEDURE dbo.NameCountByGender_indexhint
	@FirstName varchar(256)
AS
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd WITH (INDEX ([cx_FirstNameByBirthDate_1966_2015]))
	JOIN ref.FirstName as fn on
	  fnbd.FirstNameId=fn.FirstNameId
	WHERE fn.FirstName = @FirstName
	GROUP BY Gender;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_indexhint @FirstName='Matthew';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
-- We get consistent performance
-- but the nested loop plan was actually faster for names without so many rows
EXEC dbo.NameCountByGender_indexhint @FirstName='Fay' WITH RECOMPILE;
GO
/* 
Pros:
	Consistent performance when compiled for different values
	"As fast" as it was before the nonclustered index on FirstNameId was added

Cons:
	Not the fastest possible plans for names who don't have millions of rows
	Query will fail if index is renamed
	Query will NOT adapt if the perfect nonclustered index exists

Verdict: 
	Avoid, there are better ways.
*/





/*  FORCESCAN table hint */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_FORCESCAN;
GO
CREATE PROCEDURE dbo.NameCountByGender_FORCESCAN
	@FirstName varchar(256)
AS
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd WITH (FORCESCAN)
	JOIN ref.FirstName as fn on
	  fnbd.FirstNameId=fn.FirstNameId
	WHERE fn.FirstName = @FirstName
	GROUP BY Gender;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_FORCESCAN @FirstName='Matthew';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
-- We get consistent performance
-- but the nested loop plan was actually faster for names without so many rows
EXEC dbo.NameCountByGender_FORCESCAN @FirstName='Fay' WITH RECOMPILE;
GO
/* 
Pros:
	Consistent performance when compiled for different values
	"As fast" as it was before the nonclustered index on FirstNameId was added

Cons:
	Not the fastest possible plans for names who don't have millions of rows
	FORCESCAN will force a scan even if the perfect index is added:
		It will NOT automatically adapt perfectly if we improve the index...
		Because it's forced to scan whatever index it uses

Verdict: 
	Better than the named index hint.
	Could be acceptable if you have a practice of reviewing hinted queries every
		time you add/drop/modify an index
*/



/* Local variable...
*/
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_variable;
GO
CREATE PROCEDURE dbo.NameCountByGender_variable
	@FirstName varchar(256)
AS
	DECLARE @FirstNameId INT;
	
	SELECT @FirstNameId = FirstNameId
	FROM ref.FirstName
	WHERE FirstName = @FirstName;

	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd 
	WHERE fnbd.FirstNameId = @FirstNameId
	GROUP BY Gender;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
/* Variables declared inside stored procedures are anonymous, 
so we end up with the same old estimate problem. */
EXEC dbo.NameCountByGender_variable @FirstName='Matthew';
GO

/* There is a workaround for this, but it has notable $problems$... */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_variable;
GO
CREATE PROCEDURE dbo.NameCountByGender_variable
	@FirstName varchar(256)
AS
	DECLARE @FirstNameId INT;
	
	SELECT @FirstNameId = FirstNameId
	FROM ref.FirstName
	WHERE FirstName = @FirstName;

	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd 
	WHERE fnbd.FirstNameId = @FirstNameId
	GROUP BY Gender
		OPTION (RECOMPILE);
GO


/* 
Pros: Smarter when it compiles for Matthew (or anyone)
	Will automatically adapt if we improve the index

Cons:
	Compiles every time it runs
	Drives up CPU usage
		This is $expensive$ if this query runs frequently
		OR if we make this a habit (which is VERY COMMON when you start doing this)
	Makes perf monitoring harder if we aren't using Query Store

Verdict: 
	I avoid this, because recompiles quickly become $expensive$ in licensing dollars
	It's also very hard to monitor performance for these prior to 2016/ Query Store
*/





/* Creative, but gets VERY weird in some cases. */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_Creative;
GO
CREATE PROCEDURE dbo.NameCountByGender_Creative
	@FirstName varchar(256)
AS
	SELECT FirstNameId 
	INTO #FirstName
	FROM ref.FirstName
	WHERE FirstName=@FirstName;

	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd
	JOIN #FirstName as fn on
	  fnbd.FirstNameId=fn.FirstNameId
	where fnbd.FirstNameId=fn.FirstNameId
	GROUP BY Gender;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_Creative @FirstName='Matthew';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO

/* Note the estimated # of rows coming out of the hash match on the first plan.
Now run this and look at the same thing */
EXEC dbo.NameCountByGender_Creative @FirstName='Fay';
GO


--What if Fay runs first?
DBCC DROPCLEANBUFFERS;
GO
EXEC sp_recompile 'dbo.NameCountByGender_Creative';
GO
EXEC dbo.NameCountByGender_Creative @FirstName='Fay';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_Creative @FirstName='Matthew';
GO


/* 
Pros: Smarter when it compiles for Matthew
	Will automatically adapt if we improve the index

Cons: If it compiles for a 'small' name, we run into plan re-use issues
	SQL Server can and will re-use cached temp tables from prior executions
		... complete with the stats on those tables
	So troubleshooting this can get VERY weird in some cases!

Verdict: 
	I avoid this when possible because the statistics issues get so weird.
	Not that I don't use temp tables. I do when they are helpful!
	I just don't use them as a "fake" variable.
*/





/*  Dynamic SQL */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_DSQL;
GO
CREATE PROCEDURE dbo.NameCountByGender_DSQL
	@FirstName varchar(256)
AS
	DECLARE @FirstNameIdIN INT,
		@DSQL nvarchar(2000);

	SELECT @FirstNameIdIN = FirstNameId
	FROM ref.FirstName
	WHERE FirstName = @FirstName;

	SET @DSQL = N'
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 
	WHERE FirstNameId = @FirstNameId
	GROUP BY Gender;'

	EXEC sp_executesql @stmt = @DSQL, @params = N'@FirstNameId INT', @FirstNameId = @FirstNameIdIN;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO

EXEC dbo.NameCountByGender_DSQL @FirstName='Matthew';
GO

/*
We have a plan re-use problem here...
What if it runs first for Fay? 
*/
exec sp_recompile 'dbo.FirstNameByBirthDate_1966_2015';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL @FirstName='Fay';
GO
/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL @FirstName='Matthew';
GO

/* 
Pros: Smarter when it compiles for Matthew
	Will automatically adapt if we improve the index

Cons: If it compiles for a 'small' name, we run into plan re-use problems,
		 and it's slower again (although not the slowest it's been)

Consideration:
	Dynamic SQL *may* make troubleshooting and maintaining code trickier

Verdict: 
	I avoid this because of the plan re-use issue. We can do better with DSQL.
*/



/* We could force it to recompile the dynamic sql every time... */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_DSQL_RECOMPILE;
GO
CREATE PROCEDURE dbo.NameCountByGender_DSQL_RECOMPILE
	@FirstName varchar(256)
AS
	DECLARE @FirstNameIdIN INT,
		@DSQL nvarchar(2000);

	SELECT @FirstNameIdIN = FirstNameId
	FROM ref.FirstName
	WHERE FirstName = @FirstName;

	SET @DSQL = N'
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 
	WHERE FirstNameId = @FirstNameId
	GROUP BY Gender 
	OPTION (RECOMPILE);'

	EXEC sp_executesql @stmt = @DSQL, @params = N'@FirstNameId INT', @FirstNameId = @FirstNameIdIN;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL_RECOMPILE @FirstName='Fay';
GO
/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL_RECOMPILE @FirstName='Matthew';
GO

/* 
Pros: Smarter when it compiles for Matthew (or anyone)
	Will automatically adapt if we improve the index

Cons:
	Compiles every time it runs
	Drives up CPU usage
		This is $expensive$ if this query runs frequently
		OR if we make this a habit (which is VERY COMMON when you start doing this)
	Makes perf monitoring harder if we aren't using Query Store

Consideration:
	Dynamic SQL *may* make troubleshooting and maintaining code trickier

Verdict: 
	I avoid this because RECOMPILE is literally $expensive$ and makes monitoring
		a nightmare without query store. We can do better with DSQL.
*/




/* We can branch and have a "big plan" and a "small plan"... */
/* This uses dynamic sql, but you could also use sub-procedures */
DROP PROCEDURE IF EXISTS dbo.NameCountByGender_DSQL_OPTIMIZEFOR;
GO
CREATE PROCEDURE dbo.NameCountByGender_DSQL_OPTIMIZEFOR
	@FirstName varchar(256)
AS
	DECLARE @FirstNameIdIN INT,
		@TotalNameCount INT,
		@DSQL nvarchar(2000);

	SELECT @FirstNameIdIN = FirstNameId,
		@TotalNameCount = TotalNameCount
	FROM ref.FirstName
	WHERE FirstName = @FirstName;

	IF @TotalNameCount > 1000000

		SET @DSQL = N'
		SELECT Gender, COUNT(*)
		FROM dbo.FirstNameByBirthDate_1966_2015 
		WHERE FirstNameId = @FirstNameId
		GROUP BY Gender 
		/* Optimize for FirstName = ''Matthew'' for ''popular'' names */
		OPTION (OPTIMIZE FOR (@FirstNameId=28073));'
	ELSE 
		SET @DSQL = N'
		SELECT Gender, COUNT(*)
		FROM dbo.FirstNameByBirthDate_1966_2015 
		WHERE FirstNameId = @FirstNameId
		GROUP BY Gender 
		/* Optimize for FirstName = ''Fay'' for ''infrequent'' names */
		OPTION (OPTIMIZE FOR (@FirstNameId=20427));'

	EXEC sp_executesql @stmt = @DSQL, @params = N'@FirstNameId INT', @FirstNameId = @FirstNameIdIN;
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL_OPTIMIZEFOR @FirstName='Fay';
GO
/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_DSQL_OPTIMIZEFOR @FirstName='Matthew';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
--Just below the 1 mill threshold
EXEC dbo.NameCountByGender_DSQL_OPTIMIZEFOR @FirstName='Karen';
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
--Just above the 1 mill threshold
EXEC dbo.NameCountByGender_DSQL_OPTIMIZEFOR @FirstName='Betty';
GO


/* 
Pros: Smarter when it compiles for Matthew (or anyone)
	Will automatically adapt if we improve the index
	Uses 2 execution plans (instead of compiling every run)
	Goes parallel only for "popular" names

Considerations:
	Dynamic SQL *may* make troubleshooting and maintaining code trickier
	We had to have a reliable branching criterion, which is sometimes
		very hard, so this isn't always a good fit.

Verdict: 
	This can be a great option when it's viable.
*/








/******************************************************************
Extras / things that don't make a difference in this case
(but may be of interest for other cases!)
******************************************************************/



/* USE hint... 
This syntax is available SQL Server 206 SP1+
For SQL Server 2014, this hint is TF 9476 (hint for new cardinality estimator)
This hint tweaks cardinality estimator algorithms and uses 
	"simple containment" instead of "base containment" assumptions
https://support.microsoft.com/en-us/help/3189675/join-containment-assumption-in-the-new-cardinality-estimator-degrades-query-performance-in-sql-server-2014-and-later
*/
SELECT * FROM sys.dm_exec_valid_use_hints;
GO

DROP PROCEDURE IF EXISTS dbo.NameCountByGender_SimpleContainment;
GO
CREATE PROCEDURE dbo.NameCountByGender_SimpleContainment
	@FirstName varchar(256)
AS
	SELECT Gender, COUNT(*)
	FROM dbo.FirstNameByBirthDate_1966_2015 AS fnbd 
	JOIN ref.FirstName as fn on
	  fnbd.FirstNameId=fn.FirstNameId
	WHERE fn.FirstName = @FirstName
	GROUP BY Gender
		OPTION ( use hint ('ASSUME_JOIN_PREDICATE_DEPENDS_ON_FILTERS') );
GO

/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_SimpleContainment @FirstName='Fay';
GO
/* Cold cache - do not use on production or shared environments */
DBCC DROPCLEANBUFFERS;
GO
EXEC dbo.NameCountByGender_SimpleContainment @FirstName='Matthew' WITH RECOMPILE;
GO

