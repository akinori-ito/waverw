module rawrw;
import std.stdio;

//version = DEVELOP;

enum Endian {
    BIG=0, LITTLE=1, NATIVE=2
}

class RawRW {
    File f;
    Endian endian;
    Endian native;
    this(File _f, Endian e = Endian.NATIVE) {
        f = _f;
        endian = e;
        native = checkEndian();
    }
    this(string filename, string mode = "r", Endian e = Endian.NATIVE) {
        this(File(filename,mode),e);
    }

    Endian checkEndian() {
        short x = 0x1234;
        ubyte *p = cast(ubyte*)&x;
        if (*p == 0x12)
            return Endian.BIG;
        else
            return Endian.LITTLE;
    }

    void close() {
        f.close();
    }

    bool eof() @property {
        return f.eof;
    }

    ulong tell() {
        return f.tell();
    }

    void seek(long offset, int origin = SEEK_SET) {
        f.seek(offset,origin);
    }

    void readBuffer(T)(T[] buf) {
        f.rawRead!T(buf);
    }

    void writeString(string s) {
        f.write(s);
    }

    private void readBuffer(ubyte[] buf) {
        f.rawRead(buf);
        if (endian != Endian.NATIVE && endian != native) {
            uint i = 0;
            uint j = buf.length-1;
            while (i < j) {
                ubyte t = buf[i];
                buf[i] = buf[j];
                buf[j] = t;
            }
        }
    }

    T read(T)() {
        static if (is(T == byte) || is(T == ubyte) || is(T == char)) {
            const int n = 1;
        }
        static if (is(T == short) || is(T == ushort) || is(T == wchar)) {
            const int n = 2;
        }
        static if (is(T == int) || is(T == uint) || is(T == float) || is(T == dchar)) {
            const int n = 4;
        }
        static if (is(T == long) || is(T == ulong) || is(T == double)) {
            const int n = 8;
        }
        ubyte[n] buf;
        readBuffer(buf);
        return *(cast(T*)&buf[0]);
    }

    private void writeBuffer(T)(ubyte[] buf, T x) {
        ubyte *ptr = cast(ubyte*) &x;
        if (endian != Endian.NATIVE && endian != native) {
            for (size_t i = buf.length-1; i >= 0; i--) {
                buf[i] = *ptr;
                ptr++;
            }
        } else {
            for (int i = 0; i < buf.length; i++) {
                buf[i] = *ptr;
                ptr++;
            }
        }
        f.rawWrite(buf);
    }

    void write(T)(T x) {
        static if (is(T == byte) || is(T == ubyte)) {
            const int n = 1;
        }
        static if (is(T == short) || is(T == ushort)) {
            const int n = 2;
        }
        static if (is(T == int) || is(T == uint) || is(T == float)) {
            const int n = 4;
        }
        static if (is(T == long) || is(T == ulong) || is(T == double)) {
            const int n = 8;
        }
        ubyte[n] buf;
        writeBuffer!T(buf,x);
    }

}

version(DEVELOP) {
    void rwtest(T)(T x, Endian e) {
        auto rw = new RawRW("test.tmp","w",e);
        rw.write!T(x);
        rw.close();
        rw = new RawRW("test.tmp","r",e);
        T y = rw.read!T();
        assert(x == y);
        rw.close();
    }
    void main() 
    {
        byte x1 = -100;
        foreach (i; 0..3) {
            Endian e = cast(Endian)i;
            rwtest!ubyte(100,e);
            rwtest!byte(-100,e);
            rwtest!ushort(12345,e);
            rwtest!short(-12345,e);
            rwtest!int(12345678,e);
            rwtest!uint(-12345678,e);
            rwtest!long(-1234567812345678L,e);
            rwtest!ulong(1234567812345678L,e);
            rwtest!float(1.23456,e);
            rwtest!double(1.23456,e);
        }
    }
}