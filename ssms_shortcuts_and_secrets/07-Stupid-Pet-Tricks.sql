/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/ssms-shortcuts-secrets/




DISCLAIMER: 
    SERIOUSLY DON'T DO THESE THINGS
    THEY ARE ACTUALLY BAD
    THAT IS NOT A JOKE
*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*****************************************************************************
Problem: The 'GO' batch terminator is so pushy.

Bad Solution: Change it
*****************************************************************************/

/* Demo:
    Tools -> Options (ALT T, O)
    Query Execution
    Change Batch Separator to: GOO
*/


/* Does this work? */
SELECT  *
FROM sys.databases;
GO


/* Try it in a new session */


/* Reset the batch separator */




/*****************************************************************************
Problem: I hate a table and NOBODY SHOULD SEE IT

Terrible Solution: Hide it from SSMS
*****************************************************************************/

/* This lovely hack is courtesy Kenneth Fisher
https://sqlstudies.com/2017/04/03/hiding-tables-in-ssms-object-explorer-using-extended-properties/

As he says, this is strange! 
I think the main reason to know about this is just that someone could do it TO you.
*/

/* Demo: View Application.Cities in Object Explorer.
    Then hide it...*/

USE WideWorldImporters;
GO

EXEC sp_addextendedproperty
    @name = N'microsoft_database_tools_support',
    @value = 'Hide',
    @level0type = N'Schema', @level0name = 'Application',
    @level1type = N'Table', @level1name = 'Cities';
GO

/* Refresh Tables in Object Explorer.
What the...*/

/* It still exists and we have permissions to it... */
SELECT *
FROM sys.objects
WHERE name='Cities';
GO

SELECT *
FROM Application.Cities;
GO


/* If you wanted to monitor for this, you could use a simple
query like this...
*/
SELECT *
FROM sys.extended_properties
WHERE name='microsoft_database_tools_support';
GO

/*
But if you're concerned someone with sysadmin permissions is
going to do this, you may have a human resources problem more than a 
monitoring problem.
*/

/* Remove the extended property */
EXEC sp_dropextendedproperty
    @name = N'microsoft_database_tools_support',
    @level0type = N'Schema', @level0name = 'Application',
    @level1type = N'Table', @level1name = 'Cities';
GO

/* Refresh the table list */








