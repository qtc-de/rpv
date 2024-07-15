module ndr

// NdrFlags contains additional information for NDR data.
// Especially the has_return value is important for rpv,
// as it indicates whether a method returns a value.
@[flag]
pub enum NdrFlags as u8
{
	server_must_size
	client_must_size
	has_return
	has_pipes
	unknown
	has_async_uuid
	has_extensions
	has_async_handle
}

// NdrInterpreterOptFlags2 contains additional information
// on how to interpret NDR data. rpv needs this struct to
// determine how specific NDR types need to be parsed.
@[flag]
pub enum NdrInterpreterOptFlags2 as u8
{
	has_new_corr_desc
	client_corr_check
	server_corr_check
	has_notify
	has_notify2
	has_complex_return
	has_range_on_conformance
	has_big_by_val_param
}

// NdrProcHeaderExts defines the header in front of a RPC
// method definition. rpv mainly uses it to get access to
// the NdrInterpreterOptFlags2 struct.
pub struct NdrProcHeaderExts
{
	pub:
	size u8
	flags NdrInterpreterOptFlags2
	client_corr_hint u16
	server_corr_hint u16
	notify_index u16
}
