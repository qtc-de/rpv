module ndr

type KnownCheck = fn (mut base NdrBaseStruct) bool

// check_known checks whether the input NdrBaseStruct matches a known struct.
// The actual checks are performed by the other functions defined in this file.
// If a function finds a match, it should return true and adjust the struct name
// and struct member names within its function body.
pub fn check_known(mut base NdrBaseStruct)
{
	mut known_checks := []KnownCheck{}
	known_checks << check_guid

	for check in known_checks
	{
		if check(mut base)
		{
			return
		}
	}
}

// check_guid checks whether the specified NdrBaseStruct is the C.GUID struct.
pub fn check_guid(mut base NdrBaseStruct) bool
{
	if base.memory_size == 16 && base.members.len == 4
	{
		if base.members[0].format == .fc_long && base.members[1].format == .fc_short && base.members[2].format == .fc_short
		{
			mem3 := base.members[3]

			if mem3 is NdrSimpleArray
			{
				if mem3.total_size == 8 || mem3.NdrArray.format == .fc_byte
				{
					base.NdrComplexType.name = 'GUID'
					base.names << 'Data1'
					base.names << 'Data2'
					base.names << 'Data3'
					base.names << 'Data4'

					return true
				}
			}
		}
	}

	return false
}
