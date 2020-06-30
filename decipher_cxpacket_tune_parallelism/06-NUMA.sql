/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



--sys.dm_os_sys_info
--SQL Server 2008+
SELECT 
    cpu_count,
    hyperthread_ratio, /* Longtime confusing column */
    physical_memory_kb / 1024./1024. as physical_memory_GB, /* SQL Server 2012+ */
    max_workers_count,  
    virtual_machine_type_desc, /*  SQL Server 2008 R2 + */
    softnuma_configuration_desc, /* SQL Server 2016+ */
    socket_count, /* SQL Server 2017+ */
    cores_per_socket, /* SQL Server 2017+ */
    numa_node_count /* SQL Server 2017+ */
FROM sys.dm_os_sys_info;
GO




--SQL Server 2008+
--Q: What is node_id 64?
SELECT node_id,
    memory_node_id,
    cpu_count,
    active_worker_count,
    avg_load_balance
from sys.dm_os_nodes;
GO


--Note SPID
SELECT @@SPID;
GO
--Start up this query
--While it is running, run the query below in another session
USE BabbyNames;
GO
DROP TABLE IF EXISTS dbo.foo;
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
OPTION (MAXDOP 5);
GO

--Make sure you use the right @@SPID!
SELECT DISTINCT
    s.parent_node_id,
    t.session_id,
    t.scheduler_id,
    w.worker_address,
    t.task_state,
    wt.wait_type,
    wt.wait_duration_ms
FROM sys.dm_os_tasks AS t
JOIN sys.dm_os_schedulers AS s on
    t.scheduler_id  = s.scheduler_id
LEFT JOIN sys.dm_os_workers AS w on 
    t.worker_address=w.worker_address
LEFT JOIN sys.dm_os_waiting_tasks AS wt on 
    w.task_address=wt.waiting_task_address
WHERE t.session_id=52
ORDER BY s.parent_node_id;








/* Want to disable automatic soft-numa? 

It is disabled by the following statement, plus it requires a restart to take effect
Currently you need to manually disable the SQL Server Agent before running the command
    More info here: https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-server-configuration-transact-sql
*/

ALTER SERVER CONFIGURATION SET SOFTNUMA OFF;
GO
--Restart sequence

/* sys.dm_os_sys_info will show a different numa_node_count if you succeed */
SELECT 
    cpu_count,
    hyperthread_ratio, /* Longtime confusing column */
    physical_memory_kb / 1024./1024. as physical_memory_GB, /* SQL Server 2012+ */
    max_workers_count,  
    virtual_machine_type_desc, /*  SQL Server 2008 R2 + */
    softnuma_configuration_desc, /* SQL Server 2016+ */
    socket_count, /* SQL Server 2017+ */
    cores_per_socket, /* SQL Server 2017+ */
    numa_node_count /* SQL Server 2017+ */
FROM sys.dm_os_sys_info;
GO


--Scroll up and rerun the test query and watch the CPUs used




ALTER SERVER CONFIGURATION SET SOFTNUMA ON;
GO
--Repeat restart sequence
SELECT 
    cpu_count,
    hyperthread_ratio, /* Longtime confusing column */
    physical_memory_kb / 1024./1024. as physical_memory_GB, /* SQL Server 2012+ */
    max_workers_count,  
    virtual_machine_type_desc, /*  SQL Server 2008 R2 + */
    softnuma_configuration_desc, /* SQL Server 2016+ */
    socket_count, /* SQL Server 2017+ */
    cores_per_socket, /* SQL Server 2017+ */
    numa_node_count /* SQL Server 2017+ */
FROM sys.dm_os_sys_info;
GO


