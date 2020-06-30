/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/************************************************************ 
Let's test our query here 
************************************************************/
USE BabbyNames;
GO
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender
    OPTION (MAXDOP 10)
GO

/* This sequence measures duration and waits for the session.
Change the maxdop for the query and compare the duration and waits 

sys.dm_exec_session_wait_stats is SQL Server 2016+
*/
USE BabbyNames;
GO
DROP TABLE IF EXISTS dbo.t1, dbo.t2;
GO
DROP SEQUENCE IF EXISTS dbo.SimpleSequence
GO
CREATE SEQUENCE dbo.SimpleSequence
    START WITH 1  
    INCREMENT BY 1 ;  
GO  

create table dbo.t1 (
    runid INT NOT NULL,
    DOP	smallint,
    starttime	datetime2,
    session_id	smallint,
    wait_type	nvarchar (256),
    waiting_tasks_count	bigint,
    wait_time_ms	bigint,
    signal_wait_time_ms	bigint
);
create table dbo.t2 (
    runid INT NOT NULL,
    DOP	smallint,
    endtime	datetime2,
    session_id	smallint,
    wait_type	nvarchar (256),
    waiting_tasks_count	bigint,
    wait_time_ms	bigint,
    signal_wait_time_ms	bigint
)
GO


declare @dop smallint = 10;
declare @dsql nvarchar(max);
declare @runid INT;
while @dop > 0
BEGIN

    SELECT @runid = NEXT VALUE FOR dbo.SimpleSequence

    insert dbo.t1 (runid, DOP, starttime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    select  @runid as runid, @dop as DOP, SYSDATETIME() as starttime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    from sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID;

    select @dsql= N'
    DROP TABLE IF EXISTS dbo.foo;
    SELECT
        fnbd.Gender,
        COUNT(*) as SumNameCount
    INTO dbo.foo
    FROM dbo.FirstNameByBirthDate fnbd
    JOIN ref.FirstName as fn on
        fnbd.FirstNameId = fn.FirstNameId
    WHERE
        fn.FirstName = ''Jacob''
    GROUP BY Gender
        OPTION (MAXDOP ' + cast(@dop as nchar(2)) + N');'

    EXEC (@dsql);

    insert dbo.t2 (runid, DOP, endtime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    select @runid as runid, @dop as DOP, SYSDATETIME() as endtime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    from sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID;

    set @dop -= 1;

END
GO





--Analyze
SELECT 
    dbo.t2.DOP,
    duration.duration_ms,
    dbo.t2.wait_type,
    wait.wait_time_ms,
    cast(wait.wait_time_ms / duration.duration_ms as numeric (10,3)) avg_wait_time_ms,
    signal.signal_wait_time_ms,
    cast(signal.signal_wait_time_ms / duration.duration_ms   as numeric(10,3)) as avg_signal_wait_time_ms
FROM dbo.t2
LEFT OUTER JOIN dbo.t1 on dbo.t2.wait_type=dbo.t1.wait_type  
    and dbo.t2.runid = dbo.t1.runid
OUTER APPLY (SELECT cast
    (DATEDIFF(ms, (select max(starttime) from dbo.t1 as t where t.DOP=t2.DOP), 
    dbo.t2.endtime) as numeric(10,3)) as duration_ms) as duration
OUTER APPLY (SELECT dbo.t2.wait_time_ms - ISNULL(dbo.t1.wait_time_ms,0) as wait_time_ms) as wait
OUTER APPLY (SELECT dbo.t2.signal_wait_time_ms - ISNULL(dbo.t1.signal_wait_time_ms,0) as signal_wait_time_ms) as signal
WHERE
    dbo.t2.wait_time_ms IS NOT NULL
    and dbo.t2.wait_time_ms > ISNULL(dbo.t1.wait_time_ms,0)
ORDER BY t2.DOP DESC, t2.wait_time_ms DESC
    OPTION (RECOMPILE, MAXDOP 1)
GO


/* Show analysis in Excel */





--Let's test another query
--We're going "cold cache" on this one...

DROP TABLE IF EXISTS dbo.foo;
dbcc dropcleanbuffers;
GO

SELECT
    ISNULL(CAST(ROW_NUMBER() OVER (ORDER BY (SELECT 'boop')) AS BIGINT),0) AS FirstNameByBirthDateId,
    DATEADD(mi,n.Num * 5.1,CAST('1/1/' + CAST(ReportYear AS CHAR(4)) AS datetime2(0))) as FakeBirthDateStamp,
    fn.StateCode,
    fn.FirstNameId,
    Gender,
    CAST(NULL AS TINYINT) as Flag1,
    CAST(NULL AS CHAR(1)) as Flag2
INTO dbo.foo
FROM agg.FirstNameByYearState AS fn
CROSS APPLY (select Num from ref.Numbers where Num <= fn.NameCount) AS n
OPTION (MAXDOP 10);
GO





/* Reset */
ALTER SEQUENCE dbo.SimpleSequence RESTART WITH 1 ;  
truncate table dbo.t1;
truncate table dbo.t2;
GO

/* Test: NOTE: This sequence clears out memory for the whole instance:
NOT friendly to instances where anyone else may be using it!
*/
declare @dop smallint = 10;
declare @dsql nvarchar(max);
declare @runid INT;
while @dop > 0
BEGIN

    SELECT @runid = NEXT VALUE FOR dbo.SimpleSequence

    DROP TABLE IF EXISTS dbo.foo;
    dbcc dropcleanbuffers;

    waitfor delay '00:00:01'

    insert dbo.t1 (runid, DOP, starttime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    select  @runid as runid, @dop as DOP, SYSDATETIME() as starttime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    from sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID;

    select @dsql= N'
        SELECT
            ISNULL(CAST(ROW_NUMBER() OVER (ORDER BY (SELECT ''boop'')) AS BIGINT),0) AS FirstNameByBirthDateId,
            DATEADD(mi,n.Num * 5.1,CAST(''1/1/'' + CAST(ReportYear AS CHAR(4)) AS datetime2(0))) as FakeBirthDateStamp,
            fn.StateCode,
            fn.FirstNameId,
            Gender,
            CAST(NULL AS TINYINT) as Flag1,
            CAST(NULL AS CHAR(1)) as Flag2
        INTO dbo.foo
        FROM agg.FirstNameByYearState AS fn
        CROSS APPLY (select Num from ref.Numbers where Num <= fn.NameCount) AS n
        OPTION (MAXDOP ' + cast(@dop as nchar(2)) + N');'

    EXEC (@dsql);

    insert dbo.t2 (runid, DOP, endtime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms)
    select @runid as runid, @dop as DOP, SYSDATETIME() as endtime, session_id, wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
    from sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID;

    set @dop -= 1;

END
GO





--Analyze
SELECT 
    dbo.t2.DOP,
    duration.duration_ms,
    dbo.t2.wait_type,
    wait.wait_time_ms,
    cast(wait.wait_time_ms / duration.duration_ms as numeric (10,3)) avg_wait_time_ms,
    signal.signal_wait_time_ms,
    cast(signal.signal_wait_time_ms / duration.duration_ms   as numeric(10,3)) as avg_signal_wait_time_ms
FROM dbo.t2
LEFT OUTER JOIN dbo.t1 on dbo.t2.wait_type=dbo.t1.wait_type  
    and dbo.t2.runid = dbo.t1.runid
OUTER APPLY (SELECT cast
    (DATEDIFF(ms, (select max(starttime) from dbo.t1 as t where t.DOP=t2.DOP), 
    dbo.t2.endtime) as numeric(10,3)) as duration_ms) as duration
OUTER APPLY (SELECT dbo.t2.wait_time_ms - ISNULL(dbo.t1.wait_time_ms,0) as wait_time_ms) as wait
OUTER APPLY (SELECT dbo.t2.signal_wait_time_ms - ISNULL(dbo.t1.signal_wait_time_ms,0) as signal_wait_time_ms) as signal
WHERE
    dbo.t2.wait_time_ms IS NOT NULL
    and dbo.t2.wait_time_ms > ISNULL(dbo.t1.wait_time_ms,0)
ORDER BY t2.DOP DESC, t2.wait_time_ms DESC
    OPTION (RECOMPILE, MAXDOP 1)
GO


