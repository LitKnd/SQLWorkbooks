/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/a-dynamic-sqlchallenge/

PROBLEM FILE: A Dynamic SQL Challenge
*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO



/*****************************************************************************
Your SQLChallenge...

Add variables and code to the following procedure, dbo.loopthroughdbs
This procedure exists ONLY in SQLChallengeDB01
The procedure uses a cursor to loop through each database named SQLChallengeDB%
    (You should have SQLChallengeDB01 to SQLChallengeDB05)
In each database, you need to call the dbo.CallMeMaybe proc
    We need to pass in the value for the @p1 parameter,
       based on @p1 as provided to dbo.loopthroughdbs
You must insert the results into the @results table (this proc will return them at the end)

You have two sample calls below the proc for testing

Stretch: Write the solution TWO different ways
Extra stretch: Write the solution THREE different ways

*****************************************************************************/

/* Here is your procedure to modify */

USE SQLChallengeDB1;
GO

--This procedure exists ONLY in SQLChallengeDB1
CREATE OR ALTER PROCEDURE dbo.loopthroughdbs @p1 INT = 1
AS
BEGIN

    /* 
    Declare more variables here as needed
    */
    DECLARE @db sysname;

    DECLARE @results TABLE
    (
        db sysname NOT NULL,
        p INT NOT NULL
    );

    DECLARE sqlchallengedbcursor CURSOR FAST_FORWARD LOCAL READ_ONLY FOR
    SELECT name
    FROM sys.databases
    WHERE name LIKE 'SQLChallengeDB%';

    OPEN sqlchallengedbcursor;

    FETCH NEXT FROM sqlchallengedbcursor
    INTO @db;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        /* 
    Add code beginning here
    We need to call the dbo.CallMeMaybe proc in each database
        For each execution, we want to provide the value for the @p1 parameter,
            as passed into this procedure
    We want to insert the results into the @results table variable and this proc will return them at the end
    */


        /* 
    Add code ending here
    */

        FETCH NEXT FROM sqlchallengedbcursor
        INTO @db;
    END;

    SELECT db,
           p
    FROM @results;

    CLOSE sqlchallengedbcursor;
    DEALLOCATE sqlchallengedbcursor;

END;
GO

EXEC dbo.loopthroughdbs @p1 = 128;
GO

--Output should look like this after changes are made:

--db	            p
--SQLChallengeDB1	128
--SQLChallengeDB2	128
--SQLChallengeDB3	128
--SQLChallengeDB4	128
--SQLChallengeDB5	128

EXEC dbo.loopthroughdbs @p1 = 2;
GO

--Output should look like this after changes are made:

--db	            p
--SQLChallengeDB1	2
--SQLChallengeDB2	2
--SQLChallengeDB3	2
--SQLChallengeDB4	2
--SQLChallengeDB5	2