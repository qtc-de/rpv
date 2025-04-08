module internals

// non exhaustive list of compatible RPC runtime versions. If the
// RPC runtime version of the current machine does not match one of
// this versions, a warning is displayed. We are happy to extend this
// list when you report us other working versions.
pub const compatible_rpc_versions = [
	u64(0x6000324D70000), // 6.3.9431.0000
	u64(0x6000325804000), // 6.3.9600.16384
	u64(0x6000325804340), // 6.3.9600.17216
	u64(0x6000325804407), // 6.3.9600.17415
	u64(0x60003258045FF), // 6.3.9600.17919
	u64(0x6000325804774), // 6.3.9600.18292
	u64(0x6000325804AE8), // 6.3.9600.19176
	u64(0x6000325804C52), // 6.3.9600.19538
	u64(0xA000028004000), // 10.0.10240.16384
	u64(0xA00002800401C), // 10.0.10240.16412
	u64(0xA0000280041C9), // 10.0.10240.16841
	u64(0xA0000295A0000), // 10.0.10586.0
	u64(0xA0000295A0132), // 10.0.10586.306
	u64(0xA0000295A0498), // 10.0.10586.1176
	u64(0xA0000380603E8), // 10.0.14342.1000
	u64(0xA000038190000), // 10.0.14361.0
	u64(0xA000038390000), // 10.0.14393.0
	u64(0xA000038390052), // 10.0.14393.82
	u64(0xA0000383906EA), // 10.0.14393.1770
	u64(0xA000038390908), // 10.0.14393.2312
	u64(0xA000038390A69), // 10.0.14393.2665
	u64(0xA000038390C2B), // 10.0.14393.3115
	u64(0xA00003AD70000), // 10.0.15063.0
	u64(0xA00003AD701BF), // 10.0.15063.447
	u64(0xA00003AD702A2), // 10.0.15063.674
	u64(0xA00003F6803E8), // 10.0.16232.1000
	u64(0xA00003FAB000F), // 10.0.16299.15
	u64(0xA00003FAB00C0), // 10.0.16299.192
	u64(0xA00003FAB0135), // 10.0.16299.309
	u64(0xA00003FAB0173), // 10.0.16299.371
	u64(0xA00003FAB01EC), // 10.0.16299.492
	u64(0xA00003FAB02D6), // 10.0.16299.726
	u64(0xA00003FAB034E), // 10.0.16299.846
	u64(0xA0000427903E8), // 10.0.17017.1000
	u64(0xA0000428103E8), // 10.0.17025.1000
	u64(0xA000042B203EA), // 10.0.17074.1002
	u64(0xA000042EE0001), // 10.0.17134.1
	u64(0xA000042EE0030), // 10.0.17134.48
	u64(0xA000042EE0070), // 10.0.17134.112
	u64(0xA000042EE00E4), // 10.0.17134.228
	u64(0xA000042EE0197), // 10.0.17134.407
	u64(0xA000042EE01D7), // 10.0.17134.471
	u64(0xA000042EE0288), // 10.0.17134.648
	u64(0xA000042EE046A), // 10.0.17134.1130
	u64(0xA000045630001), // 10.0.17763.1
	u64(0xA000045630086), // 10.0.17763.134
	u64(0xA0000456300C2), // 10.0.17763.194
	u64(0xA00004563017B), // 10.0.17763.379
	u64(0xA0000456302CF), // 10.0.17763.719
	u64(0xA000045630360), // 10.0.17763.864
	u64(0xA000045630629), // 10.0.17763.1577
	u64(0xA0000456306A1), // 10.0.17763.1697
	u64(0xA000045630757), // 10.0.17763.1879
	u64(0xA0000456307CF), // 10.0.17763.1999
	u64(0xA000047BA0001), // 10.0.18362.1
	u64(0xA000047BA01DC), // 10.0.18362.476
	u64(0xA000047BA0274), // 10.0.18362.628
	u64(0xA00004A610001), // 10.0.19041.1
	u64(0xA00004A6101FC), // 10.0.19041.508
	u64(0xA00004A610222), // 10.0.19041.546
	u64(0xA00004A610276), // 10.0.19041.630
	u64(0xA00004A610296), // 10.0.19041.662
	u64(0xA00004A6102EA), // 10.0.19041.746
	u64(0xA00004A61041C), // 10.0.19041.1052
	u64(0xA00004A610439), // 10.0.19041.1081,
	u64(0xA00004A610508), // 10.0.19041.1288,
	u64(0xA00004A61135D), // 10.0.19041.4957
	u64(0xA0000536A0001), // 10.0.21354.1
	u64(0xA000055EC0001), // 10.0.21996.1,
	u64(0xA000055F00001), // 10.0.22000.1
]

