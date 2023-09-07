#include <windows.h>
#include <winternl.h>

/*
 * This file contains the required method definitions for NtQueryInformationProcess,
 * NtWow64QueryInformationProcess64 and NtWow64ReadVirtualMemory64. It is probably
 * easier to resolve and define these methods in plain C rather than writing the
 * corresponding v code.
 */
typedef NTSTATUS (NTAPI* NtQueryInformationProcessFn_T)(
    IN      HANDLE                  ProcessHandle,
    IN      PROCESSINFOCLASS        ProcessInformationClass,
    OUT     PVOID                   ProcessInformation,
    IN      ULONG                   ProcessInformationLength,
    OUT     PULONG                  ReturnLength OPTIONAL
);

typedef NTSTATUS (NTAPI* NtWow64QueryInformationProcess64Fn_T)(
    IN      HANDLE                  ProcessHandle,
    IN      PROCESSINFOCLASS        ProcessInformationClass,
    OUT     PVOID                   ProcessInformation,
    IN      ULONG                   ProcessInformationLength,
    OUT     PULONG                  ReturnLength OPTIONAL
);

typedef DWORD (NTAPI* NtWow64ReadVirtualMemory64Fn_T)(
    IN      HANDLE                  ProcessHandle,
    IN      UINT64                  BaseAddress,
    OUT     PVOID                   Buffer,
    IN      UINT64                  BufferLength,
    OUT     PUINT64                 ReturnLength
);

NtQueryInformationProcessFn_T    NtQueryInformationProcessFn    = NULL;
NtWow64QueryInformationProcess64Fn_T NtWow64QueryInformationProcess64Fn = NULL;
NtWow64ReadVirtualMemory64Fn_T NtWow64ReadVirtualMemory64Fn = NULL;

NTSTATUS NTAPI NtQueryInformationProcess(HANDLE ph, PROCESSINFOCLASS piClass, PVOID pi, ULONG piLen, PULONG retLen)
{
    if (NtQueryInformationProcessFn == NULL)
    {
        NtQueryInformationProcessFn = (NtQueryInformationProcessFn_T)GetProcAddress(GetModuleHandle("ntdll.dll"), "NtQueryInformationProcess");
    }

    return NtQueryInformationProcessFn(
        ph,
        piClass,
        pi,
        piLen,
        retLen
    );
}

NTSTATUS NtWow64QueryInformationProcess64(HANDLE ph, PROCESSINFOCLASS piClass, PVOID pi, ULONG piLen, PULONG retLen)
{
    if (NtWow64QueryInformationProcess64Fn == NULL)
    {
        NtWow64QueryInformationProcess64Fn = (NtWow64QueryInformationProcess64Fn_T)GetProcAddress(GetModuleHandle("ntdll.dll"), "NtWow64QueryInformationProcess64");
    }

    return NtWow64QueryInformationProcess64Fn(
        ph,
        piClass,
        pi,
        piLen,
        retLen
    );
}

NTSTATUS NtWow64ReadVirtualMemory64(HANDLE ph, UINT64 BaseAddress, PVOID buffer, UINT64 bufferLen, PUINT64 retLen)
{
    if (NtWow64ReadVirtualMemory64Fn == NULL)
    {
        NtWow64ReadVirtualMemory64Fn = (NtWow64ReadVirtualMemory64Fn_T)GetProcAddress(GetModuleHandle("ntdll.dll"), "NtWow64ReadVirtualMemory64");
    }

    return NtWow64ReadVirtualMemory64Fn(
        ph,
        BaseAddress,
        buffer,
        bufferLen,
        retLen
    );
}
