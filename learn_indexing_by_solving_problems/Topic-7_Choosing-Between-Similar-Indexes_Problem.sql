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
/*                     Baby Boomers                                */
/*******************************************************************/
USE BabbyNames;
GO

/*
The "baby boom" in the United States occurred between 1946 and 1964

Given the following query and the agg.FirstNameByYear table,
which of the non-clustered indexes will require fewer logical reads?
*/

SELECT TOP 10
	ReportYear,
	SUM(NameCount) as TotalBirthsReported
FROM agg.FirstNameByYear
WHERE
	ReportYear <= 2000
	and Gender='F'
GROUP BY ReportYear
ORDER BY SUM(NameCount) DESC;
GO

CREATE INDEX [A]
	on agg.FirstNameByYear (Gender)
	INCLUDE ( ReportYear, FirstNameId, NameCount );
GO

CREATE INDEX [B]
	on agg.FirstNameByYear (Gender, ReportYear)
	INCLUDE ( NameCount );
GO

/* agg.FirstNameByYear has no other nonclustered indexes.
It has a clustered primary key on: (ReportYear ASC, FirstNameId ASC, Gender ASC)
*/





/*Baseline */
SET STATISTICS IO, TIME ON;
GO
SELECT TOP 10
	ReportYear,
	SUM(NameCount) as TotalBirthsReported
FROM agg.FirstNameByYear
WHERE
	ReportYear <= 2000
	and Gender='F'
GROUP BY ReportYear
ORDER BY SUM(NameCount) DESC;
GO
SET STATISTICS IO, TIME OFF;
GO



/* Actual execution plan */
SELECT TOP 10
	ReportYear,
	SUM(NameCount) as TotalBirthsReported
FROM agg.FirstNameByYear
WHERE
	ReportYear <= 2000
	and Gender='F'
GROUP BY ReportYear
ORDER BY SUM(NameCount) DESC;
GO