/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tuning-a-stored-procedure-sqlchallenge-1-hour-10-minutes/

SQLChallenge: Tuning a Stored Procedure

CHALLENGE FILE

****************************************************************************/


RAISERROR (N'🛑 Did you mean to run the whole thing? 🛑', 20, 1) WITH LOG;
GO


/*****************************************************************************

CHALLENGE: TUNING A STORED PROCEDURE
🔧 SETUP 🔧

*****************************************************************************/



/****************************************************
Create database
****************************************************/

USE master;
GO

WHILE @@TRANCOUNT > 0
	ROLLBACK

IF DB_ID('SQLChallenge') IS NOT NULL
BEGIN
	ALTER DATABASE SQLChallenge SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE SQLChallenge;
END
GO

CREATE DATABASE SQLChallenge
GO


ALTER DATABASE SQLChallenge SET QUERY_STORE = ON;
GO




/*****************************************************************************

💼 CHALLENGE: TUNING A STORED PROCEDURE 💼

Run the query with the two samples below - fast and slow.

When the query is slow....
	* Can you pinpoint in the execution plan where it is slow, and why?
	* Can you speed up the slow query with minimal code changes?

Note: your challenge is not to try to fix every problem in the code -- 
	there are a LOT, not the least of which is that there is no protection against SQL injection!

	Your mission is to pinpoint the biggest performance problem and fix it as quickly as possible.

	To make this even more fun, the number of rows returned by the second result set can naturally vary slightly

    The procedure only needs to be run from one session at a time (as is the case with the original)

    You can change /add /remove whatever you want in the procedure to tackle the biggest performance problem,
        while maintaining the basic functionality of the procecure

*****************************************************************************/


/****************************************************
Create procedure
****************************************************/


USE SQLChallenge;
GO

CREATE OR ALTER PROCEDURE dbo.TuneMe
	@number_of_rows int = 1000,
	@fillfactor smallint = 80,
	@modification_sql_injection nvarchar(max) = N'DELETE FROM dbo.index_maint_tests where id%2=0;',
	@number_of_times_to_run_modification smallint = 1
AS
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
		WHILE @i <= @number_of_rows
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
	WITH (FILLFACTOR = ' + CAST(@fillfactor as varchar(3)) + N');'

	exec sp_executesql @sql;

	SELECT allocated_page_page_id, next_page_page_id, page_type_desc
	INTO #pagenumbers_1
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	--modification
	SET @i=1;
	WHILE @i <= @number_of_times_to_run_modification
	BEGIN
		EXEC sp_executesql @modification_sql_injection;
		set @i=@i+1;
	END

	SELECT allocated_page_page_id, next_page_page_id, page_type_desc
	INTO #pagenumbers_2
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- reorganize
	ALTER INDEX ix_index_maint_tests on index_maint_tests REORGANIZE;

	SELECT allocated_page_page_id, next_page_page_id, page_type_desc
	INTO #pagenumbers_3
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- offline rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD;

	SELECT allocated_page_page_id, next_page_page_id, page_type_desc
	INTO #pagenumbers_4
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

	-- online rebuild 
	ALTER INDEX ix_index_maint_tests on index_maint_tests REBUILD WITH (ONLINE=ON);

	SELECT allocated_page_page_id, next_page_page_id, page_type_desc
	INTO #pagenumbers_5
	FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('index_maint_tests'),1,NULL, 'detailed')
	WHERE is_allocated = 1 and page_type_desc = 'DATA_PAGE';

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

GO

set statistics time, io off;
GO
--fast
EXEC dbo.TuneMe
	@number_of_rows = 1000,
	@fillfactor = 80,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%2=0;',
	@number_of_times_to_run_modification = 1;
GO

--slow
EXEC dbo.TuneMe
	@number_of_rows = 100000,
	@fillfactor = 90,
	@modification_sql_injection = N'DELETE FROM dbo.index_maint_tests where id%5=0;',
	@number_of_times_to_run_modification = 1;
GO

