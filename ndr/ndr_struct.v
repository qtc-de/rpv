module ndr

import utils

// MaybePointerInfo represents the possible presence of an NdrPointerInfo
// struct. It is a sum type between NdrPointerInfo and NdrNone.
type MaybePointerInfo = NdrPointerInfo | NdrNone

// NdrPointerInfoInstance is a pointer like struct that contains the
// offsets and the NdrType type of the referenced type. At least that's
// what I would guess. This type was copied from James implementation
// and I'm not really sure, how it is used or formatted.
pub struct NdrPointerInfoInstance {
	mem_offset int
	buf_offset int
	pointer_type NdrType
}

// read_pointer_info_instance attempts to read an NdrPointerInfoInstace
// from process memory at the specified address.
pub fn (mut context NdrContext) read_pointer_info_instance(mut addr &voidptr)! NdrPointerInfoInstance
{
	mem_offset := context.read[u16](mut addr)!
	buf_offset := context.read[u16](mut addr)!
	pointer_type := context.read_type_ext(mut addr)!

	return NdrPointerInfoInstance {
		mem_offset: mem_offset
		buf_offset: buf_offset
		pointer_type: pointer_type
	}
}

// NdrPointerInfo is a pointer like struct that probably references another
// NDR type. At least that's what I would guess. This type was copied from
// James implementation and I'm not really sure, how it is used or formatted.
pub struct NdrPointerInfo {
	NdrBaseType
	base_ptr_type NdrFormatChar
	sub_ptr_type NdrFormatChar
	iterations int
	increment int
	offset int
	ptr_instances []NdrPointerInfoInstance
}

// read_pointer_info attempts to read an NdrPointerInfo from process
// memory at the specified address.
pub fn (mut context NdrContext) read_pointer_info(mut addr &voidptr)! NdrPointerInfo
{
	context.read[u8](mut addr)! //padding
	mut instances := []NdrPointerInfoInstance{}

	mut offset := 0
	mut increment := 0
	mut iterations := 0

	base_ptr_type := context.read[NdrFormatChar](mut addr)!
	sub_ptr_type := context.read[NdrFormatChar](mut addr)!
	utils.log_debug('Base pointer type is ${base_ptr_type}')

	match base_ptr_type
	{
		.fc_no_repeat { instances << context.read_pointer_info_instance(mut addr)! }
		.fc_fixed_repeat,
		.fc_variable_repeat {

			if base_ptr_type == .fc_fixed_repeat
			{
				iterations = context.read[u16](mut addr)!
			}

			increment = context.read[i16](mut addr)!
			offset = context.read[i16](mut addr)!
			ptr_num := context.read[i16](mut addr)!

			utils.log_debug('Attempting to read ${ptr_num} pointers')

			for ctr := 0; ctr < ptr_num; ctr++ {
				instances << context.read_pointer_info_instance(mut addr)!
			}
		}
		else {}
	}

	for context.read[NdrFormatChar](mut addr)! != NdrFormatChar.fc_end {}

	return NdrPointerInfo {
		format: NdrFormatChar.fc_pp
		base_ptr_type: base_ptr_type
		sub_ptr_type: sub_ptr_type
		iterations: iterations
		increment: increment
		offset: offset
		ptr_instances: instances
	}
}

// NdrComplexType is the base type that is extended by all other struct
// definitions within this file. The NdrBaseType member indicates the type
// of the underlying struct.
pub struct NdrComplexType {
	NdrBaseType
	member_count u32
	mut:
	name string
}

// NdrStructMember represents one member of an NdrStruct. A struct member
// needs obviously an associated type and an offset within the struct.
// Additionally, the member name is saved within NdrStructMember.
pub struct NdrStructMember {
	pub:
	typ NdrType
	offset u32
	name string
}

// NdrStructPad represents padding that is applied to struct members.
// Padding bytes are common within of struct definitions to align types
// to certain boundaries. NdrStructPad just consists out of the
// NdrBaseType that defines the padding.
pub struct NdrStructPad {
	NdrBaseType
}

// size returns the actual size of the padding provided by NdrStructPad.
// The size can take values from one to seven depending on the inner
// NdrBaseType.
pub fn (pad NdrStructPad) size() u32
{
	match pad.format
	{
		.fc_structpad1 { return 1 }
		.fc_structpad2 { return 2 }
		.fc_structpad3 { return 3 }
		.fc_structpad4 { return 4 }
		.fc_structpad5 { return 5 }
		.fc_structpad6 { return 6 }
		.fc_structpad7 { return 7 }
		else {}
	}

	return 0
}

