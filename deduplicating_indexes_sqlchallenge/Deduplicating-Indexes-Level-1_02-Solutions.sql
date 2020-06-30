/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-deduplicate-indexes-level-1

SQLChallenge
Deduplicate Indexes: Level 1

SOLUTION FILE


*****************************************************************************/

RAISERROR (N'🛑 Did you mean to run the whole thing? 🛑', 20, 1) WITH LOG;
GO



/*****************************************************************************

💼 CHALLENGE RECAP: DEDUPLICATE INDEXES 💼

Your task is to de-duplicate the indexes on the dbo.FactInventory table
based on their definitions only -- there's no index "usage" stats to 
consider this time.

Consider the indexes created above, along with any indexes on the table that
are restored with the database.

For indexes you choose to drop:

* List the drop command for the index
* Note any risks that are associated with dropping the index

*****************************************************************************/




/*****************************************************************************
What if we don't know what indexes are on the table?
*****************************************************************************/


--Demo: scripting indexes from Object Explorer Details
--Relevant settings: Tools -> Options -> SQL Server Object Explorer -> Scripting
--Two that I find especially useful:
        --Script Data Compression Options
        --Script Partition Schemes

--Scripting out indexes on a table: you've got options!
--More complex scripts
    --https://littlekendra.com/2016/05/05/how-to-script-out-indexes-from-sql-server/
    --https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/releases
    --https://www.sqlskills.com/blogs/kimberly/category/sp_helpindex-rewrites/

--My script from the link above, modified to limit by table name
DECLARE @table_name sysname = 'FactInventory'
SELECT 
    DB_NAME() AS database_name,
    sc.name + N'.' + t.name AS table_name,
    (SELECT MAX(user_reads) 
        FROM (VALUES (last_user_seek), (last_user_scan), (last_user_lookup)) AS value(user_reads)) AS last_user_read,
    last_user_update,
    CASE si.index_id WHEN 0 THEN N'/* No create statement (Heap) */'
    ELSE 
        CASE is_primary_key WHEN 1 THEN
            N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(si.name) + N' PRIMARY KEY ' +
                CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED '
            ELSE N'CREATE ' + 
                CASE WHEN si.is_unique = 1 then N'UNIQUE ' ELSE N'' END +
                CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED ' +
                N'INDEX ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' '
        END +
        /* key def */ N'(' + key_definition + N')' +
        /* includes */ CASE WHEN include_definition IS NOT NULL THEN 
            N' INCLUDE (' + include_definition + N')'
            ELSE N''
        END +
        /* filters */ CASE WHEN filter_definition IS NOT NULL THEN 
            N' WHERE ' + filter_definition ELSE N''
        END +
        /* with clause - compression goes here */
        CASE WHEN row_compression_partition_list IS NOT NULL OR page_compression_partition_list IS NOT NULL 
            THEN N' WITH (' +
                CASE WHEN row_compression_partition_list IS NOT NULL THEN
                    N'DATA_COMPRESSION = ROW ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + row_compression_partition_list + N')' END
                ELSE N'' END +
                CASE WHEN row_compression_partition_list IS NOT NULL AND page_compression_partition_list IS NOT NULL THEN N', ' ELSE N'' END +
                CASE WHEN page_compression_partition_list IS NOT NULL THEN
                    N'DATA_COMPRESSION = PAGE ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + page_compression_partition_list + N')' END
                ELSE N'' END
            + N')'
            ELSE N''
        END +
        /* ON where? filegroup? partition scheme? */
        ' ON ' + CASE WHEN psc.name is null 
            THEN ISNULL(QUOTENAME(fg.name),N'')
            ELSE psc.name + N' (' + partitioning_column.column_name + N')' 
            END
        + N';'
    END AS index_create_statement,
    si.index_id,
    si.name AS index_name,
    partition_sums.reserved_in_row_GB,
    partition_sums.reserved_LOB_GB,
    partition_sums.row_count,
    stat.user_seeks,
    stat.user_scans,
    stat.user_lookups,
    user_updates AS queries_that_modified,
    partition_sums.partition_count,
    si.allow_page_locks,
    si.allow_row_locks,
    si.is_hypothetical,
    si.has_filter,
    si.fill_factor,
    si.is_unique,
    ISNULL(pf.name, '/* Not partitioned */') AS partition_function,
    ISNULL(psc.name, fg.name) AS partition_scheme_or_filegroup,
    t.create_date AS table_created_date,
    t.modify_date AS table_modify_date
