module ndr

import utils

// NdrMember is a helper type to provide unified methods for structs
// and methods
type NdrMember = NdrBasicParam | NdrStructMember

// NdrAttr is a type to represent NDR type attributes. NDR types can
// have attributes like [size_is(arg3)] to indicate that the size of
// the current argument is determined by argument three of the same
// method. If such attributes are present, rpv represents them by
// NdrAttr structs.
//
// The actual format of these attributes differs depending on the
// underlying NdrType and the type of attribute. For example, the
// relationship on arg3 in the example above can be encoded as
// absolute offset within the current method or as relative offset
// to the current attribute. Moreover, there are attributes containing
// constant information and attributes that contain more complex
// expressions.
//
// NdrAttr is a sum type that merges all these types of attributes
// into a single representation.
type NdrAttr = NdrStrAttr | NdrGlobalOffsetAttr | NdrRelativeOffsetAttr | NdrConstantAttr | NdrExprAttr | NdrRangeAttr

// NdrStrAttr is probably the most simple NDR attribute. It just
// contains a plain string that needs to be displayed when formatting
// the attribute.
pub struct NdrStrAttr
{
pub:
	value string
}

// NdrGlobalOffsetAttr represents an attribute that points to another
// parameter within the same method or another struct member. The
// associated parameter is identified by an offset that is contained
// within the struct. The actual meaning of the attribute differs
// depending on the NdrType it is attached to. Therefore, the struct
// contains an NdrFormatChar member to indicate how the attribute needs
// to be used.
pub struct NdrGlobalOffsetAttr
{
pub:
	offset     int
	typ        NdrFormatChar
	operator   NdrFormatChar
	is_varying bool
}

// format returns the string representation of an NdrGlobalOffsetAttr.
// It is required to provide the full parameter or member list for the
// method, to determine which parameter the global offset is referencing
// to.
pub fn (attr NdrGlobalOffsetAttr) format(members []NdrMember) string
{
	for member in members
	{
		if member.offset == attr.offset
		{
			name := apply_operator(member.name, attr.operator)

			match attr.typ
			{
				.fc_encapsulated_union,
				.fc_non_encapsulated_union
				{
					return '[switch_is(${name})]'
				}

				else
				{
					prefix := if attr.is_varying { 'length_is' } else { 'size_is' }

					match member
					{
						NdrBasicParam
						{
							if member.attrs.has(.is_out)
							{
								return '[${prefix}(,${name})]'
							}
						}

						else {}
					}

					return '[${prefix}(${name})]'
				}
			}
		}
	}

	return ''
}

// NdrRelativeOffsetAttr represents an attribute that points to another
// member within the same struct. The associated member is identified
// by an offset that is contained within the struct. In contrast to
// NdrGlobalOffsetAttr, this offset is relative to the member the
// attribute is attached to. The actual meaning of the attribute
// differs depending on the NdrType it is attached to. Therefore, the
// struct contains an NdrFormatChar member to indicate how the attribute
// needs to be used.
pub struct NdrRelativeOffsetAttr
{
pub:
	offset     int
	typ        NdrFormatChar
	operator   NdrFormatChar
	is_varying bool
}

// format returns the string representation of an NdrRelativeOffsetAttr.
// It is required to provide the full member list to the method, to
// determine which parameter the global offset is referencing to.
pub fn (attr NdrRelativeOffsetAttr) format(self NdrStructMember, members []NdrStructMember) string
{
	prefix := if attr.is_varying { 'length_is' } else { 'size_is' }

	for member in members
	{
		if int(member.offset) == (int(self.offset) + attr.offset)
		{
			name := apply_operator(member.name, attr.operator)

			match attr.typ
			{
				.fc_encapsulated_union,
				.fc_non_encapsulated_union
				{
					return '[switch_is(${name})]'
				}

				else
				{
					return '[${prefix}(${name})]'
				}
			}
		}
	}

	offset := apply_operator('${attr.offset}', attr.operator)

	match attr.typ
	{
		.fc_encapsulated_union,
		.fc_non_encapsulated_union
		{
			return '[switch_is(${offset})]'
		}

		else
		{
			return '[${prefix}(${offset})]'
		}
	}
}

// NdrConstantAttr is an attribute that just contains a constant value. This
// value is contained inside the offset member. Despite the attribute seems
// always to have the same meaning in any context [size_is(offset)], the
// associated type is still included within the struct.
pub struct NdrConstantAttr
{
pub:
	offset     int
	typ        NdrFormatChar
	is_varying bool
}

// format returns the string representation of an NdrConstantAttr. This is
// currently [size_is(offset)] for all possible associated types.
pub fn (attr NdrConstantAttr) format() string
{
	prefix := if attr.is_varying { 'length_is' } else { 'size_is' }
	return '[${prefix}(${attr.offset})]'
}

// NdrRangeAttr is an attribute that just contains a range that is defined
// by too integer values.
pub struct NdrRangeAttr
{
pub:
	start int
	end   int
}

// format returns the string representation of an NdrRangeAttr. This is
// just [range(start, end)].
pub fn (attr NdrRangeAttr) format() string
{
	return '[range(${attr.start}, ${attr.end})]'
}

