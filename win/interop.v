module win

import os
import utils
import encoding.base64

/*
 * interop.v contains all the low level code where we call Win32 API
 * from v. This file has grown other time and the defined methods
 * probably use different type definitions and calling conventions.
 * It works, but probably requires a cleanup at some point in time :)
 */

#flag -lversion
#flag -lpsapi
#flag -lole32
#flag -lsecur32
#flag -lrpcrt4
#flag -lgdi32
#flag -I @VMODROOT/src/c
#flag @VMODROOT/src/c/windows.o
#include "psapi.h"
#include "winver.h"
#include "tlhelp32.h"
#include "winternl.h"
#include "ntstatus.h"
#include "shellapi.h"
#include "rpc.h"
#include "rpcndr.h"
#include "rpcdce.h"
#include "objbase.h"
#include "defines.h"
#include "wingdi.h"
#include "sspi.h"
#include "imagehlp.h"

type PULONG = &u32
type USHORT = u16
type BOOL = bool
type BYTE = u8
type CHAR = u8
type WORD = u16
type DWORD = u32
type DWORD64 = u64
type HANDLE = voidptr
type LONG = int
type LPCSTR = &char
type LPDWORD = &u32
type LPSTR = &char
type PSID = &C.SID
type PSID_NAME_USE = &SID_NAME_USE
type UINT = u32
type ULONG = u32
type ULONG64 = u64
type ULONG_PTR = &u32
type WCHAR = u16
type PVOID = voidptr
type LPVOID = voidptr
type PWSTR = &u16
type HRESULT = u32
type PLONG = int
type REGSAM = int
type SIZE_T = u32
type ULONGLONG = u64
type PCSTR = &char
type NTSTATUS = u32
type KPRIORITY = u32

// Arch represents an CPU architecture. Architectures can be x86
// x64 or are unknown.
pub enum Arch {
	x86
	x64
	unk
}

// TOKEN_INFORMATION_CLASS is a copy of the corresponding windows
// enum. It is used to identify the type of information that is
// assigned to or retrieved from an access token. Using enum's
// with C prefix in v seems not to be supported at the time of
// writing. Therefore, we need to redefine it.
pub enum TOKEN_INFORMATION_CLASS {
	token_user = 1
	token_groups
	token_privileges
	token_owner
	token_primary_group
	token_default_dacl
	token_source
	token_type
	token_impersonation_level
	token_statistics
	token_restricted_sids
	token_session_id
	token_groups_and_privileges
	token_session_reference
	token_sand_box_inert
	token_audit_policy
	token_origin
	token_elevation_type
	token_linked_token
	token_elevation
	token_has_restrictions
	token_access_information
	token_virtualization_allowed
	token_virtualization_enabled
	token_integrity_level
	token_ui_access
	token_mandatory_policy
	token_logon_sid
	token_is_app_container
	token_capabilities
	token_app_container_sid
	token_app_container_number
	token_user_claim_attributes
	token_device_claim_attributes
	token_restricted_user_claim_attributes
	token_restricted_device_claim_attributes
	token_device_groups
	token_restricted_device_groups
	token_security_attributes
	token_is_restricted
	token_process_trust_level
	token_private_name_space
	token_singleton_attributes
	token_bno_isolation
	token_child_process_flags
	token_is_less_privileged_app_container
	token_is_sandboxed
	token_is_app_silo
	max_token_info_class
}

// SID_NAME_USE is a copy of the corresponding windows
// enum. It is used to identify the type of an SID. Using
// enum's with C prefix in v seems not to be supported at
// the time of writing. Therefore, we need to redefine it.
pub enum SID_NAME_USE {
	sid_type_user = 1
	sid_type_group
	sid_type_domain
	sid_type_alias
	sid_type_well_known_group
	sid_type_deleted_account
	sid_type_invalid
	sid_type_unknown
	sid_type_computer
	sid_type_label
	sid_type_logon_session
}

// PS_PROTECTION is an internally used windows struct that is used
// to determine the protection level of a process. We re-implement it
// here to get access to it.
pub struct PS_PROTECTION {
	level u8
}

// C.RGBQUAD represents the well known RGBQUAD struct from widows. In rpv
// it is not used, but definition is required for C interop.
@[typedef]
pub struct C.RGBQUAD {
	rgbBlue		BYTE
	rgbGreen	BYTE
	rgbRed		BYTE
	rgbReserved	BYTE
}

// C.RGBQUAD represents the well known COMM_FAULT_OFFSETS struct from widows.
// In rpv it is not used, but definition is required for C interop.
@[typedef]
pub struct C.COMM_FAULT_OFFSETS {
	CommOffset	u16
	FaultOffset u16
}

// C.GUID represents the well known GUID struct from widows. In rpv,
// it is used for different purposes. Mainly to identify RPC interfaces,
// that all contain GUIDs as part of their internal definition.
@[typedef]
pub struct C.GUID {
	Data1 u32
	Data2 u16
	Data3 u16
	Data4 [8]u8
}

// equals checks whether two C.GUID structs are the same. This can especially
// be used to compare RPC interfaces to each other.
pub fn (this C.GUID) equals(other C.GUID) bool
{
	if this.Data1 != other.Data1 || this.Data2 != other.Data2 || this.Data3 != other.Data3
	{
		return false
	}

	for ctr := 0; ctr < 8; ctr++
	{
		if this.Data4[ctr] != other.Data4[ctr]
		{
			return false
		}
	}

	return true
}

// C.IMAGE_DOS_HEADER is a well known header that can be found in PE files.
// rpv is especially interested in the e_lfanew member, as this contains the
// offset to the C.IMAGE_NT_HEADERS.
@[typedef]
pub struct C.IMAGE_DOS_HEADER {
	e_magic WORD
	e_cblp WORD
	e_cp WORD
	e_crlc WORD
	e_cparhdr WORD
	e_minalloc WORD
	e_maxalloc WORD
	e_ss WORD
	e_sp WORD
	e_csum WORD
	e_ip WORD
	e_cs WORD
	e_lfarlc WORD
	e_ovno WORD
	e_res [4]WORD
	e_oemid WORD
	e_oeminfo WORD
	e_res2 [10]WORD
	e_lfanew LONG
}

// IMAGE_SECTION_HEADER represents the header of an image section. rpv uses
// this section header to find the .data section, where RPV servers are usually
// contained in. At the time of writing I'm no longer sure why the struct was
// defined without C prefix, but probably because the union member contained
// in C.IMAGE_SECTION_HEADER caused problems.
pub struct IMAGE_SECTION_HEADER {
	name	[8]char
	misc DWORD
	virtual_address DWORD
	size_of_raw_data DWORD
	ptr_to_raw_data DWORD
	ptr_to_reloc DWORD
	ptr_to_line_nums DWORD
	numer_of_relos WORD
	numer_of_line_nums WORD
	characteristics DWORD
}

// C.IMAGE_NT_HEADERS represents the PE header format. rpv uses it to determine
// the architecture the PE was compiled for and to locate the different sections
// within the PE file.
@[typedef]
pub struct C.IMAGE_NT_HEADERS {
	Signature DWORD
	FileHeader C.IMAGE_FILE_HEADER
	OptionalHeader C.IMAGE_OPTIONAL_HEADER
}

// C.IMAGE_OPTIONAL_HEADER is actually not used by rpv and is only defined to
// complete the C.IMAGE_NT_HEADERS struct definition.
@[typedef]
pub struct C.IMAGE_OPTIONAL_HEADER {
	Magic WORD
	MajorLinkerVersion BYTE
	MinorLinkerVersion BYTE
	SizeOfCode DWORD
	SizeOfInitializedData DWORD
	SizeOfUninitializedData DWORD
	AddressOfEntryPoint DWORD
	BaseOfCode DWORD
	BaseOfData DWORD
	ImageBase voidptr
	SectionAlignment DWORD
	FileAlignment DWORD
	MajorOperatingSystemVersion WORD
	MinorOperatingSystemVersion WORD
	MajorImageVersion WORD
	MinorImageVersion WORD
	MajorSubsystemVersion WORD
	MinorSubsystemVersion WORD
	Win32VersionValue DWORD
	SizeOfImage DWORD
	SizeOfHeaders DWORD
	CheckSum DWORD
	Subsystem WORD
	DllCharacteristics WORD
	SizeOfStackReserve usize
	SizeOfStackCommit usize
	SizeOfHeapReserve usize
	SizeOfHeapCommit usize
	LoaderFlags DWORD
	NumberOfRvaAndSizes DWORD
    DataDirectory &C.IMAGE_DATA_DIRECTORY = unsafe { nil }
}

