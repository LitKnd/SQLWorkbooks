/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/who-made-that-schema-change-a-ddl-trigger-sqlchallenge/

SQLChallenges are suitable to be run ONLY on private test instances

CHALLENGE FILE

Documentation on DDL Triggers: https://docs.microsoft.com/en-us/sql/relational-databases/triggers/ddl-triggers
Documentation on DDL Events: https://docs.microsoft.com/en-us/sql/relational-databases/triggers/ddl-events
	
*****************************************************************************/


/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


USE SQLChallengeDDLTrigger;
GO


/*****************************************************************************
CHALLENGE: 

Create a DDL Trigger named DDLWatcher

The DDLWatcher trigger should record all of the following activity to a table
    in the SQLChallengeDDLTriggerWatcher database, named
    dbo.DDLWatcher
        This table was created by the setup script

    Note that the activity you'll be logging takes places in the 
        SQLChallengeDDLTrigger database

    The trigger should log activity for these types of commands if they are run
         in ANY database on the instance
        (we are simply testing in SQLChallengeDDLTrigger)

    You do not need to log activity for any other types of commands
    
*****************************************************************************/




/*****************************************************************************
Activity to test (inital rounds)
Each of these six actions should be logged to a table in the SQLChallengeDDLTriggerWatcher datababase

Note: The entire set of commands is re-runnable
*****************************************************************************/


USE SQLChallengeDDLTrigger;
GO

CREATE TABLE dbo.watchmego
(
    col1 INT,
    col2 CHAR(3)
);
GO

ALTER TABLE dbo.watchmego ADD col3 BIT CONSTRAINT df_watchmego DEFAULT 1;
GO

ALTER TABLE dbo.watchmego DROP CONSTRAINT df_watchmego;
GO

ALTER TABLE dbo.watchmego DROP COLUMN col3;
GO

EXEC sp_rename @objname = 'dbo.watchmego', @newname = 'watchmegone';
GO

DROP TABLE dbo.watchmegone;
GO



/*****************************************************************************
Activity to test (final round)

This is the same set of commands from the first round
This time, however, the commands are run from the context of user = stormy
    stormy only has permissions in the SQLChallengeDDLTrigger database

You need to get your DDL trigger to work without explicitly changing permissions for stormy
    (you can change permissions on the trigger or on the table, you just
    want to use a pattern that doesn't require you to set permissions for
    each user who may cause the trigger to fire on the instance)
*****************************************************************************/

USE SQLChallengeDDLTrigger;
GO

EXEC AS USER = 'stormy';
GO

SELECT USER_NAME() AS USER_NAME,
       SUSER_NAME() AS SUSER_NAME;

CREATE TABLE dbo.watchmego
(
    col1 INT,
    col2 CHAR(3)
);
GO

ALTER TABLE dbo.watchmego ADD col3 BIT CONSTRAINT df_watchmego DEFAULT 1;
GO

ALTER TABLE dbo.watchmego DROP CONSTRAINT df_watchmego;
GO

ALTER TABLE dbo.watchmego DROP COLUMN col3;
GO

EXEC sp_rename @objname = 'dbo.watchmego', @newname = 'watchmegone';
GO

DROP TABLE dbo.watchmegone;
GO

--Go back to our normal user
REVERT;
GO

SELECT USER_NAME() AS USER_NAME,
       SUSER_NAME() AS SUSER_NAME;
GO


