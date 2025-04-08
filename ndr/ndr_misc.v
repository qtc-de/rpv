module ndr

// NdrRange represents a wrapper type around a type that has an upper
// and a lower limit. The actual wrapped type is contained within the
// `typ` property. The lower limit is stored in `min` and the upper in
// `max`. The inherited `NdrBaseType` property is always `.fc_range`
pub struct NdrRange
{
	NdrBaseType
	typ NdrBaseType
	min int
	max int
}

// attr returns the lower and upper limit of the range type as an NdrStrAttr.
// The syntax looks like this: [range(lower,upper)]
pub fn (range NdrRange) attrs() []NdrAttr
{
	return [NdrStrAttr{ value: '[range(${range.min},${range.max})]' } ]
}

// format returns the type representation as it should look like in the
// decompiled IDL. In this case, this is just the wrapped types format.
// The actual range information during formatting can be obtained by
// calling the attrs function.
pub fn (range NdrRange) format() string
{
	return range.typ.format()
}

// size returns the size of the range. This is always equivalent to the
// size of the inner type.
pub fn (range NdrRange) size() u32
{
	return range.typ.size()
}

// read_range reads an `NdrRange` struct from process memory at the
// specified address.
pub fn (context NdrContext) read_range(mut addr &voidptr)! NdrRange
{
	typ := context.read[NdrFormatChar](mut addr)!
	min := context.read[int](mut addr)!
	max := context.read[int](mut addr)!

	return NdrRange
	{
		format: .fc_range
		typ: NdrBaseType { format: typ }
		min: min
		max: max
	}
}

// NdrPipe represents the NDR type for a pipe,
pub struct NdrPipe
{
	NdrBaseType
	typ       NdrType
	alignment u8
}

// comments returns a simple NdrComment that indicates that the parameter
// is a pipe. This comment is currently static.
pub fn (range NdrPipe) comments() []NdrComment
{
	return [NdrComment{ value: 'FC_PIPE' }]
}

// format returns the type representation as it should look like in the
// decompiled IDL. In this case, this is just the wrapped types format.
pub fn (range NdrPipe) format() string
{
	return range.typ.format()
}

// size returns the size of the pipe. This is always equivalent to the
// size of the inner type.
pub fn (range NdrPipe) size() u32
{
	return range.typ.size()
}

// read_pipe reads an `NdrPipe` struct from process memory at the
// specified address.
pub fn (mut context NdrContext) read_pipe(mut addr &voidptr)! NdrPipe
{
	alignment := context.read[u8](mut addr)!
	typ := context.read_offset(mut addr)!

	return NdrPipe
	{
		format:    .fc_pipe
		typ:       typ
		alignment: alignment
	}
}

// NdrSupplement represents supplemental information for its actual type.
// This information always consists out of two parts. For context types, the
// first part are flags whereas the second part is the context id. For
// string types, the first part is the lower, the second the upper bound.
pub struct NdrSupplement
{
	NdrBaseType
	typ        NdrFormatChar
	supplement NdrType
	part_one   u32
	part_two   u32
}

// attrs returns multiple NdrAttr describing the supplement. Currently
// this is only used for supplements of type NdrHandle or NdrSystemHandle.
// For these types, the static value [context_handle] is returned within
// an NdrStrAttr.
pub fn (sup NdrSupplement) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{}

	match sup.supplement
	{
		NdrHandle,
		NdrSystemHandle
		{
			attrs << NdrStrAttr{'[context_handle]'}
		}

		else {}
	}

	return attrs
}

// comments returns multiple NdrComments describing the supplement.
// For string types, the comment contains a description of the range.
// For handle types, the comment contains flags and the context ID
// of the handle.
pub fn (sup NdrSupplement) comments() []NdrComment
{
	mut comments := [NdrComment{ value: 'FC_SUPPLEMENT' }]

	match sup.supplement
	{
		NdrString,
		NdrStructureString,
		NdrConformantString,
		NdrConformantStructureString
		{
			comments << NdrComment{ value: 'range: ${sup.part_one},${sup.part_two}' }
		}

		NdrHandle,
		NdrSystemHandle
		{
			comments << NdrComment{ value: 'flags: ${sup.part_one.hex()} contextID: ${sup.part_two.hex()}' }
		}

		else {}
	}

	return comments
}

// format returns the type representation as it should look like in the
// decompiled IDL. In this case, this is just the wrapped types format.
// The actual supplemental information of the NdrSupplement can be obtained
// by calling the attrs and comments methods.
pub fn (sup NdrSupplement) format() string
{
	return sup.supplement.format()
}

// size returns the size of the NdrSupplement. This is currently just
// the size of a voidptr.
pub fn (sup NdrSupplement) size() u32
{
	return sizeof(voidptr)
}

// read_supplement reads an `NdrSupplement` struct from process memory at
// the specified address.
pub fn (mut context NdrContext) read_supplement(mut addr &voidptr)! NdrSupplement
{
	typ := context.read[NdrFormatChar](mut addr)!
	supplement := context.read_offset(mut addr)!

	part_one := context.read[u32](mut addr)!
	part_two := context.read[u32](mut addr)!

	return NdrSupplement
	{
		format:     .fc_supplement
		typ:        typ
		supplement: supplement
		part_one:   part_one
		part_two:   part_two
	}
}