// NdrExprAttr represents an attribute that holds NdrExpression types. These
// can express more complex parameter relationships. Usually these expression
// read like math terms and consist out of multiple arguments that are connected
// by operators (plus, minus, etc.). The arguments can again reference other
// members within a struct. NdrExprAttr contains the actual expression as string
// and also the arguments as NdrExpression types. When formatting the NdrExprAttr,
// the arguments need to be resolved and inserted into the expression string.
pub struct NdrExprAttr
{
	arguments        []NdrExpression
	expression       string
	correlation_type NdrCorrelationType
	typ              NdrFormatChar
	is_varying       bool
}

// format returns the string representation of an NdrExprAttr. The skeleton for
// this string representation is already contained within the expression member
// of the struct. However, the arguments need to be resolved and inserted into
// this expression to make it complete. Therefore, it is required to provide
// an array of other struct members to the list. Since references to other members
// are relative to the current member, it needs to also be provided.
pub fn (attr NdrExprAttr) format(self NdrMember, members []NdrMember) string
{
	mut expr_str := attr.expression
	mut var_expressions := []NdrVariableExpression{}

	for expr in attr.arguments
	{
		match expr
		{
			NdrVariableExpression
			{
				var_expressions << expr
			}

			NdrOperatorExpression
			{
				var_expressions << expr.collect_var_expr()
			}

			else {}
		}
	}

	for expr in var_expressions
	{
		mut match_index := 0;

		match attr.correlation_type
		{
			.fc_normal_conformance
			{
				match_index = expr.offset + int(self.offset)
			}

			.fc_top_level_conformance,
			.fc_pointer_conformance
			{
				match_index = expr.offset
			}

			else
			{
				utils.log_debug('Missing implementation for correlation type: ${attr.correlation_type}')
			}
		}

		for member in members
		{
			if int(member.offset) == match_index
			{
				expr_str = expr_str.replace('var{{${expr.offset}}}', member.name)
			}
		}
	}

	match attr.typ
	{
		.fc_encapsulated_union,
		.fc_non_encapsulated_union
		{
			return '[switch_is(${expr_str})]'
		}

		else
		{

			prefix := if attr.is_varying { 'length_is' } else { 'size_is' }
			return '[${prefix}(${expr_str})]'
		}
	}
}

// format returns the string representation for a list of NdrAttr types.
// This function makes sure, that each attribute only appears a single
// time and returns them concatenated as string.
pub fn (attr_list []NdrAttr) format() string
{
	mut attrs_str := ''

	for attr in attr_list.uniq()
	{
		match attr
		{
			NdrStrAttr { attrs_str += attr.value }
			else {}
		}
	}

	return attrs_str
}

// format_struct returns the string representation for a list of NdrAttr types
// when they are associated with a struct. Some attributes require a list of
// other available struct members and therefore a dedicated format method,
// that can supply this information.
pub fn (attr_list []NdrAttr) format_struct(member NdrStructMember, members []NdrStructMember) string
{
	mut attrs_str := ''

	for attr in attr_list.uniq()
	{
		match attr
		{
			NdrRangeAttr,
			NdrConstantAttr
			{
				attrs_str += attr.format()
			}

			NdrStrAttr { attrs_str += attr.value }
			NdrExprAttr { attrs_str += attr.format(NdrMember(member), members.map(NdrMember(it))) }
			NdrGlobalOffsetAttr { attrs_str += attr.format(members.map(NdrMember(it))) }
			NdrRelativeOffsetAttr { attrs_str += attr.format(member, members) }
		}
	}

	return attrs_str
}

// format_struct returns the string representation for a list of NdrAttr types
// when they are associated with a function. It seems to be the case that
// certain attributes like NdrRelativeOffsetAttr are not used for functions.
// Others require a list of other available  parameters and therefore a
// dedicated format method, that can supply this information.
pub fn (attr_list []NdrAttr) format_function(param NdrBasicParam, params []NdrBasicParam) string
{
	mut attrs_str := ''

	for attr in attr_list.uniq()
	{
		match attr
		{
			NdrRangeAttr,
			NdrConstantAttr
			{
				attrs_str += attr.format()
			}

			NdrStrAttr { attrs_str += attr.value }
			NdrExprAttr { attrs_str += attr.format(NdrMember(param), params.map(NdrMember(it))) }
			NdrGlobalOffsetAttr { attrs_str += attr.format(params.map(NdrMember(it))) }

			else
			{
				utils.log_debug('Missing function attribute: ${attr}')
			}
		}
	}

	return attrs_str
}

// uniq filters a list if NdrAttr and returns a list with only unique
// attributes. Not sure whether this is a "bug" or that it is intended
// by NDR, but attributes tend to appear in duplicates quite frequently.
pub fn (attr_list []NdrAttr) uniq() []NdrAttr
{
	mut uniq := []NdrAttr{cap: attr_list.len}

	for attr in attr_list
	{
		if !(attr in uniq)
		{
			uniq << attr
		}
	}

	return uniq
}

// apply_operator applies the specified NDR conformant operator to the
// input string
pub fn apply_operator(input string, operator NdrFormatChar) string
{
	match operator
	{
		.fc_add_1 { return '${input} + 1' }
		.fc_sub_1 { return '${input} - 1' }
		.fc_mult_2 { return '${input} * 2' }
		.fc_div_2 { return '${input} / 2' }
		.fc_dereference { return '*${input}' }
		else {}
	}

	return input
}
