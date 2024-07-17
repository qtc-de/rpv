module win

import os

// CV_INFO_PDB70 represents information that is contained within the
// debug directory of an executable. rpv is especially interested in
// the pdb_path member, that contains the file system path of an
// associated .pdb file. rpv reads this struct from process memory.
struct CV_INFO_PDB70{
	v_signature u32
	signature C.GUID
	age u32
	pdb_path [260]char
}

// C.IMAGE_DEBUG_DIRECTORY contains the formatting of the debug
// directory of an executable.
@[typedef]
struct C.IMAGE_DEBUG_DIRECTORY {
  Characteristics DWORD
  TimeDateStamp DWORD
  MajorVersion WORD
  MinorVersion WORD
  Type DWORD
  SizeOfData DWORD
  AddressOfRawData DWORD
  PointerToRawData DWORD
}

// SymbolInfoV contains information on a resolved symbol. This
// struct is used by the C.SymFomAddr function, that attempts
// to resolve a symbol.
struct SymbolInfoV {
       size_of_struct ULONG
       type_index ULONG
       reserved [2]ULONG64
       info ULONG
       size ULONG
       mod_base ULONG64
       flags ULONG
       value ULONG64
       address ULONG64
       register ULONG
       scope ULONG
       tag ULONG
       name_len ULONG
       max_name_len ULONG = u32(512)
       name [512]CHAR
}

// get_module_pdb_info attempts to obtain debug information from the debug directory
// of the specified module within the specified process.
pub fn get_module_pdb_info(process_handle HANDLE, module_base voidptr)! CV_INFO_PDB70
{
	pdb_info := CV_INFO_PDB70{}
	mut debug_dir := &u8(0)

	dos_header := C.IMAGE_DOS_HEADER{}
	debug_directory := C.IMAGE_DEBUG_DIRECTORY{}

	if !C.ReadProcessMemory(process_handle, module_base, &dos_header, sizeof(dos_header), &voidptr(0))
	{
		return error('Failed to read IMAGE_DOS_HEADER.')
	}

	unsafe
	{
		$if x64
		{
			is_wow_64 := false

			if !C.IsWow64Process(process_handle, &is_wow_64)
			{
				return error('IsWow64Process failed.')
			}

			if is_wow_64
			{
				// currently, cross architecture RPC enumeration is not supported. Therefore,
				// it is not necessary to setup symbols from x64 for WOW64 processes. We keep
				// the implementation as cross architecture support might be added in future.

				return error('Wrong architecture')

				//nt_headers32 := C.IMAGE_NT_HEADERS32{}

				//if !C.ReadProcessMemory(process_handle, &u8(module_base) + u32(dos_header.e_lfanew), &nt_headers32, sizeof(nt_headers32), &voidptr(0))
				//{
				//	return error('Failed to read IMAGE_NT_HEADERS32.')
				//}

				//debug_dir = &u8(module_base) + u32(nt_headers32.OptionalHeader.DataDirectory[C.IMAGE_DIRECTORY_ENTRY_DEBUG].VirtualAddress)
				//goto Shared
			}
		}

		nt_headers := C.IMAGE_NT_HEADERS{}

		if !C.ReadProcessMemory(process_handle, &u8(module_base) + u32(dos_header.e_lfanew), &nt_headers, sizeof(nt_headers), &voidptr(0))
		{
			return error('Failed to read IMAGE_NT_HEADERS.')
		}

		debug_dir = &u8(module_base) + u32(nt_headers.OptionalHeader.DataDirectory[C.IMAGE_DIRECTORY_ENTRY_DEBUG].VirtualAddress)

		//Shared:

		if !C.ReadProcessMemory(process_handle, debug_dir, &debug_directory, sizeof(debug_directory), &voidptr(0))
		{
			return error('Unable to read IMAGE_DEBUG_DIR.')
		}

		if !C.ReadProcessMemory(process_handle, &u8(module_base) + u32(debug_directory.AddressOfRawData), &pdb_info, sizeof(pdb_info), &voidptr(0))
		{
			return error('Unable to read CV_INFO_PDB70.')
		}
	}

	if pdb_info.v_signature != 0x53445352
	{
		return error('Invalid signature for PDB struct.')
	}

	return pdb_info
}

// get_pdb_path attempts to obtain the pdb file path of the specified module within
// the specified process
pub fn get_pdb_path(process_handle HANDLE, symbol_path string, module_base voidptr)! string
{
	pdb_info := get_module_pdb_info(process_handle, module_base)!
	pdb_path := unsafe { cstring_to_vstring(&char(pdb_info.pdb_path[..].data)) }

	if pdb_path.contains('\\')
	{
		return pdb_path
	}

	if symbol_path == ""
	{
		return error('No symbol path configured.')
	}

	if symbol_path.starts_with('srv*')
	{
		return os.join_path(
			symbol_path.trim_string_left("srv*"),
			pdb_path,
			[
				'${pdb_info.signature.Data1:08X}',
				'${pdb_info.signature.Data2:04X}',
				'${pdb_info.signature.Data3:04X}',
				'${pdb_info.signature.Data4[0]:02X}',
				'${pdb_info.signature.Data4[1]:02X}',
				'${pdb_info.signature.Data4[2]:02X}',
				'${pdb_info.signature.Data4[3]:02X}',
				'${pdb_info.signature.Data4[4]:02X}',
				'${pdb_info.signature.Data4[5]:02X}',
				'${pdb_info.signature.Data4[6]:02X}',
				'${pdb_info.signature.Data4[7]:02X}',
				'${pdb_info.age:X}',
			].join(''),
			pdb_path
		)
	}

	return os.join_path_single(symbol_path, pdb_path)
}
