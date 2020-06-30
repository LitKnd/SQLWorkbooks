/*****************************************************************************
Copyright (c) 2020 Kendra Little
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
http://creativecommons.org/licenses/by-nc-sa/4.0/

This script is from the online course https://littlekendra.com/course/how-to-decipher-cxpacket-waits-and-control-parallelism

*****************************************************************************/


/* ✋🏻 Doorstop ✋🏻  */
RAISERROR(N'Did you mean to run the whole thing?',20,1) WITH LOG;
GO


USE BabbyNames;
GO

/* Set cost threshold to the max */
exec sp_configure 'cost threshold for parallelism', 32767;
GO
RECONFIGURE
GO


/************************************************************ 
Can we force parallelism if the cost is below the threshold?
************************************************************/

/*
MAXDOP hints don't force parallelism.
They specify how many cores will be used IF a parallel plan is selected
Having an estimated cost for single-threaded execution above the threshold is a requirement for that
*/

--Validate
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender
    OPTION (MAXDOP 8);
GO


/* Same thing for database level maxdop */
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 8
GO  

SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Mister'
GROUP BY Gender;
GO


/* Reset */
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0
GO  






/************************************************************ 
What if I force a parallel plan with a USE PLAN hint?
************************************************************/

/* Copy the XML for the parallel plan.
 */
SELECT 
    qst.query_sql_text,
    qsp.is_forced_plan,
    qsq.query_id,
    qsp.plan_id,
    qsp.engine_version,
    qsp.compatibility_level,
    qsp.query_plan_hash,
    qsp.is_forced_plan,
    qsp.plan_forcing_type_desc,
    cast(qsp.query_plan as XML) as plan_xml
FROM sys.query_store_query as qsq
JOIN sys.query_store_query_text as qst on 
    qsq.query_text_id = qst.query_text_id
JOIN sys.query_store_plan as qsp on qsq.query_id = qsp.query_id
WHERE qst.query_sql_text like N'%fn.FirstName = ''Jacob''%';
GO


