/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/


*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*****************************************************************************
Problem: Which Extended Events Wizard should I use?

Solution: Use the one which does NOT call itself a wizard.
*****************************************************************************/

/* Demo:
	Go to Management -> Extended Events

	Right click on the Sessions folder
	
	There's "New Session Wizard" and "New Session"

	Both are wizards!

	Both are complicated
	
	But the "Wizard" doesn't let you do everything

	My advice: Just use "New Session" and get used to one wizard
*/





/*****************************************************************************
Problem: I'm tired of setting a filter on each event

Solution: Set multiple filters at once
*****************************************************************************/

--Let's say we want to run a trace just for our session id
SELECT @@SPID;
GO

/* Demo:

Management - Extended Events
Right click, new session

	Name it: Tuning
	Template: Tuning

	Events: Configure
	Select all the events using SHIFT
	Click on the 'Filter (Predicate)' tab

	Add a filter for sqlserver.session_id = your session number

	Go to data storage, use S:\XEvents\Tuning

	Start the trace
*/

ALTER EVENT SESSION [Tuning] ON SERVER STATE = START;
GO


/* Run a query and then review the output */
use WideWorldImporters
GO
SELECT 'CAN YOU SEE ME NOW????';
GO



/* Stop and delete the trace */
ALTER EVENT SESSION [Tuning] ON SERVER STATE = STOP;
GO

DROP EVENT SESSION [Tuning] ON SERVER;
GO





/*****************************************************************************
Problem: I can't find an event I read about in a blog post

Solution: Check the (hidden) 'Debug' events
*****************************************************************************/

/* Demo: I read a blog about the query_thread_profile event, 
and I want to test it on my demo instance.

Management - Extended Events
Right click, new session

	Name it: query_thread_profile
	Events: query_thread_profile

Nothing shows up!?!?!

	Click the down carat to the right of 'Channel'
	Now you can add the event

	Go to data storage
	I have an error because of a bug in my version of SSMS
		(https://connect.microsoft.com/SQLServer/feedback/details/3133065)
	Paste in S:\XEvents\test

Note: this particular event is VERY verbose. 
I just picked it as an example of a debug event :)
Test carefully.
*/



/* Stop and delete the trace */
ALTER EVENT SESSION [query_thread_profile] ON SERVER STATE = STOP;
GO

DROP EVENT SESSION [query_thread_profile] ON SERVER;
GO