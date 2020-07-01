/*
Original demo from:
https://github.com/Microsoft/sql-server-samples/blob/master/samples/features/automatic-tuning/force-last-good-plan/sql-scripts/demo-full.sql

License info from: https://github.com/Microsoft/sql-server-samples/blob/master/license.txt
This material is built on:

Microsoft SQL Server Sample Code
Copyright (c) Microsoft Corporation
All rights reserved.

MIT License.

Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/



/****************************************************************************************************************
* Restore WideWorldImporters database
* WideWorldImporters-Full.bak is 121MB and can be downloaded from:
* https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
****************************************************************************************************************/
USE master;
GO

IF DB_ID('WideWorldImporters') IS NOT NULL
BEGIN
    ALTER DATABASE WideWorldImporters SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE WideWorldImporters FROM DISK=
	'S:\MSSQL\Backup\WideWorldImporters-Full.bak'  
	WITH REPLACE,
	MOVE 'WWI_Primary' to 'S:\MSSQL\Data\WideWorldImporters.mdf',
	MOVE 'WWI_UserData' to 'S:\MSSQL\Data\WideWorldImporters_UserData.ndf',
	MOVE 'WWI_Log' to 'S:\MSSQL\Data\WideWorldImporters.ldf',
	MOVE 'WWI_InMemory_Data_1' to 'S:\MSSQL\Data\WideWorldImporters_InMemory_Data_1';
GO
USE WideWorldImporters;
GO


/********************************************************
*  Automatic tuning in action
*  Change to original code: create stored procedure 
    dbo.AutoTuningTest so we can test different types 
    of recompile hints
********************************************************/
CREATE OR ALTER PROCEDURE dbo.AutoTuningTest
    @packagetypeid INT
AS
    SELECT avg([UnitPrice]*[Quantity]) AS TotalPrice
    INTO #dontfloodssmswithresultsets
	FROM Sales.OrderLines
	WHERE PackageTypeID = @packagetypeid;
GO


/********************************************************
*	RESET - clear everything
********************************************************/
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
ALTER DATABASE current SET QUERY_STORE CLEAR ALL;
GO

-- Enable automatic tuning on the database:
ALTER DATABASE current
SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON);
GO

-- Verify that actual state on FLGP is ON:
SELECT name, actual_state_desc, status = IIF(desired_state_desc <> actual_state_desc, reason_desc, 'Status:OK')
FROM sys.database_automatic_tuning_options
WHERE name = 'FORCE_LAST_GOOD_PLAN';
GO



-- 1. Start workload - execute procedure 30-300 times 
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 60 -- NOTE: This number shoudl be increased if you don't get a plan change regression.



-- 2. Cause the plan regression
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.AutoTuningTest	@packagetypeid = 0;
GO


-- 3. Start the workload again.
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 20



-- 4. Find a recommendation and check is it in "Verifying" or "Success" state:
SELECT reason, score,
	JSON_VALUE(state, '$.currentValue') state,
	JSON_VALUE(state, '$.reason') state_transition_reason,
    JSON_VALUE(details, '$.implementationDetails.script') script,
    planForceDetails.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON (Details, '$.planForceDetails')
    WITH (  [query_id] int '$.queryId',
            [new plan_id] int '$.regressedPlanId',
            [recommended plan_id] int '$.recommendedPlanId'
          ) as planForceDetails;
GO

		  
-- 5. Recommendation is in "Verifying" state, but the last good plan is forced, 
-- so the query will be faster. Execute and look at actual plan.
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO




/***************************************************************************************************************
* RECOMPILE HINTS STOP AUTO-TUNING
* This is on purpose: by adding a recompile hint we are saying:
* "We want a fresh compile, we do not want to re-use a plan"
* Forcing a plan would go against the spirit of this.
****************************************************************************************************************/

/***************************************************************************************************************
* RECOMPILE Type 1: WITH RECOMPILE in header
****************************************************************************************************************/

CREATE OR ALTER PROCEDURE dbo.AutoTuningTest
    @packagetypeid INT
    WITH RECOMPILE
AS
    SELECT avg([UnitPrice]*[Quantity]) AS TotalPrice
    INTO #dontfloodssmswithresultsets
	FROM Sales.OrderLines
	WHERE PackageTypeID = @packagetypeid;
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
ALTER DATABASE current SET QUERY_STORE CLEAR ALL;
GO

