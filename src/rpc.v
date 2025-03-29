module rpv

import os
import win
import utils
import internals { RpcServer, RpcInterface, RpcAddress, RpcServerInterface }

// RpvProcessInformation contains general process information like the pid,
// ppid or cmdline of a process. Moreover, it contains an RpcInfo struct
// that holds the RPC information that is associated with the corresponding
// process. If no RPC servers are present in the process, the RpcInfo struct
// has an rpc_type attribute with value no_rpc.
pub struct RpvProcessInformation {
	pub mut:
	pid		u32
	ppid	u32
	childs  []u32
	arch	win.Arch = win.Arch.unk
	name	string
	path	string
	cmdline string
	user	string
	version u64
	desc	string
	rpc_info RpcInfo
}

// RpcInfo contains RPC related information of a process. The RpcType determines
// the type of available RPC servers. This can be plain RPC, DCOM, Hybrid (RPC & DCOM)
// or no_rpc. General RPC server information is stored in the RpcServerInfo struct.
// RPC interface information is stored in an RpcInterfaceInfo array with one element
// per RPC interface
pub struct RpcInfo {
	pub:
	server_info RpcServerInfo
	interface_infos []RpcInterfaceInfo
	rpc_type RpcType
}

// RpcServerInfo contains general information about an RPC server. This includes its
// base address, authentication and endpoint information and the internal RpcServer
// struct that contains more low level information.
pub struct RpcServerInfo {
	pub:
	base voidptr
	server RpcServer
	intf_count int
	auth_infos []RpcAuthInfo
	endpoints []RpcEndpoint
}

// RpcInterfaceInfo contains general information about an RPC interface. This includes its
// uuid, base address, name, security callback and other information. Moreover it contains
// the MIDL_STUB_DESC that is required for decompiling the RPC methods of the interface.
pub struct RpcInterfaceInfo {
	pub:
	base voidptr
	dispatch_table_addr voidptr
	location win.LocationInfo
	id string
	version string
	annotation string
	ep_registered bool
	intf RpcInterface
	ndr_info NdrInfo
	typ RpcType
	methods []RpcMethod
	midl_stub_desc C.MIDL_STUB_DESC
	pub mut:
	name string
	sec_callback SecurityCallback
}

// RpcInterfaceInfo contains general information about an RPC interface. This includes its
// uuid, base address, name, security callback and other information. Moreover it contains
// the MIDL_STUB_DESC that is required for decompiling the RPC methods of the interface.
pub struct RpcBasicInfo {
	pub:
	server_info RpcServerBasicInfo
	interface_infos []RpcInterfaceBasicInfo
	rpc_type RpcType
}

// RpcServerBasicInfo is a reduced version of RpcServerInfo with only a subset of fields
// available. When enumerating RPC servers, RpcServerBasicInfo structs are generated.
// These can then be enriched to create RpcServerInfo structs.
pub struct RpcServerBasicInfo {
	pub:
	base voidptr
	server RpcServer
	intf_count int
}

// RpcInterfaceBasicInfo is a reduced version of RpcInterfaceInfo with only a subset of fields
// available. When enumerating RPC servers, RpcInterfaceBasicInfo structs are generated.
// These can then be enriched to create RpcInterfaceInfo structs.
pub struct RpcInterfaceBasicInfo {
	pub:
	base voidptr
	intf RpcInterface
	typ RpcType
}

// RpcMethod represents a method defined on an RPC interface. RpcMethods have a base address
// with their corresponding executable code and a format address that contains information
// on how the method has to be called. The format address is used during decompilation.
pub struct RpcMethod {
	pub:
	addr voidptr
	fmt voidptr
	offset u32
	pub mut:
	name string
	symbols []string
}

// RpcType is used to determine the type if RPC servers that are associated with a process.
// Processes without RPC server have an RPC type of no_rpc. DCOM servers have type dcom
// and mixed servers (RPC + DCOM) have type hybrid. Moreover, there is the type wrong_arch,
// since x64/x86 rpv is currently only capable of enumerating x64/x86 processes.
pub enum RpcType {
	rpc
	dcom
	hybrid
	no_rpc
	wrong_arch
}

