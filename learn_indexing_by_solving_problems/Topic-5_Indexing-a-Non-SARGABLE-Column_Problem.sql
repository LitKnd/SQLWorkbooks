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
/*                        %nom% !                                 */
/*******************************************************************/

/* There's one column on our table that is usually null.
But *sometimes* it contains a note.
InevitableLOBColumn is NVARCHAR(MAX).
This column is periodically searched with queries like the following....
*/

USE BabbyNames;
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

/* Make this query as fast as possible, using the most efficient nonclustered index possible. */




/* Baseline */
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



/* Look at the actual execution plan */
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

/* Notice that we don't have a predicate in the scan.
It's deciding to do a separate filter operator this time. */


/* Design your non-clustered index */
/* No template this time! */








