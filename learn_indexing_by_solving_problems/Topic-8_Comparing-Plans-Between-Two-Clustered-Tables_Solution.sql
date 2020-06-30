/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




/*
Make sure you've created these two indexes from the problem script...
*/
CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Natural_ReportYear_Gender_NameCount
ON agg.FirstNameByYearWide_Natural (ReportYear, Gender, NameCount DESC)
GO

CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount
ON agg.FirstNameByYearWide_Surrogate (ReportYear, Gender, NameCount DESC)
GO


/* Problem: What are we missing with our setup and testing of agg.FirstNameByYearWide_Surrogate?
What could go wrong? */





/*******************************************************************/
/*                        ANSWER                                   */
/*          Changing the Clustering Key on an existing table       */
/*******************************************************************/


/* At minimum, we should enforce uniqueness on ReportYear, Gender, FirstNameId
    with some kind of index or constraint (which is implemented as an index).
    We were enforcing that rule in the old table, but we aren't in the new one.
*/

/* Considerations:
Primary Key Constraint (PK)
    Enforced using an index (clustered or nonclustered)
    NO INCLUDED COLUMNS
    Tables in transactional replication are required to have a PK
Unique Constraint
    Enforced using an index behind the scenes
    You can create foreign keys against a unique constraint
    NO INCLUDED COLUMNS
Unique Index
    You can create foreign keys against a unique index
    Included columns ARE allowed

*/

/* Let's start by enforcing uniqueness on these columns. */
ALTER TABLE agg.FirstNameByYearWide_Surrogate
    ADD CONSTRAINT pk_FirstNameByYearWide_Surrogate_ReportYear_Gender_FirstNameId
    PRIMARY KEY NONCLUSTERED (ReportYear, Gender, FirstNameId);
GO

/*
We also need to test our query to make sure it's still fast.
*/




/* Baseline the queries */
SET STATISTICS IO, TIME ON;
GO
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
/* New table, surrogate key */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Surrogate AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6,
    ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12,
    ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18,
    ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Surrogate AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
SET STATISTICS IO, TIME OFF;
GO





/* Compare estimated plans */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
/* New table, surrogate key */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Surrogate AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Surrogate AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO


/*
The old query uses our nonclustered index in part.
Why is it doing a clustered index scan as well?

But pointed at the new table, it's not using our nonclustered indexes on the _Surrogate table at all!
*/



/* Go into the Sort operator's ORDER BY properties to see what it's doing:

    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].ReportYear Ascending,
    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].Gender Ascending,
    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].NameCount Descending
*/

/* OK, our index does that:
    CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount
    ON agg.FirstNameByYearWide_Surrogate (ReportYear, Gender, NameCount DESC)
    GO
*/

/* Now look at the OUTPUT list on the sort operator:

    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].ReportYear,
    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].Gender,
    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].FirstNameId,
    [BabbyNames].[agg].[FirstNameByYearWide_Surrogate].NameCount

*/

/* Aha! We don't have FirstNameId in our index.
FirstNameId was implicitly being added to the old index because it was part of the clustering key!
FirstNameId is one of the join columns in the query.
*/


CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount
ON agg.FirstNameByYearWide_Surrogate (ReportYear, Gender, NameCount DESC, FirstNameId)
WITH (DROP_EXISTING=ON)
GO

EXEC sp_rename
    'agg.FirstNameByYearWide_Surrogate.ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount',
    'ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount_FirstNameId';
GO



/* Compare estimated plans */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
/* New table, surrogate key */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Surrogate AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Surrogate AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO



/* Baseline them */
SET STATISTICS IO, TIME ON;
GO
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Natural AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Natural AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
/* New table, surrogate key */
with NameRank AS (
    SELECT
        ROW_NUMBER () OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC) as RankByGenderAndRow,
        ReportYear,
        Gender,
        FirstNameId,
        NameCount
    FROM agg.FirstNameByYearWide_Surrogate AS fnby
)
SELECT
    NameRank.ReportYear, NameRank.Gender, fn.FirstName,  NameRank.NameCount,
    ReportColumn1, ReportColumn2, ReportColumn3, ReportColumn4, ReportColumn5, ReportColumn6, ReportColumn7, ReportColumn8, ReportColumn9, ReportColumn10, ReportColumn11, ReportColumn12, ReportColumn13, ReportColumn14, ReportColumn15, ReportColumn16, ReportColumn17, ReportColumn18, ReportColumn19, ReportColumn20
FROM NameRank
JOIN agg.FirstNameByYearWide_Surrogate AS fnby on
    fnby.FirstNameId=NameRank.FirstNameId and
    fnby.Gender=NameRank.Gender and
    fnby.ReportYear=NameRank.ReportYear
JOIN ref.FirstName as fn on fnby.FirstNameId=fn.FirstNameId
WHERE RankByGenderAndRow = 1
GO
SET STATISTICS IO, TIME OFF;
GO



/*****************************************************/
/* Can we make the query EVEN faster?                */
/*****************************************************/


CREATE NONCLUSTERED COLUMNSTORE INDEX ncx_BatchModeHack
    on ref.FirstName (FirstNameId)
WHERE ( FirstNameId = 1  and FirstNameId = 0 );
GO


--Scroll up to re-test the queries
--What changed? Why is it faster?

--Important: what are the risks / downsides to using this hack (it's a hack!!!)




DROP INDEX IF EXISTS
    ix_FirstNameByYearWide_Natural_ReportYear_Gender_NameCount ON agg.FirstNameByYearWide_Natural,
    ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount ON agg.FirstNameByYearWide_Surrogate,
    ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount_FirstNameId ON agg.FirstNameByYearWide_Surrogate,
    ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount_INCLUDES ON agg.FirstNameByYearWide_Surrogate,
    ncx_BatchModeHack on ref.FirstName;
GO

ALTER TABLE  agg.FirstNameByYearWide_Surrogate
DROP CONSTRAINT pk_FirstNameByYearWide_Surrogate_ReportYear_Gender_FirstNameId;
GO



