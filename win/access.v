module win

/*
 * This file contains access masks for different access types. All definitions
 * are basically copied from the NtApiDotNet project.
 */

 // GenericAccessRights represents access masks for generic purposes
pub enum GenericAccessRights as u32
{
	no_access = u32(0)
	access0 = u32(0x00000001)
	access1 = u32(0x00000002)
	access2 = u32(0x00000004)
	access3 = u32(0x00000008)
	access4 = u32(0x00000010)
	access5 = u32(0x00000020)
	access6 = u32(0x00000040)
	access7 = u32(0x00000080)
	access8 = u32(0x00000100)
	access9 = u32(0x00000200)
	access10 = u32(0x00000400)
	access11 = u32(0x00000800)
	access12 = u32(0x00001000)
	access13 = u32(0x00002000)
	access14 = u32(0x00004000)
	access15 = u32(0x00008000)
	delete = u32(0x00010000)
	read_control = u32(0x00020000)
	write_dac = u32(0x00040000)
	write_owner = u32(0x00080000)
	synchronize = u32(0x00100000)
	access_system_security = u32(0x01000000)
	maximum_allowed = u32(0x02000000)
	generic_all = u32(0x10000000)
	generic_execute = u32(0x20000000)
	generic_write = u32(0x40000000)
	generic_read = u32(0x80000000)
}

 // FileAccessRights represents access masks used for file access
pub enum FileAccessRights as u32
{
	no_access = u32(0)
	read_data = u32(0x0001)
	write_data = u32(0x0002)
	append_data = u32(0x0004)
	read_ea = u32(0x0008)
	write_ea = u32(0x0010)
	execute = u32(0x0020)
	delete_child = u32(0x0040)
	read_attributes = u32(0x0080)
	write_attributes = u32(0x0100)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

 // ThreadAccessRights represents access masks used for thread access
pub enum ThreadAccessRights as u32
{
	terminate = u32(0x0001)
	suspend_resume = u32(0x0002)
	alert = u32(0x0004)
	get_context = u32(0x0008)
	set_context = u32(0x0010)
	set_information = u32(0x0020)
	query_information = u32(0x0040)
	set_thread_token = u32(0x0080)
	impersonate = u32(0x0100)
	direct_impersonation = u32(0x0200)
	set_limited_information = u32(0x0400)
	query_limited_information = u32(0x0800)
	resume = u32(0x1000)
	all_access = u32(0x1FFFFF)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

 // ProcessAccessRights represents access masks used for process access
pub enum ProcessAccessRights as u32
{
	no_access = u32(0)
	terminate = u32(0x0001)
	create_thread = u32(0x0002)
	set_session_id = u32(0x0004)
	vm_operation = u32(0x0008)
	vm_read = u32(0x0010)
	vm_write = u32(0x0020)
	dup_handle = u32(0x0040)
	create_process = u32(0x0080)
	set_quota = u32(0x0100)
	set_information = u32(0x0200)
	query_information = u32(0x0400)
	suspend_resume = u32(0x0800)
	query_limited_information = u32(0x1000)
	set_limited_information = u32(0x2000)
	all_access = u32(0x1FFFFF)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// EventAccessRights represents access masks used for event access
pub enum EventAccessRights as u32
{
	query_state = u32(1)
	modify_state = u32(2)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// JobAccessRights represents access masks used for job access
pub enum JobAccessRights as u32
{
	no_access = u32(0)
	assign_process = u32(0x1)
	set_attributes = u32(0x2)
	query = u32(0x4)
	terminate = u32(0x8)
	set_security_attributes = u32(0x10)
	impersonate = u32(0x20)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// MutantAccessRights represents access masks used for mutant access
pub enum MutantAccessRights as u32
{
	no_access = u32(0)
	modify_state = u32(1)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}


// KeyAccessRights represents access masks used for key access
pub enum KeyAccessRights as u32
{
	query_value = u32(0x0001)
	set_value = u32(0x0002)
	create_sub_key = u32(0x0004)
	enumerate_sub_keys = u32(0x0008)
	notify = u32(0x0010)
	create_link = u32(0x0020)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// SectionAccessRights represents access masks used for section access
pub enum SectionAccessRights as u32
{
	query = u32(0x0001)
	map_write = u32(0x0002)
	map_read = u32(0x0004)
	map_execute = u32(0x0008)
	extend_size = u32(0x0010)
	map_execute_explicit = u32(0x0020)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// SemaphoreAccessRights represents access masks used for semaphore access
pub enum SemaphoreAccessRights as u32
{
	no_access = u32(0)
	query_state = u32(1)
	modify_state = u32(2)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// TokenAccessRights represents access masks used for token access
pub enum TokenAccessRights as u32
{
	no_access = u32(0)
	assign_primary = u32(0x0001)
	duplicate = u32(0x0002)
	impersonate = u32(0x0004)
	query = u32(0x0008)
	query_source = u32(0x0010)
	adjust_privileges = u32(0x0020)
	adjust_groups = u32(0x0040)
	adjust_default = u32(0x0080)
	adjust_session_id = u32(0x0100)
	generic_read = u32(GenericAccessRights.generic_read)
	generic_write = u32(GenericAccessRights.generic_write)
	generic_execute = u32(GenericAccessRights.generic_execute)
	generic_all = u32(GenericAccessRights.generic_all)
	delete = u32(GenericAccessRights.delete)
	read_control = u32(GenericAccessRights.read_control)
	write_dac = u32(GenericAccessRights.write_dac)
	write_owner = u32(GenericAccessRights.write_owner)
	synchronize = u32(GenericAccessRights.synchronize)
	maximum_allowed = u32(GenericAccessRights.maximum_allowed)
	access_system_security = u32(GenericAccessRights.access_system_security)
}

// AccessRights is a sum type that includes all different type of access rights
type AccessRights = FileAccessRights | ThreadAccessRights | ProcessAccessRights | EventAccessRights | JobAccessRights | MutantAccessRights | KeyAccessRights | SectionAccessRights | SemaphoreAccessRights | TokenAccessRights | GenericAccessRights
