/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/


*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO

/* We begin in the master db */
use master;
GO




/*****************************************************************************
Problem: Reaching for the mouse too often.

Solution: Favorite shortcuts!
*****************************************************************************/


/* SUMMARY...
New Session: CTRL + N
	I  remember this as "Control Newness"

Use Database: CTRL + U
	I remember this as "Control USE"
	If CTRL + U doesn�t work for you, it might be this bug: 
        https://connect.microsoft.com/SQLServer/feedback/details/2534820/ssms-ctrl-u-doesnt-work/
	It also might be a 3rd party plugin

Execute Query: CTRL + E
	I remember this as "Control Execution"
	OR F5 <--- Not my thing, but different keystrokes for different folks

Show / Hide Results: CTRL + R
	I remember this as, "Control Results"

*/

/* Demo:
Copy this query to the clipboard with CTRL + C
Do a new session with CTRL + N
Use the WideWorldImporters database with CTRL + U
Paste the query into the session window with CTRL + V
Execute the query with CTRL + E
Show / Hide results with CTRL + R

Extra fun!
F6: Toggle between query and results panes
CTRL+ F4: Close current sessions (Control 4 Session)
*/

SELECT OrderID, ExpectedDeliveryDate
FROM Sales.Orders
WHERE ExpectedDeliveryDate > '2016-01-01';
GO


/* Demo: The USE database dialog is a little wacky on case sensitive instances.
Do CTRL + U
Type a capital MS and hit enter.

*/




/*****************************************************************************
Problem: I don't want to use the mouse to switch to another open session

Solution: 
	CTRL + F4 closes the current window/session
		You can also use the menus! ALT , f, c 
	CTRL + TAB lets you cycle between sessions
*****************************************************************************/


/* Demo:
	Close the current window with ALT, f, c

	Use CTRL + TAB to cycle through other sessions

		Note: You can use ALT + F7 to navigate to other tool windows (like object explorer)
		I never remember this one 
*/








/*****************************************************************************
Problem: Typing is soooooo much work

Solution: Autocomplete TSQL with Intellisense
*****************************************************************************/

/* SUMMARY....
Down Arrow / Up Arrow = Navigates through a list of suggestions from intellisense

Tab or return to select an item

Intellisense acting weird?
	Refresh local cache: CTRL + SHIFT + R  
*/



/* Demo: enable/ disable Intellisense
	In SQL Server 2012, this was...
		CTRL + Q , CTRL + I
		I remember this as, "Control Quacky Intellisense"

	Now in SSMS 17.2, this is...
		CTRL + B, CTRL + I
		I remember this as, "Control Baffling Intellisense"
*/


/*
Demo: Intellisense will correct case...
 Type capital M, then autcomplete master database with tab 
 */
USE M
GO


/*
Demo: using arrows with intellisense
 Type sys.dat, arrow down to select sys.database_files, tab to autocomplete.
 */
SELECT *
FROM sys.dat
GO


/* Demo: completion mode vs suggestion mode.
    I find this confusing as heck.

    Completion mode is on and working if suggestions are HIGHLIGHTED
        Completion mode makes it awkward to type names intellisense doesn't know about
		You can use ESC to cancel Intellisense. I don't love that, though.

Try to type SELECT * FROM sys.database with completion mode on 
    (using a space after the word)
*/

SELECT *
FROM sys.dat


/*
Toggle to suggestion mode with CTRL + ALT + Spacebar
    Suggestion mode is on and working if suggestions are outlined with a box 
	Now typing sys.database (spacebar) doesn't autocomplete
	(FYI, sys.database doesn't exist)
*/
 
SELECT *
FROM sys.dat



/* 
Demo: refreshing cache with intellisense
*/
USE master;
GO
/* Use CTRL + SHIFT + R to refresh cache.*/
SELECT CustomerTransactionID, CustomerID, TransactionTypeID, InvoiceID, PaymentMethodID, TransactionDate, AmountExcludingTax, TaxAmount, TransactionAmount, OutstandingBalance, FinalizationDate, IsFinalized, LastEditedBy, LastEditedWhen
FROM [Sales].[CustomerTransactions];
GO
