// C.IMAGE_NT_HEADERS32 represents the PE header format. rpv uses it to determine
// the architecture the PE was compiled for and to locate the different sections
// within the PE file.
@[typedef]
pub struct C.IMAGE_NT_HEADERS32 {
	Signature DWORD
	FileHeader C.IMAGE_FILE_HEADER
	OptionalHeader C.IMAGE_OPTIONAL_HEADER32
}

// C.IMAGE_OPTIONAL_HEADER32 is actually not used by rpv and is only defined to
// complete the C.IMAGE_NT_HEADERS32 struct definition.
@[typedef]
pub struct C.IMAGE_OPTIONAL_HEADER32 {
	Magic WORD
	MajorLinkerVersion BYTE
	MinorLinkerVersion BYTE
	SizeOfCode DWORD
	SizeOfInitializedData DWORD
	SizeOfUninitializedData DWORD
	AddressOfEntryPoint DWORD
	BaseOfCode DWORD
	BaseOfData DWORD
	ImageBase DWORD
	SectionAlignment DWORD
	FileAlignment DWORD
	MajorOperatingSystemVersion WORD
	MinorOperatingSystemVersion WORD
	MajorImageVersion WORD
	MinorImageVersion WORD
	MajorSubsystemVersion WORD
	MinorSubsystemVersion WORD
	Win32VersionValue DWORD
	SizeOfImage DWORD
	SizeOfHeaders DWORD
	CheckSum DWORD
	Subsystem WORD
	DllCharacteristics WORD
	SizeOfStackReserve DWORD
	SizeOfStackCommit DWORD
	SizeOfHeapReserve DWORD
	SizeOfHeapCommit DWORD
	LoaderFlags DWORD
	NumberOfRvaAndSizes DWORD
    DataDirectory &C.IMAGE_DATA_DIRECTORY = unsafe { nil }
}

// C.IMAGE_DATA_DIRECTORY represents a data directory. This struct is actually
// not used by rpv, but defined to complete the C.IMAGE_OPTIONAL_HEADER struct.
@[typedf]
pub struct C.IMAGE_DATA_DIRECTORY
{
	VirtualAddress DWORD
	Size DWORD
}

// C.IMAGE_FILE_HEADER represents the COFF header and is used by rpv to
// obtain the architecture the PE was compiled for and the number of it's
// contained sections.
@[typedef]
pub struct C.IMAGE_FILE_HEADER {
	Machine WORD
	NumberOfSections WORD
	TimeDateStamp DWORD
	PointerToSymbolTable DWORD
	NumberOfSymbols DWORD
	SizeOfOptionalHeader WORD
	Characteristics WORD
}

// ModuleSectionInfo contains information about a section within a module.
// rpv mainly uses this to encapsulate related information on the .data
// section of a module. This information contains the base address of the
// section as well as it's size and architecture.
pub struct ModuleSectionInfo{
	pub:
	base &u8
	size u32
	arch Arch
}

// C.SHFILEINFOA contains information on a file object. rpv uses this struct
// to obtain a handle to the icon of a file.
@[typedef]
pub struct C.SHFILEINFOA {
	hIcon	voidptr
	iIcon int
	dwAttributes DWORD
	szDisplayName [260]WCHAR
	szTypeName [80]WCHAR
}

// C.PEB is the well known process environment block struct. rpv uses it to
// to obtain the cmdline a process was started with.
@[typedef]
pub struct C.PEB {
	Reserved1 [2]BYTE
	BeingDebugged BYTE
	Reserved2 [1]BYTE
	Reserved3 [2]PVOID
	Ldr voidptr
	ProcessParameters &C.RTL_USER_PROCESS_PARAMETERS = unsafe { nil }
	Reserved4 [3]PVOID
	AtlThunkSListPtr PVOID
	Reserved5 PVOID
	Reserved6 ULONG
	Reserved7 PVOID
	Reserved8 ULONG
	AtlThunkSListPtr32 ULONG
	Reserved9 [45]PVOID
	Reserved10 [96]BYTE
	PostProcessInitRoutine voidptr
	Reserved11 [128]BYTE
	Reserved12 [1]PVOID
	SessionId ULONG
}

// C.PEB64 is the well known process environment block struct. rpv uses it to
// to obtain the cmdline a process was started with. Not all fields of the
// struct were defined, as access is only required to the first few fields.
@[typedef]
pub struct C.PEB64 {
	Reserved1 [4]BYTE
	Reserved2 [2]u64
	LdrData u64
	ProcessParameters u64
}

// C.RTL_USER_PROCESS_PARAMETERS is contained within the PEB structures and
// can be used to retrieve the cmdline of a process.
@[typedef]
pub struct C.RTL_USER_PROCESS_PARAMETERS {
	Reserved1 [16]BYTE
	Reserved2 [10]PVOID
    ImagePathName C.UNICODE_STRING
    CommandLine C.UNICODE_STRING
}

// C.RTL_USER_PROCESS_PARAMETERS_WOW64 is contained within the PEB structures and
// can be used to retrieve the cmdline of a process. This version of the struct
// is required when accessing an x64 process from a x32 process.
@[typedef]
pub struct C.RTL_USER_PROCESS_PARAMETERS_WOW64 {
	Reserved1 [16]BYTE
	Reserved2 [10]u64
    ImagePathName C.UNICODE_STRING_WOW64
    CommandLine C.UNICODE_STRING_WOW64
}

// C.UNICODE_STRING is a well known struct to represent a unicode string.
@[typedef]
pub struct C.UNICODE_STRING {
   Length USHORT
   MaximumLength USHORT
   Buffer PWSTR
}

// C.UNICODE_STRING_WOW64 is a well known struct to represent a unicode string.
// This version of the struct is required by C.RTL_USER_PROCESS_PARAMETERS_WOW64,
// that is used when reading x64 command line arguments from a x32 process.
@[typedef]
pub struct C.UNICODE_STRING_WOW64 {
   Length USHORT
   MaximumLength USHORT
   Buffer u64
}

// C.PROCESS_BASIC_INFORMATION is another well known Windows structure. rpv uses
// it to find the process environment block of a process.
@[typedef]
pub struct C.PROCESS_BASIC_INFORMATION {
	ExitStatus NTSTATUS
	PebBaseAddress &C.PEB = unsafe { nil }
	AffinityMask PULONG
	BasePriority KPRIORITY
	UniqueProcessId PULONG
	InheritedFromUniqueProcessId PULONG
}

// C.PROCESS_BASIC_INFORMATION_WOW64 is another well known Windows structure. rpv uses
// it to find the process environment block of a x64 process when running as x32.
@[typedef]
pub struct C.PROCESS_BASIC_INFORMATION_WOW64 {
	ExitStatus NTSTATUS
	PebBaseAddress u64
	AffinityMask u64
	BasePriority KPRIORITY
	UniqueProcessId u64
	InheritedFromUniqueProcessId u64
}

// C.LARGE_INTEGER represents a 64bit integer value. Module version information is
// represented by this struct. The definition actually contains a union, which needs
// to be expressed as plain struct members in v at the time of writing.
@[typedef]
pub union C.LARGE_INTEGER {
	mut:
	LowPart DWORD
	HighPart LONG
	QuadPart u64
}

// C.LUID is described by Microsoft as local identifier. It is used when working
// witch process privileges. rpv needs it, to enable debug privileges for the
// current process.
@[typedef]
pub struct C.LUID {
	mut:
	LowPart DWORD
	HighPart LONG
}

