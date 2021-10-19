// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module time

pub struct TimeParseError {
	msg  string
	code int
}

fn error_invalid_time(code int) IError {
	return TimeParseError{
		msg: 'Invalid time format code: $code'
		code: code
	}
}

// parse returns time from a date string in "YYYY-MM-DD HH:MM:SS" format.
pub fn parse(s string) ?Time {
	if s == '' {
		return error_invalid_time(0)
	}
	pos := s.index(' ') or { return error_invalid_time(1) }
	symd := s[..pos]
	ymd := symd.split('-')
	if ymd.len != 3 {
		return error_invalid_time(2)
	}
	shms := s[pos..]
	hms := shms.split(':')
	hour_ := hms[0][1..]
	minute_ := hms[1]
	second_ := hms[2]
	//
	iyear := ymd[0].int()
	imonth := ymd[1].int()
	iday := ymd[2].int()
	ihour := hour_.int()
	iminute := minute_.int()
	isecond := second_.int()
	// eprintln('>> iyear: $iyear | imonth: $imonth | iday: $iday | ihour: $ihour | iminute: $iminute | isecond: $isecond')
	if iyear > 9999 || iyear < -9999 {
		return error_invalid_time(3)
	}
	if imonth > 12 || imonth < 1 {
		return error_invalid_time(4)
	}
	if iday > 31 || iday < 1 {
		return error_invalid_time(5)
	}
	if ihour > 23 || ihour < 0 {
		return error_invalid_time(6)
	}
	if iminute > 59 || iminute < 0 {
		return error_invalid_time(7)
	}
	if isecond > 59 || isecond < 0 {
		return error_invalid_time(8)
	}
	res := new_time(Time{
		year: iyear
		month: imonth
		day: iday
		hour: ihour
		minute: iminute
		second: isecond
	})
	return res
}

// parse_iso8601 parses rfc8601 time format yyyy-MM-ddTHH:mm:ss.dddddd+dd:dd as local time
// the fraction part is difference in milli seconds and the last part is offset
// from UTC time and can be both +/- HH:mm
// remarks: not all iso8601 is supported
// also checks and support for leapseconds should be added in future PR
pub fn parse_iso8601(s string) ?Time {
	if s == '' {
		return error_invalid_time(0)
	}
	t_i := s.index('T') or { -1 }
	parts := if t_i != -1 { [s[..t_i], s[t_i + 1..]] } else { s.split(' ') }
	if !(parts.len == 1 || parts.len == 2) {
		return error_invalid_time(12)
	}
	year, month, day := parse_iso8601_date(parts[0]) ?
	mut hour_, mut minute_, mut second_, mut microsecond_, mut unix_offset, mut is_local_time := 0, 0, 0, 0, i64(0), true
	if parts.len == 2 {
		hour_, minute_, second_, microsecond_, unix_offset, is_local_time = parse_iso8601_time(parts[1]) ?
	}
	mut t := new_time(
		year: year
		month: month
		day: day
		hour: hour_
		minute: minute_
		second: second_
		microsecond: microsecond_
	)
	if is_local_time {
		return t // Time already local time
	}
	mut unix_time := t.unix
	if unix_offset < 0 {
		unix_time -= (-unix_offset)
	} else if unix_offset > 0 {
		unix_time += unix_offset
	}
	t = unix2(i64(unix_time), t.microsecond)
	return t
}

// parse_rfc3339 returns time from a date string in RFC 3339 datetime format.
pub fn parse_rfc3339(s string) ?Time {
	if s == '' {
		return error_invalid_time(0)
	}
	mut t := parse_iso8601(s) or { Time{} }
	// If parse_iso8601 DID NOT result in default values (i.e. date was parsed correctly)
	if t != Time{} {
		return t
	}

	t_i := s.index('T') or { -1 }
	parts := if t_i != -1 { [s[..t_i], s[t_i + 1..]] } else { s.split(' ') }

	// Check if s is date only
	if !parts[0].contains_any(' Z') && parts[0].contains('-') {
		year, month, day := parse_iso8601_date(s) ?
		t = new_time(Time{
			year: year
			month: month
			day: day
		})
		return t
	}
	// Check if s is time only
	if !parts[0].contains('-') && parts[0].contains(':') {
		mut hour_, mut minute_, mut second_, mut microsecond_, mut unix_offset, mut is_local_time := 0, 0, 0, 0, i64(0), true
		hour_, minute_, second_, microsecond_, unix_offset, is_local_time = parse_iso8601_time(parts[0]) ?
		t = new_time(Time{
			hour: hour_
			minute: minute_
			second: second_
			microsecond: microsecond_
		})
		if is_local_time {
			return t // Time is already local time
		}
		mut unix_time := t.unix
		if unix_offset < 0 {
			unix_time -= (-unix_offset)
		} else if unix_offset > 0 {
			unix_time += unix_offset
		}
		t = unix2(i64(unix_time), t.microsecond)
		return t
	}

	return error_invalid_time(9)
}
