module win

// IconCache is used to cache bitmap icons of paths within the file
// system. Since icons of file system paths should not change frequently
// this should be fine. Apart from the performance benefit, there seems
// also to be a bug in the icon converting functions. Errors were observed
// for long running rpv usage when constantly retrieving icons.
pub struct IconCache
{
	mut:
	items map[string]string = map[string]string{}
}

// get returns an icon from the cache or retrieves it from the file system.
// When using an IconCache, this function should be used to retrieve icons
// instead of manually calling the corresponding functions from the win module.
pub fn (mut cache IconCache) get(path string)! string
{
	if cache.contains(path)
	{
		return cache.items[path]
	}

	icon_handle := win.get_module_icon(path)!
	icon_b64 := win.icon_to_bmp(icon_handle)!

	cache.items[path] = icon_b64
	return icon_b64
}

// put adds a new icon to the cache. The icon to put needs to be passed as
// base64 encoded string.
pub fn (mut cache IconCache) put(path string, icon_b64 string)
{
	cache.items[path] = icon_b64
}

// contains returns true if an icon is available for the specified path.
pub fn (cache IconCache) contains(path string) bool
{
	return path in cache.items
}

// clear removes all icons from the cache.
pub fn (mut cache IconCache) clear()
{
	cache.items.clear()
}
