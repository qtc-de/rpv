module ndr

import utils
import internals

// NdrPointerFlags contains a list of flags that can be set for
// NdrPointer types. These flags add additional information to
// the pointer that can be used during parsing and formatting.
@[flag]
pub enum NdrPointerFlags as u8
{
	fc_allocate_all_nodes
	fc_dont_free
	fc_alloced_on_stack
	fc_simple_pointer
	fc_pointer_deref
	fc_maybe_null_sizeis
}

// NdrPointer describes a simple NDR reference type. The NdrBaseType
// member of this struct contains the NdrFormatChar of the pointer
// itself (there are different types of pointers, which makes this
// information useful). The ref member represents the NdrType the
// pointer is referencing to. The flags member contains additional
// information describing the pointer.
pub struct NdrPointer {
	NdrBaseType
	ref NdrType
	flags NdrPointerFlags
}

// new creates a new instance of NdrPointer. A constructor for this type was
// defined, because it is also initialized from other modules which are not able
// to access the private format property.
pub fn NdrPointer.new(format NdrFormatChar, ref NdrType, flags NdrPointerFlags) NdrPointer
{
	return NdrPointer {
		format: format
		ref: ref
		flags: flags
	}
}

// attrs returns an array of NdrAttr that is associated to the
// NdrPointer type. This includes attributes that are associated
// to the pointer itself, as well as attributes that are associated
// to the NdrType the pointer is referencing to. In case of
// chained pointers, the pointer specific attributes [unique],
// [ref] and [ptr] are not added from the referenced pointer type.
// This causes duplicates, that are not allowed in IDL.
pub fn (pointer NdrPointer) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{cap: 1}

	match pointer.NdrBaseType.format
	{
		.fc_up { attrs << NdrStrAttr{'[unique]'} }
		.fc_rp { attrs << NdrStrAttr{'[ref]'} }
		.fc_fp { attrs << NdrStrAttr{'[ptr]'} }
		else {}
	}

	match pointer.ref.format
	{
		.fc_char,
		.fc_cstring,
		.fc_bstring,
		.fc_wstring,
		.fc_c_cstring,
		.fc_c_bstring,
		.fc_c_wstring { attrs << NdrStrAttr{'[string]'} }
		else {}
	}

	child_attrs := pointer.ref.attrs()

	for attr in child_attrs
	{
		match attr
		{
			NdrStrAttr
			{
				if attr.value in ['[unique]', '[ref]', '[ptr]']
				{
					continue
				}
			}

			else {}
		}

		attrs << attr
	}

	return attrs
}

// format returns the string representation of an NdrPointer. This
// is just the string representation of the referenced type suffixed
// with an asterisk.
pub fn (pointer NdrPointer) format() string
{
	return '${pointer.ref.format()}*'
}

// size returns the size of an NdrPointer. This is always the size
// of a pointer type within the current architecture.
pub fn (pointer NdrPointer) size() u32
{
	return sizeof(usize)
}

// read_pointer attempts to read an NdrPointer at the specified
// address from process memory.
pub fn (mut context NdrContext) read_pointer(format NdrFormatChar, mut addr &voidptr)! NdrPointer
{
	flags := context.read[NdrPointerFlags](mut addr)!

	if flags.has(.fc_simple_pointer)
	{
		ref_format := context.read[NdrFormatChar](mut addr)!
		context.read[u8](mut addr)! // padding

		utils.log_debug('  Pointer is simple pointer to: ${ref_format}')

		return NdrPointer {
			format: format
			ref: NdrBaseType { format: ref_format }
			flags: flags
		}
	}

	else
	{
		ref := context.read_offset(mut addr)!

		return NdrPointer {
			format: format
			ref: ref
			flags: flags
		}
	}
}

// NdrInterfacePointer represents an NDR pointer that is referencing
// an interface. This type of pointer contains the interface GUID within
// the iid member and has an associated NdrCorrelationDescriptor.
pub struct NdrInterfacePointer {
	NdrBaseType
	iid C.GUID
	is_constant bool
	c_desc NdrCorrelationDescriptor
}

// read_interface_pointer attempts to read an NdrInterfacePointer
// from the specified address in process memory.
pub fn(mut context NdrContext) read_interface_pointer(mut addr &voidptr)! NdrInterfacePointer
{
	typ := context.read[NdrFormatChar](mut addr)!

	if typ == NdrFormatChar.fc_constant_iid
	{
		iid := context.read[C.GUID](mut addr)!

		return NdrInterfacePointer {
			format: NdrFormatChar.fc_ip
			iid: iid
			is_constant: true
		}
	}

	else
	{
		return NdrInterfacePointer {
			format: NdrFormatChar.fc_ip
			iid: internals.iid_iunknown
			is_constant: false
		}
	}
}

// NdrByteCountPointer extends the NdrPointer type by an additional,
// optional correlation descriptor. The flags member inherited by
// NdrPointer is unused for this type and the attrs and comments
// methods need to be re-implemented to include the correlation
// descriptor.
pub struct NdrByteCountPointer {
	NdrPointer
	desc MaybeCorrelationDescriptor
}

// read_byte_count_pointer attempts to read an NdrByteCountPointer
// at the specified address from process memory.
pub fn (mut context NdrContext) read_byte_count_pointer(mut addr &voidptr)! NdrByteCountPointer
{
	format := context.read[NdrFormatChar](mut addr)!

	match format
	{
		.fc_pad
		{
			return NdrByteCountPointer {
				format: .fc_byte_count_pointer
				ref: NdrSimpleType { format: format }
				desc: NdrNone{}
			}
		}

		else
		{
			desc := context.read_correlation_descriptor(.fc_byte_count_pointer, mut addr)!
			ref := context.read_offset(mut addr)!

			return NdrByteCountPointer {
				format: .fc_byte_count_pointer
				ref: ref
				desc: desc
			}
		}
	}
}

// attrs returns an array of attributes associated with the
// NdrByteCountPointer. All possible attributes are obtained
// by calling the attrs method on the potentially contained
// NdrCorrelationDescriptor.
pub fn (ptr NdrByteCountPointer) attrs() []NdrAttr
{
	return ptr.desc.attrs()
}

// comments returns an array of NdrComment associated with the
// NdrByteCountPointer. All possible comments are obtained
// by calling the comments method on the potentially contained
// NdrCorrelationDescriptor.
pub fn (ptr NdrByteCountPointer) comments() []NdrComment
{
	return ptr.desc.comments()
}
