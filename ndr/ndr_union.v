module ndr

import math
import utils

// NdrUnionArm represents one possible representation an RPC union can take.
// The arm_type member indicates the type of the Union if the respective arm
// is used. The case_value is used to reference the arm by another field or
// parameter within procedure calls or struct definitions.
pub struct NdrUnionArm {
	arm_type NdrType
	case_value int
	name string
}

// read_union_arm attempts to read an NdrUnionArm from process memory at the
// specified address.
pub fn (mut context NdrContext) read_union_arm(mut addr &voidptr)! NdrUnionArm
{
	case_value := context.read[int](mut addr)!
	arm_type := context.read_arm_type(mut addr)!

	mut name := 'arm_${case_value}'

	if case_value < 0
	{
		name = 'arm_minus_${math.abs(case_value)}'
	}

	return NdrUnionArm {
		arm_type: arm_type
		case_value: case_value
		name: name
	}
}

// Attempt to read the NdrType of an NDR union arm at the specified
// address from process memory.
pub fn (mut context NdrContext) read_arm_type(mut addr &voidptr)! NdrType
{
	typ := context.read[u16](mut addr)!

	if (typ & 0xFF00 == 0x8000) || typ == 0
	{
		return NdrSimpleType {
			format: unsafe { NdrFormatChar(typ & 0xFF) }
		}
	}

	else if typ == 0xFFFF
	{
		return NdrNone{}
	}

	else
	{
		unsafe
		{
			*addr = voidptr(&u8(*addr) - 2)
		}

		return context.read_offset(mut addr)!
	}
}

// NdrUnionArms represents all possible representation an RPC union can take.
// The different possible types are contained within the arms member and
// are encapsulated within NdrUnionArm structs. The default_arm describes
// which representation is chosen by default, if no other one was specified.
pub struct NdrUnionArms {
	memory_size u16
	arms []NdrUnionArm
	default_arm NdrType = NdrNone{}
	alignment int
}

// read_union_arms attempts to read an NdrUnionArms struct from process memory
// At the specified address.
pub fn (mut context NdrContext) read_union_arms(mut addr &voidptr)! NdrUnionArms
{
	memory_size := context.read[u16](mut addr)!
	start_word := context.read[u16](mut addr)!

	alignment := (start_word >> 12) & 0x0F
	count := start_word & 0xFFF

	utils.log_debug('Reading union arms - size: ${memory_size}, start: ${start_word}, count: ${count}')

	mut arms := []NdrUnionArm{cap: int(count)}

	for ctr := 0; ctr < count; ctr++
	{
		arms << context.read_union_arm(mut addr)!
	}

	default_arm := context.read_arm_type(mut addr)!

	return NdrUnionArms {
		memory_size: memory_size
		arms: arms
		default_arm: default_arm
		alignment: alignment
	}
}

// NdrUnion represents an NDR union type. It extends NdrComplexType by the
// required fields to implement the ComplexType interface. Moreover, it contains
// information on the available NdrUnionArms and which type is the switch type.
//
// NDR union types can be encapsulated or nonencapsulated. For encapsulated union
// types, the union definition and the switch that selects the union arm are
// wrapped within a separate struct. In this struct, the first member is the
// switch type that specifies what union arm should be used, whereas the second
// member is the union definition. The wrapping struct can then be used in RPC
// calls without supplying further parameters.
//
// For nonencapsulated unions, it depends where the union is used. If it is used
// as a struct member, the switch type must be another struct member within the
// same struct. If it is used within a method, the switch type needs to be another
// parameter within the same method.
//
// More details can be found within the Microsoft RPC union documentation:
//
// https://learn.microsoft.com/en-us/windows/win32/rpc/unions
pub struct NdrUnion {
	NdrComplexType
	id u32
	location voidptr
	switch_type NdrFormatChar
	switch_increment int
	arms NdrUnionArms
	correlation MaybeCorrelationDescriptor
	encapsulated bool
}

// format returns the string representation of an NdrUnion. This is just the
// union name, prefixed by either the struct or union keyword (depending on
// whether the union is encapsulated or not). This function should be used
// when formatting the union for method calls or struct definitions.
pub fn (uni NdrUnion) format() string
{
	if uni.encapsulated
	{
		return 'struct ${uni.name}'
	}

	return 'union ${uni.name}'
}