// RpcAuthInfo contains authentication information that is used by the RPC server.
pub struct RpcAuthInfo {
	pub:
	principal string
	dll string
	package win.SecurityPackage
	get_key_fn voidptr
	arg voidptr
}

// SecurityCallback contains information about an RPC security callback. When registering
// RPC interfaces, a security callback can be specified that is called before RPC clients
// can invoke methods. The callback can check different attributes of the caller and then
// determine whether the call should be allowed.
pub struct SecurityCallback {
	pub mut:
	name string
	addr voidptr
	offset u32
	location win.LocationInfo
}

// RpcEndpoint contains information on an RPC endpoint that can be used to call an RPC server.
// RPC servers can have multiple endpoints associated where each endpoint can use different
// transport protocols (named pipe, TCP, HTTP, ...).
pub struct RpcEndpoint {
	pub:
	name string
	protocol string
}

// NdrInfo contains information on the Network Data Representation (NDR) of an RPC interface.
// NDR is used for marshalling and unmarshalling types during RPC calls. NDR information is
// also what allows RPC methods to be decompiled.
pub struct NdrInfo {
	pub:
	ndr_version u32
	midl_version u32
	flags usize
	syntax string
}

// get_rpc_process_infos returns an RpvProcessInformation array containing
// a process information for each process running. This method creates a
// temporary symbol resolver. If you already have a symbol resolver available,
// you should call the get_rpv_process_infos_ex method instead.
pub fn get_rpv_process_infos()! []RpvProcessInformation
{
	mut resolver := SymbolResolver{}
	return get_rpv_process_infos_ex(mut resolver)!
}

// get_rpc_process_infos returns an RpvProcessInformation array containing
// a process information for each process running. The current process is
// excluded from this procedure.
pub fn get_rpv_process_infos_ex(mut resolver SymbolResolver)! []RpvProcessInformation
{
	rpv_pid := os.getpid()

	arr_size := u32(0)
	mut processes := []u32{len: 1024}

	if !C.EnumProcesses(processes.data, u32(processes.cap) * sizeof(u32), &arr_size) {
		return error('Failed to enumerate processes.')
	}

	count := int(arr_size / sizeof(u32))
	processes.trim(count)

	mut process_infos := []RpvProcessInformation{cap: count - 1}

	for pid in processes
	{
		if pid == rpv_pid {
			continue
		}

		rpv_process_info := get_rpv_process_info(pid, mut resolver) or { continue }
		process_infos << rpv_process_info
	}

	return process_infos
}

// get_rpc_process_info returns an RpvProcessInformation struct for the
// specified pid. This struct includes general process information like
// pid, ppid or cmdline as well as RPC related information.
pub fn get_rpv_process_info(pid u32, mut resolver SymbolResolver)! RpvProcessInformation
{
	process_handle := win.open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	ppid := win.get_process_ppid(pid)!
	childs := win.get_process_childs(pid)!
	name := win.get_process_name(pid)!
	arch := win.get_process_arch(process_handle)!
	path := win.get_process_path_h(process_handle)!
	user := win.get_process_user_h(process_handle)!
	cmdline := win.get_process_cmdline_ha(process_handle, arch)!

	version := win.get_module_version(path) or { u64(0) }
	description := win.get_module_description(path) or { '' }

	mut error_obj := RpvProcessInformation {
		pid: pid
		ppid: ppid
		childs: childs
		arch: arch
		name: name
		path: path
		cmdline: cmdline
		user: user
		version: version
		desc: description
	}

	$if x64 {
		if arch == win.Arch.x86
		{
			error_obj.rpc_info = RpcInfo {
				rpc_type: .wrong_arch
			}

			return error_obj
		}
	}

	$if x32 {
		if arch == win.Arch.x64
		{
			error_obj.rpc_info = RpcInfo {
				rpc_type: .wrong_arch
			}

			return error_obj
		}
	}

	rpc_basic_info := get_process_rpc_server_h(process_handle) or
	{
		error_obj.rpc_info = RpcInfo {
			rpc_type: .no_rpc
		}

		return error_obj
	}

	rpc_info := rpc_basic_info.enrich_h(process_handle, mut resolver)!

	return RpvProcessInformation {
		pid: pid
		ppid: ppid
		childs: childs
		arch: arch
		name: name
		path: path
		cmdline: cmdline
		user: user
		version: version
		desc: description
		rpc_info: rpc_info
	}
}

