/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/a-query-writing-sqlchallenge-the-most-unique-names/

Setup:
    Download BabbyNames.bak.zip (43 MB database backup)
    https://github.com/LitKnd/BabbyNames/releases/tag/v1.3
Then review and run the script below on a SQL Server dedicated test instance
    Developer Edition recommended (Enteprise and Evaluation Editions will work too)
	
*****************************************************************************/


SET NOCOUNT, ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
USE master;
GO

IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;
END
GO

RESTORE DATABASE BabbyNames
    FROM DISK=N'S:\MSSQL\Backup\BabbyNames.bak'
    WITH
        MOVE 'BabbyNames' TO 'S:\MSSQL\Data\BabbyNames.mdf',
        MOVE 'BabbyNames_log' TO 'S:\MSSQL\Data\BabbyNames_log.ldf',
        REPLACE,
        RECOVERY;
GO
