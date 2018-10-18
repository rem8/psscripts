#######
#
# Purpose: Automate adtagent -c command with PowerShel
# Author: Lukasz Rutkowski (lukasz.rem8@gmail.com)
# Microsoft Certified: Azure Administrator Associate
#
#######

#######
#
# Static data
#
#######

# Static path for RSA Keys in Windows
$fileRSAlocation = 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\'
# Getting Network Service SID Object
$principal = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::NetworkServiceSid, $null)
# Rule for ACL to be added to key file
$right = 'Read'
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($principal, $right, 'Allow')

#######
#
# Retrieving certificate with SCOM Uses on machine and getting its properties
#
#######

#Retrieving certificate with the same thumbrint as the one imported into SCOM agent and stored in registry
$cert = (Get-ChildItem Cert:\LocalMachine\My | where { $_.Thumbprint -eq (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Machine Settings' -Name ChannelCertificateHash).ChannelCertificateHash })
#Getting thumbprint value
$certdata = $($cert.Thumbprint)
#Getting information about file name with unique key in $fileRSAlocation
$certRSAStore = $($cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName)

# ACS Agent stored the thumbprint value inside registry in binary format, so we have to convert string value of thumbprint into BINARY where each two subsequent pair of characters is converted and finally stored in $newdata
Write-Host $certdata
$newdata = for ($i = 0; $i -lt $certdata.Length; $i += 2) { [convert]::ToByte($certdata.Substring($i,2), 16) }
# Setting the value inside ADTAGENT service registry
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\AdtAgent\Parameters' -Name CertHash -Value $newdata -Type Binary

# Applying proper ACLs to RSA File - The Network Service account has to have rights to read private key file
$path = $fileRSAlocation + $certRSAStore
$acl = Get-Acl -Path $path
$acl.SetAccessRule($rule)
Set-Acl -Path $path -AclObject $acl

#Restarting ACS Agent (adtagent)

Restart-Service adtagent