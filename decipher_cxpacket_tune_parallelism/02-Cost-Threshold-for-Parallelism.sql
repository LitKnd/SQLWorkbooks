/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




--Let's run at 5 on this demo
exec sp_configure 'max degree of parallelism', 5;
GO

RECONFIGURE
GO

/************************************************************ 
Configuring cost threshold for parallelism

Instance level:
    5 (default): estimated cost of 5
*************************************************************/
use master;
GO

SELECT name, value, value_in_use, is_advanced
FROM sys.configurations
WHERE name = 'cost threshold for parallelism';
GO

exec sp_configure 'show advanced options', 1;
GO

--View items pending reconfiguration
SELECT name, value, value_in_use, is_advanced
FROM sys.configurations 
WHERE value <> value_in_use;
GO


RECONFIGURE
GO

--Set this to the default (if you need to)
exec sp_configure 'cost threshold for parallelism', 5;
GO

RECONFIGURE
GO



/************************************************************ 
Look at estimated cost

Run this query with actual plans.

View Estimated Subtree Cost on the root operator
This is an estimate, even in an actual plan
*************************************************************/
USE BabbyNames;
GO
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

/* Estimated cost:   547.107 */


/* Set the threshold for parallelsim just above this cost */
exec sp_configure 'cost threshold for parallelism', 548;
GO
RECONFIGURE
GO

/* Run this again. 
Does it go parallel?
What is the cost? 
*/
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


/* Cost threshold refers to the cost for executing the query
with just one core.

Here is the threshold for this query... */
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender 
    OPTION (MAXDOP 1);
GO




exec sp_configure 'cost threshold for parallelism', 1197;
GO
RECONFIGURE
GO


/* The cost of executing this single threaded is just under the threshold, 
so it will not go parallel.
This takes much longer to execute single threaded! */
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


/* Lower the threshold by one ... */
exec sp_configure 'cost threshold for parallelism', 1196;
GO
RECONFIGURE
GO



/* Now the cost for running this single threaded is just OVER the threshold, 
so it qualifies to go parallel */
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


/* Now let's go really high... */
exec sp_configure 'cost threshold for parallelism', 20000;
GO
RECONFIGURE
GO

/* Hints you use in the query are included in estatimed costs.
Look at the change in estimated cost after I hint this not-great index.
(Look at estimated plan.)*/
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd WITH (INDEX (ix_FirstNameByBirthDate_Gender))
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO


/* The cost threshold value for the query is higher than the threshold
(Look at estimated plan.) */


