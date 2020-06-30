/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decode-memory-pressure/

Note: This is a pressure testing script. It will impact performance and may crash Windows 
*****************************************************************************/

/* 
Windows settings we start with:
DANGER, this page file setup is going to get problematic when we
have certain kinds of external memory pressure. This is a testing setting,
NOT a best practice.

1) Open Local security policy. 
	Local policy -> User Rights Assignment
Demo starts with Lock Pages in Memory NOT granted to SQL Server
This setting requires an instance restart to take effect when changed

2) Computer properties -> Advanced System Settings -> Advanced -> 
	Performance / Settings -> Advanced -> Virtual Memory, Change ->
Set Windows page file to minimum size 500, maximum size 4000
    Note: as we're going to see, this can be dangerous!

*/



/* SQL Server settings...
We're going to start with 8GB max memory, 5 GB min memory.
(This isn't a recommendation or a best practice!)
This VM is configured with 10 GB of memory
 */

exec sp_configure 'max server memory (MB)', 8192;
GO

exec sp_configure 'min server memory (MB)', 5120;
GO

RECONFIGURE;
GO

/* Restart the SQL Server instance if you've been running a workload prior--
	This is just so you can see what these counters look like shortly after startup.
*/

/* Open up Process Explorer -- sort by Private Bytes desc 
*/


/* Open perfmon
	Perfmon.exe /sys
Add counters (default instance)
    Memory \ Available MBytes
	SQLServer:Memory Manager \ Target Server Memory (KB)
	SQLServer:Memory Manager \ Total Server Memory (KB)


Or for a named instance, they will look like:
    Memory \ Available MBytes
	MSSQL$INSTANCENAME:Memory Manager \ Target Server Memory (KB)
	MSSQL$INSTANCENAME:Memory Manager \ Total Server Memory (KB)


Look at Report View
*/


/* Before we run any queries, what do the DMVs say?
These DMVs are SQL Server 2008+, some columns are later versions only */
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO


/* OK, let's use some memory */

SELECT *
INTO dbo.COPY1
FROM dbo.FirstNameByBirthDate_2002_2017;
GO
SELECT *
INTO dbo.COPY2
FROM dbo.COPY1;
GO
SELECT *
INTO dbo.COPY3
FROM dbo.COPY2;
GO
SELECT *
INTO dbo.COPY4
FROM dbo.COPY3;
GO

/* Watch the counters while this is running */



/* Get this query going in another session for some constant reading */
while 1=1
begin
	DECLARE @noreturn char(2)
	SELECT @noreturn = t.Gender
	FROM 
    (SELECT Gender
        FROM dbo.FirstNameByBirthDate_2002_2017
        UNION
        SELECT Gender
        FROM dbo.COPY1
        UNION
        SELECT Gender
        FROM dbo.COPY2
        UNION
        SELECT Gender
        FROM dbo.COPY3
        UNION
        SELECT Gender
        FROM dbo.COPY4
    ) as t
end
GO



/* Now run testlimit64 from the SysInternals suite and watch the counters

cd S:\SysinternalsSuite

# Leak and touch memory (simulate resource usage)
.\Testlimit64.exe -d -c 2048

*/

/* what do our DMVs say? */
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO


/* Anything in the SQL Server log? */




/* Ok, now cancel the memory leak.
Watch the counters-- the target changes! 
Let it recover, and look at DMVs */
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO






/* Now try this...

# VirtualLock memory
.\Testlimit64.exe -v -c 4000

*/


/* What does this say now?
If our physical memory is below our Total Server memory, where is it coming from?
 */
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO




/* Look in the SQL Server log-- do you see this warning?
(It may take a while to show up )

********************************************************************
Date		8/13/2018 12:12:28 PM
Log		SQL Server (Current - 8/13/2018 12:07:00 PM)

Source		spid21s

Message
A significant part of sql server process memory has been paged out. 
This may result in a performance degradation. 
Duration: 0 seconds. 
Working set (KB): 2,344,356, committed (KB): 5,242,832, memory utilization: 44%.

********************************************************************
*/



/* Cancel TestLimit64, watch the counters change as it recovers.

OK, now things get real.

VM Memory = 10 gb
SQL Server is not locking pages
SQL Server Min Memory is 5GB
Page file is 4000MB

What if we try to leak 6GB of memory?
*/


/*
# Leak and touch memory (simulate resource usage)
.\Testlimit64.exe -d -c 6144

*/

SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO


/* OK, now how about these?

# VirtualLock memory
.\Testlimit64.exe -v -c 8192


.\Testlimit64.exe -d -c 8192

*/
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO




/* Look at the counters 
Look at Process Monitor
*/

/*
Cancel/ kill testlimit when you can

Check SQL Server log. Can you see what happened there?
 */


/* Stop the query in the other session. 

Grant 'Lock Pages in Memory' privilege to the SQL Server Service account
	In my case this is: NT SERVICE\MSSQL$DEV

Restart the Instance

*/



/* What does this say now? 
We should see locked page allocations*/
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO







/* Get the read query running in your second session, 
watch the counters until Total Memory grows up to hit the Target (or close) */



/* Now run testlimit64 again

# Leak and touch memory (simulate resource usage)
.\Testlimit64.exe -d -c 3000
*/
SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO



--Option: cancel the looping executing query and see how low the target will
--go with locked pages enabled and no activity in the SQL Server


--Restart the looping/executing query if you stopped it





/*  Cancel and redo with locked memory leaked...


# VirtualLock memory
.\Testlimit64.exe -v -c 3000

*/


SELECT 
    target_kb/1024. as target_MB,
	pages_kb/1024. as pages_MB /* committed memory */
FROM sys.dm_os_memory_nodes
WHERE memory_node_id = 0 /* I only have one numa node */ 
GO
SELECT 
	physical_memory_in_use_kb/1024. as physical_memory_in_use_MB,
	locked_page_allocations_kb/1024. as locked_page_allocations_MB,
    memory_utilization_percentage /* Specifies the percentage of committed memory that is in the working set.  */,
    process_physical_memory_low
FROM sys.dm_os_process_memory;
GO
select total_physical_memory_kb/1024. as total_os_physical_memory_MB,
    available_physical_memory_kb/1024. as available_os_physical_memory_MB,
    system_memory_state_desc
from sys.dm_os_sys_memory;
GO






/* OK, now how about this?

.\Testlimit64.exe -d -c 9000
*/

