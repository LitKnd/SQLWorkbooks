/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-speed-up-the-popular-names-query/

*****************************************************************************/

SET STATISTICS TIME, IO OFF
GO
SET NOCOUNT ON;
GO
USE BabbyNames;
GO

/* How do I know where to start?
This is the original problem query, no changes made.

One observation: 
	@YearToRank is a local variable, NOT a parameter
	Sometimes that changes performance / execution plans dramatically
	I would want to know how this query is normally executed
		If it's run as a proc, I'd test with a proc
		If it's run as a parameterized query, I'd test that way 
	For fun, we'll tune this in a couple of formats!

Where do we start?
First, we run initial query (local variable version) with actual plans on
	Start at the top right branch of the plan
	Ask: where are rows being filtered / predicates applied?
	Compare estimates vs actuals

	What about other branches?
*/

DECLARE @YearToRank INT = 1991;

with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	startyear.ReportYear + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	startyear.ReportYear - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	startyear.ReportYear - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	startyear.ReportYear + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = @YearToRank
	and startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender;
GO





/* 
We want to push the filter for ReportYear down to the end of the branch

Idea 1: That local variable makes @ReportYear effectively anonymous
	What if we made @ReportYear more ... literal / 
	made the value something SQL Server can see?
*/







/***********************************************
SOLUTION: Keep the local variable and
	*make it work*

This one has two steps...
************************************************/


--Step 1: Using a RECOMPILE hint with a local variable makes SQL Server see the literal values

--Run with actual plans
--Where is the predicate now in the top right branch?
--What about other branches?
DECLARE @YearToRank INT = 1991;

with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	startyear.ReportYear + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	startyear.ReportYear - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	startyear.ReportYear - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	startyear.ReportYear + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = @YearToRank
	and startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender
	OPTION (RECOMPILE);
GO




--Step 2: Simplify the join predicates in our T-SQL

--Run with actual plans
--Where is the predicate now in the top right branch?
--What about other branches?

SET STATISTICS IO ON;
GO
DECLARE @YearToRank INT = 1991;

with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	--startyear.ReportYear + 10 = ten_years_later.ReportYear
	@YearToRank + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	--startyear.ReportYear - 10 = ten_years_prior.ReportYear
	@YearToRank - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	--startyear.ReportYear - 20 = twenty_years_prior.ReportYear
	@YearToRank - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	--startyear.ReportYear + 20 = twenty_years_later.ReportYear
	@YearToRank + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = @YearToRank
	and startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender
	OPTION (RECOMPILE);
GO
SET STATISTICS IO OFF;
GO




/***********************************************
Solution: Go Literal
Let's get rid of the local variable ENTIRELY
************************************************/

--Run with actual plans on
--Look at the filter
--Where's the compute scalar next to the filter now?

--DECLARE @YearToRank INT = 1991;

SET STATISTICS IO ON;
GO

with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	1991 + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	1991 - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	1991 - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	1991 + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = 1991
	and startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender;
GO


SET STATISTICS IO OFF;
GO







/***********************************************
Solution: Make it a procedure, and tune that

It's a best practice to use re-usable, parameterized code --
for good reasons! 

RECOMPILE = 🔥🔥🚽🔥🔥

Can we find a solution that does that?
************************************************/

--Step 1: proceduralize it
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT  /* This is a parameter NOT a local variable */
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby
	)
	SELECT 
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM rankbyyear AS startyear
	JOIN rankbyyear AS ten_years_later on
		startyear.ReportYear + 10 = ten_years_later.ReportYear
		and startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN rankbyyear AS ten_years_prior on
		startyear.ReportYear - 10 = ten_years_prior.ReportYear
		and startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_prior on
		startyear.ReportYear - 20 = twenty_years_prior.ReportYear
		and startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_later on
		startyear.ReportYear + 20 = twenty_years_later.ReportYear
		and startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE 
		startyear.ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO


--Run with actual plans on.
--Is it pushing the predicate down?
SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO


