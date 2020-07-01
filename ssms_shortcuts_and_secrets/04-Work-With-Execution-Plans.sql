/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/


*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*****************************************************************************
Problem: What the heck is going on in my query?

Solution: Display estimated and actual execution plans
*****************************************************************************/

USE WideWorldImporters;
GO


/* Review: what parameters does this take?
Hover with mouse
OR -- put cursor anywhere on name, then CTRL + K, CTRL + I 
    I remember this as "Control Komplete Info"
 */
EXEC [Integration].[GetSaleUpdates] 
GO
/* Reminder ... another way to do this: 
	Highlight the ENTIRE proc name (no spaces), 
	then hit ALT+F1 (built-in shortcut for sp_help) 
*/



/* 
Use CTRL + L to see an estimated execution plan.
This does NOT execute the query
Show the button that does the same thing.
 */
EXEC [Integration].[GetSaleUpdates] @LastCutoff = '2015-01-01', @NewCutoff = '2016-01-01'
GO

/* Use mouse to drag around the plan.
Use CTRL + Scroll Bar to zoom */


/* 
Use CTRL + M to toggle 'Actual Execution Plans'
Then execute the query (CTRL + E)
 */
EXEC [Integration].[GetSaleUpdates] @LastCutoff = '2015-01-01', @NewCutoff = '2016-01-01'
GO


/* F6 to toggle through results windows.
New in SSMS 17.2:
In the execution plan pane, hit: CTRL + F

Select Table contains stock

This will search the plan properties
Arrow through to see which nodes in the plan it finds

*/