-- Verify that actual state on FLGP is ON (we already enabled this)
SELECT name, actual_state_desc, status = IIF(desired_state_desc <> actual_state_desc, reason_desc, 'Status:OK')
FROM sys.database_automatic_tuning_options
WHERE name = 'FORCE_LAST_GOOD_PLAN';
GO



-- 1. Start workload - execute procedure 30-300 times 
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 60 



-- 2. Clearing the cache isn't needed due to the RECOMPILE, but 
-- we can do it to be consistent during the test
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

--What the heck, let's run it 100 times
EXEC dbo.AutoTuningTest	@packagetypeid = 0;
GO 100


-- 3. Start the workload again.
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 20



-- 4. No recommendation
SELECT reason, score,
	JSON_VALUE(state, '$.currentValue') state,
	JSON_VALUE(state, '$.reason') state_transition_reason,
    JSON_VALUE(details, '$.implementationDetails.script') script,
    planForceDetails.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON (Details, '$.planForceDetails')
    WITH (  [query_id] int '$.queryId',
            [new plan_id] int '$.regressedPlanId',
            [recommended plan_id] int '$.recommendedPlanId'
          ) as planForceDetails;
GO

--We can run the 'faster plan' many many times and then the slower plan,
--no suggestion or auto-tuning will appear
EXEC dbo.AutoTuningTest	@packagetypeid = 0;
GO 300

EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 40

--Note: we have significantly changed the pattern by using the recompile hint
--We no longer have a plan being re-used by different parameter values!
--Everything is fast or slow on its own "compiled for" values

--But the reason that automatic plan correction will not occur is that by saying WITH RECOMPILE,
--We have said we do not want to use anyone else's plan (cached OR auto-corrected)


/* Open top resource consuming reports
View the plans
Force what looks like the 'fast plan'
*/

EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 40

select 
    qsq.query_id,
    qsp.plan_id,
    qsp.engine_version,
    qsp.compatibility_level,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc
from sys.query_store_query as qsq
join sys.query_store_plan as qsp on qsq.query_id = qsp.query_id
where qsq.object_id = OBJECT_ID('dbo.AutoTuningTest')
GO



/***************************************************************************************************************
* RECOMPILE Type 2: OPTION (RECOMPILE)
* This has the same effect as the previous demo, because the procedure has only a single statement
* This is included for completeness
****************************************************************************************************************/

CREATE OR ALTER PROCEDURE dbo.AutoTuningTest
    @packagetypeid INT
AS
    SELECT avg([UnitPrice]*[Quantity]) AS TotalPrice
    INTO #dontfloodssmswithresultsets
	FROM Sales.OrderLines
	WHERE PackageTypeID = @packagetypeid
        OPTION (RECOMPILE);
GO

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
ALTER DATABASE current SET QUERY_STORE CLEAR ALL;
GO

-- Verify that actual state on FLGP is ON (we already enabled this)
SELECT name, actual_state_desc, status = IIF(desired_state_desc <> actual_state_desc, reason_desc, 'Status:OK')
FROM sys.database_automatic_tuning_options
WHERE name = 'FORCE_LAST_GOOD_PLAN';
GO



-- 1. Start workload - execute procedure 30-300 times 
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 60 



-- 2. Clearing the cache isn't needed due to the RECOMPILE, but 
-- we can do it to be consistent during the test
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

--What the heck, let's run it 100 times
EXEC dbo.AutoTuningTest	@packagetypeid = 0;
GO 100


-- 3. Start the workload again.
EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 20



-- 4. No recommendation
SELECT reason, score,
	JSON_VALUE(state, '$.currentValue') state,
	JSON_VALUE(state, '$.reason') state_transition_reason,
    JSON_VALUE(details, '$.implementationDetails.script') script,
    planForceDetails.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON (Details, '$.planForceDetails')
    WITH (  [query_id] int '$.queryId',
            [new plan_id] int '$.regressedPlanId',
            [recommended plan_id] int '$.recommendedPlanId'
          ) as planForceDetails;
GO

--We can run the 'faster plan' many many times and then the slower plan,
--no suggestion or auto-tuning will appear
EXEC dbo.AutoTuningTest	@packagetypeid = 0;
GO 300

EXEC dbo.AutoTuningTest	@packagetypeid = 7;
GO 40

--Note: we have significantly changed the pattern by using the recompile hint
--We no longer have a plan being re-used by different parameter values!
--Everything is fast or slow on its own "compiled for" values

--But the reason that automatic plan correction will not occur is that by saying WITH RECOMPILE,
--We have said we do not want to use anyone else's plan (cached OR auto-corrected)