--Step 2: Simplify the math... what does that do on its own?
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT  /* This is a parameter NOT a local variable */
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby
	)
	SELECT 
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM rankbyyear AS startyear
	JOIN rankbyyear AS ten_years_later on
		--startyear.ReportYear + 10 = ten_years_later.ReportYear
		@YearToRank + 10 = ten_years_later.ReportYear
		and startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN rankbyyear AS ten_years_prior on
		--startyear.ReportYear - 10 = ten_years_prior.ReportYear
		@YearToRank - 10 = ten_years_prior.ReportYear
		and startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_prior on
		--startyear.ReportYear - 20 = twenty_years_prior.ReportYear
		@YearToRank - 20 = twenty_years_prior.ReportYear
		and startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_later on
		--startyear.ReportYear + 20 = twenty_years_later.ReportYear
		@YearToRank + 20 = twenty_years_later.ReportYear
		and startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE 
		startyear.ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO




--Step 3: Test the RECOMPILE hint
--Does it still work? 
--Reminder: Our goal is REUSABLE parameterized plan
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT  /* This is a parameter NOT a local variable */
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby
	)
	SELECT 
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM rankbyyear AS startyear
	JOIN rankbyyear AS ten_years_later on
		--startyear.ReportYear + 10 = ten_years_later.ReportYear
		@YearToRank + 10 = ten_years_later.ReportYear
		and startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN rankbyyear AS ten_years_prior on
		--startyear.ReportYear - 10 = ten_years_prior.ReportYear
		@YearToRank - 10 = ten_years_prior.ReportYear
		and startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_prior on
		--startyear.ReportYear - 20 = twenty_years_prior.ReportYear
		@YearToRank - 20 = twenty_years_prior.ReportYear
		and startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_later on
		--startyear.ReportYear + 20 = twenty_years_later.ReportYear
		@YearToRank + 20 = twenty_years_later.ReportYear
		and startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE 
		startyear.ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender
		OPTION (RECOMPILE);
GO

SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO


--That works, but... do we HAVE to use RECOMPILE?
--It's got downsides!




--What about a temp table? This is kind of breaking the rules.
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT  /* This is a parameter NOT a local variable */
AS
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	INTO #temp
	FROM agg.FirstNameByYear fnby;

	SELECT 
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM #temp as startyear
	JOIN #temp AS ten_years_later on
		--startyear.ReportYear + 10 = ten_years_later.ReportYear
		@YearToRank + 10 = ten_years_later.ReportYear
		and startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN #temp AS ten_years_prior on
		--startyear.ReportYear - 10 = ten_years_prior.ReportYear
		@YearToRank - 10 = ten_years_prior.ReportYear
		and startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN #temp AS twenty_years_prior on
		--startyear.ReportYear - 20 = twenty_years_prior.ReportYear
		@YearToRank - 20 = twenty_years_prior.ReportYear
		and startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN #temp AS twenty_years_later on
		--startyear.ReportYear + 20 = twenty_years_later.ReportYear
		@YearToRank + 20 = twenty_years_later.ReportYear
		and startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE startyear.ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

--Nope!
SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO





--What about a FORCESEEK hint?
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT  /* This is a parameter NOT a local variable */
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
	)
	SELECT 
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM rankbyyear AS startyear WITH (FORCESEEK) /* HERE I AM */
	JOIN rankbyyear AS ten_years_later on
		--startyear.ReportYear + 10 = ten_years_later.ReportYear
		@YearToRank + 10 = ten_years_later.ReportYear
		and startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN rankbyyear AS ten_years_prior on
		--startyear.ReportYear - 10 = ten_years_prior.ReportYear
		@YearToRank - 10 = ten_years_prior.ReportYear
		and startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_prior on
		--startyear.ReportYear - 20 = twenty_years_prior.ReportYear
		@YearToRank - 20 = twenty_years_prior.ReportYear
		and startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN rankbyyear AS twenty_years_later on
		--startyear.ReportYear + 20 = twenty_years_later.ReportYear
		@YearToRank + 20 = twenty_years_later.ReportYear
		and startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE 
		startyear.ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO










/* 
HAHAHAHAHAHAHAHA  😭

This is a natural part of the tuning process: 
try random hints and trace flags until you realize 
you should get back to basics with the query :D


Let's try a basic tuning process!
*/



--Return to step 1: what's the first/biggest thing in the query that filters results?


--Here's the "driver" branch of the query, isolated
--Does this have the same problem as the larger query, where it doesn't push down the predicate?

