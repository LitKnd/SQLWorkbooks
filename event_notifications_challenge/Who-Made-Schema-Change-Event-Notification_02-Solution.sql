/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/who-made-that-schema-change-an-event-notification-sqlchallenge/

SQLChallenges are suitable to be run ONLY on private test instances

SOLUTION FILE
*****************************************************************************/


/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/*****************************************************************************
SOLUTION 
*****************************************************************************/


/*****************************************************************************
Part 1: Configure the database
    Create queue, service, route, then event notification
*****************************************************************************/

USE SQLChallengeEventNotificationWatcher;
GO

ALTER DATABASE SQLChallengeEventNotificationWatcher
SET ENABLE_BROKER
WITH ROLLBACK IMMEDIATE;
GO

--Create a queue to receive messages.  
CREATE QUEUE NotifyQueue;
GO

--Create a service on the queue that references  
--the event notifications contract.  
CREATE SERVICE NotifyService
ON QUEUE NotifyQueue
(
    [https://schemas.microsoft.com/SQL/Notifications/PostEventNotification]
);
GO

/*
Msg 15151, Level 16, State 1, Line 36
Cannot find the contract 'https://schemas.microsoft.com/SQL/Notifications/PostEventNotification', because it does not exist or you do not have permission.

*/

---Hmm, what?
--Note: this contract comes installed with SQL Server, 
SELECT *
FROM sys.service_contracts;
GO


--OK then, http instead of https it is!
CREATE SERVICE NotifyService
ON QUEUE NotifyQueue
(
    [http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]
);
GO



--Create a route on the service to define the address   
--to which Service Broker sends messages for the service.  
CREATE ROUTE NotifyRoute
WITH
SERVICE_NAME = 'NotifyService',
ADDRESS = 'LOCAL';
GO

--Create the event notification.  
CREATE EVENT NOTIFICATION DDLWatcherEN ON SERVER 
    FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE, RENAME 
    TO SERVICE 'NotifyService', 'current database';
GO


----Note: the drop for this is:
--DROP EVENT NOTIFICATION DDLWatcherEN   
--ON SERVER 



/*****************************************************************************
Part 2: Is this thing working?
    Validate and troubleshoot
*****************************************************************************/

--Is there anything in our queue?
--If not, run our sample activity for testing from the challenge and re-check
SELECT *
FROM NotifyQueue;
GO


/* Check the SQL Server log if it's not working

Date		2/10/2019 3:52:46 PM
Log		SQL Server (Current - 2/10/2019 3:11:00 PM)

Source		spid69s

Message
An exception occurred while enqueueing a message in the target queue. Error: 15404, 
State: 19. Could not obtain information about Windows NT group/user 'DERP\Kendar', error code 0x54b.
*/


--I need to clean up my database owners to get this working!
ALTER AUTHORIZATION
ON DATABASE::SQLChallengeEventNotificationWatcher
TO sa;
GO

ALTER AUTHORIZATION ON DATABASE::SQLChallengeEventNotification TO sa;
GO



/*****************************************************************************
Part 3: Receive messages
http://www.sqlservercentral.com/articles/Event+Notifications/68831/

This code would need to be run periodically by a job, or you could get fancy
    and use an activation procedure to automatically process rows as they come in

*****************************************************************************/
-- Declare the table variable to hold the XML messages
DECLARE @messages TABLE
(
    message_data XML
);

-- Receive all the messages for the next conversation_handle from the queue into the table variable
RECEIVE CAST(message_body AS XML)
FROM NotifyQueue
INTO @messages;

-- Parse the XML from the table variable

INSERT dbo.DDLWatcher
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
SELECT message_data.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(128)') AS EventType,
       message_data.value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime2(0)') AS PostTime,
       message_data.value('(/EVENT_INSTANCE/SPID)[1]', 'INT') AS SPID,
       message_data.value('(/EVENT_INSTANCE/ServerName)[1]', 'nvarchar(128)') AS ServerName,
       message_data.value('(/EVENT_INSTANCE/LoginName)[1]', 'nvarchar(128)') AS LoginName,
       message_data.value('(/EVENT_INSTANCE/UserName)[1]', 'nvarchar(128)') AS UserName,
       message_data.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'nvarchar(128)') AS DatabaseName,
       message_data.value('(/EVENT_INSTANCE/ObjectName)[1]', 'nvarchar(128)') AS ObjectName,
       message_data.value('(/EVENT_INSTANCE/NewObjectName)[1]', 'nvarchar(128)') AS NewObjectName,
       message_data.value('(/EVENT_INSTANCE/ObjectType)[1]', 'nvarchar(128)') AS ObjectType,
       message_data.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'nvarchar(max)') AS TSQLCommand
FROM @messages;
GO

SELECT *
FROM dbo.DDLWatcher;
GO

/*****************************************
Cleanup
*****************************************/
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

IF DB_ID('SQLChallengeEventNotification') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeEventNotification
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeEventNotification;
END;