// update uses an already obtained RpvProcessInformation and enumerates it's RPC server again.
// Instead of rescanning the memory of the process, the stored RPC information is used to find
// the RPC server. If the number of interfaces and the RPC type are unchanged, the complete
// server is considered unchanged. Otherwise, all Server properties are enumerated again.
pub fn (mut pi RpvProcessInformation) update(mut resolver SymbolResolver)!
{
	process_handle := win.open_process_ext(u32(C.PROCESS_ALL_ACCESS), false, pi.pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	basic_info := validate_rpc_server(process_handle, pi.rpc_info.server_info.server, pi.rpc_info.server_info.base)!

	if basic_info.interface_infos.len == pi.rpc_info.interface_infos.len && basic_info.rpc_type == pi.rpc_info.rpc_type
	{
		for mut intf_info in pi.rpc_info.interface_infos
		{
			resolver.attach_pdb(process_handle, intf_info.location.base, intf_info.location.size) or {
				utils.log_debug('Failed to attach PDB resolver: ${err}')
			}

			intf_info.name = resolver.load_uuid(intf_info.id)

			for mut method in intf_info.methods
			{
				/*
				 * The method.symbols property was supposed to hold symbol data for function parameters
				 * that is displayed during midl decompilation. However, at the time of writing, it seems
				 * that only combase.dll contains such symbols, unless the retrieval logic is wrong.
				 * Therefore, the symbol information is currently not further used, but might be in future.
				 */
				method.name = resolver.load_symbol(intf_info.location.path, method.addr) or { method.name }
				method.symbols = resolver.load_symbols(intf_info.location.path, method.addr) or { []string{} }
			}

			if intf_info.sec_callback.addr != &voidptr(0)
			{
				if intf_info.sec_callback.location.base != intf_info.location.base {
					resolver.attach_pdb(process_handle, intf_info.sec_callback.location.base, intf_info.sec_callback.location.size) or {
						utils.log_debug('Failed to attach PDB resolver: ${err}')
					}
				}

				intf_info.sec_callback.name = resolver.load_symbol(intf_info.sec_callback.location.path, u64(intf_info.sec_callback.addr)) or { '' }
				intf_info.sec_callback.offset = u32(usize(intf_info.sec_callback.addr) - usize(intf_info.location.base))
			}

			resolver.detach_pdb()
		}

		return
	}

	rpc_info := basic_info.enrich_h(process_handle, mut resolver)!
	pi.rpc_info = rpc_info
}

// get_process_rpc_server obtains the global RPC server from the specified PID
// and returns it wrapped in a RpcBasicInfo struct. In the event that the targeted
// process does not contain an RPC server, the returned RpcBasicInfo struct has
// an rpc_type with value no_rpc.
pub fn get_process_rpc_server(pid u32)! RpcBasicInfo
{
	process_handle := win.open_process_ext(u32(C.PROCESS_ALL_ACCESS), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	return get_process_rpc_server_h(process_handle)!
}

// get_process_rpc_server_h obtains the global RPC server from the specified
// process handle and returns it wrapped in a RpcBasicInfo struct. In the
// event that the targeted process does not contain an RPC server, the
// returned RpcBasicInfo struct has an rpc_type with value no_rpc.
pub fn get_process_rpc_server_h(process_handle win.HANDLE)! RpcBasicInfo
{
	module_array_size := u32(0)

	if !C.EnumProcessModulesEx(process_handle, &voidptr(0), 0, &module_array_size, u32(C.LIST_MODULES_ALL))
	{
		return error('Unable to enumerate process modules.')
	}

	module_count := int(module_array_size / sizeof(voidptr))
	utils.log_debug('Enumerated ${module_count} modules. Allocating memory.')

	module_array := unsafe { []voidptr{len: module_count} }

	if !C.EnumProcessModulesEx(process_handle, module_array.data, module_array_size, &module_array_size, u32(C.LIST_MODULES_ALL))
	{
		return error('Unable obtain module handles.')
	}

	for ctr := 0; ctr < module_count; ctr++
	{
		p_module_name := unsafe { &char(malloc(C.MAX_PATH)) }

		defer {
			unsafe { free(p_module_name) }
		}

		C.GetModuleFileNameExA(process_handle, module_array[ctr], p_module_name, u32(C.MAX_PATH))
		module_name := unsafe { p_module_name.vstring() }

		if module_name.ends_with('RPCRT4.dll')
		{
			section_info := win.get_module_data_section(process_handle, module_array[ctr])!
			utils.log_debug('Searching for RPC servers in ${section_info.base}+${section_info.size}')

			return find_rpc_server(process_handle, section_info) or { error('Process does not expose RPC services') }
		}
	}

	return error('Process has the RPC runtime not loaded.')
}

// find_rpc_server searches the specified section of the specified process for
// the global RpcServer and returns it wrapped in a RpcBasicInfo struct. In the
// event that the targeted process does not contain an RPC server, the
// returned RpcBasicInfo struct has an rpc_type with value no_rpc.
fn find_rpc_server(process_handle win.HANDLE, section_info win.ModuleSectionInfo)? RpcBasicInfo
{
	unsafe
	{
		for cts := u32(0); cts < section_info.size; cts += sizeof(voidptr)
		{
			p_rpc_server := win.read_proc_mem_s[u64](process_handle, section_info.base + cts) or { continue }
			rpc_server := win.read_proc_mem_s[RpcServer](process_handle, voidptr(p_rpc_server)) or { continue }

			return validate_rpc_server(process_handle, rpc_server, voidptr(p_rpc_server)) or {
				continue
			}
		}
	}

	return none
}

// validate_rpc_server checks whether the RPC server candidate at p_rpc_server conforms to the RpcServer
// struct. The function does this by validating several properties of the RpcServer struct against some
// expected values. If everything matches, an RpcBasicInfo structure is created around the server and
// returned as result. Otherwise, an error is returned.
fn validate_rpc_server(process_handle win.HANDLE, rpc_server RpcServer, p_rpc_server voidptr)! RpcBasicInfo
{
	mut contains_rpc := false
	mut contains_dcom := false

	dict := rpc_server.interfaces

	if  dict.number_of_entries > internals.max_simple_dict_entries || dict.number_of_entries == 0
	{
		return error('Invalid number of RPC interfaces')
	}

	p_table := unsafe { []voidptr{len: int(dict.number_of_entries)} }
	win.read_process_memory(process_handle, dict.p_array, p_table.data, dict.number_of_entries * sizeof(voidptr))!

	mut rpc_interface_infos := []RpcInterfaceBasicInfo{cap: p_table.len}

	for ctr := 0; ctr < dict.number_of_entries; ctr++
	{
		rpc_interface := win.read_proc_mem_s[RpcInterface](process_handle, p_table[ctr]) or { continue }

		if rpc_interface.server_interface.length != sizeof(RpcServerInterface)
		{
			continue
		}

		if !(rpc_interface.server_interface.transfer_syntax.equals(internals.dce_transfer_syntax) ||
			 rpc_interface.server_interface.transfer_syntax.equals(internals.ndr64_transfer_syntax))
		{
			continue
		}

		if rpc_interface.p_rpc_server != p_rpc_server
		{
			continue
		}

		mut interface_type := RpcType.rpc

		if (rpc_interface.flags & u32(C.RPC_IF_OLE)) != 0 || unsafe { vmemcmp(&rpc_interface.server_interface.interface_id, internals.ior_callback, sizeof(C.RPC_IF_ID)) } == 0
		{
			interface_type = RpcType.dcom
			contains_dcom = true
		}

		else {
			contains_rpc = true
		}

		rpc_interface_infos << RpcInterfaceBasicInfo {
			base: p_table[ctr]
			intf: rpc_interface
			typ: interface_type
		}
	}

	if rpc_interface_infos.len < 1 {
		return error('RPC server candidate does not contain any interfaces.')
	}

	utils.log_debug('Found global RpcServer at 0x${p_rpc_server} with ${rpc_interface_infos.len} interfaces.')

	rpc_server_info := RpcServerBasicInfo {
		base: p_rpc_server
		server: rpc_server
		intf_count: rpc_interface_infos.len
	}

	mut rpc_type := RpcType.rpc

	if contains_dcom && !contains_rpc {
		rpc_type = RpcType.dcom
	}

	else if contains_dcom && contains_rpc {
		rpc_type = RpcType.hybrid
	}

	return RpcBasicInfo {
		server_info: rpc_server_info
		interface_infos: rpc_interface_infos
		rpc_type: rpc_type
	}
}

// enrich enumerates additional information around an already obtained RpcBasicInfo.
// RpcBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the server structure itself, its base address
// and the structure and base addresses of its registered interfaces. Other data, like
// available RPC endpoints, authentication information, interface names and so on
// are added when calling the enrich function.
pub fn (rpc_info RpcBasicInfo) enrich(pid u32, mut resolver SymbolResolver)! RpcInfo
{
	enriched_server_info := rpc_info.server_info.enrich(pid)!
	mut enriched_interface_infos := []RpcInterfaceInfo{cap: rpc_info.interface_infos.len}

	for interface_info in rpc_info.interface_infos
	{
		enriched_interface_infos << interface_info.enrich(pid, mut resolver)!
	}

	return RpcInfo {
		server_info: enriched_server_info
		interface_infos: enriched_interface_infos
		rpc_type: rpc_info.rpc_type
	}
}

// enrich_h enumerates additional information around an already obtained RpcBasicInfo.
// RpcBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the server structure itself, its base address
// and the structure and base addresses of its registered interfaces. Other data, like
// available RPC endpoints, authentication information, interface names and so on
// are added when calling the enrich function.
pub fn (rpc_info RpcBasicInfo) enrich_h(process_handle win.HANDLE, mut resolver SymbolResolver)! RpcInfo
{
	enriched_server_info := rpc_info.server_info.enrich_h(process_handle)!
	mut enriched_interface_infos := []RpcInterfaceInfo{cap: rpc_info.interface_infos.len}

	for interface_info in rpc_info.interface_infos
	{
		enriched_interface_infos << interface_info.enrich_h(process_handle, mut resolver)!
	}

	return RpcInfo {
		server_info: enriched_server_info
		interface_infos: enriched_interface_infos
		rpc_type: rpc_info.rpc_type
	}
}

// enrich enumerates additional information around an already obtained RpcServerBasicInfo.
// RpcServerBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the server structure itself and its base address.
// This function adds authentication information and available RPC endpoints to create
// an RpcServerInfo structure.
pub fn (server_info RpcServerBasicInfo) enrich(pid u32)! RpcServerInfo
{
	rpc_auth_info := server_info.get_rpc_auth_info(pid)!
	rpc_endpoints := server_info.get_rpc_endpoints(pid)!

	return RpcServerInfo {
		base: server_info.base
		server: server_info.server
		intf_count: server_info.intf_count
		auth_infos: rpc_auth_info
		endpoints: rpc_endpoints
	}
}

// enrich_h enumerates additional information around an already obtained RpcServerBasicInfo.
// RpcServerBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the server structure itself and its base address.
// This function adds authentication information and available RPC endpoints to create
// an RpcServerInfo structure.
pub fn (server_info RpcServerBasicInfo) enrich_h(process_handle win.HANDLE)! RpcServerInfo
{
	rpc_auth_info := server_info.get_rpc_auth_info_h(process_handle)!
	rpc_endpoints := server_info.get_rpc_endpoints_h(process_handle)!

	return RpcServerInfo {
		base: server_info.base
		server: server_info.server
		intf_count: server_info.intf_count
		auth_infos: rpc_auth_info
		endpoints: rpc_endpoints
	}
}

// enrich enumerates additional information around an already obtained RpcInterfaceBasicInfo.
// RpcInterfaceBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the RpcInterface structure itself and its base address.
// This function adds additional information like RPC methods or security callback information
// to create an RpcInterfaceInfo struct.
pub fn (interface_info RpcInterfaceBasicInfo) enrich(pid u32, mut resolver SymbolResolver)! RpcInterfaceInfo
{
	process_handle := win.open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	return interface_info.enrich_h(process_handle, mut resolver)!
}

// enrich_h enumerates additional information around an already obtained RpcServerBasicInfo.
// RpcInterfaceBasicInfo does only contain information that was collected while enumerating
// available RpcServer. This includes the RpcInterface structure itself and its base address.
// This function adds additional information like RPC methods or security callback information
// to create an RpcInterfaceInfo struct.
pub fn (interface_info RpcInterfaceBasicInfo) enrich_h(process_handle win.HANDLE, mut resolver SymbolResolver)! RpcInterfaceInfo
{
	intf_name := interface_info.get_name(resolver)
	location_info := win.get_location_info_h(process_handle, interface_info.intf.server_interface.dispatch_table)!

	utils.log_debug('Reading dispatch table from: ${voidptr(interface_info.intf.server_interface.dispatch_table)}')
	dispatch_table := win.read_proc_mem_s[C.RPC_DISPATCH_TABLE](process_handle, interface_info.intf.server_interface.dispatch_table)!

	mut midl_server_info := C.MIDL_SERVER_INFO{}
	mut midl_stub_desc := C.MIDL_STUB_DESC{}

	mut rpc_methods := []RpcMethod{cap: int(dispatch_table.DispatchTableCount)}
	resolver.attach_pdb(process_handle, location_info.base, location_info.size) or {
		utils.log_debug('Failed to attach PDB resolver: ${err}')
	}

	if interface_info.intf.server_interface.interpreter_info != &voidptr(0)
	{
		utils.log_debug('Interface is interpreted stub.')

		midl_server_info = win.read_proc_mem_s[C.MIDL_SERVER_INFO](process_handle, interface_info.intf.server_interface.interpreter_info)!
		midl_stub_desc = win.read_proc_mem_s[C.MIDL_STUB_DESC](process_handle, midl_server_info.pStubDesc)!

		for ctr := 0; ctr < dispatch_table.DispatchTableCount; ctr++
		{
			base := win.read_proc_mem_s[usize](process_handle, unsafe { midl_server_info.DispatchTable + ctr }) or { break }
			fmt := win.read_proc_mem_s[u16](process_handle, unsafe { &u16(midl_server_info.FmtStringOffset) + ctr }) or { break }

			/*
			 * The method.symbols property was supposed to hold symbol data for function parameters
			 * that is displayed during midl decompilation. However, at the time of writing, it seems
			 * that only combase.dll contains such symbols, unless the retrieval logic is wrong.
			 * Therefore, the symbol information is currently not further used, but might be in future.
			 */
			name := resolver.load_symbol(location_info.path, u64(base)) or { 'Proc${ctr}' }
			symbols := resolver.load_symbols(location_info.path, u64(base)) or { []string{} }

			unsafe {
				rpc_methods << RpcMethod {
					addr: voidptr(base)
					fmt: voidptr(&u8(midl_server_info.ProcString) + fmt)
					offset:  u32(usize(base) - usize(location_info.base))
					name: name
					symbols: symbols
				}
			}
		}
	}

	mut sec_callback := SecurityCallback {
		addr: voidptr(interface_info.intf.sec_callback)
		name: ''
	}

	if sec_callback.addr != &voidptr(0)
	{
		if sec_location := win.get_location_info_h(process_handle, sec_callback.addr)
		{
			sec_callback.location = sec_location

			if location_info.base != sec_location.base {
				resolver.attach_pdb(process_handle, sec_location.base, sec_location.size) or {
					utils.log_debug('Failed to attach PDB resolver: ${err}')
				}
			}

			sec_callback.name = resolver.load_symbol(sec_location.path, u64(sec_callback.addr)) or { '' }
			sec_callback.offset = u32(usize(sec_callback.addr) - usize(sec_location.base))
		}
	}

	resolver.detach_pdb()

	mut annotation := ''
	ep_registred := interface_info.intf.ep_mapper_flags & 0x20 != 0x00

	if ep_registred
	{
		unsafe {
			annotation = cstring_to_vstring(interface_info.intf.annotation[..].data)
		}
	}

	return RpcInterfaceInfo {
		base: interface_info.base
		id: win.uuid_to_str(interface_info.intf.server_interface.interface_id) or { 'unknown' }
		version: win.get_interface_version(interface_info.intf.server_interface.interface_id)
		intf: interface_info.intf
		typ: interface_info.typ
		dispatch_table_addr: dispatch_table.DispatchTable
		location: location_info
		name: intf_name
		ep_registered: ep_registred
		annotation: annotation
		ndr_info: NdrInfo {
			ndr_version: midl_stub_desc.Version
			midl_version: midl_stub_desc.MIDLVersion
			flags: usize(midl_stub_desc.mFlags)
			syntax: win.uuid_to_str(interface_info.intf.server_interface.transfer_syntax) or { 'unknown' }
		}
		midl_stub_desc: midl_stub_desc
		sec_callback: sec_callback
		methods: rpc_methods
	}
}

// get_rpc_auth_info obtains the RPC authentication information for the specified
// RPC server. One RPC server can contain multiple auth infos. Therefore, the result
// is returned as an array of RpcAuthInfo structs.
pub fn (server_info RpcServerBasicInfo) get_rpc_auth_info(pid u32)! []RpcAuthInfo
{
	process_handle := win.open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	return server_info.get_rpc_auth_info_h(process_handle)!
}

// get_rpc_auth_info_h obtains the RPC authentication information for the specified
// RPC server. One RPC server can contain multiple auth infos. Therefore, the result
// is returned as an array of RpcAuthInfo structs.
pub fn (server_info RpcServerBasicInfo) get_rpc_auth_info_h(process_handle win.HANDLE)! []RpcAuthInfo
{
	key := 'SOFTWARE\\Microsoft\\Rpc\\SecurityService'
	key_handle := win.HANDLE(0)

	utils.log_debug('Opening registry key ${key}')

	if C.RegOpenKeyExA(C.HKEY_LOCAL_MACHINE, &char(key.str), 0, C.KEY_READ, &key_handle) != C.ERROR_SUCCESS
	{
		return error('Unable to obten SecurityService key via RegOpenKeyExA')
	}

	defer {
		C.RegCloseKey(key_handle)
	}

	sec_packages := win.enum_security_packages()!
	dict := server_info.server.authen_info_dict

	if dict.number_of_entries > internals.max_simple_dict_entries
	{
		return error('Malformed RpcServerInfo. Contains to many auth infos.')
	}

	p_table := unsafe { []voidptr{len: int(dict.number_of_entries)} }
	win.read_process_memory(process_handle, dict.p_array, p_table.data, dict.number_of_entries * sizeof(voidptr))!

	utils.log_debug('Starting to walk through RpcAuthInfo table at ${dict.p_array} (len: ${dict.number_of_entries})')

	mut rpc_auth_infos := []RpcAuthInfo{}
	unsafe {

		for ctr := 0; ctr < dict.number_of_entries; ctr++
		{
			auth_info := win.read_proc_mem_s[internals.RPC_AUTH_INFO](process_handle, p_table[ctr]) or { continue }

			for sec_package in sec_packages
			{
				if sec_package.rpc_id != auth_info.auth_svc
				{
					continue
				}

				utils.log_debug('Found SecurityPackage match for: ${sec_package.name} (id: ${sec_package.rpc_id})')

				size := C.MAX_PATH
				p_buffer := &char(malloc(C.MAX_PATH))

				defer {
					free(p_buffer)
				}

				mut dll_name := ''
				mut principal := ''

				if C.RegQueryValueExA(key_handle, &char(auth_info.auth_svc.str().str), &voidptr(0), &voidptr(0), p_buffer, &size) == C.ERROR_SUCCESS
				{
					dll_name = cstring_to_vstring(p_buffer)
				}

				if C.ReadProcessMemory(process_handle, auth_info.principal, p_buffer, C.MAX_PATH, &voidptr(0))
				{
					principal = string_from_wide(&u16(p_buffer))
				}

				rpc_auth_infos << RpcAuthInfo {
					principal: principal
					dll: dll_name
					package: sec_package
					get_key_fn: auth_info.get_key_fn
					arg: auth_info.arg
				}
			}
		}
	}

	utils.log_debug('Returning ${rpc_auth_infos.len} SecurityPackages')
	return rpc_auth_infos
}

// get_rpc_endpoints obtains the available RPC endpoints for the specified
// RPC server. One RPC server can contain multiple RPC endpoints. Therefore,
// the result is returned as an array of RpcEndpoint structs.
pub fn (server_info RpcServerBasicInfo) get_rpc_endpoints(pid u32)! []RpcEndpoint
{
	process_handle := win.open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	return server_info.get_rpc_endpoints_h(process_handle)!
}

// get_rpc_endpoints_h obtains the available RPC endpoints for the specified
// RPC server. One RPC server can contain multiple RPC endpoints. Therefore,
// the result is returned as an array of RpcEndpoint structs.
pub fn (server_info RpcServerBasicInfo) get_rpc_endpoints_h(process_handle win.HANDLE)! []RpcEndpoint
{
	dict := server_info.server.address_dict

	if dict.number_of_entries > internals.max_simple_dict_entries
	{
		return error('Malformed RpcServerInfo. Contains to many endpoints.')
	}

	p_table := unsafe { []voidptr{len: int(dict.number_of_entries)} }
	win.read_process_memory(process_handle, dict.p_array, p_table.data, dict.number_of_entries * sizeof(voidptr))!

	utils.log_debug('Starting to walk through RpcAddress table at ${voidptr(dict.p_array)} (len: ${dict.number_of_entries})')

	mut rpc_endpoints := []RpcEndpoint{}

	unsafe {
		p_buffer := &u16(malloc(C.MAX_PATH))

		defer {
			free(p_buffer)
		}

		for entry in p_table
		{
			rpc_addr := win.read_proc_mem_s[RpcAddress](process_handle, entry) or { continue }

			win.read_process_memory(process_handle, rpc_addr.name, p_buffer, 0x100) or { continue }
			name := string_from_wide(p_buffer)

			win.read_process_memory(process_handle, rpc_addr.protocol, p_buffer, 0x100) or { continue }
			protocol := string_from_wide(p_buffer)

			rpc_endpoints << RpcEndpoint {
				name: name
				protocol: protocol
			}
		}
	}

	utils.log_debug('Found ${rpc_endpoints.len} RPC endpoints.')
	return rpc_endpoints
}

// get_interface_name attempts to obtain the interfaces name either via registered COM
// interfaces within the registry or via a lookup within an rpc symbol file. If no name
// is found, an empty string is returned.
pub fn (interface_info RpcInterfaceBasicInfo) get_name(resolver SymbolResolver) string
{
	mut name := win.get_com_interface_name(interface_info.intf.server_interface.interface_id) or { '' }

	if name != ''
	{
		return name
	}

	uuid := win.uuid_to_str(interface_info.intf.server_interface.interface_id) or { return name }
	return mut resolver.load_uuid(uuid)
}
