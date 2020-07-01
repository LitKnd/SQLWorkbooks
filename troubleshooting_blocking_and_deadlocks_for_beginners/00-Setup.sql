/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/troubleshooting-blocking-and-deadlocks-for-beginners

This script:
    Is only suitable for test environments
	Restores WideWorldImporters sample database and modifies it
	Changes lots of instance level settings, security principals, and more
	Requires sysadmin permissions
	Assumes SQL Server Agent is started (for running jobs)

YOU PROBABLY NEED TO EDIT THE BACKUP LOCATION FOR WideWorldImporters-Full.bak
THIS SCRIPT ASSUMES IT IS AT:
	S:\MSSQL\Backup\WideWorldImporters-Full.bak

NOTE: THIS LEAVES AN OPEN TRANSACTION FOR 01-Blocking-Basics.sql!
	It also creates an enabled job, 'SW_Blockee' and leaves it running -- so they block.
	When you are done, run 04-Cleanup.sql. Then run this setup script again next time!

Pre-requisites:
    Download WideWorldImporters-Full.bak (database backup) and workload-drivers.zip (contains MultithreadedOrderInsert.exe)
		Both are here:
		https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
	
    Install sp_WhoIsActive from http://sqlblog.com/files/default.aspx

Cleanup you need to do manually:
    Delete trace files from S:\XEvents
	Restore database WideWorldImporters (if you want a clean copy)