// NdrBaseStruct is the most basic NDR structure type. Struct members
// of an NdrBaseStruct are contained in the members array. Moreover,
// NdrBaseStruct adds some additional fields to implement the ComplexType
// interface.
pub struct NdrBaseStruct {
	NdrComplexType
	id u32
	alignment u8
	memory_size int
	location voidptr
	mut:
	members []NdrType
	names	[]string
}

// read_base_struct attempts to read an NdrBaseStruct from process memory
// at the specified address.
pub fn (mut context NdrContext) read_base_struct(format NdrFormatChar, mut addr &voidptr)! NdrBaseStruct
{
	location := *addr
	alignment := context.read[u8](mut addr)!
	memory_size := context.read[u16](mut addr)!
	id := context.type_cache.get_id(location)

	return NdrBaseStruct {
		id: id
		format: format
		name: 'Struct_${id}'
		alignment: alignment
		memory_size: memory_size
		location: location
	}
}

// read_member_info attempts to read struct members from the specified
// address in process memory. Members are added to the members array
// within the NdrBaseStruct. Notice that this method also reads padding
// bytes as separate members.
fn (mut base NdrBaseStruct) read_member_info(mut context NdrContext, mut addr &voidptr)!
{
	for
	{
		next := context.read_type_ext(mut addr)!

		match next
		{
			NdrNone { break }
			else { base.members << next }
		}
	}
}

// get_members returns the actual struct members of the struct as an array
// of NdrStructMember. In doing so, it skips any padding bytes that are
// contained within the members array. Moreover, this function assigns each
// member a name and an offset within the struct.
pub fn (base NdrBaseStruct) get_members() []NdrStructMember
{
	mut cur_offset := u32(0)
	mut members := []NdrStructMember{cap: base.members.len}

	for member in base.members
	{
		match member
		{
			NdrStructPad{}
			else
			{
				mut member_name := 'StructMember${cur_offset:X}'

				if members.len < base.names.len
				{
					member_name = base.names[members.len]
				}

				members << NdrStructMember {
					typ: member
					offset: cur_offset
					name: member_name
				}
			}
		}

		cur_offset += member.size()
	}

	return members
}

// format returns the string representation of an NdrBaseStruct. This is
// simply the struct name prefixed with the struct keyword. To get the
// IDL struct definition, the get_definition function needs to be called.
// This function is meant to be called when formatting the struct for
// parameter usage within IDL function descriptions.
pub fn (base NdrBaseStruct) format() string
{
	return 'struct ${base.name}'
}

// get_definition returns a string representation of NdrBaseStruct as it
// would be used within IDL. This function should only be called once per
// decompiled IDL interface to add the struct definition to the result.
pub fn (base NdrBaseStruct) get_definition() string
{
	mut struct_def := '/* Memory Size: ${base.memory_size} */\n'
	struct_def += 'typedef ${base.format()} {\n'

	members := base.get_members()

	for member in members
	{
		struct_def += '\t'

		for comment in member.typ.comments()
		{
			struct_def += '/* ${comment.value} */\n\t'
		}

		mut attrs := member.typ.attrs()

		if attrs.len > 0
		{
			attrs_str := attrs.format_struct(member, members)
			struct_def += '${attrs_str} '
		}

		struct_def += '${member.typ.format()} ${member.name}${member.typ.array()};\n'
	}

	return struct_def + '} ${base.name};'
}

// attrs returns an array of NdrAttr associated with the NdrBaseStruct.
// This is always an empty array, as NdrBaseStruct never has associated
// attributes.
pub fn (base NdrBaseStruct) attrs() []NdrAttr
{
	return []NdrAttr{}
}

// comments returns an array of NdrComment associated with the NdrBaseStruct.
// This is always an empty array, as NdrBaseStruct never has associated
// comments.
pub fn (base NdrBaseStruct) comments() []NdrComment
{
	return []NdrComment{}
}

// size returns the size of an NdrBaseStruct. This is just the value contained
// within the .memory_size member of the struct.
pub fn (base NdrBaseStruct) size() u32
{
	return u32(base.memory_size)
}