// attrs returns an array of NdrAttr that is associated with the NdrUnion.
// NdrUnion contains an optional correlation descriptor. This function just
// returns the attributes provided by this descriptor.
pub fn (uni NdrUnion) attrs() []NdrAttr
{
	return uni.correlation.attrs()
}

// size returns the size of an NdrUnion. The size of an NdrUnion is it's
// arms memory size plus the size of the switch.
pub fn (uni NdrUnion) size() u32
{
	return u32(uni.arms.memory_size + uni.switch_increment)
}

// get_definition returns the string representation of the union as it
// would be defined within an IDL file. This function should be called
// once per decompiled IDL, to add the definition of the union to the
// result.
pub fn (uni NdrUnion) get_definition() string
{
	mut union_def := '/* Memory Size: ${uni.size()} */\n'
	union_def += 'typedef [switch_type(${uni.switch_type.format()})] '
	union_def += '${uni.format()} {\n'

	mut indent := '\t'

	if uni.encapsulated
	{
		simple_type := NdrSimpleType { format: uni.switch_type }
		union_def += '\t${simple_type.format()} Selector;'
		union_def += '\tunion {\n'

		indent = '\t\t'
	}

	else
	{
		for comment in uni.correlation.comments()
		{
			union_def += '${indent}/* ${comment.value} */\n'
		}
	}

	for arm in uni.arms.arms
	{
		for comment in arm.arm_type.comments()
		{
			union_def += '${indent}/* ${comment.value} */\n'
		}

		union_def += '${indent}[case(${arm.case_value})]'

		mut attrs := arm.arm_type.attrs()
		attrs = attrs.filter(match it
			{
				NdrStrAttr,
				NdrExprAttr,
				NdrConstantAttr,
				NdrRelativeOffsetAttr
				{
					true
				}
				else { false }
			}
		)

		if attrs.len > 0
		{
			union_def += attrs.format()
		}

		if arm.arm_type.format != .fc_zero
		{
			union_def += ' ${arm.arm_type.format()} ${arm.name}${arm.arm_type.array()};\n'
		}

		else
		{
			union_def += ' /* FC_ZERO */;\n'
		}
	}

	match uni.arms.default_arm
	{
		NdrNone {}
		else
		{
			union_def += '${indent}/* default */\n'

			if uni.arms.default_arm.format != .fc_zero
			{
				union_def += '${indent}${uni.arms.default_arm.format()} Default;\n'
			}
		}
	}

	if uni.encapsulated
	{
		indent = '\t'
		union_def += '${indent}};\n'
	}

	return union_def + '} ${uni.name};\n'
}

// read_union attempts to read an NdrUnion type from the specified address
// in process memory.
pub fn (mut context NdrContext) read_union(format NdrFormatChar, mut addr &voidptr)! NdrUnion
{
	location := *addr
	id := context.type_cache.get_id(location)

	mut switch_increment := 0
	mut arms := NdrUnionArms{}
	mut switch_type := context.read[u8](mut addr)!
	mut correlation := MaybeCorrelationDescriptor(NdrNone{})

	encapsulated := format != .fc_non_encapsulated_union

	if !encapsulated
	{
		correlation = context.read_correlation_descriptor(format, mut addr)!

		mut offset := voidptr(context.add_offset(mut addr)!)
		arms = context.read_union_arms(mut &offset)!
	}

	else
	{
		switch_increment = (switch_type >> 4) & 0x0F
		switch_type = switch_type & 0x0F
		arms = context.read_union_arms(mut addr)!
	}

	uni := NdrUnion {
		NdrComplexType: NdrComplexType {
			format: format
			name: 'Union_${id}'
			member_count: u32(arms.arms.len)
		}
		id: id
		location: location
		switch_type: unsafe { NdrFormatChar(switch_type) }
		switch_increment: switch_increment
		arms: arms
		correlation: correlation
		encapsulated: encapsulated
	}

	context.type_cache.add_complex(uni)

	return uni
}
