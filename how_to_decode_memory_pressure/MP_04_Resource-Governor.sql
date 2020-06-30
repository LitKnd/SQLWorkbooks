/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decode-memory-pressure/

*****************************************************************************/



/****************************************************
Part 1: Hekaton and Resource Governor
Enable Memory Optimized Tables
****************************************************/

ALTER DATABASE BabbyNames ADD FILEGROUP MemoryOptimizedData CONTAINS MEMORY_OPTIMIZED_DATA;
GO

ALTER DATABASE BabbyNames 
    ADD FILE( NAME = 'MemoryOptimizedData' , FILENAME = 'S:\MSSQL\Data\BabbyNames_MemoryOptimizedData') 
    TO FILEGROUP MemoryOptimizedData;  
GO


/****************************************************
Configure Resource Governor
This is an Enterprise Edition feature
Microsoft recommends you use resource pools with In-Memory OLTP:
https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/bind-a-database-with-memory-optimized-tables-to-a-resource-pool
****************************************************/

USE master;
GO

IF 0 = (
    SELECT COUNT(*)
    FROM sys.resource_governor_resource_pools
    WHERE name = 'BabbyNames_Pool'
)
BEGIN 
    EXEC ('
        CREATE RESOURCE POOL BabbyNames_Pool
          WITH ( MIN_MEMORY_PERCENT = 1, MAX_MEMORY_PERCENT = 50 );  

        ALTER RESOURCE GOVERNOR RECONFIGURE;  

        EXEC sp_xtp_bind_db_resource_pool ''BabbyNames'', ''BabbyNames_Pool'' 
        '
    );
    /* This is required to make the binding take effect */
    EXEC ('

        ALTER DATABASE BabbyNames
            SET OFFLINE
            WITH ROLLBACK IMMEDIATE;

        ALTER DATABASE BabbyNames
            SET ONLINE;

    ')
END
GO

SELECT 
    pool_id,  
    name, 
    min_memory_percent,  
    max_memory_percent,
    used_memory_kb/1024. AS used_memory_MB,
    max_memory_kb/1024. AS max_memory_MB,
    target_memory_kb/1024. AS target_memory_MB  
FROM sys.dm_resource_governor_resource_pools;
GO

SELECT 
    physical_memory_kb/1024. as physical_memory_MB,
    committed_kb/1024. as committed_MB,
    committed_target_kb/1024. as committed_target_MB
from sys.dm_os_sys_info;
GO


/****************************************************
Create and populate some tables
****************************************************/

USE BabbyNames
GO

CREATE TABLE ref.FirstNameXTP(
	FirstNameId int IDENTITY(1,1) NOT NULL,
	FirstName varchar(255) NOT NULL,
	NameLength  AS (len(FirstName)),
	FirstReportYear int NOT NULL,
	LastReportYear int NOT NULL,
	TotalNameCount bigint NOT NULL,
    CONSTRAINT pk_ref_FirstNameXTP PRIMARY KEY NONCLUSTERED (FirstNameId),
    CONSTRAINT uq_ref_FirstNameXTP_FirstName UNIQUE NONCLUSTERED (FirstName)
) 
WITH (MEMORY_OPTIMIZED = ON);
GO


SET IDENTITY_INSERT ref.FirstNameXTP ON;  
GO

INSERT ref.FirstNameXTP ([FirstNameId], [FirstName], [FirstReportYear], [LastReportYear], [TotalNameCount])
SELECT [FirstNameId], [FirstName], [FirstReportYear], [LastReportYear], [TotalNameCount]
FROM ref.FirstName;
GO

SET IDENTITY_INSERT ref.FirstNameXTP OFF;  
GO


CREATE TABLE dbo.FirstNameByBirthDate_2002_2017XTP (
	FakeBirthDateStamp datetime2(0) NULL,
	FirstNameByBirthDateId bigint IDENTITY(1,1) NOT NULL,
	BirthYear  AS (datepart(year,FakeBirthDateStamp)) PERSISTED NOT NULL,
	StateCode char(2) NOT NULL,
	FirstNameId int NOT NULL,
	Gender char(1) NOT NULL,
    CONSTRAINT pk_dbo_FirstNameByBirthDate_2002_2017XTP PRIMARY KEY NONCLUSTERED (FirstNameByBirthDateId)
) WITH (MEMORY_OPTIMIZED = ON);
GO


SET IDENTITY_INSERT dbo.FirstNameByBirthDate_2002_2017XTP ON;  
GO

--Let's add 10 million rows (of the 51221030 rows)
INSERT dbo.FirstNameByBirthDate_2002_2017XTP ([FakeBirthDateStamp], [FirstNameByBirthDateId], [StateCode], [FirstNameId], [Gender])
SELECT [FakeBirthDateStamp], [FirstNameByBirthDateId], [StateCode], [FirstNameId], [Gender]
FROM dbo.FirstNameByBirthDate_2002_2017
WHERE FirstNameByBirthDateId <= 10000000;
GO

--Can we add add 10 million more rows (of the 51221030 rows)
INSERT dbo.FirstNameByBirthDate_2002_2017XTP ([FakeBirthDateStamp], [FirstNameByBirthDateId], [StateCode], [FirstNameId], [Gender])
SELECT [FakeBirthDateStamp], [FirstNameByBirthDateId], [StateCode], [FirstNameId], [Gender]
FROM dbo.FirstNameByBirthDate_2002_2017
WHERE FirstNameByBirthDateId > 10000000 and FirstNameByBirthDateId <= 20000000;
GO


/* Foreign key time! */
ALTER TABLE dbo.FirstNameByBirthDate_2002_2017XTP  
    WITH CHECK 
    ADD CONSTRAINT fk_FirstNameByBirthDate_2002_2017XTP_FirstNameId
    FOREIGN KEY(FirstNameId)
REFERENCES ref.FirstNameXTP (FirstNameId);
GO


/* How much memory are we using for the XTP tables? */
SELECT 
    pool_id,  
    name, 
    min_memory_percent,  
    max_memory_percent,
    used_memory_kb/1024. AS used_memory_MB,
    max_memory_kb/1024. AS max_memory_MB,
    target_memory_kb/1024. AS target_memory_MB  
FROM sys.dm_resource_governor_resource_pools;
GO


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


/* What does target and total look like in perf counters? */

/* What does buffer pool usage look like in sys.dm_os_buffer_descriptors ? */
--This query modified slightly from
--https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-buffer-descriptors-transact-sql
SELECT 
    name ,
    index_id, 
    CAST(COUNT(*) * 8./1024. AS NUMERIC(10,1)) AS buffer_pool_mb  
FROM sys.dm_os_buffer_descriptors AS bd   
    INNER JOIN   
    (  
        SELECT object_name(object_id) AS name   
            ,index_id ,allocation_unit_id  
        FROM sys.allocation_units AS au  
            INNER JOIN sys.partitions AS p   
                ON au.container_id = p.hobt_id   
                    AND (au.type = 1 OR au.type = 3)  
        UNION ALL  
        SELECT object_name(object_id) AS name     
            ,index_id, allocation_unit_id  
        FROM sys.allocation_units AS au  
            INNER JOIN sys.partitions AS p   
                ON au.container_id = p.partition_id   
                    AND au.type = 2  
    ) AS obj   
        ON bd.allocation_unit_id = obj.allocation_unit_id  
WHERE database_id = DB_ID()  
GROUP BY name, index_id 
HAVING COUNT(*) > 10
ORDER BY buffer_pool_mb DESC;
GO

DROP TABLE dbo.FirstNameByBirthDate_2002_2017XTP;
GO

DROP TABLE ref.FirstNameXTP;
GO


IF 1 = (
    SELECT COUNT(*)
    FROM sys.resource_governor_resource_pools
    WHERE name = 'BabbyNames_Pool'
)
BEGIN 
    EXEC ('
        EXEC sp_xtp_unbind_db_resource_pool ''BabbyNames''; 

        DROP RESOURCE POOL BabbyNames_Pool;
        '
    );
    /* This is required to make the binding take effect */
    EXEC ('
        use master;

        ALTER DATABASE BabbyNames
            SET OFFLINE
            WITH ROLLBACK IMMEDIATE;

        ALTER DATABASE BabbyNames
            SET ONLINE;

        ALTER RESOURCE GOVERNOR RECONFIGURE; 
    ')
END
GO
