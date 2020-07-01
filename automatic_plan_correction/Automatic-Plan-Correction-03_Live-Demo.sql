/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/automatic-plan-correction-in-query-store/
*****************************************************************************/

USE BabbyNames;
GO

/* We have a procedure that sometimes gets a slow plan, 
    and sometimes gets a fast plan:
    It depends on which value of @Threshold it compiles for.
    (This is called "Bad Parameter Sniffing")
*/

/* look at estimated plan - this is the slow one.
Note the row mode Segment and Windows Spool operators */
EXEC dbo.PopularNames @Threshold = NULL WITH RECOMPILE;
GO

/* Look at the estimated plan - this is the fast one.
Note the batch mode Window Aggregate operator */
EXEC dbo.PopularNames @Threshold = 50000 WITH RECOMPILE;
GO


/* In this database, I have already:
    Configured and enabled Query Store
    SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON)

    Compiled the 'fast plan' and executed it 42 times (~1.5 minutes )
    Forced a recompile
    Compiled the 'slow plan' and run it 77 times (~ 8 minutes )
*/

/* Approximately 5.5 minutes into the 'slow plan' executions, this happened.... */


SELECT 
    name,
    type,
    reason,
    score, /* Estimated value/impact for this recommendation on the 0-100 scale (the larger the better)*/
    valid_since AT TIME ZONE 'Pacific Standard Time' AS valid_since,
    last_refresh AT TIME ZONE 'Pacific Standard Time' AS last_refresh,
    state,
    is_executable_action,
    is_revertable_action,
    execute_action_start_time AT TIME ZONE 'Pacific Standard Time' AS execute_action_start_time,
    execute_action_duration,
    execute_action_initiated_by,
    execute_action_initiated_time AT TIME ZONE 'Pacific Standard Time' AS execute_action_initiated_time,
    revert_action_start_time AT TIME ZONE 'Pacific Standard Time' AS revert_action_start_time,
    details
FROM sys.dm_db_tuning_recommendations;
GO

/* Aside: AT TIME ZONE uses a call to the operating system, 
    and can cause performance problems with larger sets of data:
    http://sqlsoldier.net/wp/sqlserver/timezonesareadragseriously
*/

/* 
Check out the reason column:
    Average query CPU time changed from 2321.58ms to 71851.5ms

Dig into that state JSON column:
    {"currentValue":"Verifying","reason":"LastGoodPlanForced"}
*/



/* Unpack the 'details' JSON column */
SELECT name,
    implementationdetails.*,
    planforcedetails.*
FROM sys.dm_db_tuning_recommendations
CROSS APPLY OPENJSON(details, '$.planForceDetails')
    WITH (  queryId int '$.queryId',
            regressedPlanId int '$.regressedPlanId',
            regressedPlanExecutionCount int '$.regressedPlanExecutionCount',
            regressedPlanCpuTimeAverage varchar(1000) '$.regressedPlanCpuTimeAverage',
            recommendedPlanId int '$.recommendedPlanId',
            recommendedPlanExecutionCount int '$.recommendedPlanExecutionCount',
            recommendedPlanCpuTimeAverage varchar(1000) '$.recommendedPlanCpuTimeAverage'
          ) as planforcedetails
CROSS APPLY OPENJSON(details, '$.implementationDetails')
    WITH (  script varchar(1000) '$.script'
          ) as implementationdetails
;
GO

/* Open the 'Queries with High Variation' Query Store Report
    Set the report to CPU Time / Standard Deviation
    Find the two plans and compare them
*/

/* Review the estimated plan for this.
Then run it with actual plans on and compare.
How can you tell that it was auto-tuned? */
EXEC dbo.PopularNames @Threshold = NULL WITH RECOMPILE;
GO


/* Refresh data in the 'Queries with High Variation' Query Store Report

What does the query we just executed look like? 
    How can you tell it was auto-tuned?
    Compare the estimated cost to the auto-tuned query with the checkmark
    Compare their 'compiled for' values
*/





