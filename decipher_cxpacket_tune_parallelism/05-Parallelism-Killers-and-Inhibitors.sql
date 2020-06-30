/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism


Credits: These demos generated thanks to Paul White's post listing parallelism
inhibitors here (I'm only showing some of the items listed) 
http://sqlblog.com/blogs/paul_white/archive/2011/12/23/forcing-a-parallel-query-execution-plan.aspx

*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


--Let's roll like this...
exec sp_configure 'max degree of parallelism', 4;
GO
RECONFIGURE
GO

exec sp_configure 'cost threshold for parallelism', 50;
GO
RECONFIGURE
GO

USE BabbyNames;
GO


/************************************************************ 
Parallelism Inhibitors
************************************************************/



/************************************************************ 
TOP inhibits parallelism in a zone of the plan
Does it make a difference here? Why?
************************************************************/
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

SELECT TOP (100) 
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO


/************************************************************ 
Backward scans
************************************************************/

--Different query
SELECT TOP 100
    fnbd.FakeBirthDateStamp,
    fn.FirstName
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
ORDER BY fnbd.FakeBirthDateStamp DESC
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO


--This takes a couple of minutes to create
CREATE INDEX ix_FirstNameByBirthDate_FakeBirthDateStamp_INCLUDES on
    dbo.FirstNameByBirthDate (FakeBirthDateStamp) INCLUDE (FirstNameId)
    WITH (MAXDOP = 6, DATA_COMPRESSION = ROW);
GO

--What's our estimated cost now?
SELECT TOP 100
    fnbd.FakeBirthDateStamp,
    fn.FirstName
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
ORDER BY fnbd.FakeBirthDateStamp DESC;
GO


--What does it do here?
SELECT TOP 100
    fnbd.FakeBirthDateStamp,
    fn.FirstName
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
ORDER BY fnbd.FakeBirthDateStamp DESC
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO


--Change the sort order for FakeBirthDateStamp DESC in the index
--This takes a couple of minutes to complete
CREATE INDEX ix_FirstNameByBirthDate_FakeBirthDateStamp_INCLUDES on
    dbo.FirstNameByBirthDate (FakeBirthDateStamp DESC) INCLUDE (FirstNameId)
    WITH (MAXDOP = 6, DATA_COMPRESSION = ROW, DROP_EXISTING=ON);
GO


SELECT TOP 100
    fnbd.FakeBirthDateStamp,
    fn.FirstName
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
ORDER BY fnbd.FakeBirthDateStamp DESC
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO





DROP INDEX ix_FirstNameByBirthDate_FakeBirthDateStamp_INCLUDES on
    dbo.FirstNameByBirthDate;
GO

/************************************************************ 
Parallelism Killers
************************************************************/


/************************************************************ 
SCALAR FUNCTIONS
Some call them evil, I wonder why?
************************************************************/

--My special talent: creating a truly worthless scalar function
CREATE OR ALTER FUNCTION dbo.ReturnThatThing 
    (@ThatThing INT)
RETURNS TINYINT /* hahahahahah */
AS
BEGIN
    RETURN(@ThatThing)
END;
GO

--Compare plans
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

SELECT
    fnbd.Gender,
    dbo.ReturnThatThing (COUNT(*)) as SumNameCount /* Here's the function! */
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

/* Why does it take so long before we get that error? */


/************************************************************ 
UDFs in computed columns on a table
************************************************************/

--OK fine, I'll change the return type
CREATE OR ALTER FUNCTION dbo.ReturnThatThing 
    (@ThatThing INT)
RETURNS INT 
AS
BEGIN
    RETURN(@ThatThing)
END;
GO

exec sp_help 'ref.FirstName';
GO

ALTER TABLE ref.FirstName ADD ThatThing AS
    dbo.ReturnThatThing (TotalNameCount);
GO

--Note that our query does not reference TotalNameCount or ThatThing
--What is the plan? 
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO


ALTER TABLE ref.FirstName DROP COLUMN ThatThing;
GO

--Back to normal
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO


/************************************************************ 
System table access or system function use
************************************************************/
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount,
    (SELECT COUNT(*) from sys.objects) as object_count
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount,
    (SELECT OBJECT_ID('ref.FirstName')) as object_id
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO