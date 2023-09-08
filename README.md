<div align="center">
  <img src="https://github.com/qtc-de/rpv/assets/49147108/89c49bf5-6f97-455e-b9e1-b38b27e58658"/>
</div>
<br/>

[![](https://github.com/qtc-de/rpv/actions/workflows/build-examples.yml/badge.svg?branch=main)](https://github.com/qtc-de/rpv/actions/workflows/build-examples.yml)
[![](https://github.com/qtc-de/rpv/actions/workflows/build-examples-dev.yml/badge.svg?branch=develop)](https://github.com/qtc-de/rpv/actions/workflows/build-examples-dev.yml)
[![](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/qtc-de/rpv/releases)
[![](https://img.shields.io/badge/programming%20language-v-blue)](https://vlang.io/)
[![](https://img.shields.io/badge/license-GPL%20v3.0-blue)](https://github.com/qtc-de/rpv/blob/master/LICENSE)
[![](https://img.shields.io/badge/docs-fa6b05)](https://qtc-de.github.io/rpv)

*rpv* is a *v* library for analyzing *RPC* servers and interfaces
on the *Windows* operating system. It is inspired by [RpcView](https://www.rpcview.org/)
and uses similar ideas for finding and investigating *RPC* servers.
*rpv* does not provide a graphical user interface or a command line
interface itself. The [examples](/examples) folder contains some
examples how *rpv* can be used within your own projects. Moreover,
the [rpv-web](https://github.com/qtc-de/rpv-web) project provides
a browser based graphical user interface.


### Installation

----

*rpv* is available on [vpm](https://vpm.vlang.io/packages/qtc.rpv).
Assuming that *v* [is installed](https://github.com/vlang/v#installing-v-from-source),
installing *rpv* can be done using the following command:

```console
[user@host ~]$ v install qtc.rpv
```

After installation, *rpv* can be used to analyze *RPC* servers and
interfaces in *x64* processes. If you need to investigate *x86* instead,
you need to replace the file `rpv/internals/rpc-internal-structs.v` within
your *v* modules folder (usually at `~/.vmodules`) with the appropriate
file from the [alternate](/alternate) folder.

In future, this will hopefully no longer be necessary when [toplevel
compile time statements](https://github.com/vlang/v/discussions/18670)
are added to *v*.

As it is already implemented by [RpcView](https://github.com/silverf0x/RpcView),
the [alternate](/alternate) folder may also contain different struct
definitions for different versions of *Windows* in future. Currently,
only the struct definitions for the most recent *Windows* releases were
ported from *RpcView* to *v*.


### Qickstart

----

The following listing shows an example on how the library can be used to
enumerate *RPC* servers and interfaces. More examples can be found within
[examples](/examples) folder.

```v
import qtc_de.rpv

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
            println('[+]\t ${intf.id} (${intf.methods.len} methods)')
		}
	}
}
```


### Documentation

----

Detailed documentation for the defined methods and structures can be
found within the auto generated [html docs](https://qtc-de.github.io/rpv/).
A more usage oriented documentation does not exist at the time of
writing. It is recommended to look at the [examples](/examples) folder
or the [rpv-web](https://github.com/qtc-de/rpv-web) project to learn
how the library can be used.


### Future Work

----

In future, *rpv* will probably extended to also work for analyzing *RPC*
servers and interfaces from files without running processes.


### Disclaimer

----

*rpv* should not be used to create applications that are accessible by untrusted clients.
The library contains several *unsafe* code blocks, that bypass the memory safety features
of *v*. This is required, to get the *C* interop working, but may introduce well known
memory corruption bugs. Therefore, the library should only be used for local research
projects and should not be used for applications that are exposed to untrusted clients.


### Acknowledgments

----

Writing *rpv* would not have been possible without the excellent work
by [silverf0x](https://github.com/silverf0x) ([RpcView](https://github.com/silverf0x/RpcView)),
[James Forshaw](https://twitter.com/tiraniddo) ([sandbox-attacksurface-analysis-tools](https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools)),
Nicolas Pouvesle ([mIDA](https://github.com/tenable/mIDA)) and all the
others that contributed to these projects. They did the real work by
figuring out the different data formats used by the *RPC* runtime. My
part was only to use this knowledge and to write a *v* wrapper around
it :)