FROM sys.indexes AS si
JOIN sys.tables AS t ON si.object_id=t.object_id
JOIN sys.schemas AS sc ON t.schema_id=sc.schema_id
LEFT JOIN sys.dm_db_index_usage_stats AS stat ON 
    stat.database_id = DB_ID() 
    and si.object_id=stat.object_id 
    and si.index_id=stat.index_id
LEFT JOIN sys.partition_schemes AS psc ON si.data_space_id=psc.data_space_id
LEFT JOIN sys.partition_functions AS pf ON psc.function_id=pf.function_id
LEFT JOIN sys.filegroups AS fg ON si.data_space_id=fg.data_space_id
/* Key list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name) +
        CASE ic.is_descending_key WHEN 1 then N' DESC' ELSE N'' END
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.key_ordinal > 0
    ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS keys ( key_definition )
/* Partitioning Ordinal */ OUTER APPLY (
    SELECT MAX(QUOTENAME(c.name)) AS column_name
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.partition_ordinal = 1) AS partitioning_column
/* Include list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name)
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.is_included_column = 1
    ORDER BY c.name FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS includes ( include_definition )
/* Partitions */ OUTER APPLY ( 
    SELECT 
        COUNT(*) AS partition_count,
        CAST(SUM(ps.in_row_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_in_row_GB,
        CAST(SUM(ps.lob_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_LOB_GB,
        SUM(ps.row_count) AS row_count
    FROM sys.partitions AS p
    JOIN sys.dm_db_partition_stats AS ps ON
        p.partition_id=ps.partition_id
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
    ) AS partition_sums
/* row compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM sys.partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 1
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS row_compression_clause ( row_compression_partition_list )
/* data compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM sys.partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 2
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS page_compression_clause ( page_compression_partition_list )
WHERE 
    si.type IN (0,1,2) /* heap, clustered, nonclustered */
    AND t.name=@table_name
ORDER BY table_name, si.index_id
    OPTION (RECOMPILE);
GO


/*****************************************************************************

Step 1: Group the indexes by leading key
    Beware believing the index names! They are often incorrect
*****************************************************************************/


/* Group 1: Leads on InventoryKey */

--Clustered PK is on InventoryKey

CREATE INDEX ix_FactInventory_InventoryKey
ON dbo.FactInventory(InventoryKey);
GO

CREATE INDEX ix_FactInventory_InventoryKey_INCLUDES
ON dbo.FactInventory(InventoryKey)
INCLUDE(MinDayInStock, MaxDayInStock);
GO


/* Group 2: Leads on DateKey */

CREATE INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES
ON dbo.FactInventory(DateKey)
INCLUDE(InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost);
GO

CREATE INDEX ix_FactInventory_DateKey_INCLUDES
ON dbo.FactInventory(DateKey, InventoryKey)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);
GO

CREATE INDEX ix_FactInventory_DateKey_LoadDate_UnitCost
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity);
GO

CREATE INDEX ix_FactInventory_DateKey_LoadDate
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging);
GO


/* Group 3: Indexes that lead on non-duplicate columns.

These are riskier to drop, even thought some of the columns overlap with other indexes.
 */

CREATE INDEX ix_FactInventory_LoadDate_DateKey_UnitCost
ON dbo.FactInventory(LoadDate, DateKey, UnitCost)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_UnitCost_LoadDate_DateKey
ON dbo.FactInventory(UnitCost, LoadDate, DateKey)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_CurrencyKey
ON dbo.FactInventory(CurrencyKey);
GO

/* Let's look at some sample data... */

SELECT TOP (1)
    si.name AS index_name,
    allocated_page_file_id,
    page_level, 
    page_type_desc,
    allocated_page_page_id,
    previous_page_page_id,
    next_page_page_id
FROM sys.dm_db_database_page_allocations(
    DB_ID(), 
    OBJECT_ID('dbo.FactInventory'), 
    NULL ,
    NULL, 
    'detailed') as pa
JOIN sys.indexes as si on pa.object_id=si.object_id and pa.index_id=si.index_id
WHERE 
    pa.is_allocated=1
    and pa.page_type = 2 /* Index pages, not talking about IAM_PAGEs today*/
    and si.name = 'ix_FactInventory_LoadDate_DateKey_UnitCost'
    AND pa.page_level = 0 /* Leaf */
UNION ALL
SELECT TOP (1)
    si.name AS index_name,
    allocated_page_file_id,
    page_level, 
    page_type_desc,
    allocated_page_page_id,
    previous_page_page_id,
    next_page_page_id
FROM sys.dm_db_database_page_allocations(
    DB_ID(), 
    OBJECT_ID('dbo.FactInventory'), 
    NULL ,
    NULL, 
    'detailed') as pa
JOIN sys.indexes as si on pa.object_id=si.object_id and pa.index_id=si.index_id
WHERE 
    pa.is_allocated=1
    and pa.page_type = 2 /* Index pages, not talking about IAM_PAGEs today*/
    and si.name = 'ix_FactInventory_DateKey_LoadDate'
    AND pa.page_level = 0 /* Leaf */;
GO

--ix_FactInventory_LoadDate_DateKey_UnitCost
/*         Database    File# Page# DumpStyle*/
DBCC PAGE ('ContosoRetailDW', 1, 354248, 3);
GO

--ix_FactInventory_DateKey_LoadDate
/*         Database    File# Page# DumpStyle*/
DBCC PAGE ('ContosoRetailDW', 1, 195248, 3);
GO




/*****************************************************************************

Step 2: Analyze each group

*****************************************************************************/


/* Group 1: Leads on InventoryKey */

--Clustered PK is on InventoryKey

CREATE INDEX ix_FactInventory_InventoryKey
ON dbo.FactInventory(InventoryKey);
GO

CREATE INDEX ix_FactInventory_InventoryKey_INCLUDES
ON dbo.FactInventory(InventoryKey)
INCLUDE(MinDayInStock, MaxDayInStock);
GO

/* 
Consideration 1: The Clustered PK and ix_FactInventory_InventoryKey look like pure duplicates
    But Are they?

    Risk if we drop ix_FactInventory_InventoryKey -
        This may be selected for some queries like COUNT(*) because it's the smallest index on the table
        If the index is hinted by name, queries may fail 

*/

SELECT COUNT(*)
FROM dbo.FactInventory WITH (INDEX (ix_FactInventory_InventoryKey_INCLUDESX));

SELECT COUNT(InventoryKey)
FROM dbo.FactInventory;

/*
Consideration 2: ix_FactInventory_InventoryKey is a subset of ix_FactInventory_InventoryKey_INCLUDES
    
    What about ix_FactInventory_InventoryKey_INCLUDES? It's SO SIMILAR to ix_FactInventory_InventoryKey!
        In a previous life, I would have dropped ix_FactInventory_InventoryKey and ix_FactInventory_InventoryKey_INCLUDES
        Now, I want to know: Were these created for a special reason?
        It's possible we don't need EITHER
        It's almost certain we can drop at least one
        But I want to check into why these are here due to being burned by dropping indexes like this.
*/


/* Group 2: Leads on DateKey */

--1
CREATE INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES
ON dbo.FactInventory(DateKey)
INCLUDE(InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost);
GO

--2
CREATE INDEX ix_FactInventory_DateKey_INCLUDES
ON dbo.FactInventory(DateKey, InventoryKey)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);
GO

