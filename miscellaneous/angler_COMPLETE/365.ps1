# M365 Deep Flag Search Script
# Comprehensive search for "flag{" strings across Microsoft 365 environment

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$Password
)

# Convert SecureString to credential
$Credential = New-Object System.Management.Automation.PSCredential($Username, $Password)

Write-Host "=== M365 Deep Flag Search Script ===" -ForegroundColor Cyan
Write-Host "Connecting to Microsoft 365..." -ForegroundColor Yellow

# Install required modules if not present
$modules = @('ExchangeOnlineManagement', 'Microsoft.Graph', 'Microsoft.Online.SharePoint.PowerShell', 'PnP.PowerShell')
foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        } catch {
            Write-Host "  Warning: Could not install $module - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Results array
$results = @()

# Function to search for flag pattern
function Search-ForFlag {
    param($Object, $Property, $Location)
    
    if ($null -ne $Object.$Property -and $Object.$Property -match "flag\{") {
        # Get object name with fallback
        $objName = $Object.DisplayName
        if ([string]::IsNullOrEmpty($objName)) { $objName = $Object.Name }
        if ([string]::IsNullOrEmpty($objName)) { $objName = $Object.Identity }
        if ([string]::IsNullOrEmpty($objName)) { $objName = $Object.Title }
        if ([string]::IsNullOrEmpty($objName)) { $objName = $Object.UserPrincipalName }
        if ([string]::IsNullOrEmpty($objName)) { $objName = "Unknown" }
        
        $result = [PSCustomObject]@{
            Location = $Location
            Property = $Property
            Value = $Object.$Property
            ObjectName = $objName
        }
        return $result
    }
    return $null
}

# Function to search all properties of an object
function Search-AllProperties {
    param($Object, $Location)
    
    $foundItems = @()
    $properties = $Object.PSObject.Properties.Name
    
    foreach ($prop in $properties) {
        try {
            $value = $Object.$prop
            if ($null -ne $value -and $value -is [string] -and $value -match "flag\{") {
                $found = Search-ForFlag -Object $Object -Property $prop -Location $Location
                if ($found) { $foundItems += $found }
            }
        } catch {
            # Skip properties that can't be accessed
        }
    }
    
    return $foundItems
}

try {
    # Connect to Exchange Online
    Write-Host "`n[1/12] Connecting to Exchange Online..." -ForegroundColor Yellow
    Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false -ErrorAction Stop
    
    # Search Unified Groups
    Write-Host "[2/12] Searching Unified Groups (Teams)..." -ForegroundColor Yellow
    $groups = Get-UnifiedGroup -ResultSize Unlimited
    foreach ($group in $groups) {
        $foundItems = Search-AllProperties -Object $group -Location "UnifiedGroup"
        foreach ($item in $foundItems) {
            $results += $item
            Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
        }
    }
    
    # Search Distribution Groups
    Write-Host "[3/12] Searching Distribution Groups..." -ForegroundColor Yellow
    $distGroups = Get-DistributionGroup -ResultSize Unlimited
    foreach ($group in $distGroups) {
        $foundItems = Search-AllProperties -Object $group -Location "DistributionGroup"
        foreach ($item in $foundItems) {
            $results += $item
            Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
        }
    }
    
    # Search Dynamic Distribution Groups
    Write-Host "[4/12] Searching Dynamic Distribution Groups..." -ForegroundColor Yellow
    try {
        $dynGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
        foreach ($group in $dynGroups) {
            $foundItems = Search-AllProperties -Object $group -Location "DynamicDistributionGroup"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Mailboxes
    Write-Host "[5/12] Searching Mailboxes..." -ForegroundColor Yellow
    $mailboxes = Get-Mailbox -ResultSize Unlimited
    foreach ($mailbox in $mailboxes) {
        $foundItems = Search-AllProperties -Object $mailbox -Location "Mailbox"
        foreach ($item in $foundItems) {
            $results += $item
            Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
        }
    }
    
    # Search Contacts
    Write-Host "[6/12] Searching Mail Contacts..." -ForegroundColor Yellow
    try {
        $contacts = Get-MailContact -ResultSize Unlimited
        foreach ($contact in $contacts) {
            $foundItems = Search-AllProperties -Object $contact -Location "MailContact"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Transport Rules
    Write-Host "[7/12] Searching Transport Rules..." -ForegroundColor Yellow
    try {
        $transportRules = Get-TransportRule
        foreach ($rule in $transportRules) {
            $foundItems = Search-AllProperties -Object $rule -Location "TransportRule"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Organization Config
    Write-Host "[8/12] Searching Organization Config..." -ForegroundColor Yellow
    try {
        $orgConfig = Get-OrganizationConfig
        $foundItems = Search-AllProperties -Object $orgConfig -Location "OrganizationConfig"
        foreach ($item in $foundItems) {
            $results += $item
            Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Connect to Microsoft Graph
    Write-Host "[9/12] Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -NoWelcome -ErrorAction Stop
    
    # Search Azure AD Users
    Write-Host "[10/12] Searching Azure AD Users..." -ForegroundColor Yellow
    $users = Get-MgUser -All -Property DisplayName,UserPrincipalName,JobTitle,Department,CompanyName,OfficeLocation
    foreach ($user in $users) {
        $props = @('DisplayName', 'JobTitle', 'Department', 'CompanyName', 'OfficeLocation')
        foreach ($prop in $props) {
            $found = Search-ForFlag -Object $user -Property $prop -Location "User"
            if ($found) { 
                $results += $found
                Write-Host "  [FOUND] $($found.Location) - $($found.Property): $($found.Value)" -ForegroundColor Green
            }
        }
    }
    
    # Search Azure AD Groups
    Write-Host "[11/12] Searching Azure AD Groups..." -ForegroundColor Yellow
    $mgGroups = Get-MgGroup -All
    foreach ($group in $mgGroups) {
        $foundItems = Search-AllProperties -Object $group -Location "AzureADGroup"
        foreach ($item in $foundItems) {
            $results += $item
            Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
        }
    }
    
    # Search Applications
    Write-Host "[12/12] Searching Azure AD Applications..." -ForegroundColor Yellow
    try {
        $apps = Get-MgApplication -All
        foreach ($app in $apps) {
            $foundItems = Search-AllProperties -Object $app -Location "Application"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Service Principals
    Write-Host "[BONUS] Searching Service Principals..." -ForegroundColor Yellow
    try {
        $sps = Get-MgServicePrincipal -All
        foreach ($sp in $sps) {
            $foundItems = Search-AllProperties -Object $sp -Location "ServicePrincipal"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Domains
    Write-Host "[BONUS] Searching Domains..." -ForegroundColor Yellow
    try {
        $domains = Get-MgDomain -All
        foreach ($domain in $domains) {
            $foundItems = Search-AllProperties -Object $domain -Location "Domain"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Administrative Units
    Write-Host "[BONUS] Searching Administrative Units..." -ForegroundColor Yellow
    try {
        $adminUnits = Get-MgDirectoryAdministrativeUnit -All
        foreach ($unit in $adminUnits) {
            $foundItems = Search-AllProperties -Object $unit -Location "AdministrativeUnit"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
    # Search Organization Branding (includes UserIdLabel)
    Write-Host "[BONUS] Searching Organization Branding..." -ForegroundColor Yellow
    try {
        $orgs = Get-MgOrganization -All
        foreach ($org in $orgs) {
            # Search main organization object
            $foundItems = Search-AllProperties -Object $org -Location "Organization"
            foreach ($item in $foundItems) {
                $results += $item
                Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
            }
            
            # Search organization branding
            try {
                $branding = Get-MgOrganizationBranding -OrganizationId $org.Id -ErrorAction SilentlyContinue
                if ($branding) {
                    $foundItems = Search-AllProperties -Object $branding -Location "OrganizationBranding"
                    foreach ($item in $foundItems) {
                        $results += $item
                        Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
                    }
                }
                
                # Search localized branding
                $localizedBranding = Get-MgOrganizationBrandingLocalization -OrganizationId $org.Id -All -ErrorAction SilentlyContinue
                foreach ($locBrand in $localizedBranding) {
                    $foundItems = Search-AllProperties -Object $locBrand -Location "OrganizationBrandingLocalized"
                    foreach ($item in $foundItems) {
                        $results += $item
                        Write-Host "  [FOUND] $($item.Location) - $($item.Property): $($item.Value)" -ForegroundColor Green
                    }
                }
            } catch {
                # Branding might not be configured or accessible
            }
        }
    } catch {
        Write-Host "  Skipping: $_" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    # Disconnect
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}

# Display results
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
    Write-Host "`nTotal flags found: $($results.Count)" -ForegroundColor Green
    
    # Export to CSV
    $outputFile = "M365_Flags_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $outputFile -NoTypeInformation
    Write-Host "Results exported to: $outputFile" -ForegroundColor Yellow
} else {
    Write-Host "No flags found." -ForegroundColor Yellow
}