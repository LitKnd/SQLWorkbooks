/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/

Do these quick pre-requisites:
    1) Download WideWorldImporters-Full.bak (database backup)
	Restore it to a SQL Server 2016 test instance (restore script below)
		https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
	
    2) Install sp_WhoIsActive from http://whoisactive.com/

	3) Make sure you have the latest copy of SQL Server Management Studio
		https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms

This is worth doing so you can step through the demos yourself!

*****************************************************************************/


USE master;
GO

IF DB_ID('WideWorldImporters') IS NOT NULL
ALTER DATABASE WideWorldImporters SET OFFLINE WITH ROLLBACK IMMEDIATE

/* EDIT DRIVE/FOLDER LOCATIONS AS NEEDED */
RESTORE DATABASE WideWorldImporters FROM DISK=
	'S:\MSSQL\Backup\WideWorldImporters-Full.bak'  
	WITH REPLACE,
	MOVE 'WWI_Primary' to 'S:\MSSQL\Data\WideWorldImporters.mdf',
	MOVE 'WWI_UserData' to 'S:\MSSQL\Data\WideWorldImporters_UserData.ndf',
	MOVE 'WWI_Log' to 'S:\MSSQL\Data\WideWorldImporters.ldf',
	MOVE 'WWI_InMemory_Data_1' to 'S:\MSSQL\Data\WideWorldImporters_InMemory_Data_1';
GO