--3
CREATE INDEX ix_FactInventory_DateKey_LoadDate_UnitCost
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging, OnHandQuantity, OnOrderQuantity);
GO

--4
CREATE INDEX ix_FactInventory_DateKey_LoadDate
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE(Aging);
GO



/* Approach 1: Combine 1, 3, and 4, leave 2 alone for now

We could potentially combine three of these indexes:
    Key on DateKey (one index)
    Keys on DateKey, LoadDate, UnitCost (two indexes)

This would use less space than all three indexes combined, and seeks would be preserved.
Risks: 
    Anything hinting those indexes by name could fail
    We might not need all these columns in the keys and includes - but we can't know without
        usage stats or finding the queries using the indexes

Discussion:
    what would be the risks of trying to combine ix_FactInventory_DateKey_INCLUDES into
    this new index?
*/


--New index
CREATE INDEX ix_DateKey_LoadDate_UnitCost_INCLUDES
ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
INCLUDE (InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity)
WITH (ONLINE=ON);
GO

--Drop indexes
DROP INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES ON dbo.FactInventory;
DROP INDEX ix_FactInventory_DateKey_LoadDate_UnitCost ON dbo.FactInventory;
DROP INDEX ix_FactInventory_DateKey_LoadDate ON dbo.FactInventory;
GO
----This results in two indexes
--Total columns: 17
--KEY (DateKey, LoadDate, UnitCost)
--INCLUDE (InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity);