/* The parallel plan can be specified in a USE PLAN hint */
/* Note: Single quotes need to be escaped, I replaced ' with '' */
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender
    OPTION (USE PLAN'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.6" Build="14.0.1000.169">
  <BatchSequence>
    <Batch>
      <Statements>
        <StmtSimple StatementText="SELECT&#xD;&#xA;    fnbd.Gender,&#xD;&#xA;    COUNT(*) as SumNameCount&#xD;&#xA;FROM dbo.FirstNameByBirthDate fnbd&#xD;&#xA;JOIN ref.FirstName as fn on&#xD;&#xA;    fnbd.FirstNameId = fn.FirstNameId&#xD;&#xA;WHERE&#xD;&#xA;    fn.FirstName = ''Jacob''&#xD;&#xA;GROUP BY Gender" StatementId="1" StatementCompId="1" StatementType="SELECT" StatementSqlHandle="0x09009614953D761DE74E2CC912E40B67C0F80000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="0" StatementParameterizationType="0" RetrievedFromCache="false" StatementSubTreeCost="503.78" StatementEstRows="2" SecurityPolicyApplied="false" StatementOptmLevel="FULL" QueryHash="0x6DE939EC365666D3" QueryPlanHash="0x111129195537B896" CardinalityEstimationModelVersion="140">
          <StatementSetOptions QUOTED_IDENTIFIER="true" ARITHABORT="true" CONCAT_NULL_YIELDS_NULL="true" ANSI_NULLS="true" ANSI_PADDING="true" ANSI_WARNINGS="true" NUMERIC_ROUNDABORT="false" />
          <QueryPlan CachedPlanSize="64" CompileTime="5" CompileCPU="5" CompileMemory="528">
            <ThreadStat Branches="2" />
            <MissingIndexes>
              <MissingIndexGroup Impact="99.8827">
                <MissingIndex Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]">
                  <ColumnGroup Usage="EQUALITY">
                    <Column Name="[FirstNameId]" ColumnId="4" />
                  </ColumnGroup>
                  <ColumnGroup Usage="INCLUDE">
                    <Column Name="[Gender]" ColumnId="5" />
                  </ColumnGroup>
                </MissingIndex>
              </MissingIndexGroup>
            </MissingIndexes>
            <MemoryGrantInfo SerialRequiredMemory="2560" SerialDesiredMemory="3696" />
            <OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="92160" EstimatedPagesCached="57600" EstimatedAvailableDegreeOfParallelism="5" MaxCompileMemory="6113712" />
            <OptimizerStatsUsage>
              <StatisticsInfo LastUpdate="2018-06-15T17:27:55.00" ModificationCount="0" SamplingPercent="100" Statistics="[ix_FirstNameByBirthDate_Gender]" Table="[FirstNameByBirthDate]" Schema="[dbo]" Database="[BabbyNames]" />
              <StatisticsInfo LastUpdate="2018-05-29T11:26:29.73" ModificationCount="0" SamplingPercent="100" Statistics="[_WA_Sys_00000002_10AB74EC]" Table="[FirstName]" Schema="[ref]" Database="[BabbyNames]" />
              <StatisticsInfo LastUpdate="2018-06-15T17:25:27.21" ModificationCount="0" SamplingPercent="0.536981" Statistics="[_WA_Sys_00000004_36D11DD4]" Table="[FirstNameByBirthDate]" Schema="[dbo]" Database="[BabbyNames]" />
              <StatisticsInfo LastUpdate="2018-05-29T11:26:34.59" ModificationCount="0" SamplingPercent="100" Statistics="[pk_FirstName_FirstNameId]" Table="[FirstName]" Schema="[ref]" Database="[BabbyNames]" />
            </OptimizerStatsUsage>
            <RelOp NodeId="1" PhysicalOp="Compute Scalar" LogicalOp="Compute Scalar" EstimateRows="2" EstimateIO="0" EstimateCPU="2e-007" AvgRowSize="12" EstimatedTotalSubtreeCost="503.78" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
              <OutputList>
                <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                <ColumnReference Column="Expr1002" />
              </OutputList>
              <ComputeScalar>
                <DefinedValues>
                  <DefinedValue>
                    <ColumnReference Column="Expr1002" />
                    <ScalarOperator ScalarString="CONVERT_IMPLICIT(int,[globalagg1004],0)">
                      <Convert DataType="int" Style="0" Implicit="1">
                        <ScalarOperator>
                          <Identifier>
                            <ColumnReference Column="globalagg1004" />
                          </Identifier>
                        </ScalarOperator>
                      </Convert>
                    </ScalarOperator>
                  </DefinedValue>
                </DefinedValues>
                <RelOp NodeId="2" PhysicalOp="Stream Aggregate" LogicalOp="Aggregate" EstimateRows="2" EstimateIO="0" EstimateCPU="7e-006" AvgRowSize="16" EstimatedTotalSubtreeCost="503.78" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                  <OutputList>
                    <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                    <ColumnReference Column="globalagg1004" />
                  </OutputList>
                  <StreamAggregate>
                    <DefinedValues>
                      <DefinedValue>
                        <ColumnReference Column="globalagg1004" />
                        <ScalarOperator ScalarString="SUM([partialagg1003])">
                          <Aggregate Distinct="0" AggType="SUM">
                            <ScalarOperator>
                              <Identifier>
                                <ColumnReference Column="partialagg1003" />
                              </Identifier>
                            </ScalarOperator>
                          </Aggregate>
                        </ScalarOperator>
                      </DefinedValue>
                    </DefinedValues>
                    <GroupBy>
                      <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                    </GroupBy>
                    <RelOp NodeId="3" PhysicalOp="Sort" LogicalOp="Sort" EstimateRows="10" EstimateIO="0.0112613" EstimateCPU="0.000151838" AvgRowSize="16" EstimatedTotalSubtreeCost="503.78" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                      <OutputList>
                        <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                        <ColumnReference Column="partialagg1003" />
                      </OutputList>
                      <MemoryFractions Input="0.028169" Output="1" />
                      <Sort Distinct="0">
                        <OrderBy>
                          <OrderByColumn Ascending="1">
                            <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                          </OrderByColumn>
                        </OrderBy>
                        <RelOp NodeId="4" PhysicalOp="Parallelism" LogicalOp="Gather Streams" EstimateRows="10" EstimateIO="0" EstimateCPU="0.0285054" AvgRowSize="16" EstimatedTotalSubtreeCost="503.769" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                          <OutputList>
                            <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                            <ColumnReference Column="partialagg1003" />
                          </OutputList>
                          <Parallelism>
                            <RelOp NodeId="5" PhysicalOp="Hash Match" LogicalOp="Partial Aggregate" EstimateRows="10" EstimateIO="0" EstimateCPU="0.0264784" AvgRowSize="16" EstimatedTotalSubtreeCost="503.74" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                              <OutputList>
                                <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                <ColumnReference Column="partialagg1003" />
                              </OutputList>
                              <MemoryFractions Input="0" Output="0" />
                              <Hash>
                                <DefinedValues>
                                  <DefinedValue>
                                    <ColumnReference Column="partialagg1003" />
                                    <ScalarOperator ScalarString="COUNT(*)">
                                      <Aggregate Distinct="0" AggType="COUNT*" />
                                    </ScalarOperator>
                                  </DefinedValue>
                                </DefinedValues>
                                <HashKeysBuild>
                                  <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                </HashKeysBuild>
                                <BuildResidual>
                                  <ScalarOperator ScalarString="[BabbyNames].[dbo].[FirstNameByBirthDate].[Gender] as [fnbd].[Gender] = [BabbyNames].[dbo].[FirstNameByBirthDate].[Gender] as [fnbd].[Gender]">
                                    <Compare CompareOp="IS">
                                      <ScalarOperator>
                                        <Identifier>
                                          <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                        </Identifier>
                                      </ScalarOperator>
                                      <ScalarOperator>
                                        <Identifier>
                                          <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                        </Identifier>
                                      </ScalarOperator>
                                    </Compare>
                                  </ScalarOperator>
                                </BuildResidual>
                                <RelOp NodeId="6" PhysicalOp="Hash Match" LogicalOp="Inner Join" EstimateRows="8572.63" EstimateIO="0" EstimateCPU="139.733" AvgRowSize="9" EstimatedTotalSubtreeCost="503.714" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                                  <OutputList>
                                    <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                  </OutputList>
                                  <MemoryFractions Input="1" Output="0.971831" />
                                  <Hash>
                                    <DefinedValues />
                                    <HashKeysBuild>
                                      <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                    </HashKeysBuild>
                                    <HashKeysProbe>
                                      <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="FirstNameId" />
                                    </HashKeysProbe>
                                    <RelOp NodeId="7" PhysicalOp="Bitmap" LogicalOp="Bitmap Create" EstimateRows="1" EstimateIO="0" EstimateCPU="0.0285019" AvgRowSize="11" EstimatedTotalSubtreeCost="0.538126" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                                      <OutputList>
                                        <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                      </OutputList>
                                      <Bitmap>
                                        <DefinedValues>
                                          <DefinedValue>
                                            <ColumnReference Column="Bitmap1005" />
                                          </DefinedValue>
                                        </DefinedValues>
                                        <HashKeys>
                                          <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                        </HashKeys>
                                        <RelOp NodeId="8" PhysicalOp="Parallelism" LogicalOp="Distribute Streams" EstimateRows="1" EstimateIO="0" EstimateCPU="0.0285019" AvgRowSize="11" EstimatedTotalSubtreeCost="0.538126" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                                          <OutputList>
                                            <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                          </OutputList>
                                          <Parallelism PartitioningType="Broadcast">
                                            <RelOp NodeId="9" PhysicalOp="Clustered Index Scan" LogicalOp="Clustered Index Scan" EstimateRows="1" EstimatedRowsRead="97310" EstimateIO="0.355718" EstimateCPU="0.107198" AvgRowSize="21" EstimatedTotalSubtreeCost="0.462916" TableCardinality="97310" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                                              <OutputList>
                                                <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                              </OutputList>
                                              <IndexScan Ordered="0" ForcedIndex="0" ForceScan="0" NoExpandHint="0" Storage="RowStore">
                                                <DefinedValues>
                                                  <DefinedValue>
                                                    <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstNameId" />
                                                  </DefinedValue>
                                                </DefinedValues>
                                                <Object Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Index="[pk_FirstName_FirstNameId]" Alias="[fn]" IndexKind="Clustered" Storage="RowStore" />
                                                <Predicate>
                                                  <ScalarOperator ScalarString="[BabbyNames].[ref].[FirstName].[FirstName] as [fn].[FirstName]=''Jacob''">
                                                    <Compare CompareOp="EQ">
                                                      <ScalarOperator>
                                                        <Identifier>
                                                          <ColumnReference Database="[BabbyNames]" Schema="[ref]" Table="[FirstName]" Alias="[fn]" Column="FirstName" />
                                                        </Identifier>
                                                      </ScalarOperator>
                                                      <ScalarOperator>
                                                        <Const ConstValue="''Jacob''" />
                                                      </ScalarOperator>
                                                    </Compare>
                                                  </ScalarOperator>
                                                </Predicate>
                                              </IndexScan>
                                            </RelOp>
                                          </Parallelism>
                                        </RelOp>
                                      </Bitmap>
                                    </RelOp>
                                    <RelOp NodeId="10" PhysicalOp="Clustered Index Scan" LogicalOp="Clustered Index Scan" EstimateRows="1.52687e+008" EstimatedRowsRead="1.52687e+008" EstimateIO="329.851" EstimateCPU="33.5912" AvgRowSize="12" EstimatedTotalSubtreeCost="363.442" TableCardinality="1.52687e+008" Parallel="1" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row">
                                      <OutputList>
                                        <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="FirstNameId" />
                                        <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                      </OutputList>
                                      <IndexScan Ordered="0" ForcedIndex="0" ForceScan="0" NoExpandHint="0" Storage="RowStore">
                                        <DefinedValues>
                                          <DefinedValue>
                                            <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="FirstNameId" />
                                          </DefinedValue>
                                          <DefinedValue>
                                            <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="Gender" />
                                          </DefinedValue>
                                        </DefinedValues>
                                        <Object Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Index="[pk_FirstNameByBirthDate_FirstNameByBirthDateId]" Alias="[fnbd]" IndexKind="Clustered" Storage="RowStore" />
                                        <Predicate>
                                          <ScalarOperator ScalarString="PROBE([Bitmap1005],[BabbyNames].[dbo].[FirstNameByBirthDate].[FirstNameId] as [fnbd].[FirstNameId],N''[IN ROW]'')">
                                            <Intrinsic FunctionName="PROBE">
                                              <ScalarOperator>
                                                <Identifier>
                                                  <ColumnReference Column="Bitmap1005" />
                                                </Identifier>
                                              </ScalarOperator>
                                              <ScalarOperator>
                                                <Identifier>
                                                  <ColumnReference Database="[BabbyNames]" Schema="[dbo]" Table="[FirstNameByBirthDate]" Alias="[fnbd]" Column="FirstNameId" />
                                                </Identifier>
                                              </ScalarOperator>
                                              <ScalarOperator>
                                                <Const ConstValue="N''[IN ROW]''" />
                                              </ScalarOperator>
                                            </Intrinsic>
                                          </ScalarOperator>
                                        </Predicate>
                                      </IndexScan>
                                    </RelOp>
                                  </Hash>
                                </RelOp>
                              </Hash>
                            </RelOp>
                          </Parallelism>
                        </RelOp>
                      </Sort>
                    </RelOp>
                  </StreamAggregate>
                </RelOp>
              </ComputeScalar>
            </RelOp>
          </QueryPlan>
        </StmtSimple>
      </Statements>
    </Batch>
  </BatchSequence>
