/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/repeatable-read-and-serializable-isolation-levels-45-minutes

Setup:
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.1

Then review and run the script below on a SQL Server 2016 dedicated test instance
    Developer Edition recommended (Enteprise and Evaluation Editions will work too)
	
*****************************************************************************/

/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/****************************************************
Restore database
****************************************************/
SET NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
USE master;
GO

IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
        REPLACE,
        RECOVERY;
GO
ALTER DATABASE BabbyNames SET QUERY_STORE = ON
GO
ALTER DATABASE BabbyNames SET QUERY_STORE (OPERATION_MODE = READ_WRITE)
GO
USE BabbyNames;
GO




/****************************************************
Demo: Give me correct data, or give me death
****************************************************/

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

/* Let's make ref.FirstName a temporal table.
This isn't necessary to the demo per se, but helps review what happened afterward.*/


CREATE TABLE ref.FirstName_History (
	FirstNameId int NOT NULL,
	FirstName varchar(255) NOT NULL,
	NameLength int NULL,
	FirstReportYear int NOT NULL,
	LastReportYear int NOT NULL,
	TotalNameCount bigint NOT NULL,
	SysStartTime datetime2(7) NOT NULL,
	SysEndTime datetime2(7) NOT NULL
) ON [PRIMARY]
GO

/* Note: 
I haven't indexed the history table, I've just left it as a heap.
That's not an ideal use of a history table. I'm just keeping it simple
since that isn't the focus of this demo. 
*/

/* Add hidden columns to track system time */
ALTER TABLE ref.FirstName  
    ADD PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime),   
    SysStartTime datetime2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL 
        DEFAULT GETUTCDATE(),   
    SysEndTime datetime2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL 
        DEFAULT CONVERT(DATETIME2, '9999-12-31 23:59:59.99999999');  
GO

/* Enable system versioning */
ALTER TABLE ref.FirstName 
    SET (SYSTEM_VERSIONING = ON
        ( HISTORY_TABLE = ref.FirstName_History , DATA_CONSISTENCY_CHECK = ON )
       );
GO


/* Create two new nonclustered rowstore indexes for this demo.*/
CREATE INDEX LastReportYear_Etc on ref.FirstName (LastReportYear, FirstName, FirstNameId)
GO
CREATE INDEX FirstReportYear_Etc on ref.FirstName (FirstReportYear, TotalNameCount, FirstNameId)
GO




/* Look at the plan for this query. 

We have a hash match join and two nonclustered index seeks. 
	The 'Build' phase of the hash match uses LastReportYear_Etc. That runs first.
    The 'Probe' phase of the hash match uses FirstReportYear_Etc. That runs second.
*/
SELECT FirstNameId, FirstName, FirstReportYear, LastReportYear, TotalNameCount
FROM ref.FirstName
WHERE FirstReportYear = 1880 
and LastReportYear = 1980;
GO

/* Data... */
--FirstNameId	FirstName	FirstReportYear	LastReportYear	TotalNameCount
--1500	Claus	1880	1980	361
--6611	Media	1880	1980	473
--5466	Babe	1880	1980	728  <-- We are going to mess with this row
--91572	Docia	1880	1980	1106
--90828	Hulda	1880	1980	5406





/* Uncomment this and run it in another session */
--USE BabbyNames;
--GO
--BEGIN TRAN

--    UPDATE ref.FirstName SET TotalNameCount = 111111
--    WHERE FirstNameId = 5466


/* Now start this query in this session.
Run the demo with each isolation level */

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
GO

SELECT FirstNameId, FirstName, FirstReportYear, LastReportYear, TotalNameCount
FROM ref.FirstName
WHERE FirstReportYear = 1880 
and LastReportYear = 1980;
GO


/* In a third session, look at the lock waits */
--sp_WhoIsActive is a free procedure by Adam Machanic - whoisactive.com
exec master..sp_WhoIsActive @get_locks=1;
GO


/* In the second session, finish up.... */
--    UPDATE ref.FirstName SET FirstName = 'Baba'
--    WHERE FirstNameId = 5466

--COMMIT


/* Data... */
--FirstNameId	FirstName	FirstReportYear	LastReportYear	TotalNameCount
--1500	Claus	1880	1980	361
--6611	Media	1880	1980	473
--91572	Docia	1880	1980	1106
--90828	Hulda	1880	1980	5406
--5466	Babe	1880	1980	111111


