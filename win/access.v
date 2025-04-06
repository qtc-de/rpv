module win

/*
 * This file contains access masks for different access types. All definitions
 * are basically copied from the NtApiDotNet project.
 */

 // GenericAccessRights represents access masks for generic purposes
@[flag]
pub enum GenericAccessRights as u32
{
	access0					// 0x00000001
	access1					// 0x00000002
	access2					// 0x00000004
	access3					// 0x00000008
	access4					// 0x00000010
	access5					// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

 // FileAccessRights represents access masks used for file access
@[flag]
pub enum FileAccessRights as u32
{
	read_data				// 0x00000001
	write_data				// 0x00000002
	append_data				// 0x00000004
	read_ea					// 0x00000008
	write_ea				// 0x00000010
	execute					// 0x00000020
	delete_child			// 0x00000040
	read_attributes			// 0x00000080
	write_attributes		// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

 // ThreadAccessRights represents access masks used for thread access
@[flag]
pub enum ThreadAccessRights as u32
{
	terminate					// 0x00000001
	suspend_resume				// 0x00000002
	alert						// 0x00000004
	get_context					// 0x00000008
	set_context					// 0x00000010
	set_information				// 0x00000020
	query_information			// 0x00000040
	set_thread_token			// 0x00000080
	impersonate					// 0x00000100
	direct_impersonation		// 0x00000200
	set_limited_information		// 0x00000400
	query_limited_information	// 0x00000800
	resume						// 0x00001000
	access13					// 0x00002000
	access14					// 0x00004000
	access15					// 0x00008000
	delete						// 0x00010000
	read_control				// 0x00020000
	write_dac					// 0x00040000
	write_owner					// 0x00080000
	synchronize					// 0x00100000
	pad1						// 0x00200000
	pad2						// 0x00400000
	pad3						// 0x00800000
	access_system_security		// 0x01000000
	maximum_allowed				// 0x02000000
	pad4						// 0x04000000
	pad5						// 0x08000000
	generic_all					// 0x10000000
	generic_execute				// 0x20000000
	generic_write				// 0x40000000
	generic_read				// 0x80000000
}

 // ProcessAccessRights represents access masks used for process access
@[flag]
pub enum ProcessAccessRights as u32
{
	terminate					// 0x00000001
	create_thread				// 0x00000002
	set_session_id				// 0x00000004
	vm_operation				// 0x00000008
	vm_read						// 0x00000010
	vm_write					// 0x00000020
	dup_handle					// 0x00000040
	create_process				// 0x00000080
	set_quota					// 0x00000100
	set_information				// 0x00000200
	query_information			// 0x00000400
	suspend_resume				// 0x00000800
	query_limited_information	// 0x00001000
	set_limited_information		// 0x00002000
	access14					// 0x00004000
	access15					// 0x00008000
	delete						// 0x00010000
	read_control				// 0x00020000
	write_dac					// 0x00040000
	write_owner					// 0x00080000
	synchronize					// 0x00100000
	pad1						// 0x00200000
	pad2						// 0x00400000
	pad3						// 0x00800000
	access_system_security		// 0x01000000
	maximum_allowed				// 0x02000000
	pad4						// 0x04000000
	pad5						// 0x08000000
	generic_all					// 0x10000000
	generic_execute				// 0x20000000
	generic_write				// 0x40000000
	generic_read				// 0x80000000
}

// EventAccessRights represents access masks used for event access
@[flag]
pub enum EventAccessRights as u32
{
	query_state				// 0x00000001
	modify_state			// 0x00000002
	access2					// 0x00000004
	access3					// 0x00000008
	access4					// 0x00000010
	access5					// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// JobAccessRights represents access masks used for job access
@[flag]
pub enum JobAccessRights as u32
{
	assign_process			// 0x00000001
	set_attributes			// 0x00000002
	query					// 0x00000004
	terminate				// 0x00000008
	set_security_attribute	// 0x00000010
	impersonate				// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// MutantAccessRights represents access masks used for mutant access
@[flag]
pub enum MutantAccessRights as u32
{
	modify_state			// 0x00000001
	access1					// 0x00000002
	access2					// 0x00000004
	access3					// 0x00000008
	access4					// 0x00000010
	access5					// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}


// KeyAccessRights represents access masks used for key access
@[flag]
pub enum KeyAccessRights as u32
{
	query_value				// 0x00000001
	set_value				// 0x00000002
	create_sub_key			// 0x00000004
	enumerate_sub_keys		// 0x00000008
	notify					// 0x00000010
	create_link				// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// SectionAccessRights represents access masks used for section access
@[flag]
pub enum SectionAccessRights as u32
{
	query					// 0x00000001
	map_write				// 0x00000002
	map_read				// 0x00000004
	map_execute				// 0x00000008
	extend_size				// 0x00000010
	map_execute_explicit	// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// SemaphoreAccessRights represents access masks used for semaphore access
@[flag]
pub enum SemaphoreAccessRights as u32
{
	query_state				// 0x00000001
	modify_state			// 0x00000002
	access2					// 0x00000004
	access3					// 0x00000008
	access4					// 0x00000010
	access5					// 0x00000020
	access6					// 0x00000040
	access7					// 0x00000080
	access8					// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// TokenAccessRights represents access masks used for token access
pub enum TokenAccessRights as u32
{
	assign_primary			// 0x00000001
	duplicate				// 0x00000002
	impersonate				// 0x00000004
	query					// 0x00000008
	query_source			// 0x00000010
	adjust_privileges		// 0x00000020
	adjust_groups			// 0x00000040
	adjust_default			// 0x00000080
	adjust_session_id		// 0x00000100
	access9					// 0x00000200
	access10				// 0x00000400
	access11				// 0x00000800
	access12				// 0x00001000
	access13				// 0x00002000
	access14				// 0x00004000
	access15				// 0x00008000
	delete					// 0x00010000
	read_control			// 0x00020000
	write_dac				// 0x00040000
	write_owner				// 0x00080000
	synchronize				// 0x00100000
	pad1					// 0x00200000
	pad2					// 0x00400000
	pad3					// 0x00800000
	access_system_security	// 0x01000000
	maximum_allowed			// 0x02000000
	pad4					// 0x04000000
	pad5					// 0x08000000
	generic_all				// 0x10000000
	generic_execute			// 0x20000000
	generic_write			// 0x40000000
	generic_read			// 0x80000000
}

// AccessRights is a sum type that includes all different type of access rights
type AccessRights = FileAccessRights | ThreadAccessRights | ProcessAccessRights | EventAccessRights | JobAccessRights | MutantAccessRights | KeyAccessRights | SectionAccessRights | SemaphoreAccessRights | TokenAccessRights | GenericAccessRights
