# WaveRW library

2021/10/2 Akinori Ito

# Introduction

This library is to read and write WAV format files using Dlang. Only the basic formats (8bit linear PCM, 16bit linear PCM, 32bit linear PCM, IEEE float) are supported.

# Usage

## Read file

This sample reads the data into the memory.
```{D}
SoundData x = new SoundData("filename.wav");
```

The waveform data are converted into float (from -1 to 1) automatically. The read data can be accessed as follows.
```{D}
for (int i = 0; i < x.length; i++) {
    for (int c = 0; c < x.channels; c++) {
        writef("%f ", x.data[c][i]);
    }
    writeln("");
}
```

The SoundData can be written to a file.
```{D}
x.write("anotherfile.wav");
```

We can also compose the data.
```{D}
uint sampling_rate = 44100;
ushort channels = 2;
ushort bytespersample = 2;
ushort format = WavFormat.PCM;

auto x = new SoundData(sampling_rate,channels,bytespersample,format);

uint sampleLength = 100000;

float[] left = new float[sampleLength];
float[] right = new float[sampleLength];
foreach (i; 0..sampleLength) {
	auto t = cast(double)i/10;
	left[i] = sin(t);
	right[i] = cos(t);
}
x.setData(0,left);
x.setData(1,right);
```

