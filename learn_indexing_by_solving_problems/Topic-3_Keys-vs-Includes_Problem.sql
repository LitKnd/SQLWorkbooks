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
/*                   Keys vs Includes                              */
/*******************************************************************/

/* Create these two single column indexes */
USE BabbyNames;
GO

CREATE INDEX ix_ref_FirstName_FirstName
	on ref.FirstName (FirstName);
GO

CREATE INDEX ix_agg_FirstNameByYear_FirstNameId
	ON agg.FirstNameByYear
	( FirstNameId );
GO

/* 
sYou want to optimize indexes for this query,
which has a LIKE predicate
*/
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName like 'Ta%'
	and fnby.Gender='F';
GO

/* Can you think of a reason why SQL might not like to use one of these indexes?
What do you think you should change, and why? */


CREATE INDEX ______________________________
	ON ________________
	( _________ )           /* One or more keys */
	INCLUDE ( _________ );  /* One or more includes (optional) */
GO