/* Why doesn't that work? 
Change the database name here from master to WideWorldImporters*/
USE BabbyNames;
GO

/* Use CTRL + SHIFT + r to refresh cache.*/
SELECT CustomerTransactionID, CustomerID, TransactionTypeID, InvoiceID, PaymentMethodID, TransactionDate, AmountExcludingTax, TaxAmount, TransactionAmount, OutstandingBalance, FinalizationDate, IsFinalized, LastEditedBy, LastEditedWhen
FROM [Sales].[CustomerTransactions];
GO



USE BabbyNames;
GO




/* 
Demo: intellisense uses a separate thread.
This becomes most apparent when you use SQL Server's Dedicated Admin Connection
SQL Server reserves a session for the DAC 
Only one admin can use it at a time
Save it for emergencies -- but it's REALLY useful when you need it

Use keyboard to access menus...
ALT , Q , C, H

Connect to: admin:FASTER01

Read the error
Run this query to verify who is using the DAC...
*/

SELECT 
	@@SPID as my_session_id,
	ses.*
FROM sys.dm_exec_sessions as ses
JOIN sys.endpoints as ep on ses.endpoint_id = ep.endpoint_id
WHERE ep.name = N'Dedicated Admin Connection';
GO

--Intellisense can't suggest when I'm connected to the DAC
select * from sys.da
GO


/*
Use keyboard to access menus...
ALT , Q , C, H

Connect to regular session (not DAC): FASTER01
*/


/*
Things to be aware of:

I've had cases where SSMS was driving up CPU. 
	I had a large script open.
	I disabled Intellisense and CPU dropped waaaaay down.


As of SSMS 17.2, Intellisense *IS* available for Azure SQL Database. 
	https://connect.microsoft.com/SQLServer/feedback/details/3100677/ssms-2016-would-be-nice-to-have-intellisense-on-azure-sql-databases
*/
 



 /* Question: How do you feel about intellisense? */








/*****************************************************************************
Problem: I have no idea what scripts I have open

Solution: Simplify what's shown in SSMS Tabs
*****************************************************************************/

/* Demo:
    Tools -> Options (ALT, t, o)
    Text Editor -> Editor Tab & Status Bar

	Or: In the Options window...
		CTRL + E
		Then type Tab into the search box

    Disable options you don't need

    Reopen this script
*/





 
/*****************************************************************************
Problem: I want to keep some scripts open all the time

Solution: Configure and control pinned tabs 
*****************************************************************************/

/* Demo
    Tools -> Options (ALT, t, o)
    Environment -> Tabs and Windows

    I think it makes sense to keep pinned tabs in a separate row

    Note: pinned files are 'forgotten' when you close SSMS
*/




 
/*****************************************************************************
Problem: I'm tired of typing stored procedure names

Solution: Assign shortcuts to favorite stored procedures
*****************************************************************************/

/* Built in shortcuts.. ALT + F1 = sp_help 

The sp_WhoIsActive procedure is a free download from Adam Machanic. 
Grab it at http://whoisactive.com.

I find sp_WhoIsActive to be extremely helpful, but it's hard to remmember the parameters!
Highlight the name of the procedure and hit ALT + F1.
F6 to toggle through results and copy paste.

*/
EXEC sp_WhoIsActive;
GO


/* Summary
I run sp_WhoIsActive a lot, and I'm tired of typing it.
Let's set a custom shortcut to call it with CTRL+0.

To set a keyboard shortcut for a procedure:

Click on the �Tools� menu in Management Studio, select �Options� <- or do ALT, t, o 
Go to �Environment� then �Keyboard� then �Query Shortcuts�
Add the command you want to call into one of the available shortcuts

*/



/* Demo:

Open the Tools -> Options Menu (ALT, t, o)
Go to �Environment� then �Keyboard� then �Query Shortcuts�
Set sp_WhoIsActive for a shortcut under CTRL + 0

Open a new session and test it out
*/