--A temporary procedure can be useful for a quick test 
CREATE OR ALTER PROCEDURE #RankByYearCore
	@YearToRank INT 
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
	)
	SELECT * 
	FROM rankbyyear as startyear
	WHERE ReportYear = @YearToRank
		and startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

SET STATISTICS IO ON;
GO
exec #RankByYearCore @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO



--Hmm, what can we change that might influence processing?
--Let's move the predicate for ReportYear into the CTE
--Does that behavior change?
CREATE OR ALTER PROCEDURE #RankByYearCorePredicateMoved
	@YearToRank INT 
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank /* <--- This has been moved into the CTE */
	)
	SELECT * 
	FROM rankbyyear as startyear
	WHERE
		/* The predicate used to be out here */ 
		startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

SET STATISTICS IO ON;
GO
exec #RankByYearCorePredicateMoved @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO



/* 
Another way to write this - derived table instead of CTE.
I find this slightly easier to read for this query
Similiarly the predicate is pushed inside the derived table definition
*/
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT 
AS
	SELECT * 
	FROM ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank
	) as startyear
	WHERE startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO


SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO

--Changing this changes lots of things in the query
--I'm going to have to rewrite it

--I like to add logic back in gradually and test as I go
--First changes:
--add in ten_years_later and ref.FirstName
--These are inner joins
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT 
AS
	SELECT 
		fn.FirstName,
		startyear.Gender,
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later]
	FROM ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank
	) as startyear
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	JOIN ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank + 10
	) as ten_years_later on
		startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	WHERE startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

--Are predicates still being pushed down?
SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO




--add in ten_years_prior, twenty_years_prior, twenty_years_later
--these are all left outer joins
CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT 
AS
	SELECT
		fn.FirstName,
		startyear.Gender,
		twenty_years_prior.RankThatYear as [Rank 20 years prior],
		ten_years_prior.RankThatYear as [Rank 10 years prior],
		startyear.RankThatYear as [Rank],
		ten_years_later.RankThatYear as [Rank 10 years later],
		twenty_years_later.RankThatYear as [Rank 20 years later]
	FROM ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank
	) as startyear
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	JOIN ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank + 10
	) as ten_years_later on
		startyear.FirstNameId = ten_years_later.FirstNameId
		and startyear.Gender = ten_years_later.Gender
	LEFT JOIN ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank - 10
	) as ten_years_prior on
		startyear.FirstNameId = ten_years_prior.FirstNameId
		and startyear.Gender = ten_years_prior.Gender
	LEFT JOIN ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank - 20
	) as twenty_years_prior on
		startyear.FirstNameId = twenty_years_prior.FirstNameId
		and startyear.Gender = twenty_years_prior.Gender
	LEFT JOIN ( SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
		WHERE ReportYear = @YearToRank + 20
	) as twenty_years_later on
		startyear.FirstNameId = twenty_years_later.FirstNameId
		and startyear.Gender = twenty_years_later.Gender
	WHERE startyear.RankThatYear <= 10
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO

--How are we doing?
SET STATISTICS IO ON;
GO
exec dbo.RankByYear @YearToRank = 1991;
GO
SET STATISTICS IO OFF;
GO





/***********************************************
Solution: Rewritten query with local variable
Circling back, how does our rewrite do with a local variable?
************************************************/

SET STATISTICS IO ON;
GO
DECLARE @YearToRank INT = 1991;

SELECT
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank
) as startyear
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank + 10
) as ten_years_later on
	startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank - 10
) as ten_years_prior on
	startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank - 20
) as twenty_years_prior on
	startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank + 20
) as twenty_years_later on
	startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
WHERE startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender;

SET STATISTICS IO OFF;
GO


--Awww yeah! TACOS FOR EVERYONE
--🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮🌮



/***********************************************
Double-check: are we getting the same data back?
Let's use EXCEPT to check
The queries both return 10 rows, so I'm only running this one direction
************************************************/

DECLARE @YearToRank INT = 1991;
--original query
with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby
)
SELECT 
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM rankbyyear AS startyear
JOIN rankbyyear AS ten_years_later on
	startyear.ReportYear + 10 = ten_years_later.ReportYear
	and startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN rankbyyear AS ten_years_prior on
	startyear.ReportYear - 10 = ten_years_prior.ReportYear
	and startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_prior on
	startyear.ReportYear - 20 = twenty_years_prior.ReportYear
	and startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN rankbyyear AS twenty_years_later on
	startyear.ReportYear + 20 = twenty_years_later.ReportYear
	and startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
