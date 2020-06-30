/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-create-an-extended-events-trace/

Setup:
    Download BabbyNames.bak.zip (42 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/1.3

This database can be restored to SQL Server 2008R2 or higher, BUT this challenge is 
SQL Server 2016+

This is the SOLUTION File
*****************************************************************************/

/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO

/* 
New session -
The wizard that's not called a wizard

Search for word force. Hmmm.

Expand channels, add debug. Hmmm.

Change search term: query_store

Add event: query_store_plan_forcing_failed


Add global fields: session_id, sql_text
Configure event_file target

*/


--Scripted trace:

CREATE EVENT SESSION [Query Store Plan Forcing Failed] ON SERVER 
ADD EVENT qds.query_store_plan_forcing_failed(
    ACTION(sqlserver.session_id,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'S:\XEvents\query_store_plan_forcing_failed.xel')
WITH (MAX_MEMORY=4096 KB,
    EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY=5 SECONDS /* This defaults to 30, setting to 5 just for testing */ ,
    MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO


ALTER EVENT SESSION [Query Store Plan Forcing Failed] ON SERVER STATE = START
GO


--Test your trace using these queries. 
--What appears in the trace, and what does not?

--First statement
EXEC dbo.FreezeMe @TotalNameCountLimit = 10000;
GO

--Second statement
EXEC dbo.FreezeMe @TotalNameCountLimit = 100 WITH RECOMPILE;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

--Third statement
EXEC dbo.FreezeMe @TotalNameCountLimit = 150;
GO


--Fourth statement
EXEC dbo.FreezeMe @TotalNameCountLimit = 500;
GO

exec sp_recompile 'dbo.FreezeMe';
GO
--Bonus statement
EXEC dbo.FreezeMe @TotalNameCountLimit = 750;
GO



/* Stop the trace */

ALTER EVENT SESSION [Query Store Plan Forcing Failed] ON SERVER STATE = STOP
GO


/* Clean up */
DROP EVENT SESSION [Query Store Plan Forcing Failed] ON SERVER;
GO