// C.LUID_AND_ATTRIBUTES merges a C.LUID struct with it's associated attributes.
// This struct is used within the C.TOKEN_PRIVILEGES struct.
@[typedef]
pub struct C.LUID_AND_ATTRIBUTES {
	mut:
	  Luid C.LUID
	  Attributes DWORD
}

// C.TOKEN_PRIVILEGES contains information on privileges that are held by a token.
@[typedef]
pub struct C.TOKEN_PRIVILEGES {
	mut:
	PrivilegeCount DWORD
	Privileges     [1]C.LUID_AND_ATTRIBUTES
}

// C.TOKEN_USER contains information on the user that is associated with an access
// token.
@[typedef]
pub struct C.TOKEN_USER {
	User C.SID_AND_ATTRIBUTES
}

// C.SID_AND_ATTRIBUTES is contained in C.TOKEN_USER and is used to obtain
// information on the user an access token is associated with.
@[typedef]
pub struct C.SID_AND_ATTRIBUTES {
	Sid PSID
	Attributes DWORD
}

// C.SID is the well known security identifier structure. It is used to
// identify groups and users.
@[typedef]
pub struct C.SID {
}

// C.PROCESSENTRY32 is used when creating snapshots. It is one entry in the
// list of processes, that were available when the snapshot was taken.
@[typedef]
pub struct C.PROCESSENTRY32 {
	dwSize DWORD
	cntUsage DWORD
	th32ProcessID DWORD
	th32DefaultHeapID ULONG_PTR
	th32ModuleID DWORD
	cntThreads DWORD
	th32ParentProcessID DWORD
	pcPriClassBase LONG
	dwFlags DWORD
	szExeFile &WCHAR = unsafe { nil }
}

// C.MODULEENTRY32 is used when creating snapshots. It is one entry of a
// module list from a process.
@[typedef]
pub struct C.MODULEENTRY32 {
	dwSize DWORD
	th32ModuleID DWORD
	th32ProcessID DWORD
	GlblcntUsage DWORD
	ProccntUsage DWORD
	modBaseAddr &BYTE = unsafe { nil }
	modBaseSize DWORD
	hModule HANDLE
	szModule &WCHAR = unsafe { nil }
	szExePath &WCHAR = unsafe { nil }
}

// C.VS_FIXEDFILEINFO contains version information of a file. rpv uses
// this struct to obtain the module version of a file.
@[typedef]
pub struct C.VS_FIXEDFILEINFO {
	dwSignature DWORD
	dwStrucVersion DWORD
	dwFileVersionMS DWORD
	dwFileVersionLS DWORD
	dwProductVersionMS DWORD
	dwProductVersionLS DWORD
	dwFileFlagsMask DWORD
	dwFileFlags DWORD
	dwFileOS DWORD
	dwFileType DWORD
	dwFileSubtype DWORD
	dwFileDateMS DWORD
	dwFileDateLS DWORD
}

// C.SecPkgInfoA describes a security package. Security packages can be
// associated with RPC servers and rpv uses this struct to determine this.
@[typedef]
pub struct C.SecPkgInfoA {
	fCapabilities u32
	wVersion u16
	wRPCID u16
	cbMaxToken u32
	Name &char
	Comment &char
}

// C.MEMORY_BASIC_INFORMATION contains information about a specific memory
// region within the virtual address space.
@[typedef]
pub struct C.MEMORY_BASIC_INFORMATION {
	BaseAddress PVOID
	AllocationBase PVOID
	AllocationProtect DWORD
	RegionSize SIZE_T
	State DWORD
	Protect DWORD
	Type DWORD
}

// SecurityPackage is used by rpv to represent an SecurityPackage. It is
// basically similar to SecPkgInfoA, but the char pointers are replaced
// with string types.
pub struct SecurityPackage {
	pub:
	caps u32
	version u16
	rpc_id u16
	max_token u32
	name string
	comment string
}

// LanguageCodePage is used by rpv when obtaining module descriptions
// from files.
pub struct LanguageCodePage {
	language WORD
	codepage WORD
}

// LocationInfo is used by rpv to describe a memory location. The respective
// location is contained within the base member. The size member describes
// the size of the section, the memory location is located in. The path member
// contains the file system path of the associated file. The desc member
// contains the module description.
pub struct LocationInfo {
	pub:
	base voidptr
	size u32
	mem_info C.MEMORY_BASIC_INFORMATION
	path string
	desc string
}

// C.ICONINFO contains icon information.
@[typedef]
pub struct C.ICONINFO {
	fIcon bool
	xHotspot u32
	yHotspot u32
	hbmMask HANDLE
	hbmColor HANDLE
}

// C.BITMAP describes an array of bytes that forms an icon. When processing
// file system icons, this type is used to encode the icons.
@[typedef]
pub struct C.BITMAP {
	mut:
	bmType int
	bmWidth int
	bmHeight int
	bmWidthBytes int
	bmPlanes u16
	bmBitsPixel u16
	bmBits voidptr = unsafe { nil }
}

// BITMAPINFO contains additional information that describes the BITMAP.
pub struct BITMAPINFO {
	mut:
	bmi_header BITMAPV4INFOHEADER
	bmi_colors [1]C.RGBQUAD
}

// BITMAPV4INFOHEADER contains additional information that describes
// the BITMAP.
pub struct BITMAPV4INFOHEADER {
	mut:
	bv4_size DWORD
	bv4_width LONG
	bv4_height LONG
	bv4_planes WORD
	bv4_bit_count WORD
	bv4_compression DWORD
	bv4_size_image DWORD
	bv4_x_pels_per_meter LONG
	bv4_y_pels_per_meter LONG
	bv4_clr_used DWORD
	bv4_clr_important DWORD
	bv4_red_mask DWORD = 0x00ff0000
	bv4_green_mask DWORD = 0x0000ff00
	bv4_blue_mask DWORD = 0x000000ff
	bv4_alpha_mask DWORD = 0xff000000
	bv4_cs_type DWORD
	bv4_endpoints [36]BYTE
	bv4_gamma_red DWORD
	bv4_gamma_green DWORD
	bv4_gamma_blue DWORD
}

// BITMAPFILEHEADER describes the first few bytes of a bitmap file.
@[typedef]
pub struct C.BITMAPFILEHEADER {
	mut:
	bfType WORD
	bfSize DWORD
	bfReserved1 WORD
	bfReserved2 WORD
	bfOffBits DWORD
}

// SYSTEM_INFO contains information on the currently operating system
// and the underlying hardware. rpv uses it, to obtain the process
// architecture.
pub struct SYSTEM_INFO {
	processor_architecture WORD
	reserved WORD
	page_size DWORD
	minimum_application_address LPVOID
	maximum_application_address LPVOID
	active_processor_mask &DWORD = unsafe { nil }
	number_of_processors DWORD
	processor_type DWORD
	allocation_granularity DWORD
	processor_level WORD
	processor_revision WORD
}

pub const (
	ioctl_open_process				= u32(0x8335003C)
	th32cs_snapprocess				= u32(0x00000002)
	th32cs_snapmodule				= u32(0x00000008)
	th32cs_snapmodule32				= u32(0x00000010)
	process_protect_information	    = u32(0x0000003d)
	rpc_is_wow64 = false
)

// open_process_ext is and extended version of the Win32 OpenProcess function.
// it first attempts to open a handle to the specified PID via OpenProcess directly.
// if this does not work, it attempts to open the handle via the PROCEXP152.sys driver.
// this allows to open handles even for protected processes.
pub fn open_process_ext(desired_access u32, inherit_handle bool, pid u32) !HANDLE {

	utils.log_debug('Opening handle to process ${pid} with access mask 0x${desired_access.hex()}')

	bytes_returned := u32(0)
	process := C.OpenProcess(desired_access, inherit_handle, pid)

	if process == HANDLE(0) {

		utils.log_debug('OpenProcess failed. Trying via process explorer')

		procexp := C.CreateFileA('\\\\.\\PROCEXP152'.str, C.GENERIC_READ, 0, 0, C.OPEN_EXISTING,
			C.FILE_ATTRIBUTE_NORMAL, 0)

		if int(procexp) == C.INVALID_HANDLE_VALUE {
			return error('Could not open process explorer pipe.')
		}

		h_pid := HANDLE(pid)
		result := C.DeviceIoControl(procexp, ioctl_open_process, &h_pid, sizeof(h_pid), &process, sizeof(HANDLE), &bytes_returned, 0)

		if !result {
			last_error := C.GetLastError()
			return error('DeviceIOControl returned error code 0x${last_error.hex()}')
		}
	}

	utils.log_debug('Successfully obtained process handle')

	return process
}