/* Query the full history for this FirstNameId */
SELECT *, SysStartTime, SysEndTime  
FROM ref.FirstName FOR SYSTEM_TIME ALL  /* <-- yeah, temporal table! */
WHERE FirstNameId = 5466;
GO



/* Read committed:
    WAIT: 
        <Lock resource_type="KEY" 
            index_name="FirstReportYear_Etc" 
            request_mode="S" 
            request_status="WAIT" 
            request_count="1" />
    GRANT:
        <Lock resource_type="PAGE" 
            page_type="*" 
            index_name="FirstReportYear_Etc" 
            request_mode="IS" 
            request_status="GRANT" 
            request_count="1" />
        <Lock resource_type="OBJECT" request_mode="IS" request_status="GRANT" request_count="1" />
Repeatable read:
    WAIT:
        <Lock resource_type="KEY" 
            index_name="FirstReportYear_Etc" 
            request_mode="S" 
            request_status="WAIT" 
            request_count="1" />

    GRANT:
        <Lock resource_type="KEY" 
            index_name="FirstReportYear_Etc" 
            request_mode="S" 
            request_status="GRANT" 
            request_count="148" />
        <Lock resource_type="KEY" 
            index_name="LastReportYear_Etc" 
            request_mode="S" 
            request_status="GRANT" 
            request_count="515" />
        <Lock resource_type="PAGE" 
            page_type="*" 
            index_name="FirstReportYear_Etc" 
            request_mode="IS" 
            request_status="GRANT" 
            request_count="1" />
        <Lock resource_type="PAGE" 
            page_type="*" 
            index_name="LastReportYear_Etc" 
            request_mode="IS" 
            request_status="GRANT" 
            request_count="3" />

        <Lock resource_type="OBJECT" request_mode="IS" request_status="GRANT" request_count="1" />

Serializable:
    WAIT:
        <Lock resource_type="KEY" 
            index_name="FirstReportYear_Etc" 
            request_mode="RangeS-S" 
            request_status="WAIT" 
            request_count="1" />

    GRANT:
        <Lock resource_type="KEY" 
            index_name="FirstReportYear_Etc" 
            request_mode="RangeS-S" 
            request_status="GRANT" 
            request_count="148" />
        <Lock resource_type="KEY" 
            index_name="LastReportYear_Etc" 
            request_mode="RangeS-S" 
            request_status="GRANT" 
            request_count="516" />
        <Lock resource_type="PAGE" 
            page_type="*" 
            index_name="FirstReportYear_Etc" 
            request_mode="IS" 
            request_status="GRANT" 
            request_count="1" />
        <Lock resource_type="PAGE" 
            page_type="*" 
            index_name="LastReportYear_Etc" 
            request_mode="IS" 
            request_status="GRANT" 
            request_count="3" />
        <Lock resource_type="OBJECT" request_mode="IS" request_status="GRANT" request_count="1" />

*/
GO



/* Reset */
UPDATE ref.FirstName 
    SET FirstName = 'Babe', 
    TotalNameCount= 728
WHERE FirstNameId = 5466;
GO

ALTER TABLE ref.FirstName SET ( SYSTEM_VERSIONING=OFF) ;
GO

TRUNCATE TABLE ref.FirstName_History;
GO

/* Enable system versioning */
ALTER TABLE ref.FirstName 
    SET (SYSTEM_VERSIONING = ON
        ( HISTORY_TABLE = ref.FirstName_History , DATA_CONSISTENCY_CHECK = ON )
       );
GO


/**********************************************
Back to the slides
**********************************************/





/****************************************************
Demo: But I didn�t ask for serializable!
****************************************************/

USE BabbyNames;
GO

/* Drop current FKs.*/
ALTER TABLE agg.FirstNameByYearState 
    DROP CONSTRAINT IF EXISTS fk_FirstNameByYearState_FirstName
GO
ALTER TABLE agg.FirstNameByYear 
    DROP CONSTRAINT IF EXISTS fk_FirstNameByYear_FirstName
GO


/* Create new Foreign Keys.
This time we specify cascading updates and deletes */
ALTER TABLE agg.FirstNameByYearState  
    WITH CHECK 
    ADD CONSTRAINT fk_FirstNameByYearState_FirstName 
    FOREIGN KEY(FirstNameId)
    REFERENCES ref.FirstName (FirstNameId)
    ON DELETE CASCADE 
    ON UPDATE CASCADE;
