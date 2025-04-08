// This file mainly contains structures and constants that are used internally by the RPC
// runtime but that do not change among the different RPC runtime versions. Most of the
// structures were figured out by the authors of RpcView (https://github.com/silverf0x/RpcView)

module internals

import win

type RPC_STATUS = int
type RpcForwardFunction = fn (interfaceid &C.GUID, interfaceversion &C.RPC_VERSION, objectid &C.GUID, rpcpro &u8, ppdestendpoint &voidptr) RPC_STATUS
type RpcCallbackFunction = fn (intf_handle voidptr, context voidptr) RPC_STATUS

// ListEntry represents one node in a list with a forward and a backward pointer.
// It is used within RtlCriticalSectionDebug and the RpcServer struct.
pub struct ListEntry {
	f_link &ListEntry = unsafe { nil }
	b_link &ListEntry = unsafe { nil }
}

// RtlCriticalSectionDebug is a mutex related structure. It is not really used by rpv
// but needs to be defined as it is part of other RpcStructures.
pub struct RtlCriticalSectionDebug {
	section_type                  u16
	creator_back_trace_index      u16
	critical_section              &RtlCriticalSection = unsafe { nil }
	process_locks_list            ListEntry
	entry_count                   u32
	contention_count              u32
	flags                         u32
	creator_back_trace_index_high u16
	spare_word                    u16
}

// RtlCriticalSection is a mutex related structure. It is not really used by rpv
// but needs to be defined as it is part of other RpcStructures.
pub struct RtlCriticalSection {
	debug_info      &RtlCriticalSectionDebug = unsafe { nil }
	lock_count      u32
	recursion_count u32
	owning_thread   voidptr = unsafe { nil }
	lock_semaphor   voidptr = unsafe { nil }
	spin_count      u32
}

// Mutex is a synchronization struct to signal ownership of a thread on a
// critical section. It is not really used by rpv but needs to be defined
// as it is part of other RpcStructures.
pub struct Mutex {
	critical_section RtlCriticalSection
}

// SimpleDict represents a simple dictionary struct. Actually, it feels more
// like an array than a dictionary, as contained elements are simply references
// by the p_array (pointer array) member. Internal RPC structs use this struct
// to reference to different elements like e.g. their interfaces.
pub struct SimpleDict {
pub:
	p_array           &voidptr = unsafe { nil }
	array_size        u32
	number_of_entries u32
	small_array       [4]voidptr
}

// RpcProtSeqEndpoint is an internal RPC structure. It is not really used
// by rpv but needs to be defined as it is part of other RpcStructures.
pub struct RpcProtSeqEndpoint {
	rpc_protocol_sequence &char = unsafe { nil }
	endpoint              &char = unsafe { nil }
}

// RpcServerInterface is an internal RPC structure that stores interface related
// information. It is contained within the RpcInterface struct and provides
// information such as the interface id, it's transfer syntax and RPC flags.
pub struct RpcServerInterface {
pub:
	length             u32
	interface_id       C.RPC_IF_ID
	transfer_syntax    C.RPC_IF_ID
	dispatch_table     &C.RPC_DISPATCH_TABLE = unsafe { nil }
	endpoint_count     u32
	rpc_endpoints      &RpcProtSeqEndpoint = unsafe { nil }
	entry_point_vector &voidptr = unsafe { nil }
	interpreter_info   &C.MIDL_SERVER_INFO = unsafe { nil }
	flags              u32
}

// C.RPC_IF_ID represents an ID of an RPC interface. This is basically an GUID
// but also contains a major and minor version.
@[typedef]
pub struct C.RPC_IF_ID {
	Uuid      C.GUID
	VersMajor u16
	VersMinor u16
}

// equals checks whether two C.RPC_IF_ID structs are the same. This is the case
// if they have a matching GUID and the same major and minor version.
pub fn (this C.RPC_IF_ID) equals(other C.RPC_IF_ID) bool
{
	return this.Uuid.equals(other.Uuid) && this.VersMajor == other.VersMajor && this.VersMinor == other.VersMinor
}

// C.RPC_DISPATCH_TABLE contains information on the defined RPC methods of an
// RPC interface. rpv uses it to determine the method count, that can be obtained
// from the DispatchTableCount property.
@[typedef]
pub struct C.RPC_DISPATCH_TABLE {
	DispatchTableCount u32
	DispatchTable      voidptr
	Reserved           isize
}

// C.MIDL_SERVER_INFO contains more detailed information on the defined RPC methods
// of an RPC interface. The DispatchTable member contains references to the corresponding
// executable methods, whereas the ProcString member contains information on the
// formatting of these methods. This is used in conjunction with the FmtStringOffset
// property, which contains the offset of the different methods within the ProcString,
// to decompile RPC methods.
@[typedef]
pub struct C.MIDL_SERVER_INFO {
	pStubDesc       &C.MIDL_STUB_DESC = unsafe { nil }
	DispatchTable   &voidptr          = unsafe { nil }
	ProcString      &char             = unsafe { nil }
	FmtStringOffset &u16              = unsafe { nil }
	ThunkTable      &voidptr          = unsafe { nil }
	pTransferSyntax &C.RPC_IF_ID      = unsafe { nil }
	nCount          &u32              = unsafe { nil }
	pSyntaxInfo     voidptr           = unsafe { nil }
}

