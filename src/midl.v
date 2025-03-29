module rpv

import win
import ndr
import utils

const oi_has_rpc_flags = u8(0x08)
const explicit_handle = u8(0x00)

// MidlInterface contains detailed RPC interface information. This includes the id,
// name and version of the interface, as well as RPC methods and type definitions
// that are used within these methods. The MidlInterface struct can be obtained by
// decompiling an RPC interface.
pub struct MidlInterface {
	pub:
	id string
	name string
	version string
	types []ndr.ComplexType
	functions []MaybeMidlFunction
}

// format returns IDL source code as string for the corresponding MidlInterface
// struct. The source code contains all method definitions, as well as type
// definitions that are used by the corresponding methods.
pub fn (intf MidlInterface) format() string
{
	mut result := '[\n\tuuid(${intf.id}),\n\tversion(${intf.version})\n]\n\n'

	result += 'interface ${intf.name}\n{\n'

	for typ in intf.types
	{
		for line in typ.get_definition().split_into_lines()
		{
			result += '\t${line}\n'
		}

		result += '\n'
	}

	for func in intf.functions
	{
		match func
		{
			MidlFunction
			{
				for line in func.format().split_into_lines()
				{
					result += '\t${line}\n'
				}
			}

			MidlInvalidFunction
			{
				result += '\t/* decoding ${func.name} failed */\n'
			}
		}

		result += '\n'
	}

	return result + '}'
}

// MidlFunction contains detailed RPC method information. This includes the name
// of a method, information in it's required parameters and return value and other
// information. A MidlFunction struct can be obtained by decompiling an RPC method.
struct MidlFunction {
	pub mut:
	name string
	offset usize
	opcode int
	arg_num u8
	arg_offset usize
	handle_offset usize
	interpreter_flags ndr.NdrFlags
	param_list []ndr.NdrBasicParam
	return_value ndr.NdrBasicParam
}

// format returns the IDL source code of a MidlFunction struct as string. This string
// only includes the method's source code and does not contain type definitions that
// are used within the method.
pub fn (func MidlFunction) format() string
{
	mut func_str := '${func.return_value.format()} ${func.name}('

	if func.param_list.len == 0 {
		return '${func_str});'
	}

	for param in func.param_list
	{
		for comment in param.comments()
		{
			func_str += '\n\t/* ${comment.value} */'
		}

		func_str += '\n\t'
		attrs := param.attrs()

		if attrs.len > 0
		{
			func_str += '${attrs.format_function(func.param_list)} '
		}

		func_str += '${param.format()},'
	}

	for param in func.param_list
	{
		func_str = func_str.replace('offset(${param.offset})', param.name)
	}

	return '${func_str[..func_str.len-1]}\n);'
}

// MidlInvalidFunction represents an RPC method that was not successfully decompiled.
// It is used within the sum type MaybeMidlFunction to represent possible success
// of the decompilation methods.
struct MidlInvalidFunction {
	pub mut:
	name string
}

// MaybeMidlFunction contains either a valid MidlFunction struct, that represents an
// successfully decompiled RPC method or a MidlInvalidFunction that represents a failed
// RPC method decompilation result.
type MaybeMidlFunction = MidlFunction | MidlInvalidFunction

// decode_all_methods attempts to decompile all RPC methods defined on an RPC interface.
// If successful, the method returns a MidlInterface struct for the RPC interface. However,
// decompilation can be partial successful, if only some methods failed to decompile. In
// this case, these functions are represented by the MidlInvalidFunction struct.
pub fn (intf RpcInterfaceInfo) decode_all_methods(pid u32)! MidlInterface
{
	return intf.decode_methods(pid, []int{len: intf.methods.len, init: index})!
}

// decode_methods attempts to decompile specific RPC methods defined on an RPC interface.
// The methods to decompiled are selected by specifying their index within the methods array.
// If successful, the method returns a MidlInterface struct for the RPC interface. However,
// decompilation can be partial successful, if only some methods failed to decompile. In
// this case, these functions are represented by the MidlInvalidFunction struct.
pub fn (intf RpcInterfaceInfo) decode_methods(pid u32, methods []int)! MidlInterface
{
	mut resolver := SymbolResolver{}
	mut type_cache := ndr.TypeCache{}

	functions := intf.decode_methods_ex(pid, methods, mut resolver, mut type_cache)!

	mut types := type_cache.get_types()
	types.sort(a.id < b.id)

	mut name := intf.name
	if name == ''
	{
		name = '${intf.id}'
	}

	return MidlInterface {
		id: '${intf.id}'
		name: name.replace('-', '')
		version: intf.version
		types: types
		functions: functions
	}
}

