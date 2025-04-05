module ndr

import utils

// NdrArray is the most basic NDR array structure. It consists out of
// a NdrBaseType that describes the NdrArray itself and an element_type
// that describes the contained elements. Additionally, a pointer layout
// can be contained.
pub struct NdrArray {
	NdrBaseType
	alignment u8
	element_type NdrType = NdrNone{}
	pointer_layout MaybePointerInfo = NdrNone{}
}

// format returns the string representation of an NdrArray. This is just
// the string representation of the element_type. The array suffix is added
// by other methods during the formatting process.
pub fn (array NdrArray) format() string
{
	return array.element_type.format()
}

// read_array attempts to read an NdrArray from process memory at the
// specified address.
pub fn(mut context NdrContext) read_array(format NdrFormatChar, alignment u8, mut addr &voidptr)! NdrArray
{
	mut ndr_type := context.read_type_ext(mut addr)!
	utils.log_debug('Array element type is ${ndr_type}.')

	match mut ndr_type
	{
		NdrPointerInfo
		{
			element_type := context.read_type_ext(mut addr)!

			return NdrArray {
				format: format,
				alignment: alignment,
				element_type: element_type
				pointer_layout: ndr_type
			}
		}

		else
		{
			return NdrArray {
				format: format,
				alignment: alignment,
				element_type: ndr_type
			}
		}
	}
}

// NdrSimpleArray extends NdrArray by adding a total_size member
// that describes the size of the array.
pub struct NdrSimpleArray {
	NdrArray
	total_size u32
}

// length returns the length of an NdrSimpleArray. This is the total
// size divided by the size of the element_type.
pub fn (array NdrSimpleArray) length() u32
{
	elem_size := array.element_type.size()

	if elem_size > 0
	{
		return u32(array.size() / elem_size)
	}

	return 0
}

// size returns the size of the NdrSimpleArray. This is always equivalent
// to the total_size member of the NdrSimpleArray.
pub fn (array NdrSimpleArray) size() u32
{
	return array.total_size
}

// read_simple_array attempts to read an NdrSimpleArray from process memory
// at the specified address.
pub fn (mut context NdrContext) read_simple_array(format NdrFormatChar, mut addr &voidptr)! NdrSimpleArray
{
	mut total_size := u32(0)
	alignment := context.read[u8](mut addr)!

	if format == NdrFormatChar.fc_smfarray
	{
		total_size = context.read[u16](mut addr)!
	}

	else
	{
		total_size = context.read[u32](mut addr)!
	}

	return NdrSimpleArray {
		NdrArray: context.read_array(format, alignment, mut addr)!
		total_size: total_size
	}
}

// NdrConformantArray extends NdrArray and adds an additional element_size field
// as well as two optional CorrelationDescriptors.
pub struct NdrConformantArray {
	NdrArray
	element_size u32
	c_desc MaybeCorrelationDescriptor
	v_desc MaybeCorrelationDescriptor
}

// read_conformant_array attempts to read an NdrConformantArray from the specified
// address in process memory.
pub fn (mut context NdrContext) read_conformant_array(format NdrFormatChar, mut addr &voidptr)! NdrConformantArray
{
	alignment := context.read[u8](mut addr)!
	element_size := context.read[u16](mut addr)!

	c_desc := context.read_correlation_descriptor(format, mut addr)!
	mut v_desc := MaybeCorrelationDescriptor(NdrNone{})

	if format == .fc_cvarray
	{
		v_desc = context.read_correlation_descriptor_ex(format, true, mut addr)!
	}

	return NdrConformantArray {
		NdrArray: context.read_array(format, alignment, mut addr)!
		element_size: element_size
		c_desc: c_desc
		v_desc: v_desc
	}
}

// attrs returns an array of NdrAttr associated with the NdrConformantArray.
// Possible attributes are fetched from the two optional correlation descriptors.
pub fn (array NdrConformantArray) attrs() []NdrAttr
{
    mut attrs := []NdrAttr{}

    attrs << array.c_desc.attrs()
    attrs << array.v_desc.attrs()

    return attrs
}