GO

ALTER TABLE agg.FirstNameByYear  
    WITH CHECK 
    ADD CONSTRAINT fk_FirstNameByYear_FirstName 
    FOREIGN KEY(FirstNameId)
    REFERENCES ref.FirstName (FirstNameId)
    ON DELETE CASCADE 
    ON UPDATE CASCADE;
GO

/* Create indexes on the child tables.
These allow you to find any name quickly by FirstNameId */
CREATE NONCLUSTERED INDEX ix_agg_FirstNameByYearState_FirstNameId 
    on agg.FirstNameByYearState (FirstNameId);
GO

CREATE NONCLUSTERED INDEX ix_agg_FirstNameByYear_FirstNameId 
    on agg.FirstNameByYear (FirstNameId);
GO



--Run in this session (except for the rollback )
BEGIN TRAN
    DELETE FROM ref.FirstName
    WHERE FirstNameId = 2;


ROLLBACK


--Look at the locks in another session
--sp_WhoIsActive is a free procedure by Adam Machanic - whoisactive.com
exec sp_WhoIsActive @get_locks = 1;
GO


/* Why are exclusive locks not enough?

What if someone were to INSERT a row into the child before we committed?
Range locks protect against that
https://blogs.msdn.microsoft.com/conor_cunningham_msft/2009/03/13/conor-vs-isolation-level-upgrade-on-updatedelete-cascading-ri/
*/

--Make sure you...
ROLLBACK



/**********************************************
Back to the slides
**********************************************/



/****************************************************
Demo:  Are my apps using repeatable read or serializable?
****************************************************/

/* Serializable indication: have I been waiting on 
key range locks since startup? */
SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type like '%LCK_M_R%'
AND wait_time_ms > 1;
GO


/* Sorry, not so much detail in query store. We just get LCK_M_%,
no deep specifics at this point */
SELECT *
FROM sys.query_store_wait_stats
WHERE wait_category_desc = 'Lock';
GO


/* Session level settings for existing sessions: sys.dm_exec_sessions
https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql
    0 = Unspecified
    1 = ReadUncomitted
    2 = ReadCommitted
    3 = Repeatable
    4 = Serializable
    5 = Snapshot
*/
SELECT 
    session_id,
    login_name,
    login_time,
    last_request_start_time,
    transaction_isolation_level
FROM sys.dm_exec_sessions
WHERE transaction_isolation_level <> 2;
GO


SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
GO
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO




/* Look for queries hinting the isolation levels in the cache, like this... */

SELECT FirstNameId, FirstName, FirstReportYear, LastReportYear, TotalNameCount
FROM ref.FirstName WITH (REPEATABLEREAD)
WHERE FirstReportYear = 1900 
and LastReportYear = 2000;
GO

SELECT TOP 1
    FirstNameId, FirstName, FirstReportYear, LastReportYear, TotalNameCount
FROM ref.FirstName WITH (HOLDLOCK)
WHERE FirstReportYear = 1999 
and LastReportYear = 2000
ORDER BY TotalNameCount DESC;
GO

--Can we see that queries used those hints?
with queries AS (
SELECT 
    qs.execution_count AS [# executions],
    total_worker_time as [worker time],   
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_worker_time / execution_count / 1000. / 1000. AS numeric(30,3))
		END AS [avg cpu sec],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_logical_reads / execution_count AS numeric(30,3))
	END AS [avg logical reads],
	qs.creation_time,
	LOWER(SUBSTRING(st.text, (qs.statement_start_offset/2)+1,   
		((CASE qs.statement_end_offset  
			WHEN -1 THEN DATALENGTH(st.text)  
			ELSE qs.statement_end_offset  
			END
		- qs.statement_start_offset)/2) + 1)) as query_text,
    qp.query_plan AS [plan]
FROM sys.dm_exec_query_stats AS qs
OUTER APPLY sys.dm_exec_sql_text (plan_handle) as st
OUTER APPLY sys.dm_exec_query_plan (plan_handle) AS qp
)
SELECT *
FROM queries
WHERE query_text like '%holdlock%'
    or query_text like '%repeatableread%'
    or query_text like '%serializable%'
ORDER BY [worker time] DESC
OPTION (RECOMPILE);
GO



/**********************************************
Back to the slides
**********************************************/

