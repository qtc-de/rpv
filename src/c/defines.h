#define SECURITY_WIN32

/*
 * The following structures are required for obtaining the command line
 * of x64 processes from a x86 process running on WOW64.
 */
typedef struct _PROCESS_BASIC_INFORMATION_WOW64
{
    NTSTATUS    ExitStatus;
    ULONG64     PebBaseAddress;
    ULONG64     AffinityMask;
    KPRIORITY   BasePriority;
    ULONG64     UniqueProcessId;
    ULONG64     InheritedFromUniqueProcessId;
} PROCESS_BASIC_INFORMATION_WOW64;

typedef struct _UNICODE_STRING_WOW64 {
    USHORT      Length;
    USHORT      MaximumLength;
    ULONG64     Buffer;
} UNICODE_STRING_WOW64;

typedef struct RTL_USER_PROCESS_PARAMETERS_WOW64
{
	BYTE                    Reserved1[16];
	ULONG64                 Reserved2[10];
    UNICODE_STRING_WOW64    ImagePathName;
    UNICODE_STRING_WOW64    CommandLine;
} RTL_USER_PROCESS_PARAMETERS_WOW64, *PRTL_USER_PROCESS_PARAMETERS_WOW64;

typedef struct _PARTIAL_PEB64 {
    BYTE        Reserved1[4];
    ULONG64     Reserved2[2];
    ULONG64     LdrData;
    ULONG64     ProcessParameters;
} PEB64;