// adjust_privilege adjusts a Windows privilege by name. Within rpv, this is mainly used to
// enable the SeDebugPrivilege that is required to inspect other processes.
pub fn adjust_privilege(privilege_name string, enable_privilege bool) ! {

	utils.log_debug('Setting privilege ${privilege_name} to ${enable_privilege}')

	mut luid := C.LUID{}
	mut p_token := HANDLE(0)
	mut token_privilege := C.TOKEN_PRIVILEGES{}

	if !C.OpenProcessToken(C.GetCurrentProcess(), C.TOKEN_ALL_ACCESS, &p_token) {
		return error('OpenProcessToken failed.')
	}

	defer {
		C.CloseHandle(p_token)
	}

	if !C.LookupPrivilegeValueA(&char(0), privilege_name.str, &luid) {
		return error('LookupPrivilegeValue failed.')
	}

	token_privilege.PrivilegeCount = 1
	token_privilege.Privileges[0].Luid = luid

	if enable_privilege {
		token_privilege.Privileges[0].Attributes = C.SE_PRIVILEGE_ENABLED
	} else {
		token_privilege.Privileges[0].Attributes = C.SE_PRIVILEGE_REMOVED
	}

	if !C.AdjustTokenPrivileges(p_token, false, &token_privilege, 0, &C.TOKEN_PRIVILEGES(unsafe { nil }), &u32(0)) {
		return error('AdjustTokenPrivileges failed.')
	}

	last_error := C.GetLastError()

	if last_error != C.ERROR_SUCCESS {
		return error('AdjustTokenPrivileges caused OS error: 0x${last_error.hex()}')
	}

	utils.log_debug('Privilege was adjusted successfully')
}


// get_process_name returns the process name associated to the specified
// process id.
pub fn get_process_name(pid u32)! string
{
	utils.log_debug('Obtaining process name of process ${pid}')

	snapshot_handle := C.CreateToolhelp32Snapshot(th32cs_snapprocess, 0)

	if int(snapshot_handle) == C.INVALID_HANDLE_VALUE
	{
		return error('Unable to get snapshot of current process.')
	}

	defer
	{
		C.CloseHandle(snapshot_handle)
	}

	process_entry := C.PROCESSENTRY32{
		dwSize: sizeof(C.PROCESSENTRY32)
	}

	if !C.Process32First(snapshot_handle, &process_entry)
	{
		return error('Unable to obtain first process from snapshot.')
	}

	for
	{
		if pid == process_entry.th32ProcessID
		{
			name := unsafe { string_from_wide(process_entry.szExeFile) }
			utils.log_debug('Process name successfully obtained: ${name}')

			return name
		}

		if !C.Process32Next(snapshot_handle, &process_entry)
		{
			break
		}
	}

	return error('ppid for pid ${pid} was not found.')
}

// get_process_ppid returns the ppid of the specified process.
pub fn get_process_ppid(pid u32)! u32
{
	utils.log_debug('Obtaining ppid of process ${pid}')

	snapshot_handle := C.CreateToolhelp32Snapshot(th32cs_snapprocess, 0)

	if int(snapshot_handle) == C.INVALID_HANDLE_VALUE
	{
		return error('Unable to get snapshot of current process.')
	}

	defer
	{
		C.CloseHandle(snapshot_handle)
	}

	process_entry := C.PROCESSENTRY32{
		dwSize: sizeof(C.PROCESSENTRY32)
	}

	if !C.Process32First(snapshot_handle, &process_entry)
	{
		return error('Unable to obtain first process from snapshot.')
	}

	for
	{
		if pid == process_entry.th32ProcessID
		{
			return process_entry.th32ParentProcessID
		}

		if !C.Process32Next(snapshot_handle, &process_entry)
		{
			break
		}
	}

	return error('Process name for pid ${pid} was not found.')
}

// get_process_childs returns the process child process ids
pub fn get_process_childs(pid u32)! []u32
{
	utils.log_debug('Obtaining child pids of process ${pid}')

	snapshot_handle := C.CreateToolhelp32Snapshot(th32cs_snapprocess, 0)

	if int(snapshot_handle) == C.INVALID_HANDLE_VALUE
	{
		return error('Unable to get snapshot of current process.')
	}

	defer
	{
		C.CloseHandle(snapshot_handle)
	}

	process_entry := C.PROCESSENTRY32{
		dwSize: sizeof(C.PROCESSENTRY32)
	}

	if !C.Process32First(snapshot_handle, &process_entry)
	{
		return error('Unable to obtain first process from snapshot.')
	}

	mut childs := []u32{cap: 1024}

	for
	{
		if pid == process_entry.th32ParentProcessID
		{
			childs << process_entry.th32ProcessID
		}

		if !C.Process32Next(snapshot_handle, &process_entry)
		{
			break
		}
	}

	return childs
}

// get_process_path returns the process path associated to the specified
// process id.
pub fn get_process_path(pid u32)! string
{
	process_handle := open_process_ext(u32(C.PROCESS_QUERY_LIMITED_INFORMATION), false, pid)!

	defer
	{
		C.CloseHandle(process_handle)
	}

	return get_process_path_h(process_handle)
}

// get_process_path_h returns the process path associated to the specified
// process handle.
pub fn get_process_path_h(process_handle HANDLE)! string
{
	path_size := u32(C.MAX_PATH)
	process_path := []char{len: int(path_size)}

	if !C.QueryFullProcessImageNameA(process_handle, 0, process_path.data, &path_size)
	{
		return error('Unable to obtain process path via QueryFullProcessImageNameA')
	}

	return unsafe { cstring_to_vstring(&char(process_path.data))}
}


// get_module_version returns the module version as u64 from the specified
// file path
pub fn get_module_version(path string)! u64
{
	if !os.exists(path)
	{
		return error('The specified file ${path} does not exist!')
	}

	unused := HANDLE(0)

	mut version_size := u32(0)
	version_info := &C.VS_FIXEDFILEINFO(unsafe { nil })

	utils.log_debug('Obtaining module version of ${path}')
	version_size = C.GetFileVersionInfoSizeA(path.str, &unused)

	if version_size == 0
	{
		return error('Unable to obtain version for module ${path}')
	}

	version_data := unsafe { malloc(version_size) }

	defer
	{
		unsafe { free(version_data) }
	}

	if !C.GetFileVersionInfoA(path.str, 0, version_size, version_data)
	{
		return error('Unable to obtain VersionInfo via GetFileVersionInfo')
	}

	if !C.VerQueryValueA(version_data, '\\'.str, &version_info, &version_size)
	{
		return error('Unable to obtain VersionInfo via VerQueryValue')
	}

	mut result := C.LARGE_INTEGER{}

	unsafe
	{
		result.HighPart = version_info.dwProductVersionMS
		result.LowPart = version_info.dwProductVersionLS

		utils.log_debug('Module version obtained successfully ${result.QuadPart}')
	}

	return unsafe { result.QuadPart }
}