Cleanup done in 04-Cleanup.sql (run it separately when you're done)
	Restore WideWorldImporters
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


DECLARE @suser sysname
SELECT @suser = SUSER_NAME()
IF @suser = N'SW_Oops'
	REVERT;
GO

WHILE @@TRANCOUNT > 0 ROLLBACK;
GO

USE master;
GO

IF DB_ID('WideWorldImporters') IS NOT NULL
ALTER DATABASE WideWorldImporters SET OFFLINE WITH ROLLBACK IMMEDIATE

/* EDIT DRIVE/FOLDER LOCATIONS AS NEEDED */
RESTORE DATABASE WideWorldImporters FROM DISK=
	'S:\MSSQL\Backup\WideWorldImporters-Full.bak'  
	WITH REPLACE,
	MOVE 'WWI_Primary' to 'S:\MSSQL\Data\WideWorldImporters.mdf',
	MOVE 'WWI_UserData' to 'S:\MSSQL\Data\WideWorldImporters_UserData.ndf',
	MOVE 'WWI_Log' to 'S:\MSSQL\Data\WideWorldImporters.ldf',
	MOVE 'WWI_InMemory_Data_1' to 'S:\MSSQL\Data\WideWorldImporters_InMemory_Data_1';
GO

EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO


EXEC sp_configure 'blocked process threshold (s)', 0;
GO
RECONFIGURE
GO


USE WideWorldImporters;
GO


IF (SELECT count(*) from sys.sql_logins where name='SW_Oops')=0
CREATE LOGIN SW_Oops WITH PASSWORD=N'ThisIsBadNeverDoCheckPolicyOff',
    CHECK_POLICY=OFF;
GO

CREATE USER SW_Oops FOR LOGIN SW_Oops;
GO

ALTER ROLE [db_owner] ADD MEMBER [SW_Oops]
GO

/* Drop the alert if it already exists */
IF (SELECT COUNT(*) from msdb..sysalerts where name = N'SW_Super Simple Blocking Alert') > 0
EXEC msdb.dbo.sp_delete_alert @name=N'SW_Super Simple Blocking Alert'
GO

/* Pre-create an operator */
IF (SELECT COUNT(*) from msdb..sysoperators where name = N'SW_DemoOperator') = 0
EXEC msdb.dbo.sp_add_operator @name=N'SW_DemoOperator', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'notarealSW_DemoOperatoremail@ .com', 
		@category_name=N'[Uncategorized]'
GO


IF (SELECT count(*) from sys.sql_logins where name='SW_ImportantApp')=0
CREATE LOGIN SW_ImportantApp WITH PASSWORD=N'ThisIsBadNeverDoCheckPolicyOff',
    CHECK_POLICY=OFF;
GO

CREATE USER SW_ImportantApp FOR LOGIN SW_ImportantApp;
GO
ALTER ROLE [db_datareader] ADD MEMBER [SW_ImportantApp]
GO






IF (SELECT count(*) from sys.sql_logins where name='SW_FrankInProductManagement')=0
CREATE LOGIN SW_FrankInProductManagement WITH PASSWORD=N'ThisIsBadNeverDoCheckPolicyOff',
    CHECK_POLICY=OFF;
GO

CREATE USER SW_FrankInProductManagement FOR LOGIN SW_FrankInProductManagement;
GO

/* Oh, Frank. Why did you write this code????*/
CREATE PROCEDURE dbo.FranksUpdate
	@id int
AS

	BEGIN TRAN

	SET NOCOUNT ON;  
  
	DECLARE @LastEditedBy int, @FullName nvarchar(50), @Description nvarchar(100),
		@OrderId INT, @OrderLineID INT
  
	DECLARE people_cursor CURSOR FOR   
	SELECT PersonId, FullName  
	FROM Application.People
	WHERE PersonId < @id
  
	OPEN people_cursor  
  
	FETCH NEXT FROM people_cursor INTO @LastEditedBy, @FullName  
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  

		RAISERROR(@FullName, 1, 1) WITH NOWAIT
  
		DECLARE order_cursor CURSOR FOR   
		SELECT 
			ol.OrderID,
			ol.OrderLineID,
			ol.Description
		FROM Sales.OrderLines AS ol 
		JOIN Sales.Orders as o on ol.OrderID = o.OrderID
		WHERE
			ol.LastEditedBy = @LastEditedBy  
			and o.OrderDate > GETDATE()- 1000
			and o.ExpectedDeliveryDate  > GETDATE()- 1000
  
		OPEN order_cursor  
		FETCH NEXT FROM order_cursor INTO @OrderId, @OrderLineID, @Description  
 
 
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			UPDATE Sales.OrderLines
				SET Description = ISNULL(@Description, 'Frank!')
			WHERE LastEditedBy = @LastEditedBy
				and OrderId=@OrderId
				and OrderLineID= @OrderLineID
  
			FETCH NEXT FROM order_cursor INTO @OrderId, @OrderLineID, @Description  

		END  
  
		CLOSE order_cursor  
		DEALLOCATE order_cursor  

		FETCH NEXT FROM people_cursor INTO @LastEditedBy, @FullName   

	END   
	CLOSE people_cursor;  
	DEALLOCATE people_cursor;  

	COMMIT

GO



GRANT EXECUTE ON dbo.FranksUpdate to SW_FrankInProductManagement;
GO



/* Drop these XE sessions */
IF (SELECT COUNT(*) FROM sys.server_event_sessions where name=N'SW_Blocked Process Report') > 0
DROP EVENT SESSION [SW_Blocked Process Report] ON SERVER
GO

IF (SELECT COUNT(*) FROM sys.server_event_sessions where name=N'SW_Deadlock Graph') > 0
DROP EVENT SESSION [SW_Deadlock Graph] ON SERVER
GO




/****** Create Job [Frank Did It]  ******/
IF (SELECT COUNT(*) FROM msdb..sysjobs WHERE name=N'SW_Frank Did It') > 0
	exec msdb..sp_delete_job @job_name=N'SW_Frank Did It';
GO

USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SW_Frank Did It', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Hi, I''m Frank! This is my job.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'SW_FrankInProductManagement', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'"Fix" Descriptions', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec dbo.FranksUpdate 50', 
		@database_name=N'WideWorldImporters', 
		@database_user_name=N'SW_FrankInProductManagement', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 10 seconds', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20161013, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'1567c89e-a034-4d7d-b3d4-ff205f1a41de'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO





/****** Create Job [Blockee]  ******/
IF (SELECT COUNT(*) FROM msdb..sysjobs WHERE name=N'SW_Blockee') > 0
	exec msdb..sp_delete_job @job_name=N'SW_Blockee';
GO

USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SW_Blockee', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SW_Blockee', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
SELECT
	BillToCustomerID,
	COUNT(*) as CustomerCount
FROM Sales.Customers
GROUP BY BillToCustomerID;
GO', 
		@database_name=N'WideWorldImporters', 
		@database_user_name=N'SW_ImportantApp', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO




exec msdb..sp_start_job @job_name=N'SW_Blockee'
GO


/* Leave this transaction open. */
USE WideWorldImporters;
GO
EXECUTE AS LOGIN = 'SW_Oops';
GO

BEGIN TRAN

	UPDATE Sales.Customers
	SET BillToCustomerID = 2
	WHERE BillToCustomerID = 1;

