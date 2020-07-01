/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course: https://littlekendra.com/course/automatic-plan-correction-in-query-store/
*****************************************************************************/


USE BabbyNames;
GO

/* We have some indexes on agg.FirstNameByYear */

IF 0 = (SELECT COUNT(*) FROM 
    sys.indexes 
    WHERE name='ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES') 

CREATE INDEX ix_FirstNameByYearState_FirstNameId_StateCode_Gender_ReportYear_INCLUDES
    ON agg.FirstNameByYearState
        (FirstNameId, StateCode, Gender, ReportYear)
        INCLUDE (NameCount)
GO

/* OH NO! I created a nonclustered columnstore but left out NameCount, which this query needs.
There are even more problems in the predicates of the procedure, which we're about to create. */
IF 0 = (SELECT COUNT(*) FROM 
    sys.indexes 
    WHERE name='nccx_agg_FirstNameByYearState_oops') 

CREATE NONCLUSTERED COLUMNSTORE INDEX nccx_agg_FirstNameByYearState_oops 
    on agg.FirstNameByYearState (FirstNameId, StateCode, Gender, ReportYear);
GO

/* Here is our test procedure. It has some performance problems. */
CREATE OR ALTER PROCEDURE dbo.PopularNames
    @Threshold INT = NULL
AS
    SET NOCOUNT ON;

    with RunningTotal AS (
	    SELECT
		    fnby.FirstNameId,
            fnby.StateCode,
            fnby.Gender,
		    ReportYear,
		    SUM(NameCount) OVER (PARTITION BY fnby.FirstNameId, StateCode, Gender ORDER BY fnby.ReportYear) as TotalNamed
	    FROM agg.FirstNameByYearState as fnby
    ),
    RunningTotalPlusLag AS (
	    SELECT
		    FirstNameId,
            StateCode,
            Gender,
		    ReportYear,
		    TotalNamed,
		    LAG(TotalNamed, 1, 0) OVER (PARTITION BY FirstNameId, StateCode, Gender ORDER BY ReportYear) AS TotalNamedPriorYear
	    FROM RunningTotal
    )
    SELECT
	    fn.FirstName,
        RunningTotalPlusLag.StateCode,
        RunningTotalPlusLag.Gender,
	    RunningTotalPlusLag.ReportYear,
	    RunningTotalPlusLag.TotalNamed,
	    RunningTotalPlusLag.TotalNamedPriorYear
    INTO #results
    FROM RunningTotalPlusLag
    JOIN ref.FirstName as fn on
        RunningTotalPlusLag.FirstNameId=fn.FirstNameId
    WHERE 
        (@Threshold is NULL
         and TotalNamed >= 100 
	     and (TotalNamedPriorYear < 100  OR TotalNamedPriorYear IS NULL)
        )
        OR
        (TotalNamed >= @Threshold 
	    and (TotalNamedPriorYear < @Threshold  OR TotalNamedPriorYear IS NULL)
        )
    ORDER BY ReportYear DESC, StateCode;
GO


DECLARE @msg nvarchar(1000);
SET @msg = cast(sysdatetime() as nvarchar(23)) + N'- FAST PLAN gets batch mode window aggregate operator'
RAISERROR (@msg, 1,1) WITH NOWAIT;
GO

EXEC dbo.PopularNames @Threshold = 500000;
GO

EXEC dbo.PopularNames @Threshold = NULL;
GO

EXEC dbo.PopularNames @Threshold = 200000;
GO 40


DECLARE @msg nvarchar(1000);
SET @msg = cast(sysdatetime() as nvarchar(23)) + N'- oh no, a recompile comes along '
RAISERROR (@msg, 1,1) WITH NOWAIT;
exec sp_recompile 'dbo.PopularNames';
GO


DECLARE @msg nvarchar(1000);
SET @msg = cast(sysdatetime() as nvarchar(23)) + N'- SLOW PLAN gets row mode window spool :( '
RAISERROR (@msg, 1,1) WITH NOWAIT;

EXEC dbo.PopularNames @Threshold = NULL;
GO

EXEC dbo.PopularNames @Threshold = 500000;
GO

EXEC dbo.PopularNames @Threshold = 600000;
GO 75


DECLARE @msg nvarchar(1000);
SET @msg = cast(sysdatetime() as nvarchar(23)) + N'All done!'
RAISERROR (@msg, 1,1) WITH NOWAIT;