</ShowPlanXML>
')

GO




/************************************************************ 
What if I force a parallel plan with Query Store? 
SQL Server 2016+

************************************************************/
SELECT 
    qst.query_sql_text,
    qsq.query_id,
    qsp.plan_id,
    qsp.engine_version,
    qsp.compatibility_level,
    qsp.query_plan_hash,
    qsp.plan_forcing_type_desc,
    cast(qsp.query_plan as XML) as plan_xml
FROM sys.query_store_query as qsq
JOIN sys.query_store_query_text as qst on 
    qsq.query_text_id = qst.query_text_id
JOIN sys.query_store_plan as qsp on qsq.query_id = qsp.query_id
WHERE qst.query_sql_text like N'%fn.FirstName = ''Jacob''%';
GO


/* Plug in the query id and the plan id */
exec sp_query_store_force_plan @query_id=121, @plan_id=127;
GO

/* Look at estimated plan
Then run with actual plans on
Then look at estimated plans again */
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

exec sp_query_store_unforce_plan @query_id=121, @plan_id=127;
GO


/* We can only force a parallel plan for a query with query store if:
There's a parallel plan in Query Store for the EXACT same query text
(including hints)
*/






/************************************************************ 
What if I freeze a parallel plan with a Plan Guide?
SQL Server 2008+ 

In this case we must have a plan in the cache. 
The plan guide is basically doing the same as the 'USE HINT' option above.
************************************************************/

