module ndr

import utils

// NdrFormatChar contains a list of possible types that can be encountered
// within an NDR type definition.
pub enum NdrFormatChar as u8
{
	fc_zero = u8(0x00)
	fc_byte = u8(0x01)
	fc_char = u8(0x02)
	fc_small = u8(0x03)
	fc_usmall = u8(0x04)
	fc_wchar = u8(0x05)
	fc_short = u8(0x06)
	fc_ushort = u8(0x07)
	fc_long = u8(0x08)
	fc_ulong = u8(0x09)
	fc_float = u8(0x0A)
	fc_hyper = u8(0x0B)
	fc_double = u8(0x0C)
	fc_enum16 = u8(0x0D)
	fc_enum32 = u8(0x0E)
	fc_ignore = u8(0x0F)
	fc_error_status_t = u8(0x10)
	fc_rp = u8(0x11)
	fc_up = u8(0x12)
	fc_op = u8(0x13)
	fc_fp = u8(0x14)
	fc_struct = u8(0x15)
	fc_pstruct = u8(0x16)
	fc_cstruct = u8(0x17)
	fc_cpstruct = u8(0x18)
	fc_cvstruct = u8(0x19)
	fc_bogus_struct = u8(0x1A)
	fc_carray = u8(0x1B)
	fc_cvarray = u8(0x1C)
	fc_smfarray = u8(0x1D)
	fc_lgfarray = u8(0x1E)
	fc_smvarray = u8(0x1F)
	fc_lgvarray = u8(0x20)
	fc_bogus_array = u8(0x21)
	fc_c_cstring = u8(0x22)
	fc_c_bstring = u8(0x23)
	fc_c_sstring = u8(0x24)
	fc_c_wstring = u8(0x25)
	fc_cstring = u8(0x26)
	fc_bstring = u8(0x27)
	fc_sstring = u8(0x28)
	fc_wstring = u8(0x29)
	fc_encapsulated_union = u8(0x2A)
	fc_non_encapsulated_union = u8(0x2B)
	fc_byte_count_pointer = u8(0x2C)
	fc_transmit_as = u8(0x2D)
	fc_represent_as = u8(0x2E)
	fc_ip = u8(0x2F)
	fc_bind_context = u8(0x30)
	fc_bind_generic = u8(0x31)
	fc_bind_primitive = u8(0x32)
	fc_auto_handle = u8(0x33)
	fc_callback_handle = u8(0x34)
	fc_unused1 = u8(0x35)
	fc_pointer = u8(0x36)
	fc_alignm2 = u8(0x37)
	fc_alignm4 = u8(0x38)
	fc_alignm8 = u8(0x39)
	fc_unused2 = u8(0x3A)
	fc_unused3 = u8(0x3B)
	fc_system_handle = u8(0x3C)
	fc_structpad1 = u8(0x3D)
	fc_structpad2 = u8(0x3E)
	fc_structpad3 = u8(0x3F)
	fc_structpad4 = u8(0x40)
	fc_structpad5 = u8(0x41)
	fc_structpad6 = u8(0x42)
	fc_structpad7 = u8(0x43)
	fc_string_sized = u8(0x44)
	fc_unused5 = u8(0x45)
	fc_no_repeat = u8(0x46)
	fc_fixed_repeat = u8(0x47)
	fc_variable_repeat = u8(0x48)
	fc_fixed_offset = u8(0x49)
	fc_variable_offset = u8(0x4A)
	fc_pp = u8(0x4B)
	fc_embedded_complex = u8(0x4C)
	fc_in_param = u8(0x4D)
	fc_in_param_basetype = u8(0x4E)
	fc_in_param_no_free_inst = u8(0x4F)
	fc_in_out_param = u8(0x50)
	fc_out_param = u8(0x51)
	fc_return_param = u8(0x52)
	fc_return_param_basetype = u8(0x53)
	fc_dereference = u8(0x54)
	fc_div_2 = u8(0x55)
	fc_mult_2 = u8(0x56)
	fc_add_1 = u8(0x57)
	fc_sub_1 = u8(0x58)
	fc_callback = u8(0x59)
	fc_constant_iid = u8(0x5A)
	fc_end = u8(0x5B)
	fc_pad = u8(0x5C)
	fc_expr = u8(0x5D)
	fc_split_dereference = u8(0x74)
	fc_split_div_2 = u8(0x75)
	fc_split_mult_2 = u8(0x76)
	fc_split_add_1 = u8(0x77)
	fc_split_sub_1 = u8(0x78)
	fc_split_callback = u8(0x79)
	fc_forced_bogus_struct = u8(0xB1)
	fc_transmit_as_ptr = u8(0xB2)
	fc_represent_as_ptr = u8(0xB3)
	fc_user_marshal = u8(0xB4)
	fc_pipe = u8(0xB5)
	fc_supplement = u8(0xB6)
	fc_range = u8(0xB7)
	fc_int3264 = u8(0xB8)
	fc_uint3264 = u8(0xB9)
}

