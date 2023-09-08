module main

import os
import flag
import qtc_de.rpv

fn main()
{
	mut fp := flag.new_flag_parser(os.args)

	fp.application('decompile')
	fp.version('v1.0.0')
	fp.description('Simple example on how to decompile RPC interfaces')
	id := fp.string('id', `i`, '', 'interface ID to decompile (required)')

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

	infos := rpv.get_rpv_process_infos() or { panic(err) }

	for info in infos
	{
		for intf in info.rpc_info.interface_infos
		{
			if intf.id == id
			{
				if decoded := intf.decode_all_methods(info.pid)
				{
					println(decoded.format())
				}

				else
				{
					println(err)
				}

				return
			}
		}
	}

	println('[-] Unable to find interface with id: `${id}`.')
}
