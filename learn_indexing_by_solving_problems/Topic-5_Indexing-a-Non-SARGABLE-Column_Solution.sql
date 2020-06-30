/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/*******************************************************************/
/*                        Solution                                 */
/*******************************************************************/





/* What were your ideas for the index?                */
/* Key:                     Include:                  */
/* Any filters or other ideas?                        */

















/*  The red herring: full text indexing.               */
/* Full text indexing helps with finding whole words,
    or words leading with a prefix.                    */
/* It does not help with leading wildcards.
    So it will NOT help with '%nom%'                  */






/* Answer 1: The Giant Index Burrito                   */

/* We can try this.... */
CREATE INDEX ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017
	(InevitableLOBColumn)
	INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, FakeSystemCreateDateTime)
GO





/* Nope. Not gonna happen.

Msg 1919, Level 16, State 1, Line 99
Column 'InevitableLOBColumn' in table 'dbo.FirstNameByBirthDate_2000_2017' is of a
type that is invalid for use as a key column in an index.
*/













/* Answer 2: The (Modified) Giant Index Burrito                             */
/* An included column can be used for a predicate, it just requires a scan. */
/* But that's likely to be faster than scanning the whole table.            */
/* Right?

Right? 

Warning: this takes ~2.5 minutes to create
*/

CREATE INDEX ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017
	(FakeSystemCreateDateTime)
	INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, InevitableLOBColumn)
GO


/* FakeSystemCreateDateTime is in the key just because something has to be,
and it's in the ORDER BY of the query.                                       */

/* While the index is creating, test these two queries from another session
and talk about locks during non-clustered index create:

SELECT TOP 100 * from dbo.FirstNameByBirthDate_2000_2017;

SELECT TOP 100 * from dbo.FirstNameByBirthDate_2000_2017 with (updlock);

*/


/* How big is this index? */
SELECT
	si.index_id,
	si.name as index_name,
	si.fill_factor,
	si.is_primary_key,
	ps.reserved_page_count * 8./1024. as reserved_MB,
	ps.lob_reserved_page_count * 8./1024. lob_reserved_MB,
	ps.row_count
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes si on ps.object_id=si.object_id and ps.index_id=si.index_id
JOIN sys.objects so on si.object_id=so.object_id
JOIN sys.schemas sc on so.schema_id=sc.schema_id
WHERE sc.name='dbo' and
    so.name='FirstNameByBirthDate_2000_2017';
GO






/* Measure performance */
SET STATISTICS IO, TIME ON;
GO
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	InevitableLOBColumn
FROM dbo.FirstNameByBirthDate_2000_2017
WHERE
	InevitableLOBColumn like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO
SET STATISTICS IO, TIME OFF;
GO




/* Look at the plan */
/* Is it using the index? */
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	InevitableLOBColumn
FROM dbo.FirstNameByBirthDate_2000_2017
WHERE
	InevitableLOBColumn like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO









/* Answer 3: More of a taco sized index.                                             */
/* We can't sort the index by InevitableLobColumn, because LOBs can't be in the key. */
/* But we can create an index on for rows where it is not null                       */
CREATE INDEX ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017
	(FakeSystemCreateDateTime)
	INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, InevitableLOBColumn)
WHERE (InevitableLOBColumn IS NOT NULL)
WITH (DROP_EXISTING = ON);
GO






/* How big is this index? */
SELECT
	si.index_id,
	si.name as index_name,
	si.fill_factor,
	si.is_primary_key,
	ps.reserved_page_count * 8./1024. as reserved_MB,
	ps.lob_reserved_page_count * 8./1024. lob_reserved_MB,
	ps.row_count
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes si on ps.object_id=si.object_id and ps.index_id=si.index_id
JOIN sys.objects so on si.object_id=so.object_id
JOIN sys.schemas sc on so.schema_id=sc.schema_id
WHERE sc.name='dbo' and
    so.name='FirstNameByBirthDate_2000_2017';
GO

/*
Let's think about read and write operations.
When will SQL Server have to modify this index? */




/* Do I have to add WHERE InevitableLOBColumn IS NOT NULL to the query to match
to get it to use the index? */
/* Measure performance */
SET STATISTICS IO, TIME ON;
GO
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	InevitableLOBColumn
FROM dbo.FirstNameByBirthDate_2000_2017
WHERE
	InevitableLOBColumn like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO
SET STATISTICS IO, TIME OFF;
GO


/*
Improvements:
* Single threaded
* MUCH lighter on insert, update, delete
* Lower impact on memory when used
* Less locking in default implementation of read committed
*/


/* Look at the actual plan */
/* Is it using the index? */
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	InevitableLOBColumn
FROM dbo.FirstNameByBirthDate_2000_2017
WHERE
	InevitableLOBColumn like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO

/* Stop and admire:
    The filter on the index is WHERE (InevitableLOBColumn IS NOT NULL)
    The optimizer matched the index to this query even though
        the query does NOT have the IS NOT NULL text!
*/






/* Answer 3: A more compact taco?                                       */

CREATE INDEX ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017
	(FakeSystemCreateDateTime)
	INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, InevitableLOBColumn)
WHERE (InevitableLOBColumn IS NOT NULL)
WITH (DATA_COMPRESSION=PAGE, DROP_EXISTING=ON);
GO

