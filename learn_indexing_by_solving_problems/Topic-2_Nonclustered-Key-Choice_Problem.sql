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
/*                 Nonclustered Key Choice                         */
/*******************************************************************/


/* You need to make this query use the fewest logical reads possible.
You must create one single-column nonclustered index to do this.

	(No filters, compression, etc. No changing the query. Only one index.)
	(No deleting rows or truncating the table.)
*/

USE BabbyNames;
GO

/* The query */
SELECT
	fnby.Gender,
	fnby.NameCount,
	fnby.ReportYear
FROM agg.FirstNameByYear AS fnby
JOIN ref.FirstName AS fn on
	fnby.FirstNameId=fn.FirstNameId
WHERE
	fn.FirstName = 'Taylor'
	and fnby.Gender='F';
GO



/* 
The tables have only these indexes (Clustered PKs) 
The indexes already exist, the code is here for your reference
*/
--ALTER TABLE agg.FirstNameByYear
--	ADD CONSTRAINT pk_aggFirstNameByYear PRIMARY KEY CLUSTERED
--	(ReportYear, FirstNameId, Gender);
--GO

--ALTER TABLE ref.FirstName
--	ADD CONSTRAINT pk_FirstName_FirstNameId PRIMARY KEY CLUSTERED
--	(FirstNameId);
--GO



/* Design your nonclustered index 
    Here is the syntax in fill-in-the-blank format
*/

CREATE INDEX ix_onecolumn
	ON __________________  /* tablename */
	( _________________ ) /* key columname */ ;
GO



