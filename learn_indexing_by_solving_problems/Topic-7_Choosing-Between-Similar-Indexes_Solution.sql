/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




/*******************************************************************/
/*                        SOLUTION                                 */
/*                     Baby Boomers                                */
/*******************************************************************/


/* Create both indexes, if you have not already */
IF (SELECT COUNT(*) from sys.indexes where name='A') = 0
CREATE INDEX [A]
	on agg.FirstNameByYear (Gender)
	INCLUDE ( ReportYear, FirstNameId, NameCount );
GO


IF (SELECT COUNT(*) from sys.indexes where name='B') = 0
CREATE INDEX [B]
	on agg.FirstNameByYear (Gender, ReportYear)
	INCLUDE ( NameCount );
GO




/* Test both indexes */
SET STATISTICS IO, TIME ON;
GO
SELECT TOP 10
	ReportYear,
	SUM(NameCount) as TotalBirthsReported
FROM agg.FirstNameByYear WITH (INDEX ([A]))
WHERE
	ReportYear <= 2000
	and Gender='F'
GROUP BY ReportYear
ORDER BY SUM(NameCount) DESC;
GO


SELECT TOP 10
	ReportYear,
	SUM(NameCount) as TotalBirthsReported
FROM agg.FirstNameByYear WITH (INDEX ([B]))
WHERE
	ReportYear <= 2000
	and Gender='F'
GROUP BY ReportYear
ORDER BY SUM(NameCount) DESC;
GO
SET STATISTICS IO, TIME OFF;
GO





/* The indexes perform exactly the same way.
Why?
Well, the indexes are secretly identical.
We can prove it. */


/* First, let's confirm the logical definitions. */
SELECT
	si.name as index_name,
    si.index_id,
	ic.key_ordinal,
	ic.is_included_column,
	c.name as column_name,
	t.name as data_type_name,
	c.is_identity,
	ic.is_descending_key
FROM sys.objects AS so
JOIN sys.schemas AS sc on so.schema_id=sc.schema_id
JOIN sys.indexes AS si on so.object_id=si.object_id
JOIN sys.index_columns AS ic on si.object_id=ic.object_id
	and si.index_id=ic.index_id
JOIN sys.columns AS c on ic.object_id=c.object_id
	and ic.column_id=c.column_id
JOIN sys.types as t on c.system_type_id=t.system_type_id
WHERE sc.name='agg'
    and so.name='FirstNameByYear'
ORDER BY index_name, key_ordinal, is_included_column DESC;
GO




/* Those are the logical definitions.
They've been adjusted to account for the clustered index on the table,
which is on: ReportYear ASC, FirstNameId ASC, Gender ASC */





/* OK, let's see the *actual* definitions */
/* What's really in agg.FirstNameByYear.[A] ? */
/* Note: this is an expensive query for large tables and
sys.dm_db_database_page_allocations is officially an undocumented DMV */
/* Pick an index page */
SELECT TOP 10
    si.index_id,
    allocated_page_page_id,
	extent_file_id,
    page_type_desc,
    next_page_page_id,
    previous_page_page_id
FROM sys.dm_db_database_page_allocations
    (DB_ID(),
    OBJECT_ID('agg.FirstNameByYear'),
    NULL,
    NULL,
    'DETAILED') AS alloc
JOIN sys.indexes as si on alloc.object_id=si.object_id and alloc.index_id=si.index_id
WHERE
    si.name='A'
    and is_allocated = 1
    and page_level=0 /* Leaf only */
    and page_type_desc = 'INDEX_PAGE'
ORDER BY allocated_page_page_id;
GO





/* Now let's look at the page. */
/* To get results back to this window from DBCC PAGE, we need to turn on TF 3604
https://support.microsoft.com/en-us/kb/83065
*/
DBCC TRACEON(3604);
GO
       /* database_name, filenum, pagenum, dumpstyle*/
DBCC PAGE (BabbyNames, 1, 70264, 3 )
GO

/* List out the row headers of the actual index:
    Gender(key), ReportYear(key), FirstNameId(key), INCLUDES: NameCount)

This index was defined logically as:
    Gender(key) INCLUDES: ReportYear, FirstNameId, NameCount

The clustered index keys are:
    ReportYear, FirstNameId, Gender

What happened:
    * SQL Server promoted ReportYear and FirstNameId into the key behind the scenes.
    * It did NOT store Gender twice.
*/







/* What's really in agg.FirstNameByYear.[B] ? */
/* Note: this is an expensive query for large tables and sys.dm_db_database_page_allocations is officially an undocumented DMV */
/* Pick an index page */
SELECT TOP 10
    si.index_id,
    allocated_page_page_id,
	extent_file_id,
    page_type_desc,
    next_page_page_id,
    previous_page_page_id
FROM sys.dm_db_database_page_allocations
    (DB_ID(),
    OBJECT_ID('agg.FirstNameByYear'),
    NULL,
    NULL,
    'DETAILED') AS alloc
JOIN sys.indexes as si on alloc.object_id=si.object_id and alloc.index_id=si.index_id
WHERE
    si.name='B'
    and is_allocated = 1
    and page_level=0 /* Leaf only */
    and page_type_desc = 'INDEX_PAGE'
ORDER BY allocated_page_page_id;
GO

/* plug in the page number */
DBCC PAGE (BabbyNames, 1, 83104, 3 )
GO

/* List out the row headers:
    Gender(key), ReportYear(key), FirstNameId(key), INCLUDES: NameCount

This index was defined logically as:
    Gender (key), ReportYear(key), INCLUDES: NameCount

The clustered index keys are:
    ReportYear, FirstNameId, Gender

What happened:
    SQL Server promoted added FirstNameId and put it into the key
    It did NOT store Gender or ReportYear twice


Here's why:

SQL Server must be able to:
    Uniquely get to every row of a nonclustered index using the key
    Identify the related row in the clustered index for every row in a nonclustered index

If a clustered index isn't unique, it makes duplicate rows unique behind the scenes with a "uniquifier".
If a nonclustered index doesn't have a unique key, it adds the clustered index key to end of the nonclustered index key (if it isn't there yet).
If a nonclustered index key IS unique, the clustering key will be added to the included columns.



Arguably, the second index is better, just because
its performance will be better if the clustered index is changed.
*/



/* Could we have easily identified that these are duplicates? */


/* There's a couple free procedures and scripts out there....
Index diagnosis procedures:
    Kimberly Tripp's sp_helpindex
    Brent Ozar Unlimited's sp_BlitzIndex

For this specific issue of finding physicaly identical indexes,
Jason Strate has a great script (no procedure required) here:
    http://www.jasonstrate.com/2013/03/thats-actually-a-duplicate-index/
    Scroll down to listing 8
*/


DROP INDEX IF EXISTS
    [B] on agg.FirstNameByYear,
    [A] on agg.FirstNameByYear;
GO
