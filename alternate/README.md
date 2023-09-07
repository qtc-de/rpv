### Alternate RPC Internal Struct Definitions

----

This folder contains alternate definitions for the internal RPC structures used 
by the Windows operating system. Depending on your Windows version, the internally
used RPC structures are different and an corresponding file needs to be selected.
By default, *rpv* uses struct definitions that match the most recent Windows releases.

In the current state of [v](https://vlang.io/), the different struct definitions files
need to be exchanged before compilation. In future releases of the language, structs
will support attributes and it will be possible to selectively disable and enable structs
depending on the architecture and compiler flags.

All credits for the structure definitions belong to the authors of [RpcView](https://github.com/silverf0x/RpcView),
who did the actual hard work, figuring out how these structures are aligned and used
by the RPC runtime.

At the time of writing, only the most recent structure version was ported from *RpcView*
to *v*. Feel free to contribute struct definitions for older Windows versions :)
