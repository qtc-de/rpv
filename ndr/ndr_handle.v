module ndr

import win

// NdrSystemHandleResource represents the type an NdrSystemHandle is
// referencing to.
pub enum NdrSystemHandleResource as u8
{
	file        = 0
	semaphore   = 1
	event       = 2
	mutex       = 3
	process     = 4
	token       = 5
	section     = 6
	reg_key     = 7
	thread      = 8
	composition = 9
	socket      = 10
	job         = 11
	pipe        = 12
}

// NdrSystemHandle represents a regular Windows handle to a specific
// resource. The type of the resource is encoded within the resource
// member.
pub struct NdrSystemHandle
{
	NdrBaseType
	resource    NdrSystemHandleResource
	access_mask u32
}

// read_system_handle attempts to read an NdrSystemHandle from the
// specified address in process memory.
pub fn (mut context NdrContext) read_system_handle(mut addr &voidptr)! NdrSystemHandle
{
	resource := context.read[NdrSystemHandleResource](mut addr)!
	access_mask := context.read[u32](mut addr)!

	return NdrSystemHandle
	{
		format:      .fc_system_handle
		resource:    resource
		access_mask: access_mask
	}
}

// attrs returns the attributes for NdrSystemHandle.
pub fn (handle NdrSystemHandle) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{cap: 1}
	mut format := '[system_handle(${handle.get_attr_name()}'

	if handle.access_mask != 0
	{
		format += ', 0x${handle.access_mask.hex()}'
	}

	attrs << NdrStrAttr
	{
		value: format + ')]'
	}

	return attrs
}

// comments returns the comments for NdrSystemHandle.
pub fn (handle NdrSystemHandle) comments() []NdrComment
{
	mut comments := []NdrComment{}
	comments << NdrComment { value: 'HANDLE for resource type: ${handle.resource}' }

	if handle.access_mask != 0
	{
		mut format := 'Access: '

		unsafe
		{
			match handle.resource
			{
				.pipe,
				.file
				{
					format += win.FileAccessRights(handle.access_mask).str()
				}

				.process
				{
					format += win.ProcessAccessRights(handle.access_mask).str()
				}

				.thread
				{
					format += win.ProcessAccessRights(handle.access_mask).str()
				}

				.event
				{
					format += win.EventAccessRights(handle.access_mask).str()
				}

				.job
				{
					format += win.JobAccessRights(handle.access_mask).str()
				}

				.mutex
				{
					format += win.MutantAccessRights(handle.access_mask).str()
				}

				.reg_key
				{
					format += win.KeyAccessRights(handle.access_mask).str()
				}

				.section
				{
					format += win.SectionAccessRights(handle.access_mask).str()
				}

				.semaphore
				{
					format += win.SemaphoreAccessRights(handle.access_mask).str()
				}

				.token
				{
					format += win.TokenAccessRights(handle.access_mask).str()
				}

				else
				{
					format += '0x${handle.access_mask.hex()}'
				}
			}

			comments << NdrComment { value: format }
		}
	}

	return comments
}

// get_attr_name returns the name for the resource the handle is refering to
// as required in the system_handle attribute
pub fn (handle NdrSystemHandle) get_attr_name() string
{
	match handle.resource
	{
		.file        { return 'sh_file' }
		.semaphore   { return 'sh_semaphore' }
		.event       { return 'sh_event' }
		.mutex       { return 'sh_mutex' }
		.process     { return 'sh_process' }
		.token       { return 'sh_token' }
		.section     { return 'sh_section' }
		.reg_key     { return 'sh_reg_key' }
		.thread      { return 'sh_thread' }
		.composition { return 'sh_composition' }
		.socket      { return 'sh_socket' }
		.job         { return 'sh_job' }
		.pipe        { return 'sh_pipe' }
	}
}

// NdrHandle represents a general purpose RPC handle. More information on these
// handles can be found within the MIDL language reference by Microsoft:
//
// https://learn.microsoft.com/en-us/windows/win32/midl/midl-language-reference
pub struct NdrHandle
{
	NdrBaseType
}

// attrs returns an array of NdrAttr that are assigned to the handle. Depending
// on the handle type, a static prefix is returned.
pub fn (handle NdrHandle) attrs() []NdrAttr
{
	mut attrs := []NdrAttr{cap: 1}

	match handle.format
	{
		.fc_bind_context { attrs << NdrStrAttr{'[context_handle]'} }
		.fc_callback_handle { attrs << NdrStrAttr{'[callback]'} }
		.fc_auto_handle { attrs << NdrStrAttr{'[auto_handle]'} }
		else {}
	}

	return attrs
}

// comments returns comments that are associated with the NdrHandle. This
// is only used if the underlying NdrBaseType is not one of .fc_bind_context,
// .fc_callback_handle or .fc_auto_handle. In this case, the underlying
// NdrBaseType is returned within the comment.
pub fn (handle NdrHandle) comments() []NdrComment
{
	mut comments := []NdrComment{}

	if !(handle.format in [.fc_bind_context, .fc_callback_handle, .fc_auto_handle])
	{
		comments << NdrComment { value: handle.format.str() }
	}

	return comments
}
