#################################################
# HelloID-Conn-Prov-Target-FreshService-Requesters-Create
# PowerShell V2
#################################################

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
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

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

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }
        if ($correlationField -ne 'primary_email') {
            throw 'Correlation is enabled but account correlation field is set incorrectly. This target system only supports correlation based on primary_email'
        }

        # Check if an existing requester can be correlated
        $emailValue = [System.Web.HttpUtility]::UrlEncode($actionContext.Data.primary_email)
        $splatGetParams = @{
            Uri     = "$($baseURL)/api/v2/requesters?email=$($emailValue)"
            Method  = 'GET'
            Headers = $headers
        }

        $correlatedAccount = (Invoke-RestMethod @splatGetParams).requesters

    }

    if ($correlatedAccount.Count -eq 0) {
        $action = 'CreateAccount'
    } elseif ($correlatedAccount.Count -eq 1) {
        $action = 'CorrelateAccount'
    } elseif ($correlatedAccount.Count -gt 1) {
        throw "Multiple accounts found for person where $correlationField is: [$correlationValue]"
    }

    # Process
    switch ($action) {
        'CreateAccount' {
            $splatCreateParams = @{
                Uri     = "$($baseURL)/api/v2/requesters"
                Method  = 'POST'
                Headers = $headers
                Body    = $actionContext.Data | ConvertTo-Json
            }

            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating FreshService-Requesters account'

                $createdAccount = (Invoke-RestMethod @splatCreateParams).requester

                $splatDeactivateParams = @{
                    Uri     = "$($baseURL)/api/v2/requesters/$($createdAccount.id)"
                    Method  = 'DELETE'
                    Headers = $headers
                }

                [void](Invoke-RestMethod @splatDeactivateParams)

                $outputContext.AccountReference = $createdAccount.Id
                $createdAccount = $createdAccount | select-object $actioncontext.data.PSobject.Properties.Name
                $outputContext.Data = $createdAccount
            } else {
                Write-Information '[DryRun] Create and correlate FreshService-Requesters account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating FreshService-Requesters account'
            
            $outputContext.AccountReference = $correlatedAccount.Id
            $outputContext.AccountCorrelated = $true
            $correlatedAccount = $correlatedAccount | Select-Object $actioncontext.data.PSobject.Properties.Name
            $outputContext.Data = $correlatedAccount
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-FreshService-RequestersError -ErrorObject $ex
        $auditLogMessage = "Could not create or correlate FreshService-Requesters account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditLogMessage = "Could not create or correlate FreshService-Requesters account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}