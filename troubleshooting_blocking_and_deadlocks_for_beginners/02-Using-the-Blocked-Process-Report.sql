/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/troubleshooting-blocking-and-deadlocks-for-beginners
*****************************************************************************/


RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


/* 
We need to configure SQL Server to record information about blocking.

That way if we can't look at the exact moment when blocking is happening, we can still get info.

We can do this with the Blocked Process Report.
*/

/* Step 1) Configure the Blocked Process Threshold in sp_configure */
--Check for any pending configurations before we change anything
SELECT * FROM sys.configurations where value <> value_in_use;
GO

/* We need to see 'advanced options'  */
EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO

/* This defaults to 0, which means the blocked process report won't be issued */
SELECT * FROM sys.configurations WHERE name=N'blocked process threshold (s)';
GO

/* Let's tell  SQL Server to issue the blocked process report every 5 seconds.
5 is the LOWEST value you want for this.
*/
EXEC sp_configure 'blocked process threshold (s)', 5;
GO

RECONFIGURE
GO


/* Step 2)  We need to configure a trace to pick up the blocked process report --
	without a trace, it doesn't get recorded. */
/* This trace created simply with the Extended Events Session GUI and then scripted. */
/* On older versions of SQL Server, you can pick up the blocked process report with a Server Side Trace (SQLTrace) */

CREATE EVENT SESSION [SW_Blocked Process Report] ON SERVER
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file(SET filename=N'S:\XEvents\Blocked-Process-Report.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,
    MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

/* Now start the trace */
ALTER EVENT SESSION [SW_Blocked Process Report] ON SERVER STATE = START;
GO




/* Step 3) I already installed the Blocked Process Report Viewer stored procedure by Michael J Swart
from http://sqlblockedprocesses.codeplex.com/releases/view/625776.

This is a cool procedure: you can copy the trace file off the server and run it totally out of production.
OR you can point it at an Extended Events session!
 */

exec dbo.sp_blocked_process_report_viewer @Source='SW_Blocked Process Report', @Type='XESESSION';
GO


/* 
We haven't had any blocking since I just created this.
So... let's go for another cup of coffee.
*/



/* While we're gone, a whole barrel of inserts come in.
	Open MultithreadedOrderInsert.exe  and get ready to run
	From the WideWorldImporters workload drivers 
		(free from Microsoft, get workload-drivers.zip from
		 https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0)

	I installed it to: S:\WideWorldImporters\workload-drivers\order-insert
*/


/* Frank starts doing some work */
EXEC msdb.dbo.sp_start_job @job_name = N'SW_Frank Did It';
GO
EXEC msdb.dbo.sp_update_job  @job_name = N'SW_Frank Did It',  @enabled = 1;  
GO  

/* Now start the inserts */





/* Phone the Psychic Friends Network and take a look at what's running while we're gone... */
/* We should have periodic blocking */
exec sp_WhoIsActive;
GO




/* Has the Blocked Process Report caught anything? */
exec dbo.sp_blocked_process_report_viewer @Source='SW_Blocked Process Report', @Type='XESESSION';
GO

/* Stop the inserts. */
/* Frank is done */
EXEC msdb.dbo.sp_stop_job @job_name = N'SW_Frank Did It';
GO
EXEC msdb.dbo.sp_update_job  @job_name = N'SW_Frank Did It',  @enabled = 0;  
GO  

/* OK, let's dig in */
exec dbo.sp_blocked_process_report_viewer @Source='SW_Blocked Process Report', @Type='XESESSION';
GO


/* sp_blocked_process_report_viewer reads the trace and puts the events in a chain.
    It sorts the information into groups and points out who is blocking whom
    
Open the first block-ee under lead blocker.

Who is the blocking-process? We can see:
    loginname = SW_FrankInProductManagement
	clientapp = SQLAgent - TSQL JobStep (Job 0xC03F0139B191B440829F2E9447EA56F5 : Step 1)
    inputbuf = exec dbo.FranksUpdate 50
		If running a multi-statement transaction outside of a procedure, will be the last statement run
*/

/* We can find the job name ... */
SELECT *
FROM msdb..sysjobs
WHERE job_id=0xDD61370ACE3B39449D1CFE4E86ECBE06;
GO

/* We can look at Frank's code... */
USE WideWorldImporters;
GO
EXEC sp_helptext 'dbo.FranksUpdate'
GO


/* In our case, if we look through Frank's code, he's doing
a giant transaction which contains a nested cursor, and there
is only one modification statement (updating Sales.OrderLines).

If there were multiple modification statements, we could
use the blocked process reports to break down which table has
the blocking */


/*
Look at the details for the blocked process in the XML
*/


/* Decode the object id for the blocked process */
SELECT 
	sc.name as schemaname, 
	so.name as procname
FROM sys.objects AS so
JOIN sys.schemas AS sc on so.schema_id=sc.schema_id
WHERE object_id = 1419152101
GO


/*
This is sometimes in the pattern: 
	waitresource="KEY: 6:72057594047561728 (187f5d415a31)"
	waitresource="KEY: db_id: hobt_id (index key magic hash stuff)"
In that case you can find the table name by querying sys.partitions for the hobt_id

SELECT sc.name as schema_name, o.name as object_name, i.name as index_name
FROM sys.partitions AS p
JOIN sys.objects as o on p.object_id=o.object_id
JOIN sys.indexes as i on p.index_id=i.index_id and p.object_id=i.object_id
JOIN sys.schemas AS sc on o.schema_id=sc.schema_id
WHERE hobt_id = 72057594047561728;
GO

You can further use the built in, but undocumented, %%lockres%% function
to identify the row-- %%lockres%% returns that magic index key magic hash stuff.
But careful about performance - it will scan the table!
https://www.littlekendra.com/2016/10/17/decoding-key-and-page-waitresource-for-deadlocks-and-blocking/
*/


/* 
Our process was blocked on a page:
	waitresource = PAGE: PAGE: 6:3:38510
	waitresource = PAGE: DBID, DataFileId, Page #
*/

--PAGE: PAGE: 6:3:20244

--6:3:36868

--We need to turn on trace flag 3604 for our session to print the results
--from DBCC page to this window (not the error log)
DBCC TRACEON (3604);
GO
/* DBCC PAGE (DBID, FileId, PageId, DumpStyle) */
DBCC PAGE (6, 3, 36868, 2);
GO
--Metadata: IndexId = 1
--Metadata: ObjectId = 94623380 

SELECT 
	sc.name as schemaname, 
	so.name as tablename
FROM sys.objects AS so
JOIN sys.schemas AS sc on so.schema_id=sc.schema_id
WHERE object_id = 94623380
GO



/* 
Challenge: How would you summarize this situation?

    * Don't re-write Frank's code!
    * Draft a quick summary in your own words explaining what's happening.
    * Outline some high level suggestions to solve the problem.
*/

