### Network Data Representation (NDR)

----

When defining or calling *Windows RPC* methods, the *Interface Definition Language* (*IDL*)
is used to describe these methods and the utilized data types. *Network Data Representation*
(*NDR*), on the other hand, handles the marshalling and unmarshalling of these types during
method calls and provides the corresponding mappings. By inspecting process memory, these
mappings can be found and evaluated to recover the method and type definitions from the
original *IDL* file.

The *decompiler* defined within the files in this folder is strongly influenced by the
[NtApiDotNet](https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools/tree/main/NtApiDotNet/Ndr).
It is basically a port of the *C#* decompiler written by [James Forshaw](https://twitter.com/tiraniddo)
and he deserves the actual praise.

Nonetheless, porting the decompiler was not easy and I'm not sure whether I implemented
everything correctly or whether it is *complete*. Feel free to create issues if something
does not work on your machine :)
