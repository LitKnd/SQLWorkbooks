/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tuning-a-stored-procedure-sqlchallenge-1-hour-10-minutes/

SQLChallenge: Tuning a Stored Procedure

SOLUTION FILE

****************************************************************************/


RAISERROR (N'🛑 Did you mean to run the whole thing? 🛑', 20, 1) WITH LOG;
GO


--For rerunnability
DBCC TRACEOFF (7412, -1);
GO

DBCC TRACESTATUS;
GO

/****************************************************
PROBLEM 1:
Which query do we need to tune?
****************************************************/

USE SQLChallenge;
GO


--Try running with actual plans on. What happens?
--slow
EXEC dbo.TuneMe
	@number_of_rows = 100000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1;
GO


--Turn off actual plans and run it "normally"
--Try this in another session while it's going
--Note that the plan has estimates only
--WhoIsActive.com
EXEC sp_WhoIsActive @get_plans=1;
GO
--We can see the plan and logical reads going up

--Try Activity Monitor
--This does finish in about a minute, but what if it was much longer?





/****************************************************
Option: TF 7412
https://blogs.msdn.microsoft.com/sql_server_team/query-progress-anytime-anywhere/

We are on SQL Server 2014 SP2+, so we can do this:
Trace flag 7412 (global) / Query_thread_profile extended event

****************************************************/


DBCC TRACEON (7412, -1);
GO

--Run this in this session, and now check sp_WhoIsActive in the other session for the 'big' query
--Do you see actual rows?
EXEC dbo.TuneMe
	@number_of_rows = 100000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1;
GO


--Run this in this session
--Pull up the live query plan from activity monitor
--After it finishes: can you see actual times and rows? (you have to hover over operators to see actual rows)

EXEC dbo.TuneMe
	@number_of_rows = 100000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1;
GO





/****************************************************
Option: Query Store
****************************************************/


--Can you find the long-running query in Query Store using the Top Resource Consumers report?

