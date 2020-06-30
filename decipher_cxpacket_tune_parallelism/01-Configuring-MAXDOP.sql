/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/************************************************************ 
Configuring max degree of parallelism

Instance level:
    0 (default): all available logical processors, up to 64
    1: No parallel queries
*************************************************************/
use master;
GO

SELECT name, value, value_in_use, is_advanced
FROM sys.configurations
WHERE name = 'max degree of parallelism';
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

exec sp_configure 'max degree of parallelism', 2;
GO

RECONFIGURE
GO

/* Run this query with actual plans.
View ThreadStat on the root operator.
View Actual Time Statistics for different operators */
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

/* Change to 8, then rerun the query and compare */
exec sp_configure 'max degree of parallelism', 8;
GO
RECONFIGURE
GO


/************************************************************ 
Database level - SQL Server 2016+ 
    0: instance configuration will be used
    This feature makes the most sense with Azure SQL Database
************************************************************/
USE BabbyNames;
GO

SELECT configuration_id, name, value, is_value_default, value_for_secondary
FROM sys.database_scoped_configurations
WHERE name= 'MAXDOP';
GO

ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4
GO  
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = 0;
GO

/* Run and look at actual plan */
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

/* Reset */
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0
GO  



/************************************************************ 
Resource Governor: Workload groups of queries
    SQL Server 2008+
    Enterprise Edition Only

This can make sense when you can't change the code, and you need
    to change the maxdop for a set of queries based on the user it logs in as,
    application, etc
************************************************************/
USE master;
GO

CREATE RESOURCE POOL MAXDOPDemo;
GO
CREATE WORKLOAD GROUP SingleThreadedOnly 
    /* Why is there an underscore here? Deep Thoughts. */
    WITH (MAX_DOP = 1)
    USING MAXDOPDemo;
GO


CREATE FUNCTION dbo.ClassifyThis()
RETURNS SYSNAME
WITH SCHEMABINDING
AS
BEGIN
	RETURN 
        (--Note: this ain't secure, usernames can be spoofed
		SELECT CASE WHEN SUSER_SNAME() = 'DERPDERP\Kendar'
		THEN N'SingleThreadedOnly'
		ELSE N'default'
		END 
);
END
GO
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.ClassifyThis);
GO

ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

SELECT classifier_function_id, is_enabled
from sys.resource_governor_configuration;
GO
SELECT group_id, name, max_dop
from sys.resource_governor_workload_groups;
GO




/* Look at estimated plan, then run with actual */
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



/* "The classifier function is run for new connections so that their workloads can be assigned to workload groups."
https://docs.microsoft.com/en-us/sql/relational-databases/resource-governor/enable-resource-governor */
/* Reconnect and redo*/


USE master;
GO
ALTER RESOURCE GOVERNOR DISABLE;  
GO
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL);
GO
DROP FUNCTION IF EXISTS dbo.ClassifyThis;
GO
DROP WORKLOAD GROUP SingleThreadedOnly;
GO
DROP RESOURCE POOL MAXDOPDemo;
GO

/* I like to reconnect at this point out of superstition */


/* I don't love Resource Governor for changing around DOP -- 
    it makes troubleshooting more confusing than other methods

There have been some cases when there wasn't another good way to change DOP other than this
    Example: You can't set MAXDOP for DBCC CHECKDB below SQL Server 2014 SP2
    If CHECKDB uses too many resources, Resource Governor can limit it

Be very careful not to add a lot of overhead to your classifier function, 
    or to limit more than you intend to!
*/




/************************************************************ 
Query level: MAXDOP hint.
    Enable actual plans,
    Run this without the hint, 
    then with the hint
************************************************************/
USE BabbyNames;
GO

/* Notice that we get a different cost and a different 
plan shape when the optimizer is in on the MAXDOP decision */
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Mister'
GROUP BY Gender
    OPTION (MAXDOP 1);
GO


