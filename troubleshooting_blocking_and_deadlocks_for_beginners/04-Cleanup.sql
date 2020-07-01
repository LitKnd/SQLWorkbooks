/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/troubleshooting-blocking-and-deadlocks-for-beginners


Cleanup you need to do manually:
    Delete trace files from S:\XEvents
	Restore database WideWorldImporters (if you want a clean copy)

This script will:
	Reset 'blocked process threshold (s)' to 0 using sp_configure + RECONFIGURE
	Kill off session for SW_Oops if he has an open transaction (00-Setup.sql left open)
	Delete SQL Agent Jobs: 'SW_Blockee', 'SW_Frank Did It'
	Delete SQL Agent Alert: 'SW_Super Simple Blocking Alert'
	Delete Operator: SW_DemoOperator
	Drop Logins SW_Oops, SW_FrankInProductManagement, SW_ImportantApp
	Drop Extended Events Sessions: 
		'SW_Blocked Process Report'
		'SW_Deadlock Graph'
*****************************************************************************/

use master;
GO

-------------------------------------------------------------------------------
--Reset 'blocked process threshold (s)' to 0 using sp_configure + RECONFIGURE
-------------------------------------------------------------------------------
EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO


EXEC sp_configure 'blocked process threshold (s)', 0;
GO
RECONFIGURE
GO

-------------------------------------------------------------------------------
--Kill off session for SW_Oops if he has an open transaction (00-Setup.sql left open)
-------------------------------------------------------------------------------
DECLARE @session_id int=NULL,
	@dsql NVARCHAR(1000) = N'',
	@msg NVARCHAR(1000) = N'';
SELECT @session_id=session_id 
FROM sys.dm_exec_sessions where login_name='SW_Oops'
IF @session_id IS NULL
BEGIN
	SET @msg = N'No spid found for SW_Oops'
	RAISERROR (@msg, 1, 1) WITH NOWAIT;
END
ELSE
BEGIN
	SET @dsql= N'KILL ' + cast(@session_id as NVARCHAR(10));
	SET @msg = N'Killing spid ' +  cast(@session_id as NVARCHAR(10)) + N' for SW_Oops'
	RAISERROR (@msg, 1, 1) WITH NOWAIT;
	EXEC sp_executesql @dsql;
END
GO


-------------------------------------------------------------------------------
--Delete SQL Agent Jobs: 'SW_Blockee', 'SW_Frank Did It'
-------------------------------------------------------------------------------
IF (SELECT COUNT(*) FROM msdb..sysjobs WHERE name=N'SW_Blockee') > 0
	exec msdb..sp_delete_job @job_name=N'SW_Blockee';
GO

IF (SELECT COUNT(*) FROM msdb..sysjobs WHERE name=N'SW_Frank Did It') > 0
	exec msdb..sp_delete_job @job_name=N'SW_Frank Did It';
GO


-------------------------------------------------------------------------------
--Delete SQL Agent Alert: 'SW_Super Simple Blocking Alert'
-------------------------------------------------------------------------------
IF (SELECT COUNT(*) from msdb..sysalerts where name = N'SW_Super Simple Blocking Alert') > 0
EXEC msdb.dbo.sp_delete_alert @name=N'SW_Super Simple Blocking Alert'
GO

-------------------------------------------------------------------------------
--Delete Operator: SW_DemoOperator
-------------------------------------------------------------------------------

IF (SELECT COUNT(*) from msdb..sysoperators where name = N'SW_DemoOperator') > 0
EXEC msdb.dbo.sp_delete_operator @name=N'SW_DemoOperator';
GO

-------------------------------------------------------------------------------
--Drop Logins SW_Oops, SW_FrankInProductManagement, SW_ImportantApp
-------------------------------------------------------------------------------
IF (SELECT count(*) from sys.sql_logins where name='SW_Oops') > 0
	DROP LOGIN SW_Oops;
GO

IF (SELECT count(*) from sys.sql_logins where name='SW_FrankInProductManagement') > 0
	DROP LOGIN SW_FrankInProductManagement;
GO

IF (SELECT count(*) from sys.sql_logins where name='SW_ImportantApp') > 0
	DROP LOGIN SW_ImportantApp;
GO

-------------------------------------------------------------------------------
--Drop Extended Events Sessions: 
--	'SW_Blocked Process Report'
--	'SW_Deadlock Graph'
-------------------------------------------------------------------------------
IF (SELECT COUNT(*) FROM sys.server_event_sessions where name=N'SW_Blocked Process Report') > 0
DROP EVENT SESSION [SW_Blocked Process Report] ON SERVER
GO

IF (SELECT COUNT(*) FROM sys.server_event_sessions where name=N'SW_Deadlock Graph') > 0
DROP EVENT SESSION [SW_Deadlock Graph] ON SERVER
GO
