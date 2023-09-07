module ndr

// ComplexType is an interface that should be implemented by all NDR structure
// and union types. Implementing ComplexType allows a type to be used within a
// TypeCache, which is basically required for rpv to work correctly. Implementing
// ComplexType requires the implementing type to have a unique ID, a location
// where the type has been found in process memory and a get_definition method
// to obtain the string representation of the ComplexType as defined in IDL.
interface ComplexType {
	id u32
	location voidptr
	get_definition() string
}

// TypeCache is used to prevent decompilation of already decompiled types.
// NDR can contain references to the same data types multiple times. When
// decompiling without a TypeCache, these types would be decompiled several
// times, creating an unnecessary overhead. TypeCache caches these references
// associated with the already decompiled type to speedup this procedure.
//
// The struct contains a mapping between process memory addresses and associated
// NdrTypes. Moreover, for each first encountered complex type (struct or union),
// it caches the type definition within the types member. When finishing
// decompilation, the types member contains all complex types that have
// been encountered within an interface. This allows easy formatting of
// decompilation results.
pub struct TypeCache {
	mut:
	type_map map[string]NdrType
	types []ComplexType
	complex_id u32
}

// contains checks whether the specified address was already decompiled
// and is contained inside the TypeCache.
pub fn (cache TypeCache) contains(addr voidptr) bool
{
	return addr.str() in cache.type_map
}

pub fn (cache TypeCache) get(addr voidptr)! NdrType
{
	return cache.type_map[addr.str()] or {
		return error('Address ${addr.str()} was not found')
	}
}

// set adds a new address and the associated type to the type cache.
pub fn (mut cache TypeCache) set(addr voidptr, typ NdrType)
{
	cache.type_map[addr.str()] = typ
}

// get_id returns a unique id for the type at the specified address.
// When decompiling types, each type needs a unique name. rpv assigns
// names like struct1 or union1337 to new types. The suffix number
// is incremented on the type cache and represents the amount of types
// that has already been resolved. If the specified address was not
// already decompiled, a new number is returned and the counter gets
// incremented. If the type is already known, it's corresponding id
// gets returned.
pub fn (mut cache TypeCache) get_id(addr voidptr) u32
{
	for def in cache.types
	{
		if def.location == addr
		{
			return def.id
		}
	}

	return cache.complex_id++
}

// add_complex adds a new complex type to the types member of the TypeCache.
// The function first checks whether the complex type already exists within
// the cache to ensure that the final type list only contains unique types.
// If this is not the case, the specified complex type is added to the list.
pub fn (mut cache TypeCache) add_complex(candidate ComplexType)
{
	for def in cache.types
	{
		if def.location == candidate.location
		{
			return
		}
	}

	cache.types << candidate
}

// get_types returns an array of ComplexType representing all types
// that have been cached in the TypeCache. This list only contains unique
// types and can be used to format type information for an interface.
pub fn (cache TypeCache) get_types() []ComplexType
{
	return cache.types
}
