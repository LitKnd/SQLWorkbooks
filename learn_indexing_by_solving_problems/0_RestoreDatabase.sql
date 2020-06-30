/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

DATABASE INFO
    * The database was backed up from SQL Server 2017 RTM+ CU4. It can be restored to SQL Server 2017 or higher.
    * We are using an expanded copy of the BabbyNames database. It contains data from 1880 - 2017.
    * The restored database takes up 16GB of space.�

TO RESTORE
    1. Download BabbyNames_Indexing20180503.zip from https://github.com/LitKnd/BabbyNames/releases
    2. Unzip and you will have 4 files which are all part of one backup
    3. Move all four backup files to your favorite directory to restore from

    4. Modify the script below to use your own drive and file locations to restore and configure the database

****************************************/

/* These are the settings I use for demos. I have 4 vCPUs on the demo instance */
exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO

exec sp_configure 'max degree of parallelism', 4;
GO
exec sp_configure 'cost threshold for parallelism', 5;
GO
RECONFIGURE
GO


use master;
GO

IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
	ALTER DATABASE BabbyNames
		SET SINGLE_USER
		WITH ROLLBACK IMMEDIATE;
END
GO
RESTORE DATABASE BabbyNames FROM 
    DISK = N'S:\MSSQL\Backup\BabbyNames_Indexing_20180530_1-of-4.bak', /* Change location */
    DISK = N'S:\MSSQL\Backup\BabbyNames_Indexing_20180530_2-of-4.bak', /* Change location */
    DISK = N'S:\MSSQL\Backup\BabbyNames_Indexing_20180530_3-of-4.bak', /* Change location */
    DISK = N'S:\MSSQL\Backup\BabbyNames_Indexing_20180530_4-of-4.bak'  /* Change location */   
WITH 
    MOVE 'BabbyNames' TO 'T:\MSSQL\Data\BabbyNames.mdf',               /* Change location */
    MOVE 'BabbyNames_log' TO 'T:\MSSQL\Data\BabbyNames_log.ldf',       /* Change location */
    MOVE 'FG1DAT1' TO 'T:\MSSQL\Data\BabbyNames_FG1DAT1.ndf',          /* Change location */
    MOVE 'FG1DAT2' TO 'T:\MSSQL\Data\BabbyNames_FG1DAT2.ndf',          /* Change location */
    MOVE 'FG1DAT3' TO 'T:\MSSQL\Data\BabbyNames_FG1DAT3.ndf',          /* Change location */
    MOVE 'FG1DAT4' TO 'T:\MSSQL\Data\BabbyNames_FG1DAT4.ndf',          /* Change location */
	REPLACE,
	RECOVERY;
GO