/* Copy the plan_handle we want */
SELECT 
    qs.plan_handle,
    qs.last_dop,
    st.[text],
    qs.statement_start_offset,
    cast(qp.query_plan as XML) as query_plan
FROM sys.dm_exec_query_stats AS qs  
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st  
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) AS qp  
WHERE st.[text]
    LIKE N'%fn.FirstName = ''Jacob''%'; 
GO

/* Plug in the handle */
DECLARE 
    @handle varbinary(64),
    @offset int;  

SELECT 
    @handle = qs.plan_handle,
    @offset = qs.statement_start_offset  
FROM sys.dm_exec_query_stats AS qs  
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st  
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) AS qp  
WHERE 
    qs.plan_handle = 0x06000500E764081E907C33595102000001000000000000000000000000000000000000000000000000000000;
 
EXECUTE sys.sp_create_plan_guide_from_handle @name =  N'FreezeParallelPlan',  
    @plan_handle = @handle,  
    @statement_start_offset = @offset;  
GO


/* Look at estimated plan
Run with actual.
The text must match EXACTLY for the plan guide to kick in
For example, if you include this comment, that doesn't match*/
SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO



EXEC sys.sp_control_plan_guide N'DROP', N'FreezeParallelPlan';  
GO



/************************************************************ 
What if I don't have a parallel plan in cache or in Query Store?
There are unsupported ways to (sometimes) get a parallel plan

Both of these are undocumented and unsupported by Microsoft:
    Trace Flag 8649
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))  -- 2016 SP1 CU2+
************************************************************/



SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender
    OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO

--Note that it's not in this list. Why? Unsupported.
--Do I really want to leave this hint in my code?
SELECT name
FROM sys.dm_exec_valid_use_hints;
GO


--Repeat: This trace flag is unsupported
--We are enabling it just for our session
--This can still be useful in SQL Server 2016+, because I don't have to change
--the query text. 
--I can 'inject' a paralle query plan into cache and Query Store for the old query text!
DBCC TRACEON (8649, 0);
GO

DBCC TRACESTATUS;
GO

SELECT
    fnbd.Gender,
    COUNT(*) as SumNameCount
FROM dbo.FirstNameByBirthDate fnbd
JOIN ref.FirstName as fn on
    fnbd.FirstNameId = fn.FirstNameId
WHERE
    fn.FirstName = 'Jacob'
GROUP BY Gender;
GO

--What is the estimated cost?

DBCC TRACEOFF (8649, 0);
GO

--Now that I've got this plan in cache, I can freeze it / force it, etc.