module ndr

// KnownType represents a list of known struct types. At the time
// of writing, only C.GUID is contained.
pub enum KnownType {
	guid
}

// NdrKnownType represents a known type. The typ member indicates
// which kind of known type it is, whereas the NdrBaseType member
// contains information on the underlying NdrFormatChar.
pub struct NdrKnownType {
	NdrBaseType
	typ KnownType
}

// format returns the string representation of an NdrKnownTyp.
// Currently, this is just the name of the type representation
// within the KnownType enum in uppercase.
pub fn (known NdrKnownType) format() string
{
	return known.typ.str().to_upper()
}

// size returns the size of an NdrKnownType. Based on the typ
// member, a different static value is returned.
pub fn (known NdrKnownType) size() u32
{
	match known.typ
	{
		.guid { return 16 }
	}

	return 0
}
