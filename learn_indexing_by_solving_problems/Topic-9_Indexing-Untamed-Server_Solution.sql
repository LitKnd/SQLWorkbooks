/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/learn-indexing-by-solving-problems-sql-seminar-june-2018/

*****************************************************************************/

RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO



/*********************************************************************
We're going to look at this from two perspectives....
First, Query Store

Then, plan cache and missing index DMVs

In each one, we're going to see how we would make our top two index recommendations to test.

*********************************************************************/




/*********************************************************************
Query Store...
If I have SQL Server 2016+ available, I want to test and use this to get
at those juicy execution plans
*********************************************************************/

--Query Store isn't on by default
--You need to enable it and configure collection and retention options
--Start light - you control how much data it stores!
--Make sure you have at least CU1 if you're not running enterprise or 
--	dev edition, it fixes an important cleanup bug: https://support.microsoft.com/en-us/kb/3178297


/*
Open 'Top Resource Consuming Queries' Report
    This is a built-in report
    Reports show up automagically after Query Store is enabled for the database

Go to the time period where you care about performance
	(The "Configure" button at top right does this)

Make sure you're on the "Duration - Total" view

The top query has two plans-- show them
    Neither plan is asking for an index
        The faster one is *scanning* an NC index.
        The nested loop plan is much slower
        Hover over the nonclustered index scan
            Look at the predicate
            Can we get rid of that with an index change?
        Hover over the key lookup
            Is there a non-seek predicate?
            Look at the output list
            How can we get rid of the key lookup?
        Would this change also prevent the NC index scan plan?
            Change to the index scan plan
            Look at the predicate and output

Recommendation for #1 slow query:
    Add Gender Key and  NameCount included column 
        to agg.FirstNameByYear.ix_FirstNameByYear_FirstNameId
    Gender is already effectively there, but the query needs it, so let's be explicit
    Giving it NameCount will eliminate the key lookup and index scan options

    Long term, to make this seekable the code needs a rewrite of one of these flavors to get rid of the "or" logic...
        Dynamic SQL
        Sub-procedures
*/

/* Let's look at index usage on the table for a sanity check */
/* This is the free sp_BlitzIndex procedure from Brent Ozar Unlimited */
/* If you pass in a database, schema, and index name it lists existing and missing indexes for the table */
exec sp_BlitzIndex 
    @DatabaseName='BabbyNames', 
    @SchemaName='agg', 
    @TableName='FirstNameByYear';
GO



/*********************************************************************
If we didn't have Query Store, we'd look at the Plan Cache and Missing Index DMVs...
*********************************************************************/


/* sp_BlitzCache looks at the plan cache. */
/* This will have info since the instance was restarted, but we don't know what's missing. */
/* Recompile hints and memory pressure can cause gaps. */
exec sp_BlitzCache @HideSummary=1;
GO


/*  #1 Query ...
Look at the top two lines
    They're related!
    Look at the plan.
    Familiar?

    We only see the nested loop plan. Why is that?
    Go back to BlitzCache and look at
        warnings
        average reads
    We could decode that we need to add the included column to the index from this as well
        It's just harder to figure out
        And we don't see that clustered index scan plan

*/

/* #2 Query ...
    Look at the next line
    Familiar?
    Same query we saw in querystore...
    We can decode the index in the same way.
*/

/* Here's one of the big problems... */
/* Let's say something flushes the plan for our #1 procedure out of cache */
exec sp_recompile 'dbo.NameCountByGender';
GO

/* Can we see it here anymore? */
exec sp_BlitzCache @HideSummary=1;
GO




/* We can run BlitzIndex with no parameters and have it give us warnings about issues,
	including our biggest tables to index. */
/* Do we see agg.FirstNameByYear warned about in here? */
exec sp_BlitzIndex;
GO

/*
That's because that slowest query didn't flag a missing index request...
	because of the way the TSQL was written.
If we keep tuning the server and it's slow again, we may find it later in the query plan cache.
It's easier when we track our slowest queries with a tool like Query Store.
*/



/* FYI, this exists! */
exec sp_BlitzQueryStore @DatabaseName = 'BabbyNames'
GO