/* Automatic plan correction isn't permanent. 
Lots of things make it un-stick the plan -- because maybe you could
get an EVEN BETTER plan, right? 

Statistics update is one thing that can un-stick the plan.
The dbo.PopularNames proc uses the table agg.FirstNameByYearState
*/
UPDATE STATISTICS agg.FirstNameByYearState;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

/* Run and look at the actual plan */
EXEC dbo.PopularNames @Threshold = NULL;
GO






















/* Wait a second, that had a plan correction! 

This is because SQL Server got smarter about updating statistics in 2012.
If data hasn't changed in the table, updating stats just gives you a polite "mmm hmm"

We have to at least *pretend* to change some data to make updating stats meaningful.
*/

BEGIN TRAN 

    DELETE FROM agg.FirstNameByYearState
    WHERE ReportYear = 1910;

ROLLBACK

UPDATE STATISTICS agg.FirstNameByYearState;
GO
 
/* Run this with actual plans on again... */
EXEC dbo.PopularNames @Threshold = NULL;
GO

/* What does the state column in sys.dm_db_tuning_recommendations say? */
select 
    name,
    type,
    reason,
    score, /* Estimated value/impact for this recommendation on the 0-100 scale (the larger the better)*/
    valid_since AT TIME ZONE 'Pacific Standard Time' AS valid_since,
    last_refresh AT TIME ZONE 'Pacific Standard Time' AS last_refresh,
    state,
    is_executable_action,
    is_revertable_action,
    execute_action_start_time AT TIME ZONE 'Pacific Standard Time' AS execute_action_start_time,
    execute_action_duration,
    execute_action_initiated_by,
    execute_action_initiated_time AT TIME ZONE 'Pacific Standard Time' AS execute_action_initiated_time,
    revert_action_start_time AT TIME ZONE 'Pacific Standard Time' AS revert_action_start_time,
    details
from sys.dm_db_tuning_recommendations;
GO

/* Refresh the Queries with High Variation report, note the changes */








/****************************************************************
Never fear, it can be auto-corrected again! 
****************************************************************/

/* We should have the 'slow' plan in cache.
Execute the procedure some more.
For fun, check out the Top Resource Consumers' report while waiting. 

Note: Make sure actual plans are disabled!*/
EXEC dbo.PopularNames @Threshold = 200000;
GO 20





SELECT 
    name,
    type,
    reason,
    state,
    is_executable_action,
    is_revertable_action,
    planforcedetails.*
FROM sys.dm_db_tuning_recommendations
CROSS APPLY OPENJSON(details, '$.planForceDetails')
    WITH (  queryId int '$.queryId',
            regressedPlanId int '$.regressedPlanId',
            regressedPlanExecutionCount int '$.regressedPlanExecutionCount',
            regressedPlanCpuTimeAverage varchar(1000) '$.regressedPlanCpuTimeAverage',
            recommendedPlanId int '$.recommendedPlanId',
            recommendedPlanExecutionCount int '$.recommendedPlanExecutionCount',
            recommendedPlanCpuTimeAverage varchar(1000) '$.recommendedPlanCpuTimeAverage'
          ) as planforcedetails
GO

/* You can manually un-force the plan,
Either in the reports, or with TSQL

Notice in this query that plan_forcing_type_desc = AUTO
 */
SELECT 
    *,
    CAST(query_plan AS XML) as XMLPlan
FROM sys.query_store_plan
WHERE query_id=7
and is_forced_plan=1;
GO

exec sp_query_store_unforce_plan @query_id=7, @plan_id=3;
GO


/* Review the state */
SELECT 
    name,
    type,
    state
FROM sys.dm_db_tuning_recommendations;
GO


/* But it may be auto-tuned again, as long as that's enabled for the DB
Execute the procedure some more.
For fun, check out the Top Resource Consumers' report while waiting. 

Note: Make sure actual plans are disabled!*/
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.PopularNames @Threshold = NULL;
GO

EXEC dbo.PopularNames @Threshold = 200000;
GO 30