// RpcInterface defines the internally used structure for RPC interfaces.
// This struct definition was copied from RpcView https://github.com/silverf0x/RpcView
// and all credits belong to the authors of RpcView. In the current state
// of v, the '[if x86]' attribute is ignored for structs, but will be
// available in future. Up to this point, we need to keep the x64 and x86
// struct definitions in separate files.
@[if x86]
pub struct RpcInterface
{
pub:
	p_rpc_server                  &RpcServer = unsafe { nil }
	flags                         u32
	mutex                         Mutex
	ep_mapper_flags               u32
	entry_point_vector            voidptr = unsafe { nil }
	sec_callback                  RpcCallbackFunction = unsafe { nil }
	server_interface              RpcServerInterface
	syntax_info                   &C.MIDL_SYNTAX_INFO = unsafe { nil }
	transfer_syntaxes             voidptr
	transfer_syntaxes_count       u32
	unk1                          u32
	nb_type_manager               u32
	max_rpc_size                  u32
	uuid_vector                   &C.UUID_VECTOR = unsafe { nil }
	manager_dict                  SimpleDict
	annotation                    [64]char
	if_callback_func              RpcCallbackFunction = unsafe { nil }
	is_call_size_limit_reached    u32
	current_null_manager_calls    u32
	current_auto_listen_calls     u32
	unk2                          [2]u32
	security_callback_in_progress u32
	security_cache_entry          u32
	security_cache_entries        [16]u32
	ep_dict                       SimpleDict
	unk3                          [4]u32
}

// RpcServer defines the internally used structure for RPC servers.
// This struct definition was copied from RpcView https://github.com/silverf0x/RpcView
// and all credits belong to the authors of RpcView. In the current state
// of v, the '[if x86]' attribute is ignored for structs, but will be
// available in future. Up to this point, we need to keep the x64 and x86
// struct definitions in separate files.
@[if x86]
pub struct RpcServer
{
pub:
	mutex                   Mutex
	is_listening1           int
	is_listening2           int
	minimum_call_threads    u32
	wait                    int
	out_calls               u32
	unk1                    u32
	in_calls                u32
	address_dict            SimpleDict
	available_calls         u32
	prot_seq_queue          SimpleDict
	unk2                    [4]u32
	out_packets             u32
	mutex2                  Mutex
	max_calls               u32
	h_event                 voidptr
	unk3                    [4]u32
	interfaces              SimpleDict
	is_listening3           int
	is_max_calls            int
	unk4                    [6]u32
	in_packets              u32
	rpc_forward_function    RpcForwardFunction = unsafe { nil }
	unk5                    [6]u32
	authen_info_dict        SimpleDict
	rpc_if_group_list_entry ListEntry
	rw_lock                 &u32 = unsafe { nil }
	field_1e0               ListEntry
}

// RpcAddress defines the internally used structure for RPC addresses.
// This struct definition was copied from RpcView https://github.com/silverf0x/RpcView
// and all credits belong to the authors of RpcView. In the current state
// of v, the '[if x86]' attribute is ignored for structs, but will be
// available in future. Up to this point, we need to keep the x64 and x86
// struct definitions in separate files.
@[if x86]
pub struct RpcAddress
{
pub:
	vtable       voidptr
	magic        u32
	addr_type    u32
	ref_count    u32
	unk1         u32
	name         &u16 = unsafe { nil }
	protocol     &u16 = unsafe { nil }
	address      &u16 = unsafe { nil }
	named        bool
	flags        u32
	associations SimpleDict
	unk2         u32
	unk3         u32
	active_calls u32
	unk4         u32
	unk5         [6]u32
	unk6         u32
	mutex        Mutex
}
