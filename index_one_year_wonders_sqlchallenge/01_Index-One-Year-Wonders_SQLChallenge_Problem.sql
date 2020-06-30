/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/design-the-best-index-for-one-year-wonders-sqlchallenge/


Setup:
    Download BabbyNames.bak.zip (42 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/1.3

This database can be restored to SQL Server 2008R2 or higher
This is the PROBLEM File
*****************************************************************************/

/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/****************************************************
Restore database 
****************************************************/
SET NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER ON
GO


--Adjust drive / folder locations for the restore
USE master;
GO
IF DB_ID('BabbyNames2017') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames2017
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames2017
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames2017.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames2017_log.ldf',
        REPLACE,
        RECOVERY;
GO

--Query Store is SQL Server 2016+,
--Comment out for lower versions
ALTER DATABASE BabbyNames2017 SET QUERY_STORE = ON
GO
ALTER DATABASE BabbyNames2017 SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO
--This command is SQL Server 2017+, adjust for lower versions
ALTER DATABASE BabbyNames2017 SET COMPATIBILITY_LEVEL = 140;
GO



/****************************************************
SQLChallenge!
****************************************************/


/* One year wonders */

/* Challenge: 

Level 1: design the best disk based nonclustered rowstore index 
for the given query-- in this case, "best" is defined as reducing 
the number of logical reads as much as possible for the query. 

Design only one index without using any more advanced indexing 
features such as filters, views, etc. 

Make no schema changes to the table other than 
creating the single nonclustered index.

Level 2: use a more advanced feature to minimize the number of
 logical reads for the query. This may involve a schema change other 
 than simply creating the index.

Level 3: use a second more advanced feature to minimize the
 number of logical reads for the query, and compare the pros
  and cons of this solution with what you designed in Level 2.
 This may involve a schema change other than simply creating 
 the index.

This "challenge" query is a fast query that would not normally 
require customized indexing. The same principles from this 
exercise apply to larger tables as well.

*/

USE BabbyNames2017;
GO

--Let's rebuild the clustered PK before we take a baseline.
--This is an offline rebuild because I haven't specified it differently.
ALTER INDEX pk_FirstName_FirstNameId on 
    ref.FirstName REBUILD
    WITH (FILLFACTOR = 100);
GO

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

/* Logical reads: 482 */
