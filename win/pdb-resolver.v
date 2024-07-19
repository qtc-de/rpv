module win

import utils

// PdbResolver is used to resolve symbols using .pdb files. This
// struct should be initialized by using the new_pdb_resolver
// function.
pub struct PdbResolver {
	process_handle	HANDLE
	module_base		voidptr
	module_size		u32
}

// new_pdb_resolver initializes symbols for the specified process and looks for the associated
// pdb file. pdb files with absolute paths are located automatically. pdb files with
// relative paths will be searched in the folder specified in the environment variable
// RPV_SYMBOL_PATH.
pub fn new_pdb_resolver(process_handle HANDLE, symbol_path string, module_base voidptr, module_size u32)! PdbResolver
{
	if !C.SymInitialize(process_handle, &voidptr(0), false)
	{
		return error('SymInitialize failed.')
	}

	pdb_path := get_pdb_path(process_handle, symbol_path, module_base)!
	utils.log_debug('Trying to load symbols from: ${pdb_path}')

	if C.SymLoadModuleEx(process_handle, &voidptr(0), &char(pdb_path.str), &voidptr(0), u64(module_base), module_size, &voidptr(0), 0) == 0
	{
		C.SymCleanup(process_handle)
		return error('Call to SymLoadModuleEx failed.')
	}

	return PdbResolver {
		process_handle: process_handle
		module_base: module_base
		module_size: module_size
	}
}

// cleanup unloads an previously created pdb context. The PdbResolver should no longer
// be used after calling this function.
pub fn (context PdbResolver) cleanup()
{
	$if x64
	{
		C.SymUnloadModule64(context.process_handle, u64(context.module_base))
	}

	$else
	{
		C.SymUnloadModule(context.process_handle, u32(context.module_base))
	}
}

// load_symbol attempts to resolve the specified symbol from an already
// created pdb context.
pub fn (context PdbResolver) load_symbol(symbol u64)! string
{
	mut disp := u64(0)
	symbol_info := SymbolInfoV{
		size_of_struct: sizeof(C.SYMBOL_INFO)
	}

	if !C.SymFromAddr(context.process_handle, symbol, &disp, &symbol_info)
	{
		return error('Unable to resolve symbol at 0x${symbol} via SymFromAddr')
	}

	return unsafe { cstring_to_vstring(&char(symbol_info.name[..].data)) }
}
