<#
Copyright (c) 2017 SQL Workbooks LLC
Terms of Use: https://sqlworkbooks.com/terms-of-service/
Contact: help@sqlworkbooks.com
#>

# This script relies on stored procedures created by 003-Recompile-Hints.sql
# The script also assumes you're using a default SQL Server instance on the local server
# The script was tested on Windows Server 2012 R2 - your mileage may vary on lower versions


# Executes a stored procedure a specified amount of times in a loop
# Fills a dataset but does nothing with it - this is only for the purpose
# of watching performance counters while the procedures run.

function LoopStoredProcedure{
	param($Limit, $Connection, $Procedure, $Parameters=@{})

	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandType = [System.Data.CommandType]::StoredProcedure
	$SqlCmd.Connection = $Connection
	$SqlCmd.CommandText = $Procedure
	foreach($parameter in $Parameters.Keys){
 		[Void] $SqlCmd.Parameters.AddWithValue("@$parameter",$Parameters[$parameter])
 	}

	$Iterations=0
	while($Iterations -ne $Limit) {
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmd)
		$DataSet = New-Object System.Data.DataSet
		[Void] $SqlAdapter.Fill($DataSet)

		$DataSet.Dispose()
	    $Iterations++
	}

	$SqlConnection.Close()
	return "All done!"
}

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=.;Database=BabbyNames;Integrated Security=True"

$Duration = Measure-Command { LoopStoredProcedure -Limit 500 -Connection $SqlConnection -Procedure "dbo.MostPopularYearByNameRecompileHint" -Parameters @{FirstName="Mary"}}
Write-Output "Recompile hint = $($Duration.TotalSeconds) seconds"

$Duration = Measure-Command { LoopStoredProcedure -Limit 500 -Connection $SqlConnection -Procedure "dbo.MostPopularYearByNameRecompileInHeader" -Parameters @{FirstName="Mary"}}
Write-Output "Recompile hint in header = $($Duration.TotalSeconds) seconds"

$Duration = Measure-Command { LoopStoredProcedure -Limit 500 -Connection $SqlConnection -Procedure "dbo.MostPopularYearByName" -Parameters @{FirstName="Mary"}}
Write-Output "No recompile hint = $($Duration.TotalSeconds) seconds"
