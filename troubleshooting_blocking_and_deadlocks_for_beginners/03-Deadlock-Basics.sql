/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/troubleshooting-blocking-and-deadlocks-for-beginners
*****************************************************************************/

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/* The Blocked Process Report is very cool, but it's just blocking.

If the blocking has to be broken up by the deadlock manager, we can get more details.

But we have to collect the Deadlock Graph for that.
The deadlock graph is XML. It has two different names, depending on how you collect it:

	In SQLTrace, this is "Deadlock Graph" in the Locks category.
	In Extended Events, this is xml_deadlock_report
*/


/* In recent versions of SQL Server, the xml_deadlock_report is picked up 
	by the system_health XEvents session.
But that session collects lots of other events, and it has max_events_limit=5000
If you want to make SURE you get your deadlock graph, it's worth setting up another trace.
*/

CREATE EVENT SESSION [SW_Deadlock Graph] ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename=N'S:\XEvents\Deadlocks.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,
	MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

/* Now start the trace */
ALTER EVENT SESSION [SW_Deadlock Graph] ON SERVER STATE = START;
GO




/* 
Now that it's set up, we lie in wait for a deadlock.

Oh, look, here comes one now!
*/


USE WideWorldImporters;
GO

/* Run the BEGIN tran and the first statement in this session.
We're taking out a lock on the Countries table */
WHILE @@TRANCOUNT > 1 ROLLBACK
BEGIN TRAN

    UPDATE Application.Countries
    SET LatestRecordedPopulation = LatestRecordedPopulation + 1
    WHERE IsoNumericCode = 840;




    /* Stop here and run the SELECT below in session 2.
    After it's running, complete this transaction....*/

    UPDATE Application.StateProvinces
    SET LatestRecordedPopulation = LatestRecordedPopulation +1
    WHERE StateProvinceCode=N'VA'
COMMIT
GO



/* Select for Session 2.
This gets blocked on the countries table, but it gets a lock on StateProvinces*/
USE WideWorldImporters;
GO
SELECT CityName, StateProvinceName, sp.LatestRecordedPopulation, CountryName
FROM Application.Cities AS city
JOIN Application.StateProvinces AS sp on
    city.StateProvinceID = sp.StateProvinceID
JOIN Application.Countries AS ctry on
    sp.CountryID=ctry.CountryID
WHERE sp.StateProvinceName = N'Virginia';
GO


/* Now finish up the transaction in Session 1*/

/* Open the extended events file, and find the deadlock graph.

Double-click on the value in details
	Note that it does not contain both updates in the first transaction!
Now show the Deadlock tab 
	Hover over the circles (processes)



Now head to the slides for a bit	
*/














/* Create this index, and then re-run the deadlock code to see if it fixes it */
CREATE INDEX ix_deadlock_killer on Application.Countries (CountryId) INCLUDE (CountryName);
GO