// decode_methods_ex attempts to decompile specific RPC methods defined on an RPC interface.
// The methods to decompiled are selected by specifying their index within the methods array.
// If successful, the method returns a MidlInterface struct for the RPC interface. However,
// decompilation can be partial successful, if only some methods failed to decompile. In
// this case, these functions are represented by the MidlInvalidFunction struct.
// Callers can specify an already existing SymbolResolver and TypeCache for this function.
// If such structures do not already exist, it is recommended to use the decode_methods method,
// that creates these structures on the fly.
pub fn (intf RpcInterfaceInfo) decode_methods_ex(pid u32, methods []int, mut resolver SymbolResolver, mut type_cache ndr.TypeCache)! []MaybeMidlFunction
{
	process_handle := win.open_process_ext(u32(C.PROCESS_VM_READ | C.PROCESS_QUERY_INFORMATION), false, pid)!

	defer {
		C.CloseHandle(process_handle)
	}

	utils.log_debug('Decoding ${intf.methods.len} methods from RPC interface ${intf.id}')

	resolver.attach_pdb(process_handle, intf.location.base, intf.location.size) or {}
	mut fct_arr := []MaybeMidlFunction{cap: intf.methods.len}

	for ctr in methods
	{
		if fct := intf.decode_method(process_handle, ctr, mut resolver, mut type_cache)
		{
			fct_arr << fct
		}

		else
		{
			utils.log_debug('Error while decoding method: ${err}')
			fct_arr << MidlInvalidFunction { name: 'Proc${ctr}' }
		}
	}

	resolver.detach_pdb()
	return fct_arr
}

