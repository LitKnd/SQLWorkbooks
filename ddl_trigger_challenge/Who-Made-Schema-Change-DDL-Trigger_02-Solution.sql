/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/who-made-that-schema-change-a-ddl-trigger-sqlchallenge/

SQLChallenges are suitable to be run ONLY on private test instances


SOLUTION FILE
	
*****************************************************************************/


/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/*****************************************************************************
Activity to test (initial rounds)
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
First iteration
Identify the events we want to log and set them up in a simple trigger
Test that the trigger is firing for those events

Documentation on DDL Events: https://docs.microsoft.com/en-us/sql/relational-databases/triggers/ddl-events
Documentation on EVENTDATA: https://docs.microsoft.com/en-us/sql/relational-databases/triggers/use-the-eventdata-function

* EVENTDATA() allows us to review everything that comes back from the event
* We should only do this testing on a private instance as this impacts EVERYONE using the instance

*****************************************************************************/


CREATE OR ALTER TRIGGER DDLWatcher
ON ALL SERVER
FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE, RENAME
AS
DECLARE @eventdata XML;
SET @eventdata = EVENTDATA();
SELECT EVENTDATA() AS EVENTDATA;
GO

/* 
Rerun activity 

Do we see the trigger fire six times?
Look at the event data output
    Note that for the sp_rename command, NewObjectName is in the output
    It is not there for other commands
*/


--We can see any server level DDL triggers this way (if we have permission):
SELECT *
FROM sys.server_triggers AS st;
GO

--In Object Explorer, this is visible under:
--> Server Objects --> Triggers

--Note that the DROP command needs to say ON ALL SERVER for this trigger:
DROP TRIGGER IF EXISTS DDLWatcher
ON ALL SERVER;
GO


/*****************************************************************************
Second iteration
Split out the column information

*****************************************************************************/

CREATE OR ALTER TRIGGER DDLWatcher
ON ALL SERVER
FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE, RENAME
AS
DECLARE @eventdata XML;
SET @eventdata = EVENTDATA();

SELECT @eventdata.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(128)') AS EventType,
       @eventdata.value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime2(0)') AS PostTime,
       @eventdata.value('(/EVENT_INSTANCE/SPID)[1]', 'INT') AS SPID,
       @eventdata.value('(/EVENT_INSTANCE/ServerName)[1]', 'nvarchar(128)') AS ServerName,
       @eventdata.value('(/EVENT_INSTANCE/LoginName)[1]', 'nvarchar(128)') AS LoginName,
       @eventdata.value('(/EVENT_INSTANCE/UserName)[1]', 'nvarchar(128)') AS UserName,
       @eventdata.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'nvarchar(128)') AS DatabaseName,
       @eventdata.value('(/EVENT_INSTANCE/ObjectName)[1]', 'nvarchar(128)') AS ObjectName,
       @eventdata.value('(/EVENT_INSTANCE/NewObjectName)[1]', 'nvarchar(128)') AS NewObjectName,
       @eventdata.value('(/EVENT_INSTANCE/ObjectType)[1]', 'nvarchar(128)') AS ObjectType,
       @eventdata.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'nvarchar(max)') AS TSQLCommand;
GO


/* 
Rerun activity 

Does the output look correct?
*/


/*****************************************************************************
Third iteration

Add SET NOCOUNT ON;
Insert into the SQLChallengeDDLTriggerWatcher.dbo.DDLWatcher table
*****************************************************************************/

CREATE OR ALTER TRIGGER DDLWatcher
ON ALL SERVER
FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE, RENAME
AS
SET NOCOUNT ON;

DECLARE @eventdata XML;
SET @eventdata = EVENTDATA();


INSERT SQLChallengeDDLTriggerWatcher.dbo.DDLWatcher
(
    EventType,
    PostTime,
    SPID,
    ServerName,
    LoginName,
    UserName,
    DatabaseName,
    ObjectName,
    NewObjectName,
    ObjectType,
    TSQLCommand
)
SELECT @eventdata.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(128)') AS EventType,
       @eventdata.value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime2(0)') AS PostTime,
       @eventdata.value('(/EVENT_INSTANCE/SPID)[1]', 'INT') AS SPID,
       @eventdata.value('(/EVENT_INSTANCE/ServerName)[1]', 'nvarchar(128)') AS ServerName,
       @eventdata.value('(/EVENT_INSTANCE/LoginName)[1]', 'nvarchar(128)') AS LoginName,
       @eventdata.value('(/EVENT_INSTANCE/UserName)[1]', 'nvarchar(128)') AS UserName,
       @eventdata.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'nvarchar(128)') AS DatabaseName,
       @eventdata.value('(/EVENT_INSTANCE/ObjectName)[1]', 'nvarchar(128)') AS ObjectName,
       @eventdata.value('(/EVENT_INSTANCE/NewObjectName)[1]', 'nvarchar(128)') AS NewObjectName,
       @eventdata.value('(/EVENT_INSTANCE/ObjectType)[1]', 'nvarchar(128)') AS ObjectType,
       @eventdata.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'nvarchar(max)') AS TSQLCommand;
GO


/* 
Rerun activity 
*/

SELECT *
FROM SQLChallengeDDLTriggerWatcher.dbo.DDLWatcher;
GO






/*****************************************************************************
Activity to test (final round)

Same set of commands, but running as user=stormy (permissions only in SQLChallengeDDLTrigger)

Question: Run once and let it fail
    Note that if the DDL trigger can't insert into the table, the calling command fails
    DDL Triggers are tightly coupled with the calling command
        Triggers are processed within the same transaction as the calling command
            If the trigger fails, the whole thing rolls back
                You can't work around this with try/catch in the trigger
    If you need a more loosely coupled solution / don't want to be in the same transaction
        Then look at Event Notifications
*****************************************************************************/

USE SQLChallengeDDLTrigger;
GO

EXEC AS USER = 'stormy';
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

--Go back to our normal user
REVERT
GO


/* One way to fix this... */
USE SQLChallengeDDLTriggerWatcher;
GO
GRANT CONNECT ON DATABASE::SQLChallengeDDLTriggerWatcher TO [public];
GO
GRANT INSERT ON OBJECT::dbo.DDLWatcher TO [public];
GO



SELECT *
FROM SQLChallengeDDLTriggerWatcher.dbo.DDLWatcher;
GO


/*****************************************************************************
Another tip from Aaron Bertrand
https://www.mssqltips.com/sqlservertip/5659/customize-sql-server-notifications-for-ddl-changes/

    If a DDL event occurs under snapshot isolation, and the auditing database does not support 
        snapshot isolation, you will get this error:

    Msg 3952, Level 16, State 1, Procedure DDLTrigger_Sample
    Snapshot isolation transaction failed accessing database 'AuditDB' because snapshot isolation 
        is not allowed in this database. Use ALTER DATABASE to allow snapshot isolation.
    To avoid this error, you�ll want to issue this statement against your auditing database:

    ALTER DATABASE AuditDB SET ALLOW_SNAPSHOT_ISOLATION ON;

*****************************************************************************/

ALTER DATABASE SQLChallengeDDLTriggerWatcher SET ALLOW_SNAPSHOT_ISOLATION ON;
GO


/*****************************************************************************
Challenge cleanup
*****************************************************************************/

DROP TRIGGER IF EXISTS DDLWatcher
ON ALL SERVER;
GO

use master;
GO

IF DB_ID('SQLChallengeDDLTriggerWatcher') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeDDLTriggerWatcher
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDDLTriggerWatcher;
END;

IF DB_ID('SQLChallengeDDLTrigger') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeDDLTrigger
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDDLTrigger;
END;