WHERE 
	startyear.ReportYear = @YearToRank
	and startyear.RankThatYear <= 10
--ORDER BY startyear.RankThatYear, startyear.Gender  /* Must comment out for EXCEPT */

--NEW QUERY
EXCEPT
SELECT
	fn.FirstName,
	startyear.Gender,
	twenty_years_prior.RankThatYear as [Rank 20 years prior],
	ten_years_prior.RankThatYear as [Rank 10 years prior],
	startyear.RankThatYear as [Rank],
	ten_years_later.RankThatYear as [Rank 10 years later],
	twenty_years_later.RankThatYear as [Rank 20 years later]
FROM ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank
) as startyear
JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank + 10
) as ten_years_later on
	startyear.FirstNameId = ten_years_later.FirstNameId
	and startyear.Gender = ten_years_later.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank - 10
) as ten_years_prior on
	startyear.FirstNameId = ten_years_prior.FirstNameId
	and startyear.Gender = ten_years_prior.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank - 20
) as twenty_years_prior on
	startyear.FirstNameId = twenty_years_prior.FirstNameId
	and startyear.Gender = twenty_years_prior.Gender
LEFT JOIN ( SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby 
	WHERE ReportYear = @YearToRank + 20
) as twenty_years_later on
	startyear.FirstNameId = twenty_years_later.FirstNameId
	and startyear.Gender = twenty_years_later.Gender
WHERE startyear.RankThatYear <= 10
ORDER BY startyear.RankThatYear, startyear.Gender;
GO










/***********************************************
END
************************************************/





/***********************************************
EXTRA: WHAT ABOUT LAG AND LEAD?
************************************************/
--Lag can access prior rows in a result set
--Lead can access subsequent rows in a result set

--This could be a very long discussion! 

--Here are two of the challenges with incorporating LAG and LEAD into this solution:

--We want the DENSE_RANK at some prior years or later years
--Issue 1: names may not be ranked in every year
SELECT TOP 100
	FirstNameId,
	fnby.ReportYear,
	DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
	Gender
FROM agg.FirstNameByYear fnby 
ORDER BY 1, 2, 3;
GO


--Issue 2: Attempts to nest windowing functions like this results in the error:
--Msg 4109, Level 15, State 1, Procedure RankByYear, Line 9 [Batch Start Line 1007]
--Windowed functions cannot be used in the context of another windowed function or aggregate.

CREATE OR ALTER PROCEDURE dbo.RankByYear
	@YearToRank INT 
AS
	with rankbyyear AS (
		SELECT fnby.ReportYear,
			DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
			LAG (DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ), 10, 0) OVER (ORDER BY ReportYear) as Lag10,
			FirstNameId,
			Gender
		FROM agg.FirstNameByYear fnby 
	)
	SELECT 
		fn.FirstName,
		startyear.Gender,
		startyear.RankThatYear as [Rank],
		Lag10
	FROM rankbyyear as startyear
	JOIN ref.FirstName fn on startyear.FirstNameId=fn.FirstNameId
	WHERE startyear.RankThatYear <= 10
		and ReportYear = @YearToRank
	ORDER BY startyear.RankThatYear, startyear.Gender;
GO







/***********************************************
EXTRA: Simple data validation query
************************************************/

--If you want to look at ranks for specific names, this can help you validate the data
/* Set the window here */
with rankbyyear AS (
	SELECT fnby.ReportYear,
		DENSE_RANK() OVER (PARTITION BY ReportYear ORDER BY NameCount DESC ) as RankThatYear,
		FirstNameId,
		Gender
	FROM agg.FirstNameByYear fnby )
SELECT 
	ReportYear,
	Gender,
	RankThatYear
FROM rankbyyear
JOIN ref.FirstName fn on rankbyyear.FirstNameId=fn.FirstNameId
where 
	fn.FirstName='Michael'
	and rankbyyear.Gender = 'M'
and rankbyyear.ReportYear  in (1971, 1981, 1991, 2001, 2011)
ORDER BY 1