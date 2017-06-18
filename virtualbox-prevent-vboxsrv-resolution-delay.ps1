if ('VirtualBox' -ne (Get-WmiObject WIN32_BIOS -Property SMBIOSBIOSVersion).SMBIOSBIOSVersion) {
    Exit 0
}

# to prevent long delays while resolving the vboxsrv (used by c:\vagrant)
# NetBIOS name, hard-code its address in the lmhosts file.
# see 12.3.9. Long delays when accessing shared folders
#     at https://www.virtualbox.org/manual/ch12.html#idm10219
Write-Output @'
255.255.255.255 VBOXSVR #PRE
255.255.255.255 VBOXSRV #PRE
'@ | Out-File -Encoding ASCII -Append 'c:\windows\system32\drivers\etc\lmhosts'
