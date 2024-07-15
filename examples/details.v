module main

import os
import flag
import qtc_de.rpv

fn main()
{
	mut fp := flag.new_flag_parser(os.args)

	fp.application('details')
	fp.version('v1.0.0')
	fp.description('Simple example on how to use rpv to obtain RPC details')
	id := fp.string('id', `i`, '', 'interface ID to obtain details from (required)')
	pdb_path := fp.string('pdb-path', `p`, '', 'path to a folder containing pdb files')
	symbol_file := fp.string('symbol-file', `s`, '', 'path to an rpv symbol file')

	fp.finalize() or
	{
		eprintln(err)
		println(fp.usage())
		return
	}

	if id == ''
	{
		println(fp.usage())
		return
	}

	mut resolver := rpv.new_resolver(symbol_file, pdb_path) or { panic(err) }
	infos := rpv.get_rpv_process_infos_ex(mut resolver) or { panic(err) }

	for info in infos
	{
		for intf in info.rpc_info.interface_infos
		{
			if intf.id == id
			{
				println('[+] Interface        : ${intf.name}')
				println('[+] Location         : ${intf.location.path}')
				println('[+] RPC Type         : ${intf.typ}')
				println('[+] Method Count     : ${intf.methods.len}')

				if intf.ep_registered
				{
					println('[+] EndpointMapper   : registered')
				}

				else
				{
					println('[+] EndpointMapper   : not registred')
				}

				println('[+] Security Callback:')

				if intf.sec_callback.addr != 0
				{
					println('[+]\t Registred   : True')
					println('[+]\t Address     : 0x${intf.sec_callback.addr}')
					println('[+]\t Offset      : 0x${intf.sec_callback.offset.hex()}')

					if intf.sec_callback.location.path != ''
					{
						println('[+]\t Location    : ${intf.sec_callback.location.path}')
					}
				}

				else
				{
					println('[+]\t Registred   : False')
				}

				println('[+] Methods:')

				for method in intf.methods
				{
					println('[+]\t ${method.name} (addr: 0x${method.addr}, offset: 0x${method.offset.hex()})')
				}

				return
			}
		}
	}

	println('[-] Unable to find interface with id: `${id}`.')
}
