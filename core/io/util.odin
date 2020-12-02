package io

import "core:runtime"

@(private)
Tee_Reader :: struct {
	using stream: Stream,
	r: Reader,
	w: Writer,
	allocator: runtime.Allocator,
}

@(private)
_tee_reader_vtable := &Stream_VTable{
	impl_read = proc(s: Stream, p: []byte) -> (n: int, err: Error) {
		t := (^Tee_Reader)(s.data);
		n, err = read(t.r, p);
		if n > 0 {
			if wn, werr := write(t.w, p[:n]); werr != nil {
				return wn, werr;
			}
		}
		return;
	},
	impl_destroy = proc(s: Stream) -> Error {
		t := (^Tee_Reader)(s.data);
		allocator := t.allocator;
		free(t, allocator);
		return .None;
	},
};

// tee_reader
// tee_reader must call io.destroy when done with
tee_reader :: proc(r: Reader, w: Writer, allocator := context.allocator) -> Reader {
	t := new(Tee_Reader, allocator);
	t.r, t.w = r, w;
	t.allocator = allocator;
	t.data = t;
	t.vtable = _tee_reader_vtable;
	res, _ := to_reader(t^);
	return res;
}


// A Limited_Reader reads from r but limits the amount of
// data returned to just n bytes. Each call to read
// updates n to reflect the new amount remaining.
// read returns EOF when n <= 0 or when the underlying r returns EOF.
Limited_Reader :: struct {
	using stream: Stream,
	r: Reader, // underlying reader
	n: i64,    // max_bytes
}

@(private)
_limited_reader_vtable := &Stream_VTable{
	impl_read = proc(using s: Stream, p: []byte) -> (n: int, err: Error) {
		l := (^Limited_Reader)(s.data);
		if l.n <= 0 {
			return 0, .EOF;
		}
		p := p;
		if i64(len(p)) > l.n {
			p = p[0:l.n];
		}
		n, err = read(l.r, p);
		l.n -= i64(n);
		return;
	},
};

new_limited_reader :: proc(r: Reader, n: i64) -> ^Limited_Reader {
	l := new(Limited_Reader);
	l.vtable = _limited_reader_vtable;
	l.data = l;
	l.r = r;
	l.n = n;
	return l;
}

@(private="package")
inline_limited_reader :: proc(l: ^Limited_Reader, r: Reader, n: i64) -> Reader {
	l.vtable = _limited_reader_vtable;
	l.data = l;
	l.r = r;
	l.n = n;
	res, _ := to_reader(l^);
	return res;
}