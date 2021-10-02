/**
 *  Authors: Akinori Ito
 *  Date: 02/10/2021
 *  Copyright: BSD
 */

module waverw;

import std.stdio;
import std.conv;
import std.math;
import rawrw;

//version=DEVELOP;

class WavFormatException : Exception {
	this(string msg = "WAV Format Error", string file = __FILE__, size_t line = __LINE__) {
		super(msg,file,line);
	}
}
class WavFormatUnsupportedException : Exception {
	this(string msg = "WAV Format Unsupported", string file = __FILE__, size_t line = __LINE__) {
		super(msg,file,line);
	}
}
class WavBadValueException : Exception {
	this(string msg = "WAV Illegal Value", string file = __FILE__, size_t line = __LINE__) {
		super(msg,file,line);
	}
}

/**
 *  
 */
class WavFormat {
	static const ushort UNKNOWN    = 0;
	static const ushort PCM        = 1;
	static const ushort MS_ADPCM   = 2;
	static const ushort FLOAT      = 3;
	static const ushort ALAW       = 6;
	static const ushort MULAW      = 7;
}

struct FormatChunk {
	uint  subchunksize;
  	ushort fmt_id;              /* format ID */
  	ushort channels;            /* number of channels */
  	uint   samplerate;          /* sampling rate */
  	uint   byterate;            /* bytes per second */
  	ushort blocksize;           /* bytes per block */
  	ushort bitpersample;        /* bits per sample */
  	uint   extensionsize;       /* size of extension */
  	ubyte[] extension;         /* extension data */
}

class WavHeader {
  	uint size;               /* file size */
  	FormatChunk fmt;         /* format */
  	uint datasize;         /* data bytes */
	/*
	* checks if the file contains the specified characters
	*/
	private bool check_format(string fmtstring, RawRW f, bool throwError = true) {
		auto len = fmtstring.length;
		for (auto i = 0; i < len; i++) {
			char c = f.read!char();
			if (f.eof || c != fmtstring[i]) {
				if (throwError)
					throw new WavFormatException("WAV format error while checking "~fmtstring);
				return false;
			}
		}
		return true;
	}
	
	private void readFormatChunk(RawRW f)
	{
		check_format("fmt ",f);
		fmt.subchunksize = f.read!uint();
		fmt.fmt_id       = f.read!ushort();
		fmt.channels     = f.read!ushort();
		fmt.samplerate   = f.read!uint();
		fmt.byterate     = f.read!uint();
		fmt.blocksize    = f.read!ushort();
		fmt.bitpersample = f.read!ushort();
		if (f.eof) throw new WavFormatException();

		auto pos = f.tell();
		if (check_format("data",f)) {
			return;
		}
		f.seek(pos,SEEK_SET);

		fmt.extensionsize = f.read!ushort();
		if (fmt.extensionsize > 0) {
			fmt.extension = new ubyte[fmt.extensionsize];
            f.readBuffer!ubyte(fmt.extension);
		}
		check_format("data",f);
	}

	private void writeFormatChunk(RawRW f)
	{
		f.writeString("fmt ");
		f.write!uint(fmt.subchunksize);
		f.write!ushort(fmt.fmt_id);
		f.write!ushort(fmt.channels);
		f.write!uint(fmt.samplerate);
		f.write!uint(fmt.byterate);
		f.write!ushort(fmt.blocksize);
		f.write!ushort(fmt.bitpersample);
		f.writeString("data");
	}

	this() {
		fmt.subchunksize = 16;
		// not initialized
	}

	this(RawRW f) {
		check_format("RIFF",f);
		size = f.read!uint();
		check_format("WAVE",f);
		readFormatChunk(f);
		datasize = f.read!uint();
	}
	void write(RawRW f) {
		f.writeString("RIFF");
		f.write(size);
		f.writeString("WAVE");
		writeFormatChunk(f);
		f.write(datasize);
	}
	void showSummary() {
		writefln("header.size=%d",size);
		writefln("subchunksize=%d",fmt.subchunksize);
		writefln("fmt_id=%d",fmt.fmt_id);              /* format ID */
		writefln("channels=%d",fmt.channels);            /* number of channels */
		writefln("samplerate=%s",fmt.samplerate);          /* sampling rate */
		writefln("byterate=%d",fmt.byterate);            /* bytes per second */
		writefln("blocksize=%d",fmt.blocksize);           /* bytes per block */
		writefln("bitpersample=%d",fmt.bitpersample);        /* bits per sample */
		writefln("extensionsize=%d",fmt.extensionsize);       /* size of extension */
		writefln("datasize=%d",datasize);
	}
}

