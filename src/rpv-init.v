module rpv

import win
import utils
import internals { validate_rpc_version }

// init initializes the rpv module by enabling SeDebugPrivilege and calling
// CoInitialize. If one of these operations fails, the module causes a panic.
// Additionally, the RPC runtime version is obtained and compared against the
// selected RPC struct definitions within the rpv.internals module.
fn init()
{
	utils.log_debug('Starting initialization of rpv.')

	win.adjust_privilege("SeDebugPrivilege", true) or
	{
		panic('Failure while enabling SeDebugPrivilege: ${err}')
	}

	if C.CoInitialize(unsafe { nil }) != C.S_OK
	{
		panic('Failure while initializing the COM library.')
	}

	rpc_version := win.get_rpc_runtime_version() or
	{
		panic('Unable to obtain RPC runtime version: ${err}')
	}

	validate_rpc_version(rpc_version) or
	{
		eprintln(err)
		return
	}

	utils.log_debug('rpv was initialized successfully.')
	utils.log_debug('RPC runtime version is: ${rpc_version.hex()}')
}