--ALTER INDEX ix_InevitableLOBColumn ON dbo.FirstNameByBirthDate_2000_2017
--REBUILD WITH (DATA_COMPRESSION=PAGE);
--GO


/* How big is the index now? */
SELECT
	si.index_id,
	si.name as index_name,
	si.fill_factor,
	si.is_primary_key,
	ps.reserved_page_count * 8./1024. as reserved_MB,
	ps.lob_reserved_page_count * 8./1024. lob_reserved_MB,
	ps.row_count
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes si on ps.object_id=si.object_id and ps.index_id=si.index_id
JOIN sys.objects so on si.object_id=so.object_id
JOIN sys.schemas sc on so.schema_id=sc.schema_id
WHERE sc.name='dbo' and
    so.name='FirstNameByBirthDate_2000_2017';
GO
/*
It's a TEENY bit smaller for the non-LOB portion.
Data compression doesn't work on LOB pages.
Plus, it'd just have to decompress all the pages to search for the text, anyway
*/



/* 
2016 Feature: COMPRESS function in TSQL.
This always outputs VARBINARY(MAX), so it would have to be stored in a different column
	And like other LOB columns, it can be an included column but not a key
Compresses data using the GZIP algorithm, can compress LOB types

https://msdn.microsoft.com/en-US/library/mt622775.aspx

If you HAVE to scan a LOB column (can't filter on other values), then compressing it in
the column in the base table:
	* Gives you fewer pages to scan
	* May require more CPU as a tradeoff, depending on how you write your queries

Note: Compressed columns can't be in index keys, either-- they're LOB columns. 
*/

--Create a copy of the table
--For speed, we're just going to copy the rows where InevitableLOBColumn IS NOT NULL
SELECT 
    FirstNameByBirthDateId, FakeBirthDateStamp, FirstNameId, FirstName, Gender, 
    COMPRESS(InevitableLOBColumn) AS InevitableLOBColumnCompressed, 
    FakeCreatedByUser, FakeSystemCreateDateTime
INTO dbo.FirstNameByBirthDate_2000_2017_compressed
FROM dbo.FirstNameByBirthDate_2000_2017
WHERE InevitableLOBColumn IS NOT NULL
GO

--Add the clustered index
ALTER TABLE dbo.FirstNameByBirthDate_2000_2017_compressed 
ADD  CONSTRAINT pk_FirstNameByBirthDate_2011_2010_FirstNameByBirthDateId_compressed PRIMARY KEY CLUSTERED 
(FirstNameByBirthDateId ASC )
WITH (SORT_IN_TEMPDB = ON) ON [PRIMARY]
GO

--How much space do the LOB columns take up now?
SELECT
	si.index_id,
	si.name as index_name,
	si.fill_factor,
	si.is_primary_key,
	ps.reserved_page_count * 8./1024. as reserved_MB,
	ps.lob_reserved_page_count * 8./1024. lob_reserved_MB,
	ps.row_count
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes si on ps.object_id=si.object_id and ps.index_id=si.index_id
JOIN sys.objects so on si.object_id=so.object_id
JOIN sys.schemas sc on so.schema_id=sc.schema_id
WHERE sc.name='dbo' and
    so.name='FirstNameByBirthDate_2000_2017_compressed';
GO

--Query against the base table
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX))
FROM dbo.FirstNameByBirthDate_2000_2017_compressed
WHERE
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX)) like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO

--We can create a filtered index with it...
CREATE INDEX ix_filtertest 
on dbo.FirstNameByBirthDate_2000_2017_compressed (FakeSystemCreateDateTime)
    INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, InevitableLOBColumnCompressed)
WHERE (InevitableLOBColumnCompressed IS NOT NULL);
GO

--But it doesn't think it's safe to use the index...
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX))
FROM dbo.FirstNameByBirthDate_2000_2017_compressed WITH (INDEX (ix_filtertest))
WHERE
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX)) like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO

--Add "InevitableLOBColumnCompressed IS NOT NULL" to the query...
SELECT
	FakeBirthDateStamp,
	FirstNameId,
	FirstName,
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX))
FROM dbo.FirstNameByBirthDate_2000_2017_compressed WITH (INDEX (ix_filtertest))
WHERE
    InevitableLOBColumnCompressed IS NOT NULL AND
	CAST(DECOMPRESS(InevitableLOBColumnCompressed) AS NVARCHAR(MAX)) like '%nom%'
ORDER BY FakeSystemCreateDateTime DESC
GO





/* Could we do this? It's missing the point, because people are going to search for different terms, but
you might wonder if it's possible.... */
CREATE INDEX ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017
	(FakeSystemCreateDateTime)
	INCLUDE (FakeBirthDateStamp, FirstNameId, FirstName, InevitableLOBColumn)
WHERE (InevitableLOBColumn LIKE '%nom%');
GO










/**************************************************************
                        CLEANUP
***************************************************************/


DROP INDEX IF EXISTS ix_InevitableLOBColumn
	ON dbo.FirstNameByBirthDate_2000_2017;
GO


DROP TABLE IF EXISTS dbo.FirstNameByBirthDate_2000_2017_compressed;
GO


/****************************************
More filtered index rules:
No functions
No LIKE
No filtered indexes on computed columns
No "or" (but you can do "IN" and it'll work for OR queries)
******************************************/
