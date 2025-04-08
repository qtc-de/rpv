module ndr

// NdrComment represents a simple structure that only holds a string.
// For some NdrTypes, it is useful to have an additional comment that
// explains what the associated type is about. In rpv, this is
// implemented by NdrComment, that can be attached to any type.
pub struct NdrComment {
pub:
	value string
}
