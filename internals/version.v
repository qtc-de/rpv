module internals

// validate_rpc_version checks whether the specified rpc_version is contained
// within the confirmed compatible RPC runtime versions. If this is not the case
// the function returns an error.
pub fn validate_rpc_version(rpc_version u64)!
{
	if !compatible_rpc_versions.contains(rpc_version)
	{
		mut error_msg := 'The version of your RPC runtime ${rpc_version.hex()} is not'
		error_msg += ' confirmed to work with the definitions in rpc-internal-structs.v.'
		error_msg += ' If something does not work, check whether a suitable file version'
		error_msg += ' can be found in the /alternate folder.'

		return error(error_msg)
	}
}
