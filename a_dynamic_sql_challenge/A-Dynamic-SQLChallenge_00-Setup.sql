/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/a-dynamic-sqlchallenge/

SETUP FILE: A Dynamic SQL Challenge
This script creates multiple databases
Note: if the databases already exist, THEY WILL BE DROPPED AND RECREATED

    SQLChallengeDB1
    SQLChallengeDB2
    SQLChallengeDB3
    SQLChallengeDB4
    SQLChallengeDB5
*****************************************************************************/
USE master;
GO

IF DB_ID('SQLChallengeDB1') IS NOT NULL
BEGIN
    USE master;

    ALTER DATABASE SQLChallengeDB1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDB1;
END;

CREATE DATABASE SQLChallengeDB1;
GO

IF DB_ID('SQLChallengeDB2') IS NOT NULL
BEGIN
    USE master;

    ALTER DATABASE SQLChallengeDB2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDB2;
END;

CREATE DATABASE SQLChallengeDB2;
GO

IF DB_ID('SQLChallengeDB3') IS NOT NULL
BEGIN
    USE master;

    ALTER DATABASE SQLChallengeDB3 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDB3;
END;

CREATE DATABASE SQLChallengeDB3;
GO

IF DB_ID('SQLChallengeDB4') IS NOT NULL
BEGIN
    USE master;

    ALTER DATABASE SQLChallengeDB4 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDB4;
END;

CREATE DATABASE SQLChallengeDB4;
GO


IF DB_ID('SQLChallengeDB5') IS NOT NULL
BEGIN
    USE master;

    ALTER DATABASE SQLChallengeDB5 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SQLChallengeDB5;
END;

CREATE DATABASE SQLChallengeDB5;
GO

USE SQLChallengeDB1;
GO
CREATE PROCEDURE dbo.CallMeMaybe @p1 INT
AS
BEGIN
    SELECT DB_NAME(),
           @p1;
END;
GO

USE SQLChallengeDB2;
GO
CREATE PROCEDURE dbo.CallMeMaybe @p1 INT
AS
BEGIN
    SELECT DB_NAME(),
           @p1;
END;
GO

USE SQLChallengeDB3;
GO
CREATE PROCEDURE dbo.CallMeMaybe @p1 INT
AS
BEGIN
    SELECT DB_NAME(),
           @p1;
END;
GO


USE SQLChallengeDB4;
GO
CREATE PROCEDURE dbo.CallMeMaybe @p1 INT
AS
BEGIN
    SELECT DB_NAME(),
           @p1;
END;
GO


USE SQLChallengeDB5;
GO
CREATE PROCEDURE dbo.CallMeMaybe @p1 INT
AS
BEGIN
    SELECT DB_NAME(),
           @p1;
END;
GO