// comments returns an array of NdrComment associated with the NdrConformantArray.
// Possible comments are fetched from the c_desc correlation descriptor.
pub fn (array NdrConformantArray) comments() []NdrComment
{
	mut comments := []NdrComment{}

	comments << array.c_desc.comments()
	comments << array.v_desc.comments()

	return comments
}

// length returns the length of an NdrConformantArray. This length is obtained
// from the correlation descriptors.
pub fn (array NdrConformantArray) length() u32
{
	match array.v_desc
	{
		NdrNone{}
		NdrCorrelationDescriptor
		{
			if array.v_desc.correlation_type == .fc_constant_conformance
			{
				return u32(array.v_desc.offset)
			}
		}
	}

	match array.c_desc
	{
		NdrNone{}
		NdrCorrelationDescriptor
		{
			if array.c_desc.correlation_type == .fc_constant_conformance
			{
				return u32(array.c_desc.offset)
			}
		}
	}

	return 0
}

// size returns the size of an NdrConformantArray. The length information
// of the array is contained within one of the correlation descriptors.
// The size is computed by multiplying this length with the element_size.
pub fn (array NdrConformantArray) size() u32
{
	if array.element_size > 0
	{
		return array.length() * array.element_size
	}

	return 0
}

// NdrBogusArray is basically the same as NdrConformantArray, but instead of
// holding an additional element_size member, the struct holds the element
// number as member.
pub struct NdrBogusArray {
	NdrConformantArray
	element_num u32
}

// read_bogus_array attempts to read an NdrBogusArray from the specified
// address in process memory.
pub fn(mut context NdrContext) read_bogus_array(format NdrFormatChar, mut addr &voidptr)! NdrBogusArray
{
	alignment := context.read[u8](mut addr)!
	num := context.read[u16](mut addr)!

	c_desc := context.read_correlation_descriptor(format, mut addr)!
	v_desc := context.read_correlation_descriptor_ex(format, true, mut addr)!

	array := context.read_array(format, alignment, mut addr)!

	return NdrBogusArray {
		NdrArray: array
		element_num: num
		c_desc: c_desc
		v_desc: v_desc
	}
}

// length returns the length of an NdrBogusArray. Since the element number is
// contained within the struct, this value is just returned. However, if the
// element_num member is zero, the element count is obtained from the correlation
// descriptors instead.
pub fn (array NdrBogusArray) length() u32
{
	if array.element_num != 0
	{
		return array.element_num
	}

	return array.NdrConformantArray.length()
}

// size returns the size of an NdrBogusArray. This is just the element number
// multiplied with the size of the element_type.
pub fn (array NdrBogusArray) size() u32
{
	return array.element_num * array.element_type.size()
}

// NdrVaryingArray extends NdrBogusArray by adding an additional total_size field.
pub struct NdrVaryingArray {
	NdrBogusArray
	total_size u32
}

// read_varying_array attempts to read an NdrVaryingArray from process memory at
// the specified address.
pub fn(mut context NdrContext) read_varying_array(format NdrFormatChar, mut addr &voidptr)! NdrVaryingArray
{
	mut total_size := u32(0)
	mut element_num := u32(0)
	alignment := context.read[u8](mut addr)!

	if format == .fc_smvarray
	{
		total_size = context.read[u16](mut addr)!
		element_num = context.read[u16](mut addr)!
	}

	else
	{
		total_size = context.read[u32](mut addr)!
		element_num = context.read[u32](mut addr)!
	}

	element_size := context.read[u16](mut addr)!
	v_desc := context.read_correlation_descriptor_ex(format, true, mut addr)!

	return NdrVaryingArray {
		NdrArray: context.read_array(format, alignment, mut addr)!
		element_size: element_size
		total_size: total_size
		element_num: element_num
		v_desc: v_desc
		c_desc: NdrNone{}
	}
}

// size returns the size of an NdrVaryingArray. This should be equivalent to
// the total_size member.
pub fn (array NdrVaryingArray) size() u32
{
	return array.total_size
}
