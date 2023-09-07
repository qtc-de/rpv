module utils

// log_debug logs the specified message to stderr. It is only used
// if rpv was compiled with the debug flag.
[if debug]
pub fn log_debug[T](msg T) {
	eprintln('[DEBUG] ${msg}')
}