// format provides formatting for basic NDR types. This really only applies to
// basic types, whereas complex type use their own format definitions.
pub fn (format NdrFormatChar) format() string
{
	typ_str := match format
	{
		.fc_byte { 'byte' }
		.fc_c_cstring,
		.fc_cstring,
		.fc_char { 'char' }
		.fc_small,
		.fc_usmall { 'small' }
		.fc_c_wstring,
		.fc_wchar { 'wchar_t' }
		.fc_short,
		.fc_enum16 { 'short' }
		.fc_ushort { 'unsigned short' }
		.fc_long,
		.fc_enum32 { 'long' }
		.fc_ulong { 'unsigned long' }
		.fc_float { 'float' }
		.fc_hyper { 'hyper' }
		.fc_double { 'double' }
		.fc_error_status_t { 'error_status_t' }
		.fc_ignore,
		.fc_int3264 { '__int3264' }
		.fc_uint3264 { 'unsigned __int3264' }
		.fc_system_handle { 'HANDLE' }
		.fc_auto_handle,
		.fc_callback_handle,
		.fc_bind_primitive,
		.fc_bind_generic { 'handle_t' }
		.fc_bind_context { 'void*' }

		else { format.str() }
	}

	return typ_str
}

// NdrNone is a helper type to indicate that an NDR type definition is missing.
// Some NDR types can have optional additional types associated. To indicate
// whether they exist or not, rpv uses Maybe structs that fallback to NdrNone
// if the type is not present.
pub struct NdrNone {
	NdrBaseType
}

// NdrNone if an NdrNone type needs to be formatted, it is always displayed as
// void. This is especially important for methods without return value.
pub fn (none_type NdrNone) format() string
{
	return 'void'
}

// NdrBaseType is the most basic NDR type. It just consists out of a NdrFormatChar.
// By default, the type is initialized with a format char with value .fc_zero.
pub struct NdrBaseType {
	format NdrFormatChar = .fc_zero
}

// attrs returns attributes for NdrBaseType. Since NdrBaseType cannot have attributes,
// the return value is always an empty NdrAttr array.
pub fn (base_type NdrBaseType) attrs() []NdrAttr
{
	return []NdrAttr{}
}

// comment returns comments associated with the NdrBaseType. This is only used if
// the underlying NdrFormatChar is an enum, to indicate whether it is enum_16
// or enum_32.
pub fn (base_type NdrBaseType) comments() []NdrComment
{
	mut comments := []NdrComment{}

	match base_type.format
	{
		.fc_enum16 { comments << NdrComment { 'enum_16' } }
		.fc_enum32 { comments << NdrComment { 'enum_32' } }
		else {}
	}

	return comments
}