class SoundData {
  	WavHeader header;
  	uint size;                /* number of samples */
	float[][] data;

	this(uint rate, ushort ch, int bytepersample, ushort format=WavFormat.PCM) {
		header = new WavHeader();
		setProfile(rate, ch, bytepersample, format);
	}

	this(SoundData x) {
		header = new WavHeader();
		setProfile(x.header.fmt.samplerate,
		           x.channels,
				   x.header.fmt.blocksize/x.channels,
				   x.header.fmt.fmt_id);
		setData(x.data);
	}
	
	this(string filename,Endian endian=Endian.LITTLE) {
		auto f = new RawRW(filename,"rb",endian);
		header = new WavHeader(f);
		data = new float[][header.fmt.channels];

		/* set parameters */
		size = header.datasize/header.fmt.blocksize;
		int samplesize = header.fmt.blocksize/header.fmt.channels;
		for (int ch = 0; ch < header.fmt.channels; ch++) {
			data[ch] = new float[size];
		}

		switch (header.fmt.fmt_id) {
		case WavFormat.PCM:
			switch (samplesize) {
			case 1:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						data[ch][i] = cast(float)f.read!ubyte() / 255.0;
					}
				}
				break;
			case 2:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						data[ch][i] = cast(float)f.read!short() / 32768.0;
					}
				}
				break;
			case 4:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						data[ch][i] = cast(float)f.read!int() / 2147483648.0;
					}
				}
				break;
			default:
				throw new WavFormatUnsupportedException("WAV format error: PCM sample size = "~to!string(samplesize)~" byte");
			}
			break;
		case WavFormat.FLOAT:
			if (samplesize == 4) {
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						data[ch][i] = f.read!float();
					}
				}
			} else {
				throw new WavFormatUnsupportedException("WAV format error: Float sample size = "~to!string(samplesize)~" byte");
			}
			break;
		default:
				throw new WavFormatUnsupportedException("WAV format error: "~to!string(header.fmt.fmt_id)~" unsupported");
		}
		f.close();
	}	
	
	ushort channels() @property {
		return header.fmt.channels;
	}
	uint length() @property {
		return size;
	}

	private T clipping(T)(float x, uint limit) {
		double y = x*limit;
		double flimit = cast(double)limit;
		if (y > flimit) y = flimit;
		else if (y < -flimit-1) y = -flimit-1;
		//std.stdio.writefln("limit=%d x=%1.2f y=%1.2f",limit,x,y);
		return cast(T)y;
	}

	void write(string filename) {
		auto f = new RawRW(filename,"wb",Endian.LITTLE);
		header.write(f);
		int samplesize = header.fmt.blocksize/header.fmt.channels;

		switch (header.fmt.fmt_id) {
		case WavFormat.PCM:
			switch (samplesize) {
			case 1:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						f.write!ubyte(clipping!ubyte(data[ch][i],255));
					}
				}
				break;
			case 2:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						f.write!short(clipping!short(data[ch][i],32767));
					}
				}
				break;
			case 4:
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						f.write!int(clipping!int(data[ch][i],2147483647));
					}
				}
				break;
			default: // should not happen
				throw new WavFormatUnsupportedException("WAV format error: PCM sample size = "~to!string(samplesize)~" byte");
			}
			break;
		case WavFormat.FLOAT:
			if (samplesize == 4) {
				for (int i = 0; i < size; i++) {
					for (int ch = 0; ch < channels; ch++) {
						f.write!float(data[ch][i]);
					}
				}
			} else { // should not happen
				throw new WavFormatUnsupportedException("WAV format error: Float sample size = "~to!string(samplesize)~" byte");
			}
			break;
		default: // should not happen
				throw new WavFormatUnsupportedException("WAV format error: "~to!string(header.fmt.fmt_id)~" unsupported");
		}
		f.close();
		
	}
	
	void setProfile(uint rate, ushort ch, uint bytepersample, ushort format)
	{
		if (ch != 1 && ch != 2)
			throw new WavFormatUnsupportedException("Unsupported format: channel number should be 1 or 2");
		switch (format) {
		case WavFormat.PCM:
			if (bytepersample != 1 && bytepersample != 2 && bytepersample != 4)
				throw new WavFormatUnsupportedException("Unsupported format: PCM byte/sample should be 1,2 or 4");
			break;
		case WavFormat.FLOAT:
			if (bytepersample != 4)
				throw new WavFormatUnsupportedException("Unsupported format: IEEE float byte/sample should be 4");
			break;
		default:
			throw new WavFormatUnsupportedException();
		}
		header.fmt.fmt_id = format;
		header.fmt.channels = ch;
		header.fmt.samplerate = rate;
		header.fmt.byterate = rate*bytepersample;
		header.fmt.blocksize = cast(ushort)(ch*bytepersample);
		header.fmt.bitpersample = cast(ushort)(8*bytepersample);
		data = new float[][ch];
	}
	
	private void setLength(uint samples)
	{
		size = samples;
		header.datasize = samples*header.fmt.blocksize;
		header.size = header.datasize+36;
	}

	void setData(uint ch, float[] newdata) {
		assert(ch < channels);
		if (channels == 2) {
			uint otherch = ch==0?1:0;
			assert(data[otherch].length == 0 || data[otherch].length == newdata.length);
			data[ch] = newdata;
			if (data[otherch].length == 0)
				setLength(cast(uint)newdata.length);
		} else {
			data[ch] = newdata;
			setLength(cast(uint)newdata.length);
		}
	}
	void setData(float[][] newdata) {
		assert(newdata.length == channels);
		data = newdata;
		setLength(cast(uint)newdata[0].length);
	}
	void showSummary() {
		header.showSummary();
		writefln("size=%d",size);
	}
}