// decode_method attempts to decompile an RPC method. The target method is specified by it's
// method index. The specified process handle needs to match the process, where the RPC interface
// is defined in. During the function call, rpv attempts to read the corresponding process memory
// to obtain the RPC method definition.
// The method definition is heavily influenced by the NtApiDotNet, RpcView and mIDA projects.
pub fn (intf RpcInterfaceInfo) decode_method(process_handle win.HANDLE, index int, mut resolver SymbolResolver, mut type_cache ndr.TypeCache)! MidlFunction
{
	if index >= intf.methods.len
	{
		return error('Method index is out of range: ${index} >= ${intf.methods.len}')
	}

	method := intf.methods[index]
	utils.log_debug('Decoding method at 0x${voidptr(method.fmt)}')

	unsafe
	{
		mut ptr := method.fmt

		handle_type := win.read_proc_mem[u8](process_handle, mut &ptr)!
		oi_flags := win.read_proc_mem[u8](process_handle, mut &ptr)!
		mut rpc_flags := u32(0)

		if (oi_flags & oi_has_rpc_flags) != 0
		{
			rpc_flags = win.read_proc_mem[u32](process_handle, mut &ptr)!
		}

		mut handle := ndr.NdrHandleParam{}

		proc_num := win.read_proc_mem[u16](process_handle, mut &ptr)!
		stack_size := win.read_proc_mem[u16](process_handle, mut &ptr)!

		utils.log_debug('\tHandle type: 0x${handle_type.hex()}')
		utils.log_debug('\tOi Flags: 0x${oi_flags.hex()}')
		utils.log_debug('\tRPC Flags: 0x${rpc_flags.hex()}')
		utils.log_debug('\tProc Num: 0x${proc_num.hex()}')
		utils.log_debug('\tStack Size: 0x${stack_size.hex()}')

		// https://learn.microsoft.com/en-us/windows/win32/rpc/handles#explicit-handles
		if handle_type == explicit_handle
		{
			utils.log_debug('Reading explicit handle.')

			context_type := win.read_proc_mem[u8](process_handle, mut &ptr)!
			context_flags := win.read_proc_mem[ndr.NdrHandleParamFlags](process_handle, mut &ptr)!
			handle_offset := win.read_proc_mem[u16](process_handle, mut &ptr)!
			param_type := ndr.NdrType(ndr.NdrSimpleType.new(ndr.NdrFormatChar(context_type)))

			utils.log_debug('Function bind type is 0x${context_type.hex()}')

			match context_type
			{
				u8(ndr.NdrFormatChar.fc_bind_generic) {
					context_flags = ndr.NdrHandleParamFlags(u8(context_flags) & 0xF0)
					ptr = voidptr(&u16(ptr) + 1)
				}

				u8(ndr.NdrFormatChar.fc_bind_context) {
					ptr = voidptr(&u16(ptr) + 1)
				}

				u8(ndr.NdrFormatChar.fc_bind_primitive) {
					if u8(context_flags) != 0 {
						context_flags = ndr.NdrHandleParamFlags.handle_param_is_via_ptr
					}
				}

				else
				{
					return error('Unsupported explicit handle type: 0x${context_type.hex()}')
				}
			}

			if context_flags.has(.handle_param_is_via_ptr)
			{
				param_type = ndr.NdrPointer.new(ndr.NdrFormatChar.fc_pointer, param_type, ndr.NdrPointerFlags.fc_simple_pointer)
			}

			handle = ndr.NdrHandleParam {
				NdrBasicParam: ndr.NdrBasicParam {
					name: 'binding'
					attrs: .is_binding
					typ: param_type
					offset: handle_offset
				}
				flags: context_flags
				explicit: true
				generic: context_type == u8(ndr.NdrFormatChar.fc_bind_generic)
			}
		}

		else
		{
			handle = ndr.NdrHandleParam {
				NdrBasicParam: ndr.NdrBasicParam {
					name: 'binding'
					attrs: .is_binding
					typ: ndr.NdrSimpleType.new(ndr.NdrFormatChar(handle_type))
					offset: 0
				}
				flags: ndr.NdrHandleParamFlags(0)
				explicit: false
				generic: false
			}
		}

		ptr = voidptr(&u16(ptr) + 1) //client_buffer := win.read_proc_mem[u16](process_handle, mut &ptr)!
		ptr = voidptr(&u16(ptr) + 1) //server_buffer := win.read_proc_mem[u16](process_handle, mut &ptr)!

		interpreter_flags := win.read_proc_mem[ndr.NdrFlags](process_handle, mut &ptr)!
		mut arg_num := win.read_proc_mem[u8](process_handle, mut &ptr)!

		if interpreter_flags.has(ndr.NdrFlags.has_return)
		{
			arg_num -= 1
		}

		header_exts := ndr.NdrProcHeaderExts{}

		if interpreter_flags.has(.has_extensions)
		{
			ext_hdr_size := win.read_proc_mem_s[u8](process_handle, ptr)!
			utils.log_debug('\tExt. Header Size: ${ext_hdr_size}')

			if ext_hdr_size >= sizeof(header_exts)
			{
				// NdrProcHeaderExts contains an additional field for x64. However, this field
				// is currently unused by rpv. We simply go with a general structure for both
				// architectures and skip possibly unread bytes afterwards.

				header_exts = win.read_proc_mem_s[ndr.NdrProcHeaderExts](process_handle, ptr)!
				ptr = voidptr(&u8(ptr) + ext_hdr_size)
			}
		}

		context := ndr.NdrContext.new(process_handle, intf.midl_stub_desc, header_exts.flags, mut type_cache)

		param_list := []ndr.NdrBasicParam{cap: int(arg_num) + 1}
		utils.log_debug('Parsing ${arg_num} procedure parameters at ${voidptr(intf.midl_stub_desc.pFormatTypes)}.')

		for ctr := 0; ctr < arg_num; ctr++
		{
			param_list << context.read_param(mut &ptr, 'arg${ctr}')!
		}

		if handle.explicit && !handle.generic
		{
			for ctr := 0; ctr < param_list.len; ctr++
			{
				if param_list[ctr].offset > handle.offset
				{
					param_list.insert(ctr, handle.NdrBasicParam)
					break
				}
			}

			for ctr := 0; ctr < param_list.len; ctr++
			{
				param_list[ctr].name = 'arg${ctr}'
			}
		}

		mut midl_function := MidlFunction {
			name: method.name
			offset: method.addr
			opcode: index
			arg_num: arg_num
			arg_offset: usize(ptr)
			handle_offset: 0
			interpreter_flags: interpreter_flags
			param_list: param_list
		}

		if interpreter_flags.has(ndr.NdrFlags.has_return)
		{
			utils.log_debug('Reading return value from 0x${voidptr(ptr)}')
			midl_function.return_value = context.read_param(mut &ptr, 'retval')!
		}

		return midl_function
	}
}
