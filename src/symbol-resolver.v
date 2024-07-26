module rpv

import os
import win
import toml

// SymbolResolver is used to resolve method and interface names during runtime.
// SymbolResolver uses a hybrid approach with PDB files and a custom rpv symbol
// file in toml format to resolve symbols. Apart from symbols, SymbolResolver
// can also track notes that were taken for RPC interfaces or methods.
pub struct SymbolResolver {
	mut:
	symbols map[string][]Symbol
	params map[string][]SymbolSet
	uuids map[string]InterfaceData
	has_pdb bool
	pdb_resolver win.PdbResolver
	pub mut:
	symbol_file string
	symbol_path string
}

// Symbol represents a single symbol. It contains the offset of the symbol and
// it's associated name.
struct Symbol {
	mut:
	name string
	offset u64
}

// SymbolSet represents a set of symbols like method parameter names.
struct SymbolSet {
	mut:
	names []string
	offset u64
}

// InterfaceData is used to associate names with RPC interfaces. Moreover, the struct
// contains notes for the interface itself and for associated RPC methods.
struct InterfaceData {
	mut:
	name string
	notes string
	method_notes map[string]string
}

// new_resolver creates a new SymbolResolver from the specified file. The file
// may already exist and needs to contain valid toml in that case. Otherwise,
// the file will be created during the next symbol sync. Specifying a PDB path
// is optional and can be done by using an absolute path to a folder containing
// .pdb files, or by using the srv*<PATH> syntax.
pub fn new_resolver(symbol_file string, pdb_path string)! SymbolResolver
{
	file_cache := toml.parse_file(symbol_file) or
	{
		toml.parse_text('')!
	}

	return parse_resolver(file_cache, pdb_path, symbol_file)
}

// parse_resolver creates a new SymbolResolver from already parsed toml data.
// The function still expects a symbol_file to be specified, since each SymbolResolver
// needs an associated symbol file where it can save it's data to. Additionally,
// a PDB path can be specified either by using an absolute path to a folder containing
// .pdb files, or by using the srv*<PATH> syntax.
pub fn parse_resolver(toml_data toml.Doc, pdb_path string, symbol_file string) SymbolResolver
{
	mut uuids := map[string]InterfaceData{}
	mut symbols := map[string][]Symbol{}

	toml_map := toml_data.to_any().as_map()

	for key, value in toml_map
	{
		if key.len == 36 && !key.ends_with('.dll') && !key.ends_with('.exe')
		{
			uuids[key] = InterfaceData{}

			for prop, val in value.as_map().as_strings()
			{
				if prop == 'name' {
					uuids[key].name = val
				}

				else if prop == 'notes' {
					uuids[key].notes = val
				}

				else {
					uuids[key].method_notes[prop] = val
				}
			}
		}

		else
		{
			values := value.as_map().as_strings()
			mut symbol_arr := []Symbol{cap: values.len}

			for offset, name in values
			{
				symbol_arr << Symbol {
					name: name
					offset: offset.u64()
				}
			}

			symbols[key] = symbol_arr
		}
	}

	return SymbolResolver {
		symbols: symbols
		uuids: uuids
		symbol_file: symbol_file
		symbol_path: pdb_path
	}
}

// load_symbol attempts to resolve the location + offset information to a symbol
// name. If successful, the symbol name is returned. If the symbol cannot be found
// the function returns none.
pub fn (resolver SymbolResolver) load_symbol(location string, offset u64)? string
{
	if location in resolver.symbols
	{
		for symbol in resolver.symbols[location]
		{
			if symbol.offset == offset
			{
				return symbol.name
			}
		}
	}

	if resolver.has_pdb
	{
		return resolver.pdb_resolver.load_symbol(offset) or { return none }
	}

	return none
}

// load_symbols attempts to resolve function parameter names from the specified location
// and offset.
pub fn (resolver SymbolResolver) load_symbols(location string, offset u64)? []string
{
	if location in resolver.params
	{
		for symbol_set in resolver.params[location]
		{
			if symbol_set.offset == offset
			{
				return symbol_set.names
			}
		}
	}

	if resolver.has_pdb
	{
		return resolver.pdb_resolver.load_symbols(offset) or { return none }
	}

	return none
}

// load_uuid attempts to resolve an interface name by looking up it's uuid.
// The function call is always successful. If the interface uuid is not found
// within the SymbolResolver, the uuid itself is returned.
pub fn (resolver SymbolResolver) load_uuid(uuid string) string
{
	if uuid in resolver.uuids
	{
		return resolver.uuids[uuid].name
	}

	return uuid
}

// load_uuid_notes attempts to load notes associated with the specified uuid.
// If successful, the corresponding notes are returned as string. Otherwise,
// none is returned.
pub fn (resolver SymbolResolver) load_uuid_notes(uuid string)? string
{
	interface_data := resolver.uuids[uuid] or { return none }
	return interface_data.notes
}

// load_uuid_method_notes attempts to load notes associated with the specified method.
// A method is identified by it's RPC interface uuid and the method index. If the method
// is found and has notes associated, they are returned. Otherwise, none is returned.
pub fn (resolver SymbolResolver) load_uuid_method_notes(uuid string, index string)? string
{
	interface_data := resolver.uuids[uuid] or { return none }
	return interface_data.method_notes[index] or { return none }
}

