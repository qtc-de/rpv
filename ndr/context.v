module ndr

import win
import utils

// NdrContext holds the decompilation context when decompiling an interface.
// This includes a process handle to the process that contains the interface
// (for reading it's process memory), the C.MIDL_STUB_DESC of the interface
// (to find type definitions based on their offset) and a TypeCache to
// quickly recognize types that have already been decompiled.
// 
pub struct NdrContext {
	process_handle win.HANDLE
	stub_desc C.MIDL_STUB_DESC
	flags NdrInterpreterOptFlags2
	pub mut:
	type_cache &TypeCache
}

// newNdrContext creates a new NdrContext. The main reason why we have a constructor
// here is to leave the struct fields access modifiers untouched. In newer v releases,
// initializing private struct fields seems only possible using a constructor.
pub fn NdrContext.new(handle win.HANDLE, stub_desc C.MIDL_STUB_DESC, flags NdrInterpreterOptFlags2, mut cache &TypeCache) NdrContext
{
	return NdrContext {
		process_handle: handle
		stub_desc: stub_desc
		flags: flags
		type_cache: cache
	}
}

// read attempts to read the type <T> from process memory at the specified
// address. If successfully, a newly created <T> type is returned. How many
// bytes to read is determined by the structure size of <T>. Notice that
// the specified address to read from is mutable. It will be incremented
// by the size of type <T>.
pub fn (context NdrContext) read[T](mut src &voidptr)! T
{
	return win.read_proc_mem[T](context.process_handle, mut src)!
}

// read_s (read_static) attempts to read the type <T> from process memory
// at the specified address. If successful, a newly created <T> type is
// returned. How many bytes to read is determined by the structure size of
// <T>. In contrast to the read function, this method does not modify the
// specified source address to read from.
pub fn (context NdrContext) read_s[T](src voidptr)! T
{
	return win.read_proc_mem_s[T](context.process_handle, src)!
}

// add_offset reads an i16 type from process memory at the specified
// address and returns the specified address incremented by the read
// amount. Many NDR types are using this pattern. Notice that the
// specified address is only incremented by the read i16 type's size.
// The address incremented by the offset is only provided as return
// value.
pub fn (mut context NdrContext) add_offset(mut addr &voidptr)! usize
{
	current := isize(*addr)
	offset := context.read[i16](mut addr)!

	if offset == 0
	{
		return 0
	}

	return usize(current + offset)
}

// read_offset reads an u16 type from process memory at the specified
// address and adds it to the specified address. Afterwards, the type
// at the new destination is read and returned. Notice that the
// specified address is only incremented by the read u16 type's size.
pub fn (mut context NdrContext) read_offset(mut addr &voidptr)! NdrType
{
	global_offset := u16(usize(*addr) - usize(context.stub_desc.pFormatTypes))
	relative_offset := context.read[u16](mut addr)!

	return context.read_type(global_offset + relative_offset)!
}

// read_type attempts to resolve an NDR type add pFormatTypes + offset.
// The method first checks, whether the specified offset was already
// resolved and can be found within the type cache. If this is the case,
// the cached type is returned. Newly resolved types are automatically
// added to the type cache.
pub fn (mut context NdrContext) read_type(offset u16)! NdrType
{
	type_offset := unsafe { voidptr(&u8(context.stub_desc.pFormatTypes) + offset) }

	if context.type_cache.contains(type_offset)
	{
		utils.log_debug('Found offset 0x${type_offset} in type cache!')
		return context.type_cache.get(type_offset)!
	}

	context.type_cache.set(type_offset, NdrIndirectTypeReference{})

	mut ptr := type_offset

	ret := context.read_type_ext(mut &ptr)!
	context.type_cache.set(type_offset, ret)

	return ret
}