--KEY (DateKey, InventoryKey)
--INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);



/* Approach 2 - JM's solution -  Combine 1 & 2, Combine 3 & 4 */

----1
--CREATE INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES
--ON dbo.FactInventory(DateKey)
--INCLUDE(InventoryKey, Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost);
--GO

----2
--CREATE INDEX ix_FactInventory_DateKey_INCLUDES
--ON dbo.FactInventory(DateKey, InventoryKey)
--INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);
--GO

--Drop the existing index with this name
DROP INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES ON dbo.FactInventory;
GO

--The OTHER index, the one we're keeping, SHOULD have that name
--Order of these two commands is important!
EXEC sp_rename 'dbo.FactInventory.ix_FactInventory_DateKey_INCLUDES', 
    'ix_FactInventory_DateKey_InventoryKey_INCLUDES';
GO



----3
--CREATE INDEX ix_FactInventory_DateKey_LoadDate_UnitCost
--ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
--INCLUDE(Aging, OnHandQuantity, OnOrderQuantity);
--GO

----4
--CREATE INDEX ix_FactInventory_DateKey_LoadDate
--ON dbo.FactInventory(DateKey, LoadDate, UnitCost)
--INCLUDE(Aging);
--GO

DROP INDEX ix_FactInventory_DateKey_LoadDate ON dbo.FactInventory;
GO
--Fix the name on this one
EXEC sp_rename 
    'dbo.FactInventory.ix_FactInventory_DateKey_LoadDate_UnitCost', 
    'ix_FactInventory_DateKey_LoadDate_UnitCost_INCLUDES';
GO



----We only have to do drops, zero creates
----This results in two indexes
--Total columns: 15 (vs 17 before)

--KEY(DateKey, InventoryKey)
--INCLUDE(Aging, OnHandQuantity, OnOrderQuantity, SafetyStockQuantity, UnitCost, LoadDate, DaysInStock);


--KEY(DateKey, LoadDate, UnitCost)
--INCLUDE(Aging, OnHandQuantity, OnOrderQuantity);





/* Group 3: Indexes that lead on non-duplicate columns.

Because these lead on unique columns, these aren't safe to drop without knowing more
    Index usage over a "long enoug" period of time (what does that mean?)
    What queries are using the indexes if they show activity
*/

CREATE INDEX ix_FactInventory_LoadDate_DateKey_UnitCost
ON dbo.FactInventory(LoadDate, DateKey, UnitCost)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_UnitCost_LoadDate_DateKey
ON dbo.FactInventory(UnitCost, LoadDate, DateKey)
INCLUDE(Aging);
GO

CREATE INDEX ix_FactInventory_CurrencyKey
ON dbo.FactInventory(CurrencyKey);
GO



/* 

💼 Takeaways 💼

Risks in dropping any index:
    1) Any queries hinting that index by name will FAIL
    2) Changing indexes (adding OR dropping) may cause deadlocks to happen (or not happen)
       ~ The same is true of changing data contents in a table, and changing TSQL ~

Key order is critical in identifying duplicates and combining indexes

Be mindful of nonclustered indexes with identical keys to the clustered index -- scanning the NC
    is often significantly faster

Index usage information is critical for:
    Should this index be combined with another, or dropped altogether?
    Estimating how many queries are likely to be impacted by dropping an index

Identifying the queries using an index is critical for:
    Knowing what will be impacted by combining or dropping an index

➡️ In Deduplicating Indexes Level 2 

    ➡️ We'll add in index usage stats
    ➡️ AND an exercise in finding the queries using indexes!
*/

