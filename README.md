# psscripts
PowerShell Scripts

1. Enable-ACSWithCert.ps1
  You can run this script inside your ACS Forwarder server and this will grab your certificate which SCOM uses and puts it into ACS Forwarder - NO MORE ADTAGENT -C !!! You can automate it now !!! :)

2. Import-ACSCertToComputerObject.ps1
  You can use this script to import all or filtered certificates stored in one location and with [hostname].CER naming convention into Active Directory computer object for ACS Forwarder computers without domains or with untrusted domain. This script mimics the use of Name Mappings step in AD Snap-In. 