// read_type_ext reads the next NdrFormatChar from the specified address
// and applies the corresponding parsing function.
pub fn (mut context NdrContext) read_type_ext(mut addr &voidptr)! NdrType
{
	mut addr_old := *addr
	mut format := context.read[NdrFormatChar](mut addr)!

	for
	{
		utils.log_debug('Found ${format} at 0x${voidptr(addr_old)}')

		match format {
			.fc_byte,
            .fc_char,
            .fc_small,
            .fc_usmall,
            .fc_wchar,
            .fc_short,
            .fc_ushort,
            .fc_long,
            .fc_ulong,
            .fc_float,
            .fc_hyper,
            .fc_double,
            .fc_enum16,
            .fc_enum32,
            .fc_error_status_t,
            .fc_int3264,
			.fc_uint3264
			{
				return NdrSimpleType{ format: format }
			}

			.fc_op,
			.fc_up,
			.fc_rp,
			.fc_fp
			{
				return context.read_pointer(format, mut addr)!
			}

			.fc_ip
			{
				return context.read_interface_pointer(mut addr)!
			}

			.fc_c_cstring,
			.fc_c_bstring,
			.fc_c_wstring
			{
				return context.read_conformant_string(format, mut addr)!
			}

			.fc_cstring,
			.fc_bstring,
			.fc_wstring
			{
				return context.read_string(format, mut addr)!
			}

			.fc_c_sstring
			{
				return context.read_conformant_structure_string(mut addr)!
			}

			.fc_sstring
			{
				return context.read_structure_string(mut addr)!
			}

            .fc_user_marshal
			{
				utils.log_debug('TODO: fc_user_marshal')
			}

            .fc_embedded_complex
			{
				context.read[u8](mut addr)! // padding
				return context.read_offset(mut addr)!
			}

            .fc_struct
			{
				mut base_struct := context.read_base_struct(format, mut addr)!
				base_struct.read_member_info(mut context, mut addr)!

				check_known(mut base_struct)
				context.type_cache.add_complex(base_struct)

				return base_struct
			}

            .fc_pstruct
			{
				return context.read_struct_with_pointers(mut addr)!
			}

			.fc_cvstruct,
            .fc_cstruct
			{
				return context.read_conformant_struct(format, mut addr)!
			}

            .fc_bogus_struct,
            .fc_forced_bogus_struct
			{
				return context.read_bogus_struct(format, mut addr)!
			}

            .fc_pp
			{
				return context.read_pointer_info(mut addr)!
			}

			.fc_smfarray,
            .fc_lgfarray
			{
				return context.read_simple_array(format, mut addr)!
			}

			.fc_carray,
            .fc_cvarray
			{
				return context.read_conformant_array(format, mut addr)!
			}

            .fc_bogus_array
			{
				return context.read_bogus_array(format, mut addr)!
			}

			.fc_lgvarray,
            .fc_smvarray
			{
				return context.read_varying_array(format, mut addr)!
			}

            .fc_range
			{
				return context.read_range(mut addr)!
			}

            .fc_encapsulated_union,
			.fc_non_encapsulated_union
			{
				return context.read_union(format, mut addr)!
			}

            .fc_structpad1,
            .fc_structpad2,
            .fc_structpad3,
            .fc_structpad4,
            .fc_structpad5,
            .fc_structpad6,
            .fc_structpad7
			{
				return NdrStructPad { format: format }
			}

            .fc_ignore
			{
				return NdrIgnore { format: format }
			}

            .fc_system_handle
			{
				return context.read_system_handle(mut addr)!
			}

            .fc_auto_handle,
            .fc_bind_context,
            .fc_bind_generic,
            .fc_bind_primitive,
            .fc_callback_handle
			{
				return NdrHandle{ format: format }
			}

            .fc_pipe
			{
				return context.read_pipe(mut addr)!
			}

            .fc_supplement
			{
				return context.read_supplement(mut addr)!
			}

            .fc_byte_count_pointer
			{
				return context.read_byte_count_pointer(mut addr)!
			}

            .fc_end
			{
				return NdrNone{}
			}

			.fc_pad {}

			else
			{
				utils.log_debug('Returning NdrUnknownType')
				return NdrUnknownType { format: format }
			}
		}

		addr_old = addr
		format = context.read[NdrFormatChar](mut addr)!
	}

	return NdrBaseType{}
}

// read_param attempts to read the param definition for an RPC method from process
// memory. For understanding the format of a method parameter, it is helpful to look
// at the associated Microsoft resource:
//
// https://learn.microsoft.com/de-de/windows/win32/rpc/parameter-descriptors#the-oif-parameter-descriptors
pub fn(mut context NdrContext) read_param(mut addr &voidptr, name string)! NdrBasicParam
{
	mut typ := NdrType(NdrNone{})

	attrs := context.read[NdrParamAttrs](mut addr)!
	stack_offset := context.read[u16](mut addr)!

	if !attrs.has(.is_basetype)
	{
		type_offset := context.read[u16](mut addr)!
		typ = context.read_type(type_offset)!
	}

	else
	{
		typ = NdrSimpleType {
			format: context.read[NdrFormatChar](mut addr)!
		}

		utils.log_debug('Found simple type: ${typ}')
		context.read[u8](mut addr)! // padding
	}

	return NdrBasicParam {
		attrs: attrs
		offset: stack_offset
		name: name
		typ: typ
	}
}