/* My change scripts (Approach 2) */

--Drop the existing index with this name
DROP INDEX ix_FactInventory_DateKey_InventoryKey_INCLUDES ON dbo.FactInventory;
GO

--The OTHER index, the one we're keeping, SHOULD have that name
--Order of these two commands is important!
EXEC sp_rename 'dbo.FactInventory.ix_FactInventory_DateKey_INCLUDES', 
    'ix_FactInventory_DateKey_InventoryKey_INCLUDES';
GO


DROP INDEX ix_FactInventory_DateKey_LoadDate ON dbo.FactInventory;
GO
--Fix the name on this one
EXEC sp_rename 
    'dbo.FactInventory.ix_FactInventory_DateKey_LoadDate_UnitCost', 
    'ix_FactInventory_DateKey_LoadDate_UnitCost_INCLUDES';
GO


DECLARE @table_name sysname = 'FactInventory'
SELECT 
    DB_NAME() AS database_name,
    sc.name + N'.' + t.name AS table_name,
    (SELECT MAX(user_reads) 
        FROM (VALUES (last_user_seek), (last_user_scan), (last_user_lookup)) AS value(user_reads)) AS last_user_read,
    last_user_update,
    CASE si.index_id WHEN 0 THEN N'/* No create statement (Heap) */'
    ELSE 
        CASE is_primary_key WHEN 1 THEN
            N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(si.name) + N' PRIMARY KEY ' +
                CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED '
            ELSE N'CREATE ' + 
                CASE WHEN si.is_unique = 1 then N'UNIQUE ' ELSE N'' END +
                CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED ' +
                N'INDEX ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' '
        END +
        /* key def */ N'(' + key_definition + N')' +
        /* includes */ CASE WHEN include_definition IS NOT NULL THEN 
            N' INCLUDE (' + include_definition + N')'
            ELSE N''
        END +
        /* filters */ CASE WHEN filter_definition IS NOT NULL THEN 
            N' WHERE ' + filter_definition ELSE N''
        END +
        /* with clause - compression goes here */
        CASE WHEN row_compression_partition_list IS NOT NULL OR page_compression_partition_list IS NOT NULL 
            THEN N' WITH (' +
                CASE WHEN row_compression_partition_list IS NOT NULL THEN
                    N'DATA_COMPRESSION = ROW ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + row_compression_partition_list + N')' END
                ELSE N'' END +
                CASE WHEN row_compression_partition_list IS NOT NULL AND page_compression_partition_list IS NOT NULL THEN N', ' ELSE N'' END +
                CASE WHEN page_compression_partition_list IS NOT NULL THEN
                    N'DATA_COMPRESSION = PAGE ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + page_compression_partition_list + N')' END
                ELSE N'' END
            + N')'
            ELSE N''
        END +
        /* ON where? filegroup? partition scheme? */
        ' ON ' + CASE WHEN psc.name is null 
            THEN ISNULL(QUOTENAME(fg.name),N'')
            ELSE psc.name + N' (' + partitioning_column.column_name + N')' 
            END
        + N';'
    END AS index_create_statement,
    si.index_id,
    si.name AS index_name,
    partition_sums.reserved_in_row_GB,
    partition_sums.reserved_LOB_GB,
    partition_sums.row_count,
    stat.user_seeks,
    stat.user_scans,
    stat.user_lookups,
    user_updates AS queries_that_modified,
    partition_sums.partition_count,
    si.allow_page_locks,
    si.allow_row_locks,
    si.is_hypothetical,
    si.has_filter,
    si.fill_factor,
    si.is_unique,
    ISNULL(pf.name, '/* Not partitioned */') AS partition_function,
    ISNULL(psc.name, fg.name) AS partition_scheme_or_filegroup,
    t.create_date AS table_created_date,
    t.modify_date AS table_modify_date
