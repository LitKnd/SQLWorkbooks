/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/a-dynamic-sqlchallenge/

SOLUTION FILE: A Dynamic SQL Challenge
*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO



/*****************************************************************************
SAMPLE SOLUTION 1 - exec sp_executesql
Pros: Flexibility, parameterization
Cons: Confusing syntax
*****************************************************************************/

CREATE OR ALTER PROCEDURE dbo.loopthroughdbs @p1 INT = 1
AS
BEGIN

    /* 
    Declare more variables here as needed
    */
    DECLARE @dsql NVARCHAR(MAX) = N'';

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
    */

        -- This doesn't work:
            --USE @db;

        --This doesn't work:
            --EXEC @db.dbo.CallMeMaybe @p1;

        SET @dsql = @db + N'.dbo.CallMeMaybe @p1=@fillmeinplz;';

        INSERT @results
        (
            db,
            p
        )
        EXEC sys.sp_executesql @stmt = @dsql,
                               @params = N'@fillmeinplz INT',
                               @fillmeinplz = @p1;


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

EXEC dbo.loopthroughdbs @p1 = 2;
GO



/*****************************************************************************
SAMPLE SOLUTION 2 - procname as variable
Pros: Nice and simple syntax

*****************************************************************************/


CREATE OR ALTER PROCEDURE dbo.loopthroughdbs @p1 INT = 1
AS
BEGIN

    /* 
    Declare more variables here as needed
    */
    DECLARE @procname sysname;

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
    */
        --You can use a variable for a procedure name
        --The variable can include the database and schema!
        SET @procname = @db + '.dbo.CallMeMaybe';
        INSERT @results
        (
            db,
            p
        )
        EXEC @procname @p1 = @p1;


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

EXEC dbo.loopthroughdbs @p1 = 2;
GO



/*****************************************************************************
SAMPLE SOLUTION 3 - EXEC
Downside: no statement parameterization / re-use
(Maybe not a huge problem in this case, only running 2x per db, but can be problematic)
*****************************************************************************/

CREATE OR ALTER PROCEDURE dbo.loopthroughdbs @p1 INT = 1
AS
BEGIN

    /* 
    Declare more variables here as needed
    */
    DECLARE @dsql NVARCHAR(MAX) = N'';

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
    */

        SET @dsql = @db + N'.dbo.CallMeMaybe @p1=''' + CAST(@p1 AS NVARCHAR(12)) + N'''';

        PRINT @dsql;

        INSERT @results
        (
            db,
            p
        )
        EXEC (@dsql);

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

EXEC dbo.loopthroughdbs @p1 = 2;
GO

