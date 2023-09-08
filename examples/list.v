module main

import qtc_de.rpv

/*
 * This example attempts to list all running processes that
 * expose RPC endpoints.
 */

fn main()
{
	infos := rpv.get_rpv_process_infos() or { panic(err) }

	for info in infos
	{
		if info.rpc_info.rpc_type in [.no_rpc, .wrong_arch]
		{
			continue
		}

		println('[+]')
		println('[+] Process Name: ${info.name}')
		println('[+] PID         : ${info.pid}')
		println('[+] User        : ${info.user}')
		println('[+] Path        : ${info.path}')

		println('[+] RPC Endpoints:')
		for endpoint in info.rpc_info.server_info.endpoints
		{
			println('[+]\t ${endpoint.protocol} - ${endpoint.name}')
		}

		println('[+] RPC Interfaces:')
		for intf in info.rpc_info.interface_infos
		{
			if intf.methods.len > 0
			{
				println('[+]\t ${intf.id} (${intf.methods.len} methods)')
			}

			else
			{
				println('[+]\t ${intf.id} (DCOM)')
			}
		}
	}
}
