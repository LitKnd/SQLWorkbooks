/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/


*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


/*****************************************************************************
Problem: I need to quickly indent or comment out blocks of code

Solution: Keyboard Shortcuts: Indent & UnIndent / Comment & UnComment 
*****************************************************************************/


/* Demo: Block indent
	Hightlight the whole block
	TAB to indent
	SHIFT + TAB to un-indent  
 */
SELECT 
	new_total.num
FROM (VALUES (1), (2), (3)) AS val(num)
CROSS APPLY (SELECT val.num + 100) as new_total(num)
WHERE new_total.num = 101;
GO	



/* Demo: Block comment
	Hightlight the whole block
	CTRL + K + C to comment
	CTRL + K + U to un-comment

Mnemonic device to remember this: �Control Kansas City� /  �Un-control Kansas City.� 
I have Merrill Aldrich (@onupdatecascade) to thank for this tip
*/
SELECT 
	new_total.num
FROM (VALUES (1), (2), (3)) AS val(num)
CROSS APPLY (SELECT val.num + 100) as new_total(num)
WHERE new_total.num = 101;
GO






/*****************************************************************************
Problem: I need indexes to script out things like compression settings

Solution: Configure Object Explorer to Script Compression and Partition Schemes for Indexes
*****************************************************************************/

/* Demo: make sure this index has data compression */
USE WideWorldImporters;
GO

ALTER INDEX [FK_Sales_Customers_AlternateContactPersonID]
on [Sales].[Customers]
REBUILD WITH (DATA_COMPRESSION = PAGE)
GO

/* Now script the index out from Object Explorer */
/* Can you tell it's compressed?  */

/* 
Click Tools � > Options (or ALT, t, o)

Go to SQL Server Object Explorer -> Scripting
	Scroll down in the right pane of options and set both of these to �True�
		Script Data Compression Options
		Script Partition Schemes

Click OK

Now script again from Object Explorer

Thanks to Adam Machanic (@AdamMachanic) for this tip!
*/




/*****************************************************************************
Problem: I hate typing table names and I can't remember column names

Solution: Script table and column names by dragging from object explorer
*****************************************************************************/
USE WideWorldImporters;
GO


/* Demo: Drag the table and column names for WideWorldImporters
view Website.Suppliers into this query */

SELECT

FROM 
GO


/* This suggestion has been recently closed as fixed, which implies that we'll be seeing
brackets around the column names when they're dragged over in a release soon:
https://connect.microsoft.com/SQLServer/feedback/details/3120203/brackets-around-column-names-when-drag-and-drop-to-query-window
*/


/* Demo: just want a few columns, but can't remember the names?
	Hover over * with your mouse 
	or put your mouse right before * and hit CTRL-K + CTRL-I
	I remember this as "Control Komplete Info" */

SELECT *
FROM Sales.BuyingGroups;
GO

/* Another way to do it...
	Highlight the table name (CTRL + SHIFT + Right Arrow)
	Hit ALT + F1 (built in shortcut for sp_help)
	F6 to toggle through results panes
	Copy out some column names
	Paste into query
*/

SELECT 
FROM Sales.BuyingGroups;
GO



/*****************************************************************************
Problem: I need to see two parts of a long script at once

Solution: Use the Splitter Bar when Editing Large Scripts
*****************************************************************************/

/* Demo:
Use the splitter bar so you can review this script's header.
Show that you can type in BOTH panes!

Closing the splitter bar:
	1) Click the mouse where you want the screen to remain after closing (either pane)
	2) Then close the splitter bar.
*/






/*****************************************************************************
Problem: I want to find something fast

Solution: Keyboard Shortcuts: Quick Find in Session
*****************************************************************************/

/* Summary:
I like CTRL + I for super quick find.
And you can even use this with the splitter bar! */


/* Demo: 
	Open the splitter bar
	Click in the top pane
	Use CTRL + i to find an instance of the word 'lose'
	Hit CTRL + i again to find the next instance

	Click in the bottom pane
	Use CTRL + i to find every instance of the word 'Quick'
	Click in bottom pane and close the splitter bar
*/





/*****************************************************************************
Problem: You hate tabs. And your files have tabs in them. EEEEEEEEK!!!

Solution: Replace Tabs with Spaces
*****************************************************************************/

/* Demo: New code 
Tools -> Options -> Text Editor -> Transact SQL

Keyboard: ALT T, O -> Text Editor -> Transact SQL

Tabs -> Insert spaces
*/


/* Existing code in this session:

CTRL + H - Open find & replace

Use the .* button to enable regular expressions

	Use \t to find or replace tab characters
	Replace it with four spaces

Then do the reverse.
*/






/*****************************************************************************
Problem: I want to edit things faster

Solution: Formatting: Regular Expressions to Add End-Lines, Type on Multiple Lines At Once
*****************************************************************************/


/* Query to format (make a copy and work on it below ) */
SELECT CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy, ValidFrom, ValidTo
FROM [Sales].[Customers];
GO

/* Demo to add line endings:

Highlight the lines to edit
CTRL + h: Bring up find and replace dialog
	Make sure it says "Selection"
	Make sure .* is enabled (for regular expressions)  

use \n to find or replace end-of-line characters
	Find comma space: ,  
	Replace with comma + new line (\n) + four spaces: ,\n	


Add a table alias 
	Note: I like to turn off intellisense before I do this (CTRL B + I)
	Click then ALT then (drag with mouse)
	Selects a column across multiple lines � or multiple columns if you want
	This will show up with a yellow highlight
	You can type on multiple lines
	You can also cut/paste

Then test the query
*/
SELECT CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID, BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit, AccountOpenedDate, StandardDiscountPercentage, IsStatementSent, IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, DeliveryRun, RunPosition, WebsiteURL, DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation, PostalAddressLine1, PostalAddressLine2, PostalPostalCode, LastEditedBy, ValidFrom, ValidTo
FROM [Sales].[Customers];
GO


/* Sample finished query... */
SELECT 
   cust.CustomerID,
   cust.CustomerName,
   cust.BillToCustomerID,
   cust.CustomerCategoryID,
   cust.BuyingGroupID,
   cust.PrimaryContactPersonID,
   cust.AlternateContactPersonID,
   cust.DeliveryMethodID,
   cust.DeliveryCityID,
   cust.PostalCityID,
   cust.CreditLimit,
   cust.AccountOpenedDate,
   cust.StandardDiscountPercentage,
   cust.IsStatementSent,
   cust.IsOnCreditHold,
   cust.PaymentDays,
   cust.PhoneNumber,
   cust.FaxNumber,
   cust.DeliveryRun,
   cust.RunPosition,
   cust.WebsiteURL,
   cust.DeliveryAddressLine1,
   cust.DeliveryAddressLine2,
   cust.DeliveryPostalCode,
   cust.DeliveryLocation,
   cust.PostalAddressLine1,
   cust.PostalAddressLine2,
   cust.PostalPostalCode,
   cust.LastEditedBy,
   cust.ValidFrom,
   cust.ValidTo
FROM [Sales].[Customers] AS cust;
GO