// C.MIDL_STUB_DESC contains information about an RPC stub. For rpv, mainly the pFormatTypes
// member is of interest, as it contains a pointer to the NDR type definitions that are used
// by the RPC methods of the corresponding interface. rpv uses this information to decompile
// RPC methods. Moreover, Reserved5 is required for parsing NDR expressions. Actually the
// member is named pExprInfo by Microsoft, but within the mingw libraries it is Reserved5.
@[typedef]
pub struct C.MIDL_STUB_DESC {
	RpcInterfaceInformation     voidptr = unsafe { nil }
	pfnAllocate                 voidptr = unsafe { nil }
	pfnFree                     voidptr = unsafe { nil }
	IMPLICIT_HANDLE_INFO        voidptr = unsafe { nil }
	apfnNdrRundownRoutines      voidptr = unsafe { nil }
	aGenericBindingRoutinePairs voidptr = unsafe { nil }
	apfnExprEval                voidptr = unsafe { nil } // mIDA: callback-table
	aXmitQuintuple              voidptr = unsafe { nil }
	pFormatTypes                &char   = unsafe { nil } // mIDA: type_raw
	fCheckBounds                int
	// Ndr library version.
	Version                     u32
	pMallocFreeStruct           voidptr = unsafe { nil }
	MIDLVersion                 u32
	CommFaultOffsets            &C.COMM_FAULT_OFFSETS = unsafe { nil }
	// New fields for version 3.0+
	aUserMarshalQuadruple       voidptr               = unsafe { nil }
	// Notify routines - added for NT5, MIDL 5.0
	NotifyRoutineTable          voidptr               = unsafe { nil }
	// Reserved for future use.
	mFlags                      &u32                  = unsafe { nil }
	// International support routines - added for 64bit post NT5
	CsRoutineTables             voidptr               = unsafe { nil }
	Reserved4                   voidptr               = unsafe { nil }
	Reserved5                   voidptr               = unsafe { nil } // mIDA: expr_table - RpcView: pExprInfo
}

// NDR_EXPR_DESC is the struct that is pointed to by C.MIDL_STUB_DESC.Reserved5, alias
// pExprInfo. It is used by rpv to parse NDR expressions. 
pub struct NDR_EXPR_DESC {
pub:
	p_offset      voidptr
	p_format_expr voidptr
}

// C.MIDL_SYNTAX_INFO is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.MIDL_SYNTAX_INFO {
	TransferSyntax        C.RPC_SYNTAX_IDENTIFIER
	DispatchTable         &C.RPC_DISPATCH_TABLE
	ProcString            &char
	FmtStringOffset       &u16
	TypeString            &char
	aUserMarshalQuadruple voidptr
	pReserved2            usize
}

// C.MIDL_INTERFACE_METHOD_PROPERTIES is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.MIDL_INTERFACE_METHOD_PROPERTIES {
	MethodCount      u16
	MethodProperties &C.MIDL_METHOD_PROPERTY_MAP
}

// C.MIDL_METHOD_PROPERTY_MAP is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.MIDL_METHOD_PROPERTY_MAP {
	count      u32
	Properties &C.MIDL_METHOD_PROPERTY
}

// C.MIDL_METHOD_PROPERTY is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.MIDL_METHOD_PROPERTY {
	Id    u32
	value usize
}

// C.UUID_VECTOR is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.UUID_VECTOR {
	Count u32
	Uuid  [1]&C.GUID
}

// C.RPC_SYNTAX_IDENTIFIER is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.RPC_SYNTAX_IDENTIFIER {
	SyntaxGUID    C.GUID
	SyntaxVersion C.RPC_VERSION
}

// C.RPC_VERSION is a struct that is used within internal RPC struct definitions.
// It is currently not used by rpv.
@[typedef]
pub struct C.RPC_VERSION {
	MajorVersion u16
	MinorVersion u16
}

// C.RPC_AUTH_INFO contains authentication related information about an RPC server.
// This includes for example the utilized security packages and the associated
// principal. rpv uses this struct only to parse the information and makes it
// accessible within the RpcAuthInfo struct.
pub struct RPC_AUTH_INFO {
pub:
	principal  &u16 = unsafe { nil }
	auth_svc   u32
	get_key_fn voidptr = unsafe { nil }
	arg        voidptr = unsafe { nil }
}

pub const max_simple_dict_entries = 0x200
pub const iid_iunknown = win.new_guid('00000000-0000-0000-C000-000000000046') or { panic(err) }
pub const dce_transfer_syntax = C.RPC_IF_ID
{
	Uuid:      win.new_guid('8A885D04-1CEB-11C9-9FE8-08002B104860') or { panic(err) }
	VersMajor: 2
	VersMinor: 0
}
pub const ndr64_transfer_syntax = C.RPC_IF_ID
{
	Uuid:      win.new_guid('71710533-BEBA-4937-8319-B5DBEF9CCC36') or { panic(err) }
	VersMajor: 2
	VersMinor: 0
}
pub const ior_callback = C.RPC_IF_ID
{
	Uuid:      win.new_guid('18f70770-8e64-11cf-9af1-0020AF6E72F4') or { panic(err) }
	VersMajor: 0
	VersMinor: 0
}
