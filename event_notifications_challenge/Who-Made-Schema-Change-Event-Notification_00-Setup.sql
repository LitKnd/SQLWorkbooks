/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/who-made-that-schema-change-an-event-notification-sqlchallenge/
SETUP FILE
	
This script creates two databases:
    * SQLChallengeEventNotificationWatcher
        This database has one table, dbo.DDLWatcher
    * SQLChallengeEventNotification

The script also creates a user named [stormy] in the SQLChallengeEventNotification database
    * This user only has permission in this database
    * It has no login, which is weird (and you don't have to create one) 
        stormy will only be used for testing in the challenge


*****************************************************************************/

USE master;
GO

IF
(
    SELECT COUNT(*)
    FROM sys.server_event_notifications
    WHERE name = 'DDLWatcherEN'
) > 0
BEGIN
    DROP EVENT NOTIFICATION DDLWatcherEN
    ON SERVER;
END;
GO

IF DB_ID('SQLChallengeEventNotificationWatcher') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeEventNotificationWatcher
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeEventNotificationWatcher;
END;

CREATE DATABASE SQLChallengeEventNotificationWatcher;
GO
USE SQLChallengeEventNotificationWatcher;
GO

CREATE TABLE dbo.DDLWatcher
(
    RowId BIGINT IDENTITY NOT NULL,
    EventType NVARCHAR(128) NULL,
    PostTime DATETIME2(0) NULL,
    SPID INT NULL,
    ServerName NVARCHAR(128) NULL,
    LoginName NVARCHAR(128) NULL,
    UserName NVARCHAR(128) NULL,
    DatabaseName NVARCHAR(128) NULL,
    ObjectName NVARCHAR(128) NULL,
    NewObjectName NVARCHAR(128) NULL,
    ObjectType NVARCHAR(128) NULL,
    TSQLCommand NVARCHAR(MAX),
    CONSTRAINT pk_DDLWatcher
        PRIMARY KEY CLUSTERED (RowId)
);


USE master;
GO


IF DB_ID('SQLChallengeEventNotification') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeEventNotification
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeEventNotification;
END;

CREATE DATABASE SQLChallengeEventNotification;
GO

--This user is being created for testing only
USE SQLChallengeEventNotification;
GO
CREATE USER [stormy] WITHOUT LOGIN;
GO
ALTER ROLE db_datawriter ADD MEMBER [stormy];
GO
GRANT ALTER TO [stormy];
GO