--If it wasn't in the report, we could query it
--One we know the query ID, we can use the 'Tracked Queries' Report
SELECT 
    (SELECT CAST(qst.query_sql_text AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    (select MAX(max_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as max_duration_ms,
    (select AVG(avg_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as avg_duration_ms,
    (select MIN(min_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as min_duration_ms,
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
WHERE so.name = 'TuneMe'
ORDER BY max_duration_ms DESC
OPTION (RECOMPILE);
GO



/****************************************************
Option: Execution plan cache
****************************************************/


SELECT TOP 10
	SUBSTRING(st.text, (qs.statement_start_offset/2)+1,   
		((CASE qs.statement_end_offset  
			WHEN -1 THEN DATALENGTH(st.text)  
			ELSE qs.statement_end_offset  
			END
		- qs.statement_start_offset)/2) + 1)  as query,
    qs.execution_count AS [# executions],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_worker_time / execution_count / 1000. / 1000. AS numeric(30,3))
		END AS [avg cpu sec],
	CASE WHEN execution_count = 0 THEN 0 ELSE
		CAST(qs.total_logical_reads / execution_count AS numeric(30,3))
	END AS [avg logical reads],
	qs.creation_time,
    qp.query_plan AS [plan]
FROM sys.dm_exec_query_stats AS qs
OUTER APPLY sys.dm_exec_sql_text (plan_handle) as st
OUTER APPLY sys.dm_exec_query_plan (plan_handle) AS qp
WHERE
    st.text LIKE '%TuneMe%'  /* Procedure name */
ORDER BY qs.total_worker_time DESC
OPTION (RECOMPILE);
GO



/****************************************************
PROBLEM 2:
Tuning the query
****************************************************/



/* The slow query
Hmm, FULL outer joins with ORs!*/

SELECT 
	coalesce(p1.allocated_page_page_id, p2.allocated_page_page_id, p3.allocated_page_page_id, p4.allocated_page_page_id, p5.allocated_page_page_id) as page_number,
	case when p1.allocated_page_page_id is not null then 'page exists' else '' end as 'initial index',
	case when p2.allocated_page_page_id is not null then 'page exists' else '' end as 'after modification',
	case when p3.allocated_page_page_id is not null then 'page exists' else '' end as 'after reorg',
	case when p4.allocated_page_page_id is not null then 'page exists' else '' end as 'after offine rebuild',
	case when p5.allocated_page_page_id is not null then 'page exists' else '' end as 'after online rebuild'
FROM #pagenumbers_1 AS p1
FULL OUTER JOIN #pagenumbers_2 as p2 on
	p1.allocated_page_page_id = p2.allocated_page_page_id
FULL OUTER JOIN #pagenumbers_3 as p3 on
	p1.allocated_page_page_id = p3.allocated_page_page_id or
	p2.allocated_page_page_id = p3.allocated_page_page_id
FULL OUTER JOIN #pagenumbers_4 as p4 on
	p1.allocated_page_page_id = p4.allocated_page_page_id or
	p2.allocated_page_page_id = p4.allocated_page_page_id or
	p3.allocated_page_page_id = p4.allocated_page_page_id
FULL OUTER JOIN #pagenumbers_5 as p5 on
	p1.allocated_page_page_id = p5.allocated_page_page_id or
	p2.allocated_page_page_id = p5.allocated_page_page_id or
	p3.allocated_page_page_id = p5.allocated_page_page_id or
	p4.allocated_page_page_id = p5.allocated_page_page_id
ORDER BY page_number;





--What if we used one table instead of 5?
--
--Let's swap in literals for the parameters and execute up to the problem query


--For rerunnability....
DROP TABLE IF EXISTS #pagenumbers, #pagenumbers_1 , #pagenumbers_2, #pagenumbers_3, #pagenumbers_4, #pagenumbers_5;
GO


--CREATE OR ALTER PROCEDURE dbo.TuneMe
--	@number_of_rows int = 1000,
--	@fillfactor smallint = 80,
--	@modification_sql_injection nvarchar(max) = N'DELETE FROM dbo.index_maint_tests where id%2=0;',
--	@number_of_times_to_run_modification smallint = 1
--AS
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DROP TABLE IF EXISTS dbo.index_maint_tests;

	CREATE TABLE dbo.index_maint_tests
	(
		id int identity not null,
		filler char(640)
	)

	-- add rows
	DECLARE @i INT = 1
	BEGIN TRAN
		WHILE @i <= 100000 /* @number_of_rows */
			BEGIN
				INSERT index_maint_tests (filler) VALUES ('a');
				SET @i = @i + 1;
			END
	COMMIT

	-- create index with specified fillfactor
	DECLARE @sql nvarchar(max);
	SELECT @sql=
	N'CREATE CLUSTERED INDEX ix_index_maint_tests 
	on index_maint_tests (id)
	WITH (FILLFACTOR = ' + CAST(90 /* @fillfactor */ as varchar(3)) + N');'

	exec sp_executesql @sql;

    CREATE TABLE #pagenumbers (
        test_id INT NOT NULL,
        allocated_page_page_id INT NOT NULL,
        next_page_page_id INT NULL, /* Do we even need this column???? */
        page_type_desc NVARCHAR(100) NULL  /* Do we even need this column???? */
    );

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 1, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	--modification
	SET @i=1;
	WHILE @i <= 1 /* @number_of_times_to_run_modification */
	BEGIN
		EXEC sp_executesql N'DELETE FROM dbo.index_maint_tests where id%5=0;' /* @modification_sql_injection */ ;
		set @i=@i+1;
	END

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 2, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- reorganize
	ALTER INDEX ix_index_maint_tests on index_maint_tests REORGANIZE;

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 3, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- offline rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD;

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 4, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- offline rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD;

    INSERT #pagenumbers (test_id, allocated_page_page_id)
    SELECT 5, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';


    /* Run to here */ 

    /* Original query for reference (we just have #pagenumbers now, so this won't work)

    #pagenumbers_1 data now has test_id = 1
    #pagenumbers_2 data now has test_id = 2, etc
    
     */
	SELECT 
		coalesce(p1.allocated_page_page_id, p2.allocated_page_page_id, p3.allocated_page_page_id, p4.allocated_page_page_id, p5.allocated_page_page_id) as page_number,
		case when p1.allocated_page_page_id is not null then 'page exists' else '' end as 'initial index',
		case when p2.allocated_page_page_id is not null then 'page exists' else '' end as 'after modification',
		case when p3.allocated_page_page_id is not null then 'page exists' else '' end as 'after reorg',
		case when p4.allocated_page_page_id is not null then 'page exists' else '' end as 'after offine rebuild',
		case when p5.allocated_page_page_id is not null then 'page exists' else '' end as 'after online rebuild'
	FROM #pagenumbers_1 AS p1
	FULL OUTER JOIN #pagenumbers_2 as p2 on
		p1.allocated_page_page_id = p2.allocated_page_page_id
	FULL OUTER JOIN #pagenumbers_3 as p3 on
		p1.allocated_page_page_id = p3.allocated_page_page_id or
		p2.allocated_page_page_id = p3.allocated_page_page_id
	FULL OUTER JOIN #pagenumbers_4 as p4 on
		p1.allocated_page_page_id = p4.allocated_page_page_id or
		p2.allocated_page_page_id = p4.allocated_page_page_id or
		p3.allocated_page_page_id = p4.allocated_page_page_id
	FULL OUTER JOIN #pagenumbers_5 as p5 on
		p1.allocated_page_page_id = p5.allocated_page_page_id or
		p2.allocated_page_page_id = p5.allocated_page_page_id or
		p3.allocated_page_page_id = p5.allocated_page_page_id or
		p4.allocated_page_page_id = p5.allocated_page_page_id
	ORDER BY page_number;



    /* What we are trying to show is whether a page exists for a given test_id
    We know we have test_ids 1, 2, 3, 4, 5
    This sounds like we can pivot it!
    */

    --One way to do it...
    SET STATISTICS IO, TIME ON
    GO
	SELECT 
        page_number, 
        CASE WHEN [1] > 0 THEN 'page exists' ELSE '' END as [initial index], 
        CASE WHEN [2] > 0 THEN 'page exists' ELSE '' END as [after modification], 
        CASE WHEN [3] > 0 THEN 'page exists' ELSE '' END as [after reorg], 
        CASE WHEN [4] > 0 THEN 'page exists' ELSE '' END as [after offine rebuild], 
        CASE WHEN [5] > 0 THEN 'page exists' ELSE '' END as [after online rebuild]
	FROM
	(SELECT 
        test_id, 
        allocated_page_page_id as page_number 
        FROM #pagenumbers)
		AS pivotsrc
	PIVOT
	( MAX(test_id)  
		FOR test_id in ([1], [2], [3], [4], [5]) 
        ) AS pivotout
    ORDER BY page_number;

    --Another way to do it, using GROUP BY + CASE
    --Compare plans
        SELECT
            allocated_page_page_id as page_number,
            MAX (case when test_id = 1 THEN 'page exists' ELSE '' END) AS [initial index],
            MAX (case when test_id = 2 THEN 'page exists' ELSE '' END) AS [after modification], 
            MAX (case when test_id = 3 THEN 'page exists' ELSE '' END) AS [after reorg], 
            MAX (case when test_id = 4 THEN 'page exists' ELSE '' END) AS [after offine rebuild],
            MAX (case when test_id = 5 THEN 'page exists' ELSE '' END) AS [after online rebuild]
        FROM #pagenumbers
        GROUP BY allocated_page_page_id
        order by page_number;
    



    SET STATISTICS IO, TIME OFF
    GO



DROP TABLE IF EXISTS #pagenumbers, #pagenumbers_1 , #pagenumbers_2, #pagenumbers_3, #pagenumbers_4, #pagenumbers_5;
GO





/* Populate in the changes. 
Let's call this TuneMe_revised
Other improvements:

    * Add @debug and related code
    * Remove unused columns from #pagenumbers
 */

CREATE OR ALTER PROCEDURE dbo.TuneMe_revised
	@number_of_rows int = 1000,
	@fillfactor smallint = 80,
	@modification_sql_injection nvarchar(max) = N'DELETE FROM dbo.index_maint_tests where id%2=0;',
	@number_of_times_to_run_modification smallint = 1,
    @debug bit = 0
AS
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE @msg NVARCHAR(MAX);
    DECLARE	@msgtime DATETIME2(7);
    DECLARE @timesincelastmsg INT;


	DROP TABLE IF EXISTS dbo.index_maint_tests;

	CREATE TABLE dbo.index_maint_tests
	(
		id int identity not null,
		filler char(640)
	)

    IF @debug = 1
    BEGIN
        SET @msg=N'CREATED dbo.index_maint_tests';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg;
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

	-- add rows
	DECLARE @i INT = 1
	BEGIN TRAN
		WHILE @i <= @number_of_rows
			BEGIN
				INSERT index_maint_tests (filler) VALUES ('a');
				SET @i = @i + 1;
			END
	COMMIT

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Added rows to dbo.index_maint_tests';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

	-- create index with specified fillfactor
	DECLARE @sql nvarchar(max);
	SELECT @sql=
	N'CREATE CLUSTERED INDEX ix_index_maint_tests 
	on index_maint_tests (id)
	WITH (FILLFACTOR = ' + CAST(@fillfactor as varchar(3)) + N');'

	exec sp_executesql @sql;

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'CREATED CLUSTERED INDEX ix_index_maint_tests on index_maint_tests (id) with specified fillfactor';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END


    --INLINE INDEX syntax for the index is SQL Server 2014+
    CREATE TABLE #pagenumbers (
        test_id INT NOT NULL,
        allocated_page_page_id INT NOT NULL
        --index ix_pagenumbers  CLUSTERED (allocated_page_page_id) WITH (FILLFACTOR = 5)
        --index ccx_pagenumbers  CLUSTERED COLUMNSTORE
    );

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'CREATED TABLE #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END


    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 1, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Inserted data for test_id 1 into #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END


	--modification
	SET @i=1;
	WHILE @i <= @number_of_times_to_run_modification
	BEGIN
		EXEC sp_executesql @modification_sql_injection;
		set @i=@i+1;
	END

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Executed @modification_sql_injection specified number of times';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 2, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Inserted data for test_id 2 into #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

	-- reorganize
	ALTER INDEX ix_index_maint_tests on index_maint_tests REORGANIZE;

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Reorg run against index on index_maint_tests';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 3, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Inserted data for test_id 3 into #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

	-- offline rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD;

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Offline rebuild run against index on index_maint_tests';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END


    INSERT #pagenumbers (test_id, allocated_page_page_id)
	SELECT 4, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';


    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Inserted data for test_id 4 into #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

	-- online rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD WITH (ONLINE=ON);


    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Online rebuild run against index on index_maint_tests';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

    INSERT #pagenumbers (test_id, allocated_page_page_id)
    SELECT 5, allocated_page_page_id
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'Inserted data for test_id 5 into #pagenumbers';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END


    --create clustered index cx_pagenumbers on #pagenumbers (allocated_page_page_id)
    --IF @debug = 1
    --BEGIN
    --    SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
    --    SET @msg=N'create clustered index cx_pagenumbers on #pagenumbers';
    --    SET @msgtime = SYSDATETIME();
    --    SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
    --    RAISERROR (@msg, 0, 1) WITH NOWAIT;
    --END


    SELECT
        allocated_page_page_id as page_number,
        MAX (case when test_id = 1 THEN 'page exists' ELSE '' END) AS [initial index],
        MAX (case when test_id = 2 THEN 'page exists' ELSE '' END) AS [after modification], 
        MAX (case when test_id = 3 THEN 'page exists' ELSE '' END) AS [after reorg], 
        MAX (case when test_id = 4 THEN 'page exists' ELSE '' END) AS [after offine rebuild],
        MAX (case when test_id = 5 THEN 'page exists' ELSE '' END) AS [after online rebuild]
    FROM #pagenumbers
    GROUP BY allocated_page_page_id
    order by page_number;

    IF @debug = 1
    BEGIN
        SET @timesincelastmsg = DATEDIFF (ms, @msgtime, SYSDATETIME());
        SET @msg=N'SELECTED data, WE R dun!';
        SET @msgtime = SYSDATETIME();
        SET @msg= CONVERT(NVARCHAR(21), @msgtime, 121) +  N': ' + @msg + N' (' + CAST(@timesincelastmsg as nvarchar(100)) + N'ms)';
        RAISERROR (@msg, 0, 1) WITH NOWAIT;
    END

GO




--fast
EXEC dbo.TuneMe_revised
	@number_of_rows = 1000,
	@fillfactor = 80,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%2=0;',
	@number_of_times_to_run_modification = 1,
    @debug=1;
GO


--Slow
EXEC dbo.TuneMe_revised
	@number_of_rows = 100000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1,
    @debug=1;
GO

/* MORE ROWS */
EXEC dbo.TuneMe_revised
	@number_of_rows = 500000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1,
    @debug = 1;
GO


/****************************************************
What does the plan look like now?
****************************************************/

--If we've ALTERED TuneMe_revised a bunch, we'll have a lot of different query_ids
--Ordering by last_execution_time
SELECT 
    qsp.last_execution_time,
    qsq.query_id,
    qsp.plan_id,
    (SELECT CAST(qst.query_sql_text AS NVARCHAR(MAX)) FOR XML PATH(''),TYPE) AS [TSQL],
    (select MAX(max_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as max_duration_ms,
    (select AVG(avg_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as avg_duration_ms,
    (select MIN(min_duration)/1000. as avg from sys.query_store_runtime_stats as rs where rs.plan_id=qsp.plan_id) as min_duration_ms,
    qsp.is_forced_plan,
    qsp.engine_version,
    qsp.compatibility_level,
    qsq.query_hash,
    qsp.query_plan_hash,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc,
    cast(qsp.query_plan as XML) as plan_xml
FROM sys.query_store_query as qsq
JOIN sys.objects as so on 
    so.object_id = qsq.object_id
JOIN sys.query_store_query_text as qst on 
    qsq.query_text_id = qst.query_text_id
JOIN sys.query_store_plan as qsp on 
    qsq.query_id = qsp.query_id
    and qsp.last_execution_time is not null
WHERE so.name = 'TuneMe_revised'
    and  CAST(qst.query_sql_text AS NVARCHAR(MAX)) like '%CASE%'
ORDER BY qsp.last_execution_time DESC
OPTION (RECOMPILE);
GO