// format returns the string representation of an NdrBaseType. This is always
// the same, as the result of the format method for the underlying NdrFormatChar.
pub fn (base_type NdrBaseType) format() string
{
	return base_type.format.format()
}

// size determines the size of the NdrBaseType. This is obviously the same as
// the size of the underlying NdrFormatChar.
pub fn (base_type NdrBaseType) size() u32
{
	match base_type.format
	{
		.fc_byte,
		.fc_small,
		.fc_char,
		.fc_usmall,
		.fc_c_cstring,
		.fc_cstring
		{
			return 1
		}

		.fc_wchar,
		.fc_short,
		.fc_ushort
		{
			return 2
		}

		.fc_long,
		.fc_ulong,
		.fc_float,
		.fc_enum16,
		.fc_enum32,
		.fc_error_status_t
		{
			return 4
		}

		.fc_hyper,
		.fc_double
		{
			return 8
		}

		.fc_int3264,
		.fc_uint3264
		{
			return sizeof(voidptr)
		}

		else
		{
			utils.log_debug('Requested size() for non matched format: ${base_type.format}')
			return 0
		}
	}
}

// NdrUnknownType extends NdrBaseType and is used if the decompilation process found
// an unknown NdrRepresentation. This should actually not happen and indicates a bug.
pub struct NdrUnknownType {
	NdrBaseType
}

// format returns the string representation of NdrUnknownType. Since this type is not
// meant to be formatted, it returns a string indicating an internal error.
pub fn (unk_typ NdrUnknownType) format() string
{
	return 'Internal error O.x'
}

// NdrSimpleType extends NdrBaseType. At the time of writing, I have no Idea why
// it was created and whether NdrBaseType could also be used instead. Should be
// investigated in future. At the first glance, it adds no additional functionality
// to NdrBaseType.
pub struct NdrSimpleType {
	NdrBaseType
}

// format returns the string representation of NdrSimpleType. This is always the
// same as the result of calling the format method on the underlying NdrBaseType.
pub fn (simple_type NdrSimpleType) format() string
{
	return simple_type.NdrBaseType.format()
}

// NdrIndirectTypeReference represents an NdrType that needs to be resolved. This
// was copied from the type cache implementation of James Forshaw and is probably
// used to allow the cache to work correctly for recursive type definitions. I
// think it is currently not fully implemented in rpv. This should be investigated.
pub struct NdrIndirectTypeReference {
	NdrBaseType
}

// format returns the string representation of NdrIndirectTypeReference. This type
// is probably not meant to be formatted and an error should be returned. Currently,
// this function returns the result of the format method, called on the underlying
// NdrBaseType. Whether this makes sense needs to be investigated.
pub fn (indirect_type NdrIndirectTypeReference) format() string
{
	return indirect_type.NdrBaseType.format()
}

// NdrType is an interface that needs to be implemented by all NdrTypes. The interface
// makes sure that each NdrType has an underlying NdrFormatChar and that it supports
// the format, attrs, comments and size methods. These methods are required to create
// the string representation of the NdrType.
interface NdrType {
	format NdrFormatChar
	format() string
	attrs() []NdrAttr
	comments() []NdrComment
	size() u32
}

// array returns an array modifier if the underlying NdrType is an array type.
// Corresponding types are expected to contain a length method, that can be used
// to determine the length of the array. An array with length five returns for
// example an modifier of [5]. Non array types return an empty modifier.
pub fn (typ NdrType) array() string
{
	mut array_mod := ''

	match typ
	{
		NdrBogusArray
		{
			array_mod = '[${typ.length()}]'
		}

		NdrSimpleArray
		{
			array_mod = '[${typ.length()}]'
		}

		NdrVaryingArray
		{
			array_mod = '[${typ.length()}]'
		}

		NdrConformantArray
		{
			array_mod = '[${typ.length()}]'
		}

		else
		{
			return ''
		}
	}

	if array_mod == '[0]'
	{
		return '[]'
	}

	return array_mod
}
