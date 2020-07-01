/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-forcing-parallelism

*****************************************************************************/
RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


/*****************************************************************************
SOLUTIONS
There are multiple solutions -- here are four
*****************************************************************************/
USE ContosoRetailDW;
GO

/*****************************************************************************
SOLUTION 1: Query Store
SQL Server 2016+
*****************************************************************************/

/* Find a parallel plan for the query in query store */
SELECT 
    (SELECT CAST(qst.query_sql_text AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    qsp.is_forced_plan,
    qsq.query_id,
    qsp.plan_id,
    qsp.engine_version,
    qsp.compatibility_level,
    qsp.query_plan_hash,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc,
    cast(qsp.query_plan as XML) as plan_xml
FROM sys.query_store_query as qsq
JOIN sys.objects as so on 
    so.object_id = qsq.object_id
JOIN sys.query_store_query_text as qst on 
    qsq.query_text_id = qst.query_text_id
JOIN sys.query_store_plan as qsp on qsq.query_id = qsp.query_id
WHERE so.name = 'TotalSalesByRegionForYear'
GO


/* Plug in the query id and the plan id */
exec sp_query_store_force_plan @query_id=3, @plan_id=3;
GO

/* Look at estimated plan,
then run with actual plan */
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

/* How many plans do we have?
What is the new plan? */
SELECT 
    (SELECT CAST(qst.query_sql_text AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    qsp.is_forced_plan,
    qsq.query_id,
    qsp.plan_id,
    qsp.engine_version,
    qsp.compatibility_level,
    qsp.query_plan_hash,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc,
    cast(qsp.query_plan as XML) as plan_xml
FROM sys.query_store_query as qsq
JOIN sys.objects as so on 
    so.object_id = qsq.object_id
JOIN sys.query_store_query_text as qst on 
    qsq.query_text_id = qst.query_text_id
JOIN sys.query_store_plan as qsp on qsq.query_id = qsp.query_id
WHERE so.name = 'TotalSalesByRegionForYear'
GO


/* Open "Queries with Forced Plans" report to compare */


/* Clean up */
exec sp_query_store_unforce_plan @query_id=3, @plan_id=3;
GO


/* Look at estimated. Then run with actual plans */
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO












/*****************************************************************************
SOLUTION 2: Plan Guide adding an undocumented hint
SQL Server 2008+ for the plan guide
SQL Server 2016+ for the undocumented hint 

NOTE: This is unsupported! It technically works, but not a good idea.
If you've got 2016 in place, why not just use Query Store plan freezing?
If you don't have 2016, another option is next using TF 8649
*****************************************************************************/
declare @planhint nvarchar(1000) = 'OPTION (USE HINT(''ENABLE_PARALLEL_PLAN_PREFERENCE''))'

EXEC sys.sp_create_plan_guide
    @name = N'Add USE HINT ENABLE_PARALLEL_PLAN_PREFERENCE',
    @stmt = N'SELECT 
    Region,
    CalendarYear,
    SUM(Amount) as TotalSales,
    MIN(YearlyIncome) as MinYearlyIncome,
    MAX(YearlyIncome) as MaxYearlyIncome
FROM dbo.V_CustomerData
    WHERE CalendarYear = @CalendarYear
GROUP BY Region, CalendarYear
ORDER BY TotalSales DESC;',
    @type = 'OBJECT',
    @module_or_batch = 'dbo.TotalSalesByRegionForYear',
    @params = NULL,
    @hints = @planhint
GO


/* Look at actual plan. 
Can you see the plan guide? */
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO


EXEC sys.sp_control_plan_guide N'DROP', N'Add USE HINT ENABLE_PARALLEL_PLAN_PREFERENCE';  
GO


EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

--ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
--GO







/*****************************************************************************
SOLUTION 3: Inject a plan into cache by using an unspported trace flag,
    then capture the plan as a USE PLAN hint
*****************************************************************************/
--This trace flag is unsupported
--We are enabling it just for our session
DBCC TRACEON (8649, 0);
GO

DBCC TRACESTATUS;
GO

----I want a new plan on the next run
--exec sp_recompile 'TotalSalesByRegionForYear';
--GO

--Get a plan into cache. The undocumented trace flag effectively
--lowers cost threshold for parallelism for our session

--Run with actual plans and look at the cost
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

--I can do this now if I want, the plan is in cache
DBCC TRACEOFF (8649);
GO



DECLARE @plan XML

SELECT 
    @plan = qp.query_plan
FROM sys.dm_exec_procedure_stats AS qs  
JOIN sys.objects as so on qs.object_id = so.object_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st  
CROSS APPLY sys.dm_exec_query_plan(plan_handle) as qp
WHERE 
    so.name='TotalSalesByRegionForYear';

DECLARE @planhint NVARCHAR(MAX) = N'OPTION (USE PLAN N''' + REPLACE(cast(@plan as NVARCHAR(MAX)), '''', '''''')  + ''')';


EXEC sys.sp_create_plan_guide
    @name = N'Add a USE PLAN hint',
    @stmt = N'SELECT 
    Region,
    CalendarYear,
    SUM(Amount) as TotalSales,
    MIN(YearlyIncome) as MinYearlyIncome,
    MAX(YearlyIncome) as MaxYearlyIncome
FROM dbo.V_CustomerData
    WHERE CalendarYear = @CalendarYear
GROUP BY Region, CalendarYear
ORDER BY TotalSales DESC;',
    @type = 'OBJECT',
    @module_or_batch = 'dbo.TotalSalesByRegionForYear',
    @params = NULL,
    @hints = @planhint
GO


EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

EXEC sys.sp_control_plan_guide N'DROP', N'Add a USE PLAN hint';  
GO






/*****************************************************************************
SOLUTION 4: Inject a plan into cache by using an unspported trace flag,
    then freeze the plan
*****************************************************************************/
--This trace flag is unsupported
--We are enabling it just for our session
DBCC TRACEON (8649, 0);
GO

DBCC TRACESTATUS;
GO

----I want a new plan on the next run
--exec sp_recompile 'TotalSalesByRegionForYear';
--GO

--Get a plan into cache. The undocumented trace flag effectively
--lowers cost threshold for parallelism for our session

--Run with actual plans and look at the cost
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

--I can do this now if I want, the plan is in cache
DBCC TRACEOFF (8649);
GO



/* Freeze the plan for the procedure */
DECLARE 
    @handle varbinary(64),
    @offset int = NULL;  

SELECT 
    @handle = qs.plan_handle
FROM sys.dm_exec_procedure_stats AS qs  
JOIN sys.objects as so on qs.object_id = so.object_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st  
WHERE 
    so.name='TotalSalesByRegionForYear'
 
EXECUTE sys.sp_create_plan_guide_from_handle @name =  N'FreezeParallelPlan',  
    @plan_handle = @handle,  
    @statement_start_offset = @offset;  
GO


/* Can you see the plan guide in the estimated and actual plans?
What is the cost? */
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO


SELECT 
    qs.plan_handle,
    qp.query_plan
FROM sys.dm_exec_procedure_stats AS qs  
JOIN sys.objects as so on qs.object_id = so.object_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st  
CROSS APPLY sys.dm_exec_query_plan(plan_handle) as qp
WHERE 
    so.name='TotalSalesByRegionForYear';
GO

EXEC sys.sp_control_plan_guide N'DROP', N'FreezeParallelPlan';  
GO



