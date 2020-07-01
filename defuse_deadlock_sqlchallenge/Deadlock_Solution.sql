/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/defuse-the-deadlock-sqlchallenge

***********************************************************************/





/* This is the SOLUTION file.
Make sure you check out the problem file first :D

Then scroll down.
Extra returns are in this file to prevent accidental spoilers.
*/



























/*************************************************************
 Solutions
*************************************************************/
USE ContosoRetailDW;
GO

/***************************************
Door #1
***************************************/

/* 
This nonclustered index defuses the deadlock, but does leave some blocking
I have chosen to "cover" the query for dbo.DimProductSubcategory
 */
CREATE INDEX ix_DimProductSubcategory_ProductSubcategoryName_INCLUDES
on dbo.DimProductSubcategory 
    (ProductSubcategoryName) INCLUDE (ProductSubcategoryKey, ProductCategoryKey);
GO

/* Clean up */
DROP INDEX ix_DimProductSubcategory_ProductSubcategoryName_INCLUDES on dbo.DimProductSubcategory;
GO




/***************************************
Door #2 
***************************************/

/* This nonclustered index defuses the deadlock and removes blocking. */
CREATE INDEX ix_DimProductCategory
on dbo.DimProductCategory (ProductCategoryKey);
GO

/* We do have near dupliate indexes on DimProductCategory now, however */
exec sp_helpindex 'DimProductCategory';
GO

/* Clean up */
DROP INDEX ix_DimProductCategory on dbo.DimProductCategory;
GO