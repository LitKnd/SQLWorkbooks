/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/who-made-that-schema-change-an-event-notification-sqlchallenge/

SQLChallenges are suitable to be run ONLY on private test instances

CHALLENGE FILE

http://www.sqlservercentral.com/articles/Event+Notifications/68831/

	
*****************************************************************************/


/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/*****************************************************************************
CHALLENGE: 

Create an event notification named DDLWatcherEN, along with any required dependent objects

The DDLWatcherEN event notification should record all of the following activity to a table
    in the SQLChallengeEventNotificationWatcher database, named
    dbo.DDLWatcher
        This table was created by the setup script

    Note that the activity you'll be logging takes places in the 
        SQLChallengeEventNotification database

    The trigger should log activity for these types of commands if they are run
         in ANY database on the instance
        (we are simply testing in SQLChallengeEventNotification)

    You do not need to log activity for any other types of commands

    You do not need to fully automate receiving the event notifications
        It's plenty to write code that receives the notifications and adds them to dbo.DDLWatcher when
            you run it manually
        You do not need to create a job that runs this periodically or make it an activation procedure
            (unless you just feel like it)
    
*****************************************************************************/




/*****************************************************************************
Activity to test (inital rounds)
Each of these six actions should be logged to a table in the SQLChallengeEventNotificationWatcher datababase

Note: The entire set of commands is re-runnable
*****************************************************************************/


USE SQLChallengeEventNotification;
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
    stormy only has permissions in the SQLChallengeEventNotification database

Does your Event Notification work for stormy?
    Or is a change in permissions needed?
*****************************************************************************/

USE SQLChallengeEventNotification;
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


