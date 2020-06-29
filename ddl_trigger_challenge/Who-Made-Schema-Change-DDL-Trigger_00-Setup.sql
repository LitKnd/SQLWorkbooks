/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course 

SQLChallenges are suitable to be run ONLY on private test instances

SETUP FILE
	
This script creates two databases:
    * SQLChallengeDDLTriggerWatcher
        This database has one table, dbo.DDLWatcher
    * SQLChallengeDDLTrigger

The script also creates a user named [stormy] in the SQLChallengeDDLTrigger database
    * This user only has permission in this database
    * It has no login, which is weird (and you don't have to create one) 
        stormy will only be used for testing in the challenge


*****************************************************************************/


USE master;
GO

DROP TRIGGER IF EXISTS DDLWatcher
ON ALL SERVER;
GO

IF DB_ID('SQLChallengeDDLTriggerWatcher') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeDDLTriggerWatcher
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDDLTriggerWatcher;
END;

CREATE DATABASE SQLChallengeDDLTriggerWatcher;
GO
USE SQLChallengeDDLTriggerWatcher;
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


IF DB_ID('SQLChallengeDDLTrigger') IS NOT NULL
BEGIN
    ALTER DATABASE SQLChallengeDDLTrigger
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDDLTrigger;
END;

CREATE DATABASE SQLChallengeDDLTrigger;
GO

--This user is being created for testing only
USE SQLChallengeDDLTrigger;
GO
CREATE USER [stormy] WITHOUT LOGIN;
GO
ALTER ROLE db_datawriter ADD MEMBER [stormy];
GO
GRANT ALTER TO [stormy];
GO