// NdrSimpleStructWithPointers is basically the same as NdrBaseStruct, but also
// contains an NdrPointerInfo. At the time of writing, the pointer information
// is not used at all and the struct is formatted in the same way as NdrBaseStruct.
pub struct NdrSimpleStructWithPointers {
	NdrBaseStruct
	pointer_info NdrPointerInfo
}

// read_struct_with_pointers attempts to read an NdrSimpleStructWithPointers struct
// from process memory at the specified address.
pub fn (mut context NdrContext) read_struct_with_pointers(mut addr &voidptr)! NdrSimpleStructWithPointers
{
	mut base_struct := context.read_base_struct(.fc_pstruct, mut addr)!
	fc_pp := context.read[NdrFormatChar](mut addr)!

	if fc_pp != .fc_pp
	{
		return error('Found unexpected pointer tpye in FC_PSTRUCT at 0x${voidptr(addr)}')
	}

	utils.log_debug('Reading pointer info')
	pointer_info := context.read_pointer_info(mut addr)!

	utils.log_debug('Reading member info')
	base_struct.read_member_info(mut context, mut addr)!

	pointer_struct := NdrSimpleStructWithPointers {
		NdrBaseStruct: base_struct
		pointer_info: pointer_info
	}

	context.type_cache.add_complex(pointer_struct)
	return pointer_struct
}

// NdrConformantStruct extends NdrBaseStruct by adding an additional conformant array
// that describes the struct. At the time of writing, the conformant_array is not used
// at all and the struct is formatted the same as NdrBaseStruct.
pub struct NdrConformantStruct {
	NdrBaseStruct
	conformant_array NdrType
}

// read_conformant_struct attempts to read an NdrConformantStruct at the specified address
// from process memory.
pub fn (mut context NdrContext) read_conformant_struct(format NdrFormatChar, mut addr &voidptr)! NdrConformantStruct
{
	mut base_struct := context.read_base_struct(format, mut addr)!
	conformant_array := context.read_offset(mut addr)!

	utils.log_debug('Reading member info')
	base_struct.read_member_info(mut context, mut addr)!
	base_struct.members << conformant_array

	conf_struct := NdrConformantStruct {
		NdrBaseStruct: base_struct
		conformant_array: conformant_array
	}

	context.type_cache.add_complex(conf_struct)
	return conf_struct
}

// NdrBogusStruct extends NdrBaseStruct by adding an additional conformant array
// that describes the struct. At the time of writing, the conformant_array is not used
// at all and the struct is formatted the same as NdrBaseStruct.
pub struct NdrBogusStruct {
	NdrBaseStruct
	conformant_array NdrType
}

// read_bogus_struct attempts to read an NdrBogusStruct at the specified address
// from process memory.
pub fn (mut context NdrContext) read_bogus_struct(format NdrFormatChar, mut addr &voidptr)! NdrBogusStruct
{
	mut base_struct := context.read_base_struct(format, mut addr)!

	conformant_array := context.read_offset(mut addr)!
	pointer_offset := context.add_offset(mut addr)!

	utils.log_debug('Reading member info')
	base_struct.read_member_info(mut context, mut addr)!

	if pointer_offset != 0
	{
		mut pointer_addr := voidptr(pointer_offset)

		for ctr := 0; ctr < base_struct.members.len; ctr++
		{
			match base_struct.members[ctr].format
			{
				.fc_pointer
				{
					base_struct.members[ctr] = context.read_type_ext(mut &pointer_addr)!
				}
				else {}
			}
		}
	}

	match conformant_array
	{
		NdrNone,
		NdrUnknownType {}
		else { base_struct.members << conformant_array }
	}

	bogus_struct := NdrBogusStruct {
		NdrBaseStruct: base_struct
		conformant_array: conformant_array
	}

	context.type_cache.add_complex(bogus_struct)
	return bogus_struct
}

// NdrIgnore is basically equivalent to an `NdrBaseType`, but gets an additional comment
// during formatting, that indicates that the type should be ignored.
pub struct NdrIgnore {
	NdrBaseType
}

// size returns the current size of a voidptr.
pub fn (ignore NdrIgnore) size() u32
{
	return sizeof(voidptr)
}

// comment returns a comment string that indicates that the type should be ignored.
pub fn (ignore NdrIgnore) comments() []NdrComment
{
	return [NdrComment{ value: 'ignore' }]
}
