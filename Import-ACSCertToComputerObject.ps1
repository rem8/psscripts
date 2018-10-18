<#
.SYNOPSIS
Script allows you to easily import your certificate into computer object in Active Directory for ACS Forwarder in untrusted domain or workgroup. It import CER file same way as Name Mappings do in AD storing value inside altsecurityidentities property.
.DESCRIPTION
The solution consists of importing CER file to AD Computer object from disk or share where they are stored. The requirement is to have CER file in <hostname>.CER file format (no FQDN, no dummy names etc.). So if CER file is named COMPUTER1.CER, the certificate will be imported into COMPUTER1 object in domain.
.PARAMETER CERLocation
The name of network share where CER files are located. User who runs the script must have read permissions on share or local drive.
.PARAMETER Domain
The name of domain where computer objects are located.
.PARAMETER Filter
String by which certs will be filtered in specified location. Only those CER files will be imported.
.EXAMPLE
Import-ACSCertToComputerObject -CERLocation C:\Temp -Domain contoso.com
Imports all certificates from C:\Temp location to all computer matched accounts in contoso.com domain
.EXAMPLE
Import-ACSCertToComputerObject -CERLocation \\myshare\CER -Domain contoso.com -Filter *123*
Imports certificates from \\myshare\CER location to all computer matched accounts in contoso.com domain where CER File \ Computer Name contains "123", i.e. COMP123 or CO123MP. Use * for wildcard.

#>

param(
[Parameter(Mandatory=$False)]
[string]$CERLocation = (Get-Variable -Scope 1 -Name PWD).Value.Path,
[Parameter(Mandatory=$False)]
[string]$Domain = $env:USERDNSDOMAIN,
[Parameter(Mandatory=$False)]
[string]$Filter = "*"
)

$filt = $Filter + ".CER"
Write-Verbose "Looking for files $($filt) in Folder $($CERLocation)"
try{
$files = Get-Item -Path $CERLocation | Get-ChildItem -File -Fitler $filt
    if ($files -eq $null) {
    Write-Warning "No CER files detected. Filter used: $filt"
    }
}
catch
{
	Write-Output "Error reading from $CERLocation. Verify the path exists and if you have read access to it"
}

$files | foreach {

	$server =  $_.Name.Split(".")[0]
	$file = $_.FullName

	try {
		$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate "$file"
	}
	catch
	{
		Write-Output "Cert file $file wrong. Skipping"
		continue
	}

	try {
		$comp = Get-ADComputer -Filter {Name -Like $server} -Server $Domain
	}
	catch
	{
		Write-Output "Computer object not exist - $server"
		continue
	}

	$paths = [Regex]::Replace($cert.Issuer, ',\s*(CN=|OU=|O=|DC=|C=)', '!$1') -split "!"

	$issuer = ""
	# Reverse the path and save as $issuer
		for ($i = $paths.count -1; $i -ge 0; $i--) {
			$issuer += $paths[$i]
			if ($i -ne 0) {
				$issuer += ","
			}
		}

	# Now $cert.issuer is reversed:
	# $issuer
	# DC=org,DC=certificates,OU= Certification Authorities,CN=Some Issuer

	# Do the same things for $cert.subject
	$paths = [Regex]::Replace($cert.subject, ',\s*(CN=|OU=|O=|DC=|C=)', '!$1') -split "!"

	$subject = ""
	# Reverse the path and save as $issuer
		for ($i = $paths.count -1; $i -ge 0; $i--) {
			$subject += $paths[$i]
			if ($i -ne 0) {
				$subject += ","
			}
		}

	# Now $cert.subject is reversed:
	# $subject
	# DC=org,DC=certificates,CN=John Smith 123456789
	
	# Format as needed for altSecurityIdentities
	$newcert = "X509:<I>$issuer<S>$subject"
	# View $newcert
	# $newcert
	# X509:<I>DC=org,DC=certificates,OU= Certification Authorities,CN=Some Issuer<S>DC=org,DC=certificates,CN=John Smith 123456789
	
	# Set the AD computer
	try {
		$comp | Set-ADComputer -Add @{'altsecurityidentities'=$newcert}
	}
	catch{
		Write-Output "Cannot write value to altsecurityidentities. Check permissions on domain level for your user. Failed server = $server"
	}
}