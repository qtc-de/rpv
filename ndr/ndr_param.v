module ndr

// NdrParamAttrs contains a list of attributes that can be used
// to describe RPC method parameters (including the return value).
// The is_binding attribute was manually added to mark the parameter
// that represents the binding. Originally, the idea was to create an
// interface NdrParam that is implemented by NdrBasicParam and
// NdrHandleParam and to define a separate format method for both
// types. However, this caused nondeterministic memory corruptions.
// We may try this approach in future again.
@[flag]
pub enum NdrParamAttrs as u16
{
	must_size
	must_free
	is_pipe
	is_in
	is_out
	is_return
	is_basetype
	is_by_value
	is_simple_ref
	is_dont_call_free_inst
	save_for_async_finish
	is_binding // manually added
}

// NdrBasicParam is the basis struct for each method parameter.
// It contains the parameter attributes, the underlying NdrType,
// the offset within the format string and the parameter name.
pub struct NdrBasicParam
{
pub mut:
	attrs             NdrParamAttrs
	typ               NdrType = NdrNone{}
	server_alloc_size int
	offset            u32
	name              string
}

// attrs returns an array of NdrAttr that is required to
// format the parameter. The array contains parameter specific
// attributes as well as type specific attributes. At the
// time of writing, parameter specific attributes are only
// [in] and [out]. Other attributes are obtained by calling
// the attrs method on the inner type.
pub fn (param NdrBasicParam) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{}

	if param.attrs.has(.is_in)
	{
		attrs << NdrStrAttr{'[in]'}
	}

	if param.attrs.has(.is_out)
	{
		attrs << NdrStrAttr{'[out]'}
	}

	attrs << param.typ.attrs()

	return attrs
}

// format returns the string representation of an NdrBasicParam.
// It  starts with the inner type name, optionally prefixed with
// an asterisk, if it is a reference type. Afterwards, the param
// name follows with an optional array suffix, if the underlying
// param type is an array type.
pub fn (param NdrBasicParam) format() string
{
	mut param_str := param.typ.format()

	if param.attrs.has(.is_simple_ref)
	{
		param_str += '*'
	}

	if param.name == 'retval'
	{
		return '${param_str}'
	}

	return '${param_str} ${param.name}${param.typ.array()}'
}

// comments returns an array of NdrComment that is associated
// with the NdrBasicParam. At the time of writing, this comment
// is only used if the param is the binding handle. In this case
// the value 'binding' is returned.
pub fn (param NdrBasicParam) comments() []NdrComment
{
	mut comments := param.typ.comments()

	if param.attrs.has(.is_binding)
	{
		comments << NdrComment { value: 'binding' }
	}

	return comments
}

// NdrHandleParamFlags contains a list of flags that can be
// used in NdrHandleParam. These flags add more information
// to the underlying handle.
@[flag]
pub enum NdrHandleParamFlags as u8
{
	ndr_context_handle_cannot_be_null
	ndr_context_handle_serialize
	ndr_context_handle_noserialize
	ndr_strict_context_handle
	handle_param_is_return
	handle_param_is_out
	handle_param_is_in
	handle_param_is_via_ptr
}

// NdrHandleParam extends NdrBasicParam for handle types.
// It contains some additional attributes like the handle
// flags and information whether it is a generic or explicit
// handle.
pub struct NdrHandleParam
{
	NdrBasicParam
pub mut:
	flags    NdrHandleParamFlags
	explicit bool
	generic  bool
}
