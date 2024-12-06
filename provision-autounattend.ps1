# NB this file executed by powershell.
# NB the remaining steps are executed by pwsh.

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

# disable autologon.
# see https://learn.microsoft.com/en-us/windows/win32/secauthn/msgina-dll-features
# see http://www.pinvoke.net/default.aspx/advapi32.lsaretrieveprivatedata
# see https://attack.mitre.org/techniques/T1003/004/
Write-Host 'Disabling auto logon...'
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace PInvoke
{
    public class LSAUtil
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_UNICODE_STRING
        {
            public UInt16 Length;
            public UInt16 MaximumLength;
            public IntPtr Buffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_OBJECT_ATTRIBUTES
        {
            public int Length;
            public IntPtr RootDirectory;
            public LSA_UNICODE_STRING ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        private enum LSA_AccessPolicy : long
        {
            POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L,
            POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L,
            POLICY_GET_PRIVATE_INFORMATION = 0x00000004L,
            POLICY_TRUST_ADMIN = 0x00000008L,
            POLICY_CREATE_ACCOUNT = 0x00000010L,
            POLICY_CREATE_SECRET = 0x00000020L,
            POLICY_CREATE_PRIVILEGE = 0x00000040L,
            POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L,
            POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L,
            POLICY_AUDIT_LOG_ADMIN = 0x00000200L,
            POLICY_SERVER_ADMIN = 0x00000400L,
            POLICY_LOOKUP_NAMES = 0x00000800L,
            POLICY_NOTIFICATION = 0x00001000L
        }

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaRetrievePrivateData(
            IntPtr PolicyHandle,
            ref LSA_UNICODE_STRING KeyName,
            out IntPtr PrivateData
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaStorePrivateData(
            IntPtr policyHandle,
            ref LSA_UNICODE_STRING KeyName,
            ref LSA_UNICODE_STRING PrivateData
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaOpenPolicy(
            ref LSA_UNICODE_STRING SystemName,
            ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
            uint DesiredAccess,
            out IntPtr PolicyHandle
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaNtStatusToWinError(
            uint status
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaClose(
            IntPtr policyHandle
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaFreeMemory(
            IntPtr buffer
        );

        private LSA_OBJECT_ATTRIBUTES objectAttributes;
        private LSA_UNICODE_STRING localsystem;
        private LSA_UNICODE_STRING secretName;

        public LSAUtil(string key)
        {
            if (key.Length == 0)
            {
                throw new Exception("Key length zero");
            }
            objectAttributes = new LSA_OBJECT_ATTRIBUTES();
            objectAttributes.Length = 0;
            objectAttributes.RootDirectory = IntPtr.Zero;
            objectAttributes.Attributes = 0;
            objectAttributes.SecurityDescriptor = IntPtr.Zero;
            objectAttributes.SecurityQualityOfService = IntPtr.Zero;
            localsystem = new LSA_UNICODE_STRING();
            localsystem.Buffer = IntPtr.Zero;
            localsystem.Length = 0;
            localsystem.MaximumLength = 0;
            secretName = new LSA_UNICODE_STRING();
            secretName.Buffer = Marshal.StringToHGlobalUni(key);
            secretName.Length = (UInt16)(key.Length * UnicodeEncoding.CharSize);
            secretName.MaximumLength = (UInt16)((key.Length + 1) * UnicodeEncoding.CharSize);
        }

        private IntPtr GetLsaPolicy(LSA_AccessPolicy access)
        {
            IntPtr LsaPolicyHandle;
            uint ntsResult = LsaOpenPolicy(ref this.localsystem, ref this.objectAttributes, (uint)access, out LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaOpenPolicy failed: " + winErrorCode);
            }
            return LsaPolicyHandle;
        }

        private static void ReleaseLsaPolicy(IntPtr LsaPolicyHandle)
        {
            uint ntsResult = LsaClose(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaClose failed: " + winErrorCode);
            }
        }

        private static void FreeMemory(IntPtr Buffer)
        {
            uint ntsResult = LsaFreeMemory(Buffer);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaFreeMemory failed: " + winErrorCode);
            }
        }

        public void SetSecret(string value)
        {
            LSA_UNICODE_STRING lusSecretData = new LSA_UNICODE_STRING();
            if (value.Length > 0)
            {
                // Create data and key.
                lusSecretData.Buffer = Marshal.StringToHGlobalUni(value);
                lusSecretData.Length = (UInt16)(value.Length * UnicodeEncoding.CharSize);
                lusSecretData.MaximumLength = (UInt16)((value.Length + 1) * UnicodeEncoding.CharSize);
            }
            else
            {
                // Delete data and key.
                lusSecretData.Buffer = IntPtr.Zero;
                lusSecretData.Length = 0;
                lusSecretData.MaximumLength = 0;
            }
            IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_CREATE_SECRET);
            uint result = LsaStorePrivateData(LsaPolicyHandle, ref secretName, ref lusSecretData);
            ReleaseLsaPolicy(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(result);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaStorePrivateData failed: " + winErrorCode);
            }
        }

        public string GetSecret()
        {
            IntPtr PrivateData = IntPtr.Zero;
            IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_GET_PRIVATE_INFORMATION);
            uint ntsResult = LsaRetrievePrivateData(LsaPolicyHandle, ref secretName, out PrivateData);
            ReleaseLsaPolicy(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaRetrievePrivateData failed: " + winErrorCode);
            }
            LSA_UNICODE_STRING lusSecretData = (LSA_UNICODE_STRING)Marshal.PtrToStructure(PrivateData, typeof(LSA_UNICODE_STRING));
            string value = Marshal.PtrToStringAuto(lusSecretData.Buffer).Substring(0, lusSecretData.Length / 2);
            FreeMemory(PrivateData);
            return value;
        }
    }
}
"@
$autoLogonKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 0
@(
    ,'AutoLogonCount'
    ,'AutoLogonSID'
    ,'DefaultDomainName'
    ,'DefaultUserName'
    ,'DefaultPassword'
) | ForEach-Object {
    Remove-ItemProperty -Path $autoLogonKeyPath -Name $_ -ErrorAction SilentlyContinue
}
$lsaUtil = New-Object PInvoke.LSAUtil -ArgumentList DefaultPassword
$lsaUtil.SetSecret('')

# install pwsh.
$p = Join-Path $PSScriptRoot provision-pwsh.ps1
Write-Host "Executing $p..."
&"$p"
$env:PATH += ";$(Split-Path -Parent (Resolve-Path 'C:\Program Files\PowerShell\*\pwsh.exe'))"

# install the remaining steps using pwsh.
$systemVendor = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Vendor).Vendor
@(
    if ($systemVendor -eq 'QEMU') { 'provision-guest-tools-qemu-kvm' }
    if ($systemVendor -eq 'VMware, Inc.') { 'provision-vmtools' }
    'provision-winrm'
    'provision-psremoting'
    'provision-openssh'
) | ForEach-Object {
    Join-Path $PSScriptRoot "$_.ps1"
} | Where-Object {
    Test-Path $_
} | ForEach-Object {
    Write-Host "Executing $_..."
    # NB for some unknown reason, when the host hypervisor is hyper-v, we cannot
    #    run scripts from the E: drive due to the default RemoteSigned policy.
    #    so, we have to explicitly bypass the execution policy.
    pwsh -ExecutionPolicy Bypass -File $_
    if ($LASTEXITCODE) {
        throw "$_ failed with exit code $LASTEXITCODE"
    }
}

# logoff from the current autologon session.
logoff
