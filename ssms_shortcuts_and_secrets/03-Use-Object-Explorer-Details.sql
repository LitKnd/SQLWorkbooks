/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/


*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO




/*****************************************************************************
Problem: I need to script out more than one index

Solution: Script out multiple objects at the same time
*****************************************************************************/

/* Demo:
Try to script out all the indexes on Sales.Customers from Object Explorer.
    Be sad for a moment.

Keep Object Explorer open!

Object Explorer Details comes to your rescue
    Open by pressing F7, or using View -> Object Explorer Details (ALT V, Arrow down)
    Navigate to Sales.Customers
    You can now select a range of indexes using the SHIFT key
    CTRL + A selects ALL
    Script em all as create to a new window

Click the 'Synchronize' button in Object Explorer Details
    Watch what happens in Object Explorer
*/






/*****************************************************************************
Problem: I need to find every ___ named ____ 

Solution: Search for objects and view properties (maybe)

I�m often hesitant to use this feature on production servers� I like it much more for dev servers and pre-production.

If you have hundreds of databases, or high number of objects in each database, be careful!

Think about it this way: when we use this search, we�re running a script where we can�t see the code.

Stopping it may be tricky if it takes too long or SSMS freezes up (and we all know that happens sometimes)
    What if it gets blocked?

So for production, I'd rather search in source control

But for non-production environments...
*****************************************************************************/


/* Demo:
Open Object Explorer and Object Explorer Details

Navigate to the WideWorldImporters database

Search for: or%

Search for: %a%

Click a row
    Right Click
    Select Synchronize

Use 'Back'
*/