// attach_pdb is used to attach a pdb resolver to the symbol resolver. PDB resolvers
// are associated to a specific process and need to be closed and reattached when symbols
// for a different process should be resolved.
pub fn (mut resolver SymbolResolver) attach_pdb(process_handle win.HANDLE, base voidptr, size u32)!
{
	if resolver.has_pdb {
		resolver.detach_pdb()
	}

	resolver.pdb_resolver = win.new_pdb_resolver(process_handle, resolver.symbol_path, base, size)!
	resolver.has_pdb = true
}

// detach_pdb is used to detach an existing pdb resolver from the symbol resolver.
pub fn (mut resolver SymbolResolver) detach_pdb()
{
	if resolver.has_pdb {
		resolver.pdb_resolver.cleanup()
		resolver.has_pdb = false
	}
}

// add_symbol is used to add a new symbol name to the resolver. The symbol is identified
// by it's location (file system path) and the offset within the corresponding file.
// The SymbolResolver is synced after the symbol was added.
pub fn (mut resolver SymbolResolver) add_symbol(location string, offset u64, name string)!
{
	symbol := Symbol {
		name: name
		offset: offset
	}

	if location in resolver.symbols
	{
		for mut sym in resolver.symbols[location]
		{
			if sym.offset == offset {
				sym.name = name
				resolver.sync()!
				return
			}
		}

		resolver.symbols[location] << symbol
	}

	else
	{
		resolver.symbols[location] = [symbol]
	}

	resolver.sync()!
}

// add_uuid_name is used to set an interface name for the specified interface uuid.
// The SymbolResolver is synced after this action.
pub fn (mut resolver SymbolResolver) add_uuid_name(uuid string, name string)!
{
	if uuid in resolver.uuids {
		resolver.uuids[uuid].name = name
	}

	else {
		resolver.uuids[uuid] = InterfaceData{ name: name }
	}

	resolver.sync()!
}

// add_uuid_notes is used to set notes for the specified interface uuid.
// The SymbolResolver is synced after this action.
pub fn (mut resolver SymbolResolver) add_uuid_notes(uuid string, notes string)!
{
	if uuid in resolver.uuids
	{
		resolver.uuids[uuid].notes = notes
	}

	else
	{
		resolver.uuids[uuid] = InterfaceData{ notes: notes }
	}

	resolver.sync()!
}

// add_uuid_notes is used to set notes for the specified interface uuid.
// The SymbolResolver is synced after this action.
pub fn (mut resolver SymbolResolver) add_uuid_method_notes(uuid string, index string, notes string)!
{
	if uuid in resolver.uuids
	{
		resolver.uuids[uuid].method_notes[index] = notes
	}

	else
	{
		resolver.uuids[uuid] = InterfaceData{ method_notes: {index: notes} }
	}

	resolver.sync()!
}

// merge can be used to merge two SymbolResolvers together. This function merges
// the symbol map and the uuid map of the resolvers together. Other properties stay
// unaffected.
pub fn (mut resolver SymbolResolver) merge(other SymbolResolver)!
{
	for key, symbols in other.symbols
	{
		if !(key in resolver.symbols)
		{
			resolver.symbols[key] = symbols
			continue
		}

		outer:
		for symbol in symbols
		{
			for mut existing in resolver.symbols[key]
			{
				if existing.offset == symbol.offset
				{
					existing.name = symbol.name
					continue outer
				}
			}

			resolver.symbols[key] << symbol
		}
	}

	for key, intf in other.uuids
	{
		if !(key in resolver.uuids)
		{
			resolver.uuids[key] = intf
		}

		if intf.name != ''
		{
			resolver.uuids[key].name = intf.name
		}

		if intf.notes != ''
		{
			resolver.uuids[key].notes = intf.notes
		}

		for method, note in intf.method_notes
		{
			resolver.uuids[key].method_notes[method] = note
		}
	}

	resolver.sync()!
}

// sync exports the SymbolResolver as toml file and writes it to the location
// specified by the symbol_file attribute.
pub fn (resolver SymbolResolver) sync()!
{
	if resolver.symbol_file != ''
	{
		os.write_file(resolver.symbol_file, toml.encode[SymbolResolver](resolver))!
	}
}

// to_toml creates the toml representation of the SymbolResolver and returns
// it as string.
pub fn (resolver SymbolResolver) to_toml() string
{
	mut toml_string := ''

	for uuid, intf_data in resolver.uuids
	{
		toml_string += '[${uuid}]\n'
		toml_string += toml.encode[InterfaceData](intf_data)
	}

	for path, symbols in resolver.symbols
	{
		toml_string += "['${path}']\n"

		for symbol in symbols
		{
			toml_string += "0x${symbol.offset.hex()}='''${symbol.name}'''\n"
		}
	}

	return toml_string + "\n"
}

// to_toml creates the toml representation of the InterfaceData and returns
// it as string.
pub fn (data InterfaceData) to_toml() string
{
	mut toml_string := ''

	if data.name != ''
	{
		toml_string += "name='''${data.name}'''\n"
	}

	if data.notes != ''
	{
		toml_string += "notes='''${data.notes}'''\n"
	}

	for index, notes in data.method_notes
	{
		toml_string += "${index}='''${notes}'''\n"
	}

	return toml_string + "\n"
}