FROM sys.indexes AS si
JOIN sys.tables AS t ON si.object_id=t.object_id
JOIN sys.schemas AS sc ON t.schema_id=sc.schema_id
LEFT JOIN sys.dm_db_index_usage_stats AS stat ON 
    stat.database_id = DB_ID() 
    and si.object_id=stat.object_id 
    and si.index_id=stat.index_id
LEFT JOIN sys.partition_schemes AS psc ON si.data_space_id=psc.data_space_id
LEFT JOIN sys.partition_functions AS pf ON psc.function_id=pf.function_id
LEFT JOIN sys.filegroups AS fg ON si.data_space_id=fg.data_space_id
/* Key list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name) +
        CASE ic.is_descending_key WHEN 1 then N' DESC' ELSE N'' END
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.key_ordinal > 0
    ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS keys ( key_definition )
/* Partitioning Ordinal */ OUTER APPLY (
    SELECT MAX(QUOTENAME(c.name)) AS column_name
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.partition_ordinal = 1) AS partitioning_column
/* Include list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name)
    FROM sys.index_columns AS ic 
    JOIN sys.columns AS c ON 
        ic.column_id=c.column_id  
        and ic.object_id=c.object_id
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.is_included_column = 1
    ORDER BY c.name FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS includes ( include_definition )
/* Partitions */ OUTER APPLY ( 
    SELECT 
        COUNT(*) AS partition_count,
        CAST(SUM(ps.in_row_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_in_row_GB,
        CAST(SUM(ps.lob_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_LOB_GB,
        SUM(ps.row_count) AS row_count
    FROM sys.partitions AS p
    JOIN sys.dm_db_partition_stats AS ps ON
        p.partition_id=ps.partition_id
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
    ) AS partition_sums
/* row compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM sys.partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 1
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS row_compression_clause ( row_compression_partition_list )
/* data compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM sys.partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 2
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS page_compression_clause ( page_compression_partition_list )
WHERE 
    si.type IN (0,1,2) /* heap, clustered, nonclustered */
    AND t.name=@table_name
ORDER BY table_name, si.index_id
    OPTION (RECOMPILE);
GO


/*  Indexes we'll further untangle when we have usage info and related queries to mine...


ALTER TABLE [dbo].[FactInventory] ADD CONSTRAINT [PK_FactInventory_InventoryKey] PRIMARY KEY CLUSTERED ([InventoryKey]) WITH (DATA_COMPRESSION = PAGE ) ON [PRIMARY];
CREATE NONCLUSTERED INDEX [ix_FactInventory_InventoryKey] ON [dbo].[FactInventory] ([InventoryKey]) ON [PRIMARY];
CREATE NONCLUSTERED INDEX [ix_FactInventory_InventoryKey_INCLUDES] ON [dbo].[FactInventory] ([InventoryKey]) INCLUDE ([MaxDayInStock], [MinDayInStock]) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [ix_FactInventory_DateKey_InventoryKey_INCLUDES] ON [dbo].[FactInventory] ([DateKey], [InventoryKey]) INCLUDE ([Aging], [DaysInStock], [LoadDate], [OnHandQuantity], [OnOrderQuantity], [SafetyStockQuantity], [UnitCost]) ON [PRIMARY];
CREATE NONCLUSTERED INDEX [ix_FactInventory_DateKey_LoadDate_UnitCost_INCLUDES] ON [dbo].[FactInventory] ([DateKey], [LoadDate], [UnitCost]) INCLUDE ([Aging], [OnHandQuantity], [OnOrderQuantity]) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [ix_FactInventory_LoadDate_DateKey_UnitCost] ON [dbo].[FactInventory] ([LoadDate], [DateKey], [UnitCost]) INCLUDE ([Aging]) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [ix_FactInventory_UnitCost_LoadDate_DateKey] ON [dbo].[FactInventory] ([UnitCost], [LoadDate], [DateKey]) INCLUDE ([Aging]) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [ix_FactInventory_CurrencyKey] ON [dbo].[FactInventory] ([CurrencyKey]) ON [PRIMARY];

*/