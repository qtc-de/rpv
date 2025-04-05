module ndr

import utils

// NDR Correlation Descriptors are kind of crazy. In general, they describe the
// relationship of one RPC struct members or arguments to other struct members
// or arguments. There are several different types of possible correlation
// descriptors. The Microsoft documentation provides quite some amount of details.
// That being said, it's still pretty hard to fully understand it and the
// implementation in this file is following the implementation by James Forshaw
//
// https://learn.microsoft.com/en-us/windows/win32/rpc/correlation-descriptors-tfs
// https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools/blob/main/NtApiDotNet/Ndr/NdrCorrelationDescriptor.cs

// NdrCorrelationType describes the different possible correlation types.
// The different types are explained in the following Microsoft article:
//
// https://learn.microsoft.com/en-us/windows/win32/rpc/correlation-descriptors-tfs
pub enum NdrCorrelationType as u8
{
	fc_normal_conformance = 0
	fc_pointer_conformance = 0x10
	fc_top_level_conformance = 0x20
	fc_constant_conformance = 0x40
	fc_top_level_multid_conformance = 0x80
}

// NdrCorrelationFlags provide additional information on a CorrelationDescriptor.
// As far as I remember, only the range member of this enum is currently used and
// implemented by rpv.
@[flag]
pub enum NdrCorrelationFlags as u8
{
	reserved
	early
	split
	is_iid_is
	dont_check
	range
}

// NdrCorrelationDescriptorRange represents a range like CorrelationDescriptor.
// This is used for values that should be part of a certain min-max range.
struct NdrCorrelationDescriptorRange
{
	min_value int
	max_value int
}

// MaybeCorrelationDescriptorRange represents the possible presence of an
// NdrCorrelationDescriptorRange. When parsing this struct from memory, it
// can result in an invalid range. In this case, it is discarded and NdrNone
// is returned instead. This sum type combines both types together.
type MaybeCorrelationDescriptorRange = NdrCorrelationDescriptorRange | NdrNone

// read_correlation_descriptor_range attempts to read an NdrCorrelationDescriptorRange
// from the specified address. If it succeeds, the parsed NdrCorrelationDescriptorRange
// is returned. Otherwise, NdrNone is returned. Both types are wrapped within the
// MaybeCorrelationDescriptorRange type.
pub fn (context NdrContext) read_correlation_descriptor_range(mut addr &voidptr)! MaybeCorrelationDescriptorRange
{
	is_valid := context.read[u8](mut addr)!
	unsafe { *addr = voidptr(&u8(*addr) + 1) }

	min_value := context.read[int](mut addr)!
	max_value := context.read[int](mut addr)!

	if (is_valid & 1) == 0
	{
		return NdrNone{}
	}

	return NdrCorrelationDescriptorRange {
		min_value: min_value
		max_value: max_value
	}
}

// NdrCorrelationDescriptor represents an NDR Correlation Descriptor. The struct
// holds all information that describes the correlation. This includes the
// correlation type, the correlation flags, an optional correlation range and
// an optional correlation expression.
struct NdrCorrelationDescriptor
{
	correlation_type NdrCorrelationType
	value_type NdrFormatChar
	operator NdrFormatChar
	offset int
	flags NdrCorrelationFlags
	range MaybeCorrelationDescriptorRange
	expression MaybeExpression = MaybeExpression(NdrNone{})
	parent NdrFormatChar
}

// MaybeCorrelationDescriptor represents the possible presence of a
// NdrCorrelationDescriptor. When parsing this struct from memory, it
// can result in an invalid correlation descriptor. In this case, it
// is discarded and NdrNone is returned instead. This sum type
// combines both types together.
type MaybeCorrelationDescriptor = NdrCorrelationDescriptor | NdrNone


// read_correlation_descriptor attempts to read an NdrCorrelationDescriptor
// from the specified address. If it succeeds, the parsed NdrCorrelationDescriptor
// is returned. Otherwise, NdrNone is returned. Both types are wrapped within the
// MaybeCorrelationDescriptor type.
pub fn (context NdrContext) read_correlation_descriptor(format NdrFormatChar, mut addr &voidptr)! MaybeCorrelationDescriptor
{
	type_byte := context.read[u8](mut addr)!
	op_byte := context.read[u8](mut addr)!
	mut offset := int(context.read[i16](mut addr)!)

	utils.log_debug('Reading correlation descriptor (type: ${type_byte.hex()}, op: ${op_byte.hex()}, offset: ${offset})')

	mut flags := 0
	mut range := MaybeCorrelationDescriptorRange(NdrNone{})
	mut operator := unsafe { NdrFormatChar(op_byte) }
	mut expression := MaybeExpression(NdrNone{})

	correlation_type := unsafe { NdrCorrelationType(type_byte & 0xF0) }
	value_type := unsafe { NdrFormatChar(type_byte & 0x0F) }

	if context.flags.has(.has_new_corr_desc) || context.flags.has(.has_range_on_conformance)
	{
		utils.log_debug('  new: ${context.flags.has(.has_new_corr_desc)}, range: ${context.flags.has(.has_range_on_conformance)}')
		flags = context.read[u16](mut addr)!

		if context.flags.has(.has_range_on_conformance)
		{
			range = context.read_correlation_descriptor_range(mut addr)!
		}
	}

	if type_byte != 0xFF || op_byte != 0xFF || offset != -1
	{
		if correlation_type == NdrCorrelationType.fc_constant_conformance
		{
			offset |= int(u32(op_byte) << 16)
			operator = .fc_zero
		}

		else if operator == .fc_expr
		{
			utils.log_debug('Reading correlation expression')
			expression = context.read_context_expression(offset)!
		}
	}

	else
	{
		return NdrNone{}
	}

	return NdrCorrelationDescriptor {
		correlation_type: correlation_type
		value_type: value_type
		operator: operator
		offset: offset
		flags: unsafe { NdrCorrelationFlags(flags) }
		range: range
		expression: expression
		parent: format
	}
}

// attrs returns an array of NdrAttr types that are defined by this
// correlation descriptor. NdrAttr is basically the way rpv expresses
// correlation. A correlation between two parameters for example is
// wrapped into an attribute and attached to the corresponding
// parameters.
pub fn (desc NdrCorrelationDescriptor) attrs() []NdrAttr
{
	mut ndr_attributes := []NdrAttr{}

	if desc.operator == .fc_expr
	{
		mut expr := desc.expression

		match mut expr
		{
			NdrOperatorExpression
			{
				ndr_attributes << NdrExprAttr
				{
					arguments: expr.arguments
					expression: expr.format()
					correlation_type: desc.correlation_type
					typ: desc.parent
				}
			}

			else
			{
				utils.log_debug('Missing implementation for ${expr}.')
			}
		}
	}

	else
	{
		match desc.correlation_type
		{
			.fc_top_level_conformance,
			.fc_pointer_conformance
			{
				ndr_attributes << NdrGlobalOffsetAttr
				{
					offset: desc.offset
					typ: desc.parent
					operator: desc.operator
				}
			}

			.fc_normal_conformance
			{
				ndr_attributes << NdrRelativeOffsetAttr
				{
					offset: desc.offset
					typ: desc.parent
					operator: desc.operator
				}
			}

			.fc_constant_conformance
			{
				ndr_attributes << NdrConstantAttr
				{
					offset: desc.offset
					typ: desc.parent
				}
			}

			.fc_top_level_multid_conformance
			{
				utils.log_debug('Missing implementation for fc_top_level_multid_conformance')
			}
		}

		match desc.range
		{
			NdrCorrelationDescriptorRange
			{
				ndr_attributes << NdrRangeAttr
				{
					start: desc.range.min_value
					end: desc.range.max_value
				}
			}

			else {}
		}
	}

	return ndr_attributes
}

// comments returns an array of NdrComment types that are defined by this
// correlation descriptor. NdrComment is used to provide more detailed
// information on an NdrCorrelationDescriptor. This is especially useful
// for debugging, as the comment includes detailed membership information
// and full NDR Expression output.
pub fn (desc NdrCorrelationDescriptor) comments() []NdrComment
{
	mut comments := []NdrComment{cap: 5}

	comments << NdrComment { value: 'Correlation Descriptor' }
	comments << NdrComment { value: 'offset: ${desc.offset}' }
	comments << NdrComment { value: 'type: ${desc.correlation_type}' }
	comments << NdrComment { value: 'flags: ${desc.flags}' }

	if desc.operator == .fc_expr
	{
		mut expr := desc.expression

		match mut expr
		{
			NdrNone{}

			// It looks like the following branches could be merged together.
			// However, if this is done, v calls NdrBaseExpression.format
			// for all branches. We need an individual cast to the desired
			// type instead and use therefore separate branches

			NdrBaseExpression
			{
				comments << NdrComment { value: 'expr: ${expr.format()}' }
			}

			NdrOperatorExpression
			{
				comments << NdrComment { value: 'expr: ${expr.format()}' }
			}

			NdrVariableExpression
			{
				comments << NdrComment { value: 'expr: ${expr.format()}' }
			}

			NdrConstantExpression
			{
				comments << NdrComment { value: 'expr: ${expr.format()}' }
			}
		}
	}

	else
	{
		match desc.correlation_type
		{
			.fc_normal_conformance,
			.fc_constant_conformance,
			.fc_top_level_conformance
			{
				return []NdrComment{}
			}

			else {}
		}

		comments << NdrComment{ value: 'operator: ${desc.operator.str()}' }
	}

	return comments
}

// attrs returns attributes defined in a MaybeCorrelationDescriptor. This
// is basically a wrapper function. It checks if a correlation descriptor
// is present and returns it's attributes if this is the case. Otherwise,
// an empty array of attributes is returned.
pub fn (maybe MaybeCorrelationDescriptor) attrs() []NdrAttr
{
	match maybe
	{
		NdrCorrelationDescriptor
		{
			return maybe.attrs()
		}

		NdrNone
		{
			return []NdrAttr{}
		}
	}
}

// comments returns comments defined in a MaybeCorrelationDescriptor. This
// is basically a wrapper function. It checks if a correlation descriptor
// is present and returns it's comments if this is the case. Otherwise,
// an empty array of attributes is returned.
pub fn (maybe MaybeCorrelationDescriptor) comments() []NdrComment
{
	match maybe
	{
		NdrCorrelationDescriptor
		{
			return maybe.comments()
		}

		NdrNone
		{
			return []NdrComment{}
		}
	}
}
