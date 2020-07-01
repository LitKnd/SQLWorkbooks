/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/sqlchallenge-forcing-parallelism

This SQLChallenge uses the free ContosoRetailDW sample database from Microsoft
Download it here:
https://www.microsoft.com/en-us/download/details.aspx?id=18279



*****************************************************************************/
RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO


/*****************************************************************************
CHALLENGE
*****************************************************************************/
SET ANSI_NULLS, QUOTED_IDENTIFIER, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
GO
SET NUMERIC_ROUNDABORT OFF;
GO



/* Restore ContosoRetailDW, a sample database from Microsoft */
USE master;
GO
IF DB_ID('ContosoRetailDW') IS NOT NULL
BEGIN
    ALTER DATABASE ContosoRetailDW 
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE
END

RESTORE DATABASE ContosoRetailDW FROM  
    DISK = N'S:\MSSQL\Backup\ContosoRetailDW.bak' WITH
        MOVE N'ContosoRetailDW2.0' TO N'S:\MSSQL14.DEV\MSSQL\DATA\ContosoRetailDW.mdf',  
        MOVE N'ContosoRetailDW2.0_log' TO N'S:\MSSQL14.DEV\MSSQL\DATA\ContosoRetailDW.ldf',  
        REPLACE,  
        STATS = 5;
GO

/* Raise compat level */
ALTER DATABASE ContosoRetailDW SET COMPATIBILITY_LEVEL = 140;
GO




/* Our instance starts with these settings */
exec sp_configure 'cost threshold for parallelism', 50;
GO
exec sp_configure 'max degree of parallelism', 4;
GO
EXEC sp_configure 'min server memory (MB)', 256;
GO
EXEC sp_configure 'max server memory (MB)', 2000;
GO
RECONFIGURE
GO

/* Set up Query Store */
ALTER DATABASE ContosoRetailDW SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, 
    QUERY_CAPTURE_MODE = ALL, /* AUTO is often best!*/
    MAX_PLANS_PER_QUERY = 200,
    MAX_STORAGE_SIZE_MB = 2048,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    SIZE_BASED_CLEANUP_MODE = AUTO,
    DATA_FLUSH_INTERVAL_SECONDS = 15,
    INTERVAL_LENGTH_MINUTES = 30,
    WAIT_STATS_CAPTURE_MODE = ON /* 2017 gets wait stats! */
    );
GO


USE ContosoRetailDW;
GO


/* Our problem uses this view */
CREATE OR ALTER VIEW dbo.V_CustomerData 
AS
SELECT
    pc.ProductCategoryName,
    psc.ProductSubcategoryName AS ProductSubcategory,
    p.ProductName AS Product,
    c.CustomerKey,
    g.RegionCountryName AS Region,
    c.BirthDate,
    DATEDIFF(dd,BirthDate,GETDATE())/365. as Age,
    c.YearlyIncome,
    d.CalendarYear,
    d.FiscalYear,
    d.CalendarMonth AS Month,
    f.SalesOrderNumber AS OrderNumber,
    f.SalesOrderLineNumber AS LineNumber,
    f.SalesQuantity AS Quantity,
    f.SalesAmount AS Amount  
FROM
    dbo.FactOnlineSales f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
JOIN dbo.DimProduct p ON f.ProductKey = p.ProductKey
JOIN dbo.DimProductSubcategory psc ON p.ProductSubcategoryKey = psc.ProductSubcategoryKey
JOIN dbo.DimProductCategory pc ON psc.ProductCategoryKey = pc.ProductCategoryKey
JOIN dbo.DimCustomer c ON f.CustomerKey = c.CustomerKey
JOIN dbo.DimGeography g ON c.GeographyKey = g.GeographyKey;
GO


/* This is our stored procedure */
CREATE OR ALTER PROCEDURE dbo.TotalSalesByRegionForYear
    @CalendarYear INT NULL
AS
SELECT 
    Region,
    CalendarYear,
    SUM(Amount) as TotalSales,
    MIN(YearlyIncome) as MinYearlyIncome,
    MAX(YearlyIncome) as MaxYearlyIncome
FROM dbo.V_CustomerData
    WHERE CalendarYear = @CalendarYear
GROUP BY Region, CalendarYear
ORDER BY TotalSales DESC;
GO


/* Run this a couple of times.
We've got some income disparity! 

Look at the plan and confirm it goes parallel.
Just for fun:
    Look at the actual plan. How many threads does this get?*/
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO



/* The lead DBA makes this change */
exec sp_configure 'cost threshold for parallelism', 200;
GO
RECONFIGURE
GO


/* What is our plan and duration now? */
EXEC dbo.TotalSalesByRegionForYear @CalendarYear = 2007;
GO

/* Challenge:
Can you get the parallel plan back for the stored procedure --

    Without changing cost threshold for parallelism
    Without changing the stored procedure definition

Note: There is more than one possible solution
*/
