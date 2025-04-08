module ndr

// NdrString represents the most basic string type and consists out of an
// NdrBaseType and the associated string length.
pub struct NdrString
{
	NdrBaseType
	length u16
}

// read_string attempts to read an NdrString from process memory at the
// specified address.
pub fn (context NdrContext) read_string(format NdrFormatChar, mut addr &voidptr)! NdrString
{
	context.read[u8](mut addr)! // padding
	length := context.read[u16](mut addr)!

	return NdrString
	{
		format: format
		length: length
	}
}

// attrs returns a list of NdrAttr associated with the NdrString. This is
// always a static NdrStrAttr of value [string].
pub fn (str NdrString) attrs() []NdrAttr
{
	return [ NdrStrAttr { value: '[string]' } ]
}

// format returns the string representation of an NdrString. Depending on
// the length of the NdrString, this is just the string formatted base type
// (for str.length <= 0) or the string formatted base type with an array
// suffix.
pub fn (str NdrString) format() string
{
	if str.length > 0
	{
		return '${str.NdrBaseType.format()}[${str.length}]'
	}

	return str.NdrBaseType.format()
}

// size returns the size of the NdrString. This is usually the length,
// except the string uses wide characters.
pub fn (str NdrString) size() u32
{
	match str.NdrBaseType.format
	{
		.fc_wstring { return 2 * str.length }
		else {}
	}

	return str.length
}

// NdrConformantString represents a string type that has an optional
// NdrCorrelationDescriptor attached. In contrast to NdrString, this
// struct is missing a length member. Instead, the string length is
// encoded within the NdrCorrelationDescriptor.
pub struct NdrConformantString
{
	NdrBaseType
	c_desc MaybeCorrelationDescriptor
}

// attrs returns an array of NdrAttr associated with the NdrConformantString.
// The NdrAttr array always includes the static NdrStrAttr with value [string].
// If a correlation descriptor is present, this usually adds a [size_is()]
// attribute.
pub fn (c_str NdrConformantString) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{cap: 1}

	attrs << NdrStrAttr { value: '[string]' }
	attrs << c_str.c_desc.attrs()

	return attrs
}

// comments returns an array of NdrComment associated with the NdrConformantString.
// Comments are only present if a correlation descriptor is available and are
// obtained by calling the comments function on the correlation descriptor.
pub fn (c_str NdrConformantString) comments() []NdrComment
{
	mut comments := []NdrComment{}

	match c_str.c_desc
	{
		NdrNone{}
		NdrCorrelationDescriptor
		{
			if c_str.c_desc.correlation_type != .fc_constant_conformance
			{
				comments << c_str.c_desc.comments()
			}
		}
	}

	return comments
}

// char_count returns the character count of an NdrConformantString. If an
// correlation descriptor with constant conformanceis present, the number
// is obtained from it. If no correlation descriptor with constant conformance
// is present, the size is either unknown or determined by another parameter.
// In this case, 0 is returned.
pub fn (c_str NdrConformantString) char_count() u32
{
	match c_str.c_desc
	{
		NdrCorrelationDescriptor
		{
			if c_str.c_desc.correlation_type == .fc_constant_conformance
			{
				return u32(c_str.c_desc.offset)
			}
		}

		NdrNone {}
	}

	return 0
}

// size returns the size of the NdrConformantString. This is usually equivalent
// to the char_count, except the string uses wide characters.
pub fn (c_str NdrConformantString) size() u32
{
	if c_str.NdrBaseType.format == .fc_c_wstring
	{
		return 2 * c_str.char_count()
	}

	return 1 * c_str.char_count()
}

// read_conformant_string attempts to read an NdrConformantString from process
// memory at the specified address.
pub fn (context NdrContext) read_conformant_string(format NdrFormatChar, mut addr &voidptr)! NdrConformantString
{
	padding := context.read[NdrFormatChar](mut addr)!
	mut c_desc := MaybeCorrelationDescriptor(NdrNone{})

	if padding == NdrFormatChar.fc_string_sized
	{
		c_desc = context.read_correlation_descriptor(format, mut addr)!
	}

	return NdrConformantString
	{
		format: format
		c_desc: c_desc
	}
}

// NdrStructureString is another NDR string type that contains the element size
// and the element number as part of it's struct definition.
pub struct NdrStructureString
{
	NdrBaseType
	element_size u8
	element_num  u16
}

// read_structure_string attempts to read an NdrStructureString from process
// memory at the specified address.
pub fn (context NdrContext) read_structure_string(mut addr &voidptr)! NdrStructureString
{
	element_size := context.read[u8](mut addr)!
	element_num := context.read[u16](mut addr)!

	return NdrStructureString
	{
		format:       NdrFormatChar.fc_sstring
		element_size: element_size
		element_num:  element_num
	}
}

// attrs returns a list of NdrAttr associated with the NdrStructureString. This is
// always a static NdrStrAttr of value [string].
pub fn (str NdrStructureString) attrs() []NdrAttr
{
	return [ NdrStrAttr { value: '[string]' } ]
}

// format returns the string representation of an NdrStructureString. Depending
// on the number of elements, this is just the string formatted base type
// (element_num <= 0) with an element size suffix or the string formatted base
// type with an array suffix (element_num > 0).
pub fn (str NdrStructureString) format() string
{
	if str.element_num > 0
	{
		return '${str.NdrBaseType.format()}<${str.element_size}>[${str.element_num}]'
	}

	return '${str.NdrBaseType.format()}<${str.element_size}>[]'
}

// size returns the size of the NdrStructureString. This is obviously the
// element number times the element size.
pub fn (str NdrStructureString) size() u32
{
	return str.element_num * str.element_size
}

// NdrConformantStructureString is pretty similar to NdrStructureString, but
// the element number is encoded within a correlation descriptor. Wherefore,
// this struct extends NdrConformantString and not NdrStructureString.
pub struct NdrConformantStructureString
{
	NdrConformantString
	element_size u8
}

// read_conformant_structure_string attempts to read an NdrConformantStructureString
// from process memory at the specified address.
pub fn (context NdrContext) read_conformant_structure_string(mut addr &voidptr)! NdrConformantStructureString
{
	element_size := context.read[u8](mut addr)!
	padding := context.read[NdrFormatChar](mut addr)!
	mut c_desc := MaybeCorrelationDescriptor(NdrNone{})

	if padding == NdrFormatChar.fc_string_sized
	{
		context.read[u8](mut addr)! // padding
		c_desc = context.read_correlation_descriptor(.fc_c_sstring, mut addr)!
	}

	return NdrConformantStructureString
	{
		format:       NdrFormatChar.fc_c_sstring
		element_size: element_size
		c_desc:       c_desc
	}
}

// format returns the string representation of an NdrConformantStructureString.
// This is always the string formatted base type suffixed by the element size.
// The element count is encoded within the correlation descriptor and formatted
// when formatting the NdrAttr array.
pub fn (str NdrConformantStructureString) format() string
{
	return '${str.NdrConformantString.format()}<${str.element_size}>[]'
}