// get_module_description returns the module description as string from the
// specified file system path.
pub fn get_module_description(path string)! string
{
	if !os.exists(path)
	{
		return error('The specified file ${path} does not exist!')
	}

	unused := HANDLE(0)

	mut version_size := u32(0)

	translate_size := u32(0)
	translate_info := &LanguageCodePage(unsafe { nil })

	utils.log_debug('Obtaining module description of ${path}')
	version_size = C.GetFileVersionInfoSizeA(path.str, &unused)

	if version_size == 0
	{
		return error('Unable to obtain module description for ${path}')
	}

	version_data := unsafe { malloc(version_size) }

	defer
	{
		unsafe { free(version_data) }
	}

	if !C.GetFileVersionInfoA(path.str, 0, version_size, version_data)
	{
		return error('Unable to obtain VersionInfo via GetFileVersionInfo')
	}

	if !C.VerQueryValueA(version_data, '\\VarFileInfo\\Translation'.str, &translate_info, &translate_size)
	{
		return error('Unable to obtain Translation via VerQueryValue')
	}

	for ctr := 0; ctr < translate_size / sizeof(LanguageCodePage); ctr++
	{
		unsafe
		{
			result := &char(0)
			result_size := u32(0)

			prop := "\\StringFileInfo\\${translate_info.language:04x}${translate_info.codepage:04x}\\FileDescription"

			if C.VerQueryValueA(version_data, prop.str, &result, &result_size)
			{
				description := cstring_to_vstring(result)
				utils.log_debug('Found description: ${description}')

				return description
			}

			translate_info++
		}
	}

	return error('No description found')
}

// get_process_user returns the associated username and domain to the specified process id
pub fn get_process_user(pid u32)! string
{
	process_handle := open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer
	{
		C.CloseHandle(process_handle)
	}

	return get_process_user_h(process_handle)!
}

// get_process_user_h returns the associated username and domain to the specified process handle
pub fn get_process_user_h(process_handle HANDLE)! string
{
	mut p_token := HANDLE(0)
	mut user_size := u32(0)

	if !C.OpenProcessToken(process_handle, C.TOKEN_QUERY, &p_token)
	{
		return error('OpenProcessToken failed.')
	}

	defer
	{
		C.CloseHandle(p_token)
	}

	C.GetTokenInformation(p_token, TOKEN_INFORMATION_CLASS.token_user, 0, 0, &user_size)
	p_token_user := unsafe { &C.TOKEN_USER(malloc(user_size)) }

	defer
	{
		unsafe { free(p_token_user) }
	}

	if !C.GetTokenInformation(p_token, TOKEN_INFORMATION_CLASS.token_user, p_token_user, user_size, &user_size)
	{
		return error('GetTokenInformation failed')
	}

	user_size = u32(0)
	domain_size := u32(0)
	sid_name_use := SID_NAME_USE.sid_type_user

	C.LookupAccountSidA(&char(0), p_token_user.User.Sid, &char(0), &user_size, &char(0), &domain_size, &sid_name_use)

	user_name := unsafe { malloc(user_size) }
	domain_name := unsafe { malloc(domain_size) }

	defer
	{
		unsafe
		{
			free(user_name)
			free(domain_name)
		}
	}

	if !C.LookupAccountSidA(&char(0), p_token_user.User.Sid, &char(user_name), &user_size, &char(domain_name), &domain_size, &sid_name_use)
	{
		return error('LookupAccountSidA failed')
	}

	unsafe
	{
		user := (&char(user_name)).vstring()
		domain := (&char(domain_name)).vstring()

		return '${domain}\\${user}'
	}
}

// get_process_cmdline obtains the cmdline by parsing the PEB of the supplied process id. When running
// as 32bit on WOW64, it is also capable of determining the commandline of 64bit processes. However,
// notice that this is the only cross-architecture function that was implemented in rpv. Obtaining RPC
// information only works from the same architecture.
pub fn get_process_cmdline(pid u32)! string
{
	process_handle := open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer
	{
		C.CloseHandle(process_handle)
	}

	return get_process_cmdline_h(process_handle)!
}

// get_process_cmdline_h obtains the cmdline by parsing the PEB of the supplied process handle. When running
// as 32bit on WOW64, it is also capable of determining the commandline of 64bit processes. However,
// notice that this is the only cross-architecture function that was implemented in rpv. Obtaining rpc
// information only works from the same architecture.
pub fn get_process_cmdline_h(process_handle HANDLE)! string
{
	arch := get_process_arch(process_handle)!
	return get_process_cmdline_ha(process_handle, arch)!
}

// get_process_cmdline_ha obtains the cmdline by parsing the PEB of the supplied process handle. When running
// as 32bit on WOW64, it is also capable of determining the commandline of 64bit processes. However,
// notice that this is the only cross-architecture function that was implemented in rpv. Obtaining rpc
// information only works from the same architecture.
pub fn get_process_cmdline_ha(process_handle HANDLE, arch Arch)! string
{
	if is_protected(process_handle)!
	{
		utils.log_debug('Process is protected. Unable to obtain cmdline for the moment.')
		return ''
	}

	$if x32
	{
		if arch == Arch.x64
		{
			// From here it gets dirty. Adresses in the remote process are now treated as u64.
			// In NtWow64ReadVirtualMemory64, the last argument is a 32bit pointer, that needs
			// to be stored in the upper bits of a u64.

			result_size := u64(0)
			peb := C.PEB64{}
			basic_info := C.PROCESS_BASIC_INFORMATION_WOW64{}
			process_params := C.RTL_USER_PROCESS_PARAMETERS_WOW64{}

			unsafe
			{
				utils.log_debug('Obtaining process information via NtWow64QueryInformationProcess64.')
				status := C.NtWow64QueryInformationProcess64(process_handle, C.ProcessBasicInformation, &voidptr(&basic_info), sizeof(C.basic_info), &voidptr(0))

				if status != C.STATUS_SUCCESS
				{
					return error('NtWow64QueryInformationProcess64 failed: 0x${status.hex()}')
				}

				utils.log_debug('Reading PEB from 0x${basic_info.PebBaseAddress.hex()}.')
				if C.NtWow64ReadVirtualMemory64(process_handle, basic_info.PebBaseAddress, &peb, sizeof(C.PEB64), u64(&result_size) << 32) != 0
				{
					return error('Failed to read PEB from: 0x${basic_info.PebBaseAddress}')
				}

				utils.log_debug('Reading process parameters from 0x${peb.ProcessParameters.hex()}.')
				if C.NtWow64ReadVirtualMemory64(process_handle, peb.ProcessParameters, &process_params, sizeof(process_params), u64(&result_size) << 32) != 0
				{
					return error('Failed to read ProcessParameters from: 0x${peb.ProcessParameters.hex()}')
				}

				cmdline := malloc(process_params.CommandLine.Length)

				defer
				{
					free(cmdline)
				}

				utils.log_debug('Reading command line from 0x${process_params.CommandLine.Buffer.hex()}.')
				if C.NtWow64ReadVirtualMemory64(process_handle, process_params.CommandLine.Buffer, cmdline, process_params.CommandLine.Length, u64(&result_size) << 32) != 0
				{
					return error('Failed to read CommandLine from: 0x${process_params.CommandLine.Buffer.hex()}')
				}

				return string_from_wide(cmdline)
			}
		}
	}

	peb := C.PEB{}
	result_size := u32(0)
	basic_info := C.PROCESS_BASIC_INFORMATION{}
	process_params := C.RTL_USER_PROCESS_PARAMETERS{}

	unsafe
	{
		utils.log_debug('Obtaining process information via NtQueryInformationProcess.')
		status := C.NtQueryInformationProcess(process_handle, C.ProcessBasicInformation, &voidptr(&basic_info), sizeof(C.PROCESS_BASIC_INFORMATION), &result_size)

		if status != C.STATUS_SUCCESS
		{
			return error('NtQueryInformationProcess failed: 0x${status.hex()}')
		}

		utils.log_debug('Reading PEB from 0x${&voidptr(basic_info.PebBaseAddress)}.')
		if !C.ReadProcessMemory(process_handle, basic_info.PebBaseAddress, &peb, sizeof(C.PEB), &result_size)
		{
			return error('Failed to read PEB from: 0x${basic_info.PebBaseAddress}')
		}

		utils.log_debug('Reading process parameters from 0x${&voidptr(peb.ProcessParameters)}.')
		if !C.ReadProcessMemory(process_handle, peb.ProcessParameters, &process_params, sizeof(C.process_params), &result_size)
		{
			return error('Failed to read ProcessParameters from: 0x${peb.ProcessParameters}')
		}

		cmdline := malloc(process_params.CommandLine.Length)

		defer
		{
			free(cmdline)
		}

		utils.log_debug('Reading command line from 0x${&voidptr(process_params.CommandLine.Buffer)}.')
		if !C.ReadProcessMemory(process_handle, process_params.CommandLine.Buffer, cmdline, process_params.CommandLine.Length, &result_size)
		{
			return error('Failed to read CommandLine from: 0x${process_params.CommandLine.Buffer}')
		}

		return string_from_wide(cmdline)
	}
}

