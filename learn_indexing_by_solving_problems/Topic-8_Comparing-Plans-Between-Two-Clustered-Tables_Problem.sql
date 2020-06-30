/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO

/*******************************************************************/
/*                        PROBLEM                                  */
/*          Comparing Plans Between Two Clustered Tables           */
/*******************************************************************/
USE BabbyNames;
GO

/* Show the two tables */

exec sp_help 'agg.FirstNameByYearWide_Natural';
GO

exec sp_help 'agg.FirstNameByYearWide_Surrogate';
GO

/* The older "Natural" table has a unique clustered index on ReportYear, Gender, FirstNameId                */
/* The new "Surrogate" we're testing has a unique clustered index on an Identity column (Badly named "Id")  */


/* The tables are wide, and have a lot of columns for reporting. */


/* We have an important query */
/* We can't rewrite the query - if we go with the new table, we'll rename objects */
/* It uses a CTE to find names by rank, then joins back to the table and returns
    a lot of columns for #1 ranked names. */
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



/* We duplicate over an index that was created for this query */
/* The index was tailored to the OVER clause of the windowing function:
    OVER (PARTITION BY ReportYear, Gender ORDER BY NameCount DESC)
*/
CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Natural_ReportYear_Gender_NameCount
ON agg.FirstNameByYearWide_Natural (ReportYear, Gender, NameCount DESC)
GO

CREATE NONCLUSTERED INDEX ix_FirstNameByYearWide_Surrogate_ReportYear_Gender_NameCount
ON agg.FirstNameByYearWide_Surrogate (ReportYear, Gender, NameCount DESC)
GO


/* Problem: What are we missing with our setup and testing of agg.FirstNameByYearWide_Surrogate?
What could go wrong? */


