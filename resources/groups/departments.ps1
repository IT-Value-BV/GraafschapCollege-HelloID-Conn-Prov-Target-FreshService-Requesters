##########################################################
# HelloID-Conn-Prov-Target-FreshService-Requesters-Resources-Group
# PowerShell V2
##########################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-FreshService-RequestersError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        } catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)]"
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    Write-Information "Creating [$($resourceContext.SourceData.Count)] resources"
    $outputContext.Success = $true

    # Connect to FreshService API
    $baseURL = $actionContext.Configuration.TenantURL.TrimEnd('/')
    $token   = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes(
            ('{0}:{1}' -f $actionContext.Configuration.APIKey, $null)
        )
    )

    $headers = @{
        "Authorization" = "Basic $token"
        "Content-Type"  = "application/json"
    }

    # Get all current departments
    $splatGetParams = @{
        Uri     = "$($baseURL)/api/v2/departments"
        Method  = 'GET'
        Headers = $headers
    }

    $currentDepartments = (Invoke-RestMethod @splatGetParams).departments

    foreach ($resource in $resourceContext.SourceData) {
        try {
            <# Resource creation preview uses a timeout of 30 seconds while actual run has timeout of 10 minutes #>
            $targetDept = $currentDepartments | Where-Object {$_.name -eq $resource.DisplayName}

            # If resource does not exist
            if (-not $targetDept) {
    
                $splatCreateParams = @{
                    Uri     = "$($baseURL)/api/v2/departments"
                    Method  = 'POST'
                    Headers = $headers
                    Body    = @{
                        #id          = $resource.externalId
                        name        = $resource.DisplayName
                        description = 'Created by HelloID'
                    } | ConvertTo-Json
                }

                if (-not ($actionContext.DryRun -eq $True)) {
                    Write-Information "Create [$($resource)] FreshService-Requesters resource"
                    [void](Invoke-RestMethod @splatCreateParams)

                } else {
                    Write-Information "[DryRun] Create FreshService-Requesters [$($resource)] resource, will be executed during enforcement"
                }

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message =  "Created resource: [$($resource)]"
                        IsError = $false
                    })
            }
        } catch {
            $outputContext.Success =$false
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
                $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObj = Resolve-FreshService-RequestersError -ErrorObject $ex
                $auditLogMessage = "Could not create FreshService-Requesters resource. Error: $($errorObj.FriendlyMessage)"
                Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
            } else {
                $auditLogMessage = "Could not create FreshService-Requesters resource. Error: $($ex.Exception.Message)"
                Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
            }
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = $auditLogMessage
                IsError = $true
            })
        }
    }
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-FreshService-RequestersError -ErrorObject $ex
        $auditLogMessage = "Could not create FreshService-Requesters resource. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not create FreshService-Requesters resource. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Message = $auditLogMessage
        IsError = $true
    })
}