// get_module_icon obtains a handle to the icon used by the specified executable
pub fn get_module_icon(path string)! voidptr
{
	if !os.exists(path)
	{
		return error('The specified file ${path} does not exist!')
	}

	file_info := C.SHFILEINFOA{}
	utils.log_debug('Obtaining icon of ${path} via SHGetFileIconA')

	if !C.SHGetFileInfoA(path.str, 0, &file_info, sizeof(C.SHFILEINFOA), C.SHGFI_ICON | C.SHGFI_LARGEICON)
	{
		return error('Unable to obtain icon for ${path}')
	}

	return file_info.hIcon
}

// is_proctected returns true if the specified handle belongs to a protected process
pub fn is_protected(h_process HANDLE)! bool
{
	result_size := u32(0)
	protection := PS_PROTECTION{}

	unsafe
	{
		utils.log_debug('Obtaining protection information via NtQueryInformationProcess.')
		status := C.NtQueryInformationProcess(h_process, process_protect_information, &voidptr(&protection), sizeof(PS_PROTECTION), &result_size)

		if status != C.STATUS_SUCCESS
		{
			return error('NtQueryInformationProcess failed: 0x${status.hex()}')
		}
	}

	if protection.level == u8(0)
	{
		return false
	}

	return true
}


// get_module_data_section obtains the address and size of the .data section of the specified
// module and returns them encapsulated within a ModuleSectionInfo structure
pub fn get_module_data_section(h_process HANDLE, module_ptr voidptr)! ModuleSectionInfo
{
	mut arch := Arch.x86
	dos_header := C.IMAGE_DOS_HEADER{}

	if !C.ReadProcessMemory(h_process, module_ptr, &dos_header, sizeof(C.IMAGE_DOS_HEADER), &voidptr(0))
	{
		return error('Unable to read ImageDosHeader from 0x${module_ptr}.')
	}

	if dos_header.e_magic != C.IMAGE_DOS_SIGNATURE
	{
		return error('Invalid magic for DOS_HEADER')
	}

	unsafe
	{
		ptr := &u8(module_ptr) + u32(dos_header.e_lfanew)
		nt_header := C.IMAGE_NT_HEADERS{}

		if !C.ReadProcessMemory(h_process, ptr, &nt_header, sizeof(C.IMAGE_NT_HEADERS), &voidptr(0))
		{
			return error('Unable to read NtHeader from 0x${module_ptr}.')
		}

		if nt_header.Signature != C.IMAGE_NT_SIGNATURE
		{
			return error('Invalid signature for NT_HEADER')
		}

		section_headers := &IMAGE_SECTION_HEADER(nil)

		if nt_header.FileHeader.Machine == u32(0x014c)
		{
			section_headers = &IMAGE_SECTION_HEADER(ptr + sizeof(C.IMAGE_NT_HEADERS32))
		}

		else
		{
			arch = Arch.x64
			section_headers = &IMAGE_SECTION_HEADER(ptr + sizeof(C.IMAGE_NT_HEADERS))
		}

		for ctr := 0; ctr < nt_header.FileHeader.NumberOfSections; ctr++
		{
			section_header := IMAGE_SECTION_HEADER{}

			if !C.ReadProcessMemory(h_process, &section_headers[ctr], &section_header, sizeof(C.IMAGE_SECTION_HEADER), &voidptr(0))
			{
				return error('Unable to read ImageSectionHeader from 0x${section_headers[ctr]}.')
			}

			if (&char(section_header.name[..].data)).vstring() == '.data' {

				return ModuleSectionInfo{
					base: &u8(module_ptr) + u32(section_header.virtual_address)
					size: section_header.misc
					arch: arch
				}
			}
		}
	}

	return error('Unable to find .data section.')
}

// get_rpc_runtime_version obtains the module version of rpcrt4.dll and returns it 
// as u64.
pub fn get_rpc_runtime_version()! u64
{
	unsafe
	{
		buffer := &char(malloc(C.MAX_PATH))

		defer
		{
			free(buffer)
		}

		if C.GetSystemDirectoryA(buffer, C.MAX_PATH) == 0
		{
			return error('Unable to obtain system directory.')
		}

		rpc_loc := buffer.vstring() + '\\rpcrt4.dll'
		return get_module_version(rpc_loc)!
	}
}

pub fn get_com_interface_name(interface_id C.RPC_IF_ID)! string
{
	uuid := uuid_to_str(interface_id)!

	key := 'Interface\\{${uuid}}'
	key_handle := HANDLE(0)

	if C.RegOpenKeyExA(C.HKEY_CLASSES_ROOT, &char(key.str), 0, C.KEY_READ, &key_handle) != C.ERROR_SUCCESS
	{
		return error('Unable to open ${key} via RegOpenKeyExA')
	}

	defer
	{
		C.RegCloseKey(key_handle)
	}

	unsafe
	{
		size := C.MAX_PATH
		p_result := &char(malloc(size))

		defer
		{
			free(p_result)
		}

		if C.RegQueryValueExA(key_handle, &voidptr(0), &voidptr(0), &voidptr(0), p_result, &size) != C.ERROR_SUCCESS
		{
			return error('Unable to read value from ${key} via RegQueryValueExA')
		}

		return cstring_to_vstring(p_result)
	}
}

// enum_security_packages returns an array of available security packages.
pub fn enum_security_packages()! []SecurityPackage
{
	sec_package_count := 0
	mut p_sec_packages := &C.SecPkgInfoA(unsafe { nil })

	utils.log_debug('Enumerating security packages via EnumerateSecurityPackagesA.')

	if C.EnumerateSecurityPackagesA(&sec_package_count, &p_sec_packages) != C.SEC_E_OK
	{
		return error('Unable to enumerate available security packages.')
	}

	defer
	{
		C.FreeContextBuffer(p_sec_packages)
	}

	sec_packages := []SecurityPackage{cap: sec_package_count}
	mut walking_pointer := p_sec_packages

	unsafe
	{
		for ctr := 0; ctr < sec_package_count; ctr++
		{
			sec_package := &C.SecPkgInfoA(walking_pointer)

			sec_packages << SecurityPackage {
				caps: sec_package.fCapabilities
				version: sec_package.wVersion
				rpc_id: sec_package.wRPCID
				max_token: sec_package.cbMaxToken
				name: cstring_to_vstring(sec_package.Name)
				comment: cstring_to_vstring(sec_package.Comment)
			}

			walking_pointer++
		}
	}

	utils.log_debug('Enumerated ${sec_packages.len} security packages.')
	return sec_packages
}