version(DEVELOP) {
	void test(ushort ch,ushort bytespersample, ushort format) {
		writefln("Testing: channels=%d byte/sample=%d format=%d",ch,bytespersample,format);
		auto x = new SoundData(44100,ch,bytespersample,format);
		float[] left = new float[44100];
		foreach (i; 0..44100) {
			auto t = cast(double)i/10;
			left[i] = sin(t);
		}
		x.setData(0,left);
		if (ch == 2) {
			float[] right = new float[44100];
			foreach (i; 0..44100) {
				auto t = cast(double)i/10;
				right[i] = cos(t);
			}
			x.setData(1,right);
		}
		//x.showSummary();
		auto filename = "tmp"~to!string(ch)~"_"~to!string(bytespersample)~"_"~to!string(format)~".wav";
		x.write(filename);

		auto y = new SoundData(filename);
		//y.showSummary();
		assert(x.size == y.size);
		assert(x.header.fmt.subchunksize == y.header.fmt.subchunksize);
  		assert(x.header.fmt.fmt_id == y.header.fmt.fmt_id);
  		assert(x.header.fmt.channels == y.header.fmt.channels);            /* number of channels */
  		assert(x.header.fmt.samplerate == y.header.fmt.samplerate);          /* sampling rate */
  		assert(x.header.fmt.byterate == y.header.fmt.byterate);            /* bytes per second */
  		assert(x.header.fmt.blocksize == y.header.fmt.blocksize);           /* bytes per block */
  		assert(x.header.fmt.bitpersample == y.header.fmt.bitpersample);        /* bits per sample */
  		assert(x.header.fmt.extensionsize == y.header.fmt.extensionsize);       /* size of extension */
		foreach (i; 0..x.length) {
			foreach (c; 0..ch) {
				//writefln("%f  %f",x.data[c][i],y.data[c][i]);
				assert(x.data[c][i] - y.data[c][i] < 1e-3);
			}
		}
	}

	void main() {
		test(1,2,WavFormat.PCM);
		test(2,2,WavFormat.PCM);
		test(1,4,WavFormat.PCM);
		test(2,4,WavFormat.PCM);
		test(1,4,WavFormat.FLOAT);
		test(2,4,WavFormat.FLOAT);
	}
}
