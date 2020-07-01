/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/troubleshooting-blocking-and-deadlocks-for-beginners
*****************************************************************************/

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


/* Our SQL Server is periodically freezing up!
First, I want to know if blocking is possibly the cause.
And I want to set up a lightweight monitor for it, just in case.
*/


/* Has blocking occurred since startup? */
/* Check sys.dm_os_wait_stats for how many LCK_ waits we've had in the past.*/
SELECT 
	wait_type,
	waiting_tasks_count,
	CAST(wait_time_ms / 1000. /60. AS NUMERIC(20,2)) AS wait_minutes,
	CASE WHEN wait_time_ms > 0 
		THEN CAST((1. * wait_time_ms / waiting_tasks_count 
            / 1000. /60.)as numeric(20,2))
		ELSE 0 END as avg_wait_minutes,
	(SELECT DATEDIFF(mi,sqlserver_start_time,SYSDATETIME()) 
        FROM sys.dm_os_sys_info) AS minutes_instance_online
FROM sys.dm_os_wait_stats as waits
WHERE 
	wait_type like 'LCK%'
	and waiting_tasks_count > 0
ORDER BY wait_minutes DESC
GO



/* Set up a performance alert to notify us if there's blocking */
USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N'SW_Super Simple Blocking Alert', 
		@message_id=0, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=300,  /* Let's talk about @delay_between_responses. This is in seconds. */
		@include_event_description_in=0, 
		@notification_message=N'We''ve got blocking -- check it out!', 
		@category_name=N'[Uncategorized]', 
		@performance_condition=N'General Statistics|Processes blocked||>|0', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO

/* We want the alert to notify me. 
For the email to work, I need to first...
	Configure Database Mail: https://msdn.microsoft.com/en-us/library/hh245116.aspx
	Configure SQL Server Agent to use Database Mail: https://msdn.microsoft.com/en-us/library/ms186358.aspx
	Create Operator: https://msdn.microsoft.com/en-us/library/ms175962.aspx

Then add a notification to the alert
*/
EXEC dbo.sp_add_notification  
 @alert_name = N'SW_Super Simple Blocking Alert',  
 @operator_name = N'SW_DemoOperator',  
 @notification_method = 1 ;  
GO  





/* Let's see if the alert fires.
Look at the alert properties and go to the history tab.
*/



/* OK, so far...
	* We checked sys.dm_os_wait_stats and confirmed lock waits have been a problem
	* We set up a blocking alert, which has emailed us and let us know blocking is happening now
	
	
Let's troubleshoot!
*/ 


/* sp_WhoIsActive is a free procedure from Adam Machanic:
	http://whoisactive.com/
It's lightweight, and is great at troubleshooting performance issues.
This queries CURRENT waits from the sys.dm_os_waiting_tasks DMV 
*/
exec sp_WhoIsActive;
GO


/* Look at the sessions with LCK waits:
	* wait_info
	* blocking_session_id

Now look at the blocker.
	* Look at the sql_text -- what's he doing?
	* Now scroll to the right and look at the 'status' column


Challenge:
	* Why is this blocking going on for so long?
	* What strategy would you take to prevent this from reoccuring long term?
        (Note: this is a difficult one, we aren't starting easy.
        Go Big Picture on your strategy.)


*/

/***********************************************************************
END OF PROBLEM -- Solution coming up next
***********************************************************************/


















/***********************************************************************
SOLUTION
***********************************************************************/


/***********************************************************************
First, the antipattern solution: NOLOCK?
***********************************************************************/

/* Look at the query text that is blocked again in sp_WhoIsActive */
exec sp_WhoIsActive;
GO

USE WideWorldImporters;
GO
SELECT
	BillToCustomerID,
	COUNT(*) as CustomerCount
FROM Sales.Customers
GROUP BY BillToCustomerID;
GO


/* You may read on the internet or hear from a coworker
that you can use "NOLOCK" to get around this, like this... */
SELECT
	BillToCustomerID,
	COUNT(*) as CustomerCount
FROM Sales.Customers WITH (NOLOCK) /* table hint */
GROUP BY BillToCustomerID;
GO


/* This is the same thing, just done without a hint */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO
SELECT
	BillToCustomerID,
	COUNT(*) as CustomerCount
FROM Sales.Customers
GROUP BY BillToCustomerID;
GO

/* 
There is a problem-- this does "dirty reads" 
In other words, you are saying, "I don't care if the data is correct."
And is the data correct?

Right now SW_Oops is changing a BillToCustomerID. We're reading the value as if it
has committed that transaction.
What if someone ran this query with NOLOCK and then we killed SW_Oops afterward?
They read data that was never committed.

We haven't addressed the actual cause of the blocking AT ALL.
*/

/* Reset this for your session */
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO




/***********************************************************************
Now let's look more at the CAUSE
***********************************************************************/

/* Let's talk about that status column in sp_WhoIsActive */
exec sp_WhoIsActive;
GO


/*
Status = 'sleeping'
	SQL Server is waiting for further input from the client
	This isn't trying to do any work... but it has an open transaction
	SQL Server holds locks for a transaction until:
		The client commits or rolls back the transaction
		The client session is killed (aka, the rollback is forced)
Status = 'suspended'
	These are waiting on a resource-- in this case they need a lock.
	They are trying to do work, but they don't have the resource they need!
*/

/* 
You may use the @get_locks parameter to see detailed lock info if you have the time.
Note: the DMV this uses can be somewhat slow if you have a lot of sessions running
*/
exec sp_WhoIsActive @get_locks=1;
GO



/* It's always a risk to kill anything. 
Rollback may be painful. 
We decide to gamble on it in this case.
*/

KILL 57;
GO


/* KILL WITH STATUSONLY does not KILL--
it shows the current progress of the rollback.
*/
KILL 57 WITH STATUSONLY;
GO


exec sp_WhoIsActive;
GO



/* But this is a short-term fix only. This can come back.

Let's talk about a strategy to find a longer term fix
in the slides. */