// get_location_info determines the memory location of the specified address within the
// specified process. It returns a LocationInfo struct that provides information on the
// module belonging to the memory location such as it's base address and module path.
pub fn get_location_info(pid u32, address voidptr)! LocationInfo
{
	process_handle := open_process_ext(u32(C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer
	{
		C.CloseHandle(process_handle)
	}

	return get_location_info_h(process_handle, address)!
}

// get_location_info determines the memory location of the specified address within the
// specified process. It returns a LocationInfo struct that provides information on the
// module belonging to the memory location such as it's base address and module path.
pub fn get_location_info_h(process_handle HANDLE, address voidptr)! LocationInfo
{
	mem_info := C.MEMORY_BASIC_INFORMATION{}

	if !C.VirtualQueryEx(process_handle, address, &mem_info, sizeof(mem_info))
	{
		return error('Failed to obtain memory basic information via VirtualQueryEx.')
	}

	mut location := ''
	p_buffer := unsafe { &char(malloc(C.MAX_PATH)) }

	defer
	{
		unsafe { free(p_buffer) }
	}

	if C.GetMappedFileNameA(process_handle, address, p_buffer, C.MAX_PATH) != 0
	{
		location = unsafe { cstring_to_vstring(p_buffer) }
		drive_mask := C.GetLogicalDrives()

		for ctr := 0; ctr < 26; ctr++
		{
			if (drive_mask & (1 << ctr)) == 0
			{
				continue
			}

			drive := '${u8(65 + ctr).ascii_str()}:'

			if C.QueryDosDeviceA(&char(drive.str), p_buffer, C.MAX_PATH) == 0
			{
				continue
			}

			device_name := unsafe { p_buffer.vstring() }

			if location.starts_with(device_name)
			{
				location = location.replace(device_name, drive)
				break
			}
		}
	}

	module_description := get_module_description(location)!
	mut base_addr := &voidptr(0)
	mut base_size := u32(0)

	if location != ''
	{
		snapshot_handle := C.CreateToolhelp32Snapshot(th32cs_snapmodule | th32cs_snapmodule, C.GetProcessId(process_handle))

		if int(snapshot_handle) == C.INVALID_HANDLE_VALUE
		{
			return error('Unable to get snapshot of current process.')
		}

		defer
		{
			C.CloseHandle(snapshot_handle)
		}

		module_entry := C.MODULEENTRY32{
			dwSize: sizeof(C.MODULEENTRY32)
		}

		if !C.Module32First(snapshot_handle, &module_entry)
		{
			return error('Unable to obtain first process from snapshot.')
		}

		for
		{
			if unsafe { string_from_wide(module_entry.szModule) == location.substr(location.last_index('\\') or { 0 } + 1, location.len) }
			{
				base_addr = module_entry.modBaseAddr
				base_size = module_entry.modBaseSize
				break
			}

			if !C.Module32Next(snapshot_handle, &module_entry)
			{
				break
			}
		}
	}

	return LocationInfo {
		base: base_addr
		size: base_size
		mem_info: mem_info
		path: location
		desc: module_description
	}
}

// icon_to_bmp transforms a windows HICON into a bitmap (bmp format) and returns the
// result as base64. Currently, only 32bit pixel format is supported.
pub fn icon_to_bmp(icon HANDLE)! string
{
	icon_info := C.ICONINFO{}

	if !C.GetIconInfo(icon, &icon_info)
	{
		return error('Unable to obtain ICONINFO via GetIconInfo function.')
	}

	bmp := C.BITMAP{}

	if C.GetObject(icon_info.hbmColor, sizeof(C.BITMAP), voidptr(&bmp)) == 0
	{
		return error('Unable to obtain BITMAP via GetObject function.')
	}

	mut clr_bits := bmp.bmPlanes * bmp.bmBitsPixel

	for bound in [1, 4, 8, 16, 24, 32]
	{
		if clr_bits <= bound
		{
			clr_bits = u16(bound)
		}
	}

    if clr_bits < 32
	{
		return error('Icons with less than 32 bit per pixel are currently not supported.')
	}

	mut bmi := BITMAPINFO{}

    bmi.bmi_header.bv4_size = sizeof(BITMAPV4INFOHEADER)
    bmi.bmi_header.bv4_width = bmp.bmWidth
    bmi.bmi_header.bv4_height = bmp.bmHeight
    bmi.bmi_header.bv4_planes = bmp.bmPlanes
    bmi.bmi_header.bv4_bit_count = bmp.bmBitsPixel

    bmi.bmi_header.bv4_compression = u32(C.BI_BITFIELDS)
    bmi.bmi_header.bv4_size_image = u32(((bmi.bmi_header.bv4_width * clr_bits + 31) & ~31) / 8 * bmi.bmi_header.bv4_height)

	mut color_bits := []int{len: int(bmi.bmi_header.bv4_size_image)}

	if C.GetDIBits(C.GetDC(&voidptr(0)), icon_info.hbmColor, 0, bmp.bmHeight, color_bits.data, &bmi, C.DIB_RGB_COLORS) == 0
	{
		return error('Unable to obtain bitmap data via GetDIBits')
	}

	// GetDIBits expects a BITMAPINFOHEADER (no V4) and resets some fields of the specified V4 Header
	bmi.bmi_header.bv4_size = sizeof(BITMAPV4INFOHEADER)
	bmi.bmi_header.bv4_alpha_mask = 0xff000000

	file_header := C.BITMAPFILEHEADER{
		bfType: 0x4d42
		bfSize: u32(sizeof(C.BITMAPFILEHEADER) + bmi.bmi_header.bv4_size + bmi.bmi_header.bv4_size_image)
		bfReserved1: 0
		bfReserved2: 0
		bfOffBits: u32(sizeof(C.BITMAPFILEHEADER) + bmi.bmi_header.bv4_size)
	}

	final_bitmap := []u8{len: int(sizeof(C.BITMAPFILEHEADER) + sizeof(BITMAPV4INFOHEADER) + bmi.bmi_header.bv4_size_image)}

	unsafe
	{
		bmp_ptr := &char(final_bitmap.data)

		vmemcpy(bmp_ptr, &file_header, sizeof(file_header))
		bmp_ptr = bmp_ptr + sizeof(file_header)

		vmemcpy(bmp_ptr, &bmi.bmi_header, sizeof(bmi.bmi_header))
		bmp_ptr = bmp_ptr + sizeof(bmi.bmi_header)

		vmemcpy(bmp_ptr, color_bits.data, color_bits.len)
	}

	return base64.encode(final_bitmap)
}

// get_process_arch returns the architecture of the process the specified
// process handle is referring to.
pub fn get_process_arch(process_handle HANDLE)! Arch
{
	mut wow64 := false
	system_info := SYSTEM_INFO{}

	C.GetNativeSystemInfo(&system_info)

	if system_info.processor_architecture == C.PROCESSOR_ARCHITECTURE_INTEL
	{
		return Arch.x86
	}

	if !C.IsWow64Process(process_handle, &wow64)
	{
		return error('Unable to run IsWow64Process')
	}

	if wow64
	{
		return Arch.x86
	}

	return Arch.x64
}

// read_process_memory attempts to read size bytes from the specified src
// within the specified process. The result is stored within the specified
// dest pointer.
pub fn read_process_memory(process_handle HANDLE, src voidptr, dest voidptr, size u32)!
{
	if !C.ReadProcessMemory(process_handle, src, dest, size, &voidptr(0))
	{
		return error('Unable to read process memory at 0x${voidptr(src)}')
	}
}

// read_proc_mem attempts to read the type T from the specified address in
// process memory. The src pointer is incremented by the size of T.
pub fn read_proc_mem[T](process_handle HANDLE, mut src &voidptr)! T
{
	unsafe
	{
		$if T.typ in [u8, u16, u32, u64, int, usize]
		{
			dest := T(0)

			if !C.ReadProcessMemory(process_handle, *src, &dest, sizeof(T), &voidptr(0))
			{
				return error('Unable to read process memory at 0x${voidptr(src)}')
			}

			src = voidptr(&u8(*src) + sizeof(T))

			return dest
		}

		$else
		{
			dest := T{}

			if !C.ReadProcessMemory(process_handle, *src, &dest, sizeof(T), &voidptr(0))
			{
				return error('Unable to read process memory at 0x${voidptr(src)}')
			}

			src = voidptr(&u8(*src) + sizeof(T))

			return dest
		}
	}
}

// read_proc_mem attempts to read the type T from the specified address in
// process memory. Compared to the read_proc_mem function, the source pointer
// is left untouched.
pub fn read_proc_mem_s[T](process_handle HANDLE, src voidptr)! T
{
	$if T.typ in [u8, u16, u32, u64, int, usize]
	{
		dest := T(0)

		if !C.ReadProcessMemory(process_handle, src, &dest, sizeof(T), &voidptr(0))
		{
			return error('Unable to read process memory at 0x${voidptr(src)}')
		}

		return dest
	}

	$else
	{
		dest := T{}

		if !C.ReadProcessMemory(process_handle, src, &dest, sizeof(T), &voidptr(0))
		{
			return error('Unable to read process memory at 0x${voidptr(src)}')
		}

		return dest
	}
}

// uuid_to_str converts the binary UUID of an RPC_IF_ID into a string
pub fn uuid_to_str(interface_id C.RPC_IF_ID)! string
{
	p_uuid_str := &char(0)

	defer
	{
		unsafe { free(p_uuid_str) }
	}

	if C.UuidToStringA(&interface_id.Uuid, &p_uuid_str) != C.RPC_S_OK
	{
		return error('Error while calling UuidToString')
	}

	return unsafe { cstring_to_vstring(p_uuid_str) }
}

// get_interface_version returns the version of an RPC_IF_ID as string
pub fn get_interface_version(interface_id C.RPC_IF_ID) string
{
	return '${interface_id.VersMajor}.${interface_id.VersMinor}'
}

// new_guid attempts to parse a C.GUID struct from the specified string.
pub fn new_guid(guid_str string)! C.GUID
{
	split := guid_str.split('-')

	if guid_str.len != 36 || split.len != 5
	{
		return error('Invalid GUID: ${guid_str}')
	}

	data4_str := split[3] + split[4]
	mut data4 := [8]u8{}

	for ctr := 0; ctr < data4.len * 2; ctr += 2
	{
		data4[ctr / 2] = u8(data4_str[ctr..ctr+2].parse_uint(16, 8)!)
	}

	return C.GUID {
		Data1: u32(split[0].parse_uint(16, 32)!)
		Data2: u16(split[1].parse_uint(16, 16)!)
		Data3: u16(split[2].parse_uint(16, 16)!)
		Data4: data4
	}
}

/*
 * The following lines contain WIN32 API function definitions that are used
 * by this file. This list has grown over time and is probably inconsistent
 * regarding method formatting.
 */
fn C.AdjustTokenPrivileges(token_handle HANDLE, disable_all bool, new_state &C.TOKEN_PRIVILEGES, length DWORD, old_state &C.TOKEN_PRIVILEGES, return_length &DWORD) bool
fn C.CoInitialize(reserved LPVOID) HRESULT
fn C.CreateFileA(file_name &char, desired_access DWORD, share_mode DWORD, security_attributes voidptr, creation_disposition DWORD, flags DWORD, tempate_file voidptr) HANDLE
fn C.CreateToolhelp32Snapshot(flags DWORD, pid DWORD) HANDLE
fn C.DeviceIoControl(handle HANDLE, control_code DWORD, in_buffer voidptr, buffer_size DWORD, out_buffer voidptr, out_buffer_size DWORD, bytes_returned &DWORD, overlapped voidptr) bool
fn C.EnumProcessModulesEx(process_handle HANDLE, module_handle_array &HANDLE, arrays_size DWORD, size_needed &DWORD, filter_flags DWORD) bool
fn C.EnumProcesses(pid_arr voidptr, size DWORD, required &DWORD) bool
fn C.EnumerateSecurityPackagesA(package_count &int, infos &&C.SecPkgInfoA) int
fn C.FreeContextBuffer(buffer voidptr) int
fn C.GetCurrentProcess() HANDLE
fn C.GetDC(window_handle HANDLE) HANDLE
fn C.GetDIBits(device_handle HANDLE, bitmal HANDLE, start u32, lines u32, bits &u8, bitmap_info &BITMAPINFO, usage int) int
fn C.GetFileVersionInfoA(filename &char, handle DWORD, size DWORD, data voidptr) bool
fn C.GetFileVersionInfoSizeA(filename &char, handle &DWORD) DWORD
fn C.GetIconInfo(icon_handle HANDLE, icon_info &C.ICONINFO) bool
fn C.GetLastError() DWORD
fn C.GetLogicalDrives() DWORD
fn C.GetMappedFileNameA(process_handle HANDLE, addr LPVOID, filename &char, size DWORD) DWORD
fn C.GetModuleFileNameExA(process_handle HANDLE, module_handle_array HANDLE, filename LPSTR, size DWORD) DWORD
fn C.GetNativeSystemInfo(system_info &SYSTEM_INFO)
fn C.GetObject(h HANDLE, c int, pv LPVOID) int
fn C.GetProcessId(process_handle HANDLE) DWORD
fn C.GetSystemDirectoryA(buffer LPSTR, size UINT) UINT
fn C.GetTokenInformation(token HANDLE, token_information_class TOKEN_INFORMATION_CLASS, token_information voidptr, token_information_length DWORD, return_length &DWORD) bool
fn C.IsWow64Process(process_handle HANDLE, is_wow64 bool) bool
fn C.IsWow64Process(process_handle HANDLE, result &BOOL) bool
fn C.LookupAccountSidA(system_name LPCSTR, sid PSID, name LPSTR, name_length LPDWORD, domain_name LPSTR, domain_length LPDWORD, usage PSID_NAME_USE) bool
fn C.LookupPrivilegeValueA(system_name &char, privilege_name &char, luid &C.LUID) bool
fn C.Module32First(snapshot_handle HANDLE, module_entry &C.MODULEENTRY32) bool
fn C.Module32Next(snapshot_handle HANDLE, module_entry &C.MODULEENTRY32) bool
fn C.NtQueryInformationProcess(process_handle HANDLE, process_info_class int, process_information PVOID, process_information_length ULONG, return_length PULONG) int
fn C.NtWow64QueryInformationProcess64(process_handle HANDLE, process_info_class int, process_information voidptr, process_information_length ULONG, return_length PULONG) int
fn C.NtWow64ReadVirtualMemory64(handle_process HANDLE, base_address u64, buffer voidptr, size u64, bytes_read &u64) int
fn C.OpenProcess(desired_access DWORD, inherit_handle bool, pid DWORD) HANDLE
fn C.OpenProcessToken(process_handle HANDLE, access_mask DWORD, token_handle &HANDLE) bool
fn C.Process32First(snapshot_handle HANDLE, process_entry &C.PROCESSENTRY32) bool
fn C.Process32Next(snapshot_handle HANDLE, process_entry &C.PROCESSENTRY32) bool
fn C.QueryDosDeviceA(device_name LPCSTR, path LPSTR, max DWORD) DWORD
fn C.QueryFullProcessImageNameA(process_handle HANDLE, flags DWORD, name &char, size &DWORD) bool
fn C.ReadProcessMemory(handle_process HANDLE, base_address voidptr, buffer voidptr, size DWORD, bytes_read &DWORD) bool
fn C.RegCloseKey(key_handle HANDLE) int
fn C.RegOpenKeyExA(key HANDLE, sub_key LPCSTR, options DWORD, acess_type REGSAM, result &HANDLE) int
fn C.RegQueryValueExA(key_handle HANDLE, value LPCSTR, resv &DWORD, reg_type &DWORD, data LPSTR, length PLONG) int
fn C.SHGetFileInfoA(path &char, file_attrs DWORD, fileinfo &C.SHFILEINFOA, file_info_size UINT, flags UINT) bool
fn C.SymCleanup(process_handle HANDLE)
fn C.SymFromAddr(process_handle HANDLE, address DWORD64, displacement &DWORD64, symbol &SymbolInfoV) bool
fn C.SymInitialize(process_handle HANDLE, search_path &char, invade_process BOOL) bool
fn C.SymLoadModuleEx(process_handle HANDLE, file_handle HANDLE, image PCSTR, mod PCSTR, dll_base u64, dll_size u32, data voidptr, flags u32) u64
fn C.SymUnloadModule(process_handle HANDLE, module_base u32)
fn C.SymUnloadModule64(process_handle HANDLE, module_base u64)
fn C.UuidToStringA(uuid &C.GUID, out_string &&char) int
fn C.VerQueryValueA(data voidptr, block &char, buffer voidptr, size &UINT) bool
fn C.VirtualQueryEx(process_handle HANDLE, address LPVOID, mem_info &C.MEMORY_BASIC_INFORMATION, length SIZE_T) bool
fn C.ZeroMemory(dest PVOID, length u32)
