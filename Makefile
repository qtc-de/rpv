Options := -os windows
x64RpcInternals := alternate/default-x64.v
x86RpcInternals := alternate/default-x86.v
RpcInternals := internals/rpc-internal-structs.v

all: decompile-x64 decompile-x86 details-x64 details-x86 list-x64 list-x86

decompile-x64: ${x64RpcInternals} examples/decompile.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/decompile.v -o examples/${@}.exe

decompile-x86: ${x86RpcInternals} examples/decompile.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/decompile.v -o examples/${@}.exe

details-x64: ${x64RpcInternals} examples/details.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/details.v -o examples/${@}.exe

details-x86: ${x86RpcInternals} examples/details.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/details.v -o examples/${@}.exe

list-x64: ${x64RpcInternals} examples/list.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/list.v -o examples/${@}.exe

list-x86: ${x86RpcInternals} examples/list.v
	cp ${<} ${RpcInternals}
	v ${Options} examples/list.v -o examples/${@}.exe

clean:
	rm -f examples/*.exe ${RpcInternals}
