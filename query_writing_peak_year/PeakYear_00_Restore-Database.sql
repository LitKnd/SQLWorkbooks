/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/tune-the-peak-years-procedure-sqlchallenge/

🛑 Caution: This script restores of databases and changes system config! 🛑
☢️ Suitable for dedicated test instances only ☢️

This restores the BabbyNames database, download it from:
	https://drive.google.com/file/d/1w0ZGZKHq4N7n6eyP5puu63MuSH3o_hWb/view?usp=sharing

*The database will restore to SQL Server 2017 and higher only*

Read through this script and make sure you want to use these settings
You will also likely need to change drive / path information on the restore command

*****************************************************************************/


use master;
GO

exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE
GO


exec sp_configure 'cost threshold for parallelism', 50;
exec sp_configure 'max degree of parallelism', 4;
exec sp_configure 'max server memory (MB)', 4000;
GO

RECONFIGURE
GO


IF DB_ID('BabbyNames') IS NOT NULL
BEGIN
    ALTER DATABASE BabbyNames SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO

/* Change drive / folder information as needed */
RESTORE DATABASE BabbyNames FROM 
    DISK = N'S:\MSSQL\Backup\BabbyNames2017_QTJS_1_of_4.bak', 
    DISK = N'S:\MSSQL\Backup\BabbyNames2017_QTJS_2_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames2017_QTJS_3_of_4.bak',
    DISK = N'S:\MSSQL\Backup\BabbyNames2017_QTJS_4_of_4.bak'
WITH REPLACE;
GO
