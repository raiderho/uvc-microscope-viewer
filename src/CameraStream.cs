using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;

namespace UvcViewer
{
    internal sealed class CameraDevice
    {
        internal string Name, Link;
        internal int Number;
        internal static List<CameraDevice> List()
        {
            IMFAttributes attributes = null;
            IntPtr array = IntPtr.Zero;
            uint count = 0;
            var devices = new List<CameraDevice>();
            var numbers = new Dictionary<string, int>(StringComparer.Ordinal);
            try
            {
                Native.Check(Native.MFCreateAttributes(out attributes, 1), "Create device attributes");
                Native.Check(attributes.SetGUID(ref Native.SourceType, ref Native.VideoCapture), "Select video devices");
                Native.Check(Native.MFEnumDeviceSources(attributes, out array, out count), "Enumerate cameras");
                if (count > 1024) throw new InvalidOperationException("Unexpected device count.");
                for (uint i = 0; i < count; i++)
                {
                    object activation = Marshal.GetObjectForIUnknown(Marshal.ReadIntPtr(array, checked((int)i * IntPtr.Size)));
                    try
                    {
                        var item = (IMFAttributes)activation;
                        string name = Native.StringValue(item, ref Native.FriendlyName);
                        int number;
                        if (!numbers.TryGetValue(name, out number)) number = 0;
                        devices.Add(new CameraDevice { Name = name, Number = number, Link = Native.StringValue(item, ref Native.SymbolicLink) });
                        numbers[name] = number + 1;
                    }
                    finally { Native.Release(activation); }
                }
                return devices;
            }
            finally
            {
                if (array != IntPtr.Zero)
                {
                    for (uint i = 0; i < count; i++) Marshal.Release(Marshal.ReadIntPtr(array, checked((int)i * IntPtr.Size)));
                    Marshal.FreeCoTaskMem(array);
                }
                Native.Release(attributes);
            }
        }

        internal static CameraDevice Find(string name, int number)
        {
            foreach (CameraDevice device in List())
                if (device.Name == name && device.Number == number) return device;
            throw new InvalidOperationException("Camera not found: " + name + " [" + number + "]. Use ListDevices.");
        }
    }

    internal sealed class VideoMode
    {
        internal int Width, Height;
        internal double Fps;
        internal Guid Subtype;
        internal string Format { get { return Subtype == Native.Mjpeg ? "mjpeg" : Subtype == Native.Yuy2 ? "yuyv422" : Subtype.ToString(); } }
        internal static VideoMode Read(IMFMediaType type)
        {
            ulong size, rate; Guid subtype;
            Native.Check(type.GetUINT64(ref Native.FrameSize, out size), "Read frame size");
            Native.Check(type.GetUINT64(ref Native.FrameRate, out rate), "Read frame rate");
            Native.Check(type.GetGUID(ref Native.Subtype, out subtype), "Read format");
            uint denominator = (uint)(rate & 0xFFFFFFFF);
            if (denominator == 0) throw new InvalidOperationException("Invalid camera frame rate.");
            return new VideoMode { Width = checked((int)(size >> 32)), Height = checked((int)(size & 0xFFFFFFFF)), Fps = (double)(rate >> 32) / denominator, Subtype = subtype };
        }
        public override string ToString()
        {
            return Format + " " + Width + "x" + Height + " " + Fps.ToString("0.###", CultureInfo.InvariantCulture) + " fps";
        }
    }

    internal sealed class CameraStream : IDisposable
    {
        private IMFMediaSource source;
        private IMFSourceReader reader;
        private byte[] frameBytes;
        internal VideoMode Mode { get; private set; }
        internal int Stride { get; private set; }

        internal CameraStream(CameraDevice device)
        {
            IMFAttributes attributes = null, readerAttributes = null;
            try
            {
                Native.Check(Native.MFCreateAttributes(out attributes, 2), "Create capture attributes");
                Native.Check(attributes.SetGUID(ref Native.SourceType, ref Native.VideoCapture), "Select video only");
                Native.Check(attributes.SetString(ref Native.SymbolicLink, device.Link), "Select camera");
                Native.Check(Native.MFCreateDeviceSource(attributes, out source), "Open camera");
                Native.Check(Native.MFCreateAttributes(out readerAttributes, 1), "Create reader attributes");
                Native.Check(readerAttributes.SetUINT32(ref Native.Processing, 1), "Enable Windows RGB conversion");
                Native.Check(Native.MFCreateSourceReaderFromMediaSource(source, readerAttributes, out reader), "Create camera reader");
                Native.Check(reader.SetStreamSelection(Native.AllStreams, false), "Disable all streams");
                Native.Check(reader.SetStreamSelection(Native.Video, true), "Enable video stream");
            }
            catch { Dispose(); throw; }
            finally { Native.Release(attributes); Native.Release(readerAttributes); }
        }

        internal List<VideoMode> Modes()
        {
            var result = new List<VideoMode>();
            for (uint i = 0; i < 4096; i++)
            {
                IMFMediaType type;
                int hr = reader.GetNativeMediaType(Native.Video, i, out type);
                if (hr == Native.NoMoreTypes) break;
                Native.Check(hr, "List camera formats");
                try { result.Add(VideoMode.Read(type)); }
                finally { Native.Release(type); }
            }
            return result;
        }

        internal void Configure(string format, int width, int height, int fps)
        {
            Guid subtype = format == "mjpeg" ? Native.Mjpeg : Native.Yuy2;
            bool found = false;
            for (uint i = 0; i < 4096; i++)
            {
                IMFMediaType type;
                int hr = reader.GetNativeMediaType(Native.Video, i, out type);
                if (hr == Native.NoMoreTypes) break;
                Native.Check(hr, "Find camera format");
                try
                {
                    var candidate = VideoMode.Read(type);
                    if (candidate.Subtype == subtype && candidate.Width == width && candidate.Height == height && Math.Abs(candidate.Fps - fps) < 0.1)
                    {
                        Native.Check(reader.SetCurrentMediaType(Native.Video, IntPtr.Zero, type), "Set camera format");
                        found = true; break;
                    }
                }
                finally { Native.Release(type); }
            }
            if (!found) throw new InvalidOperationException("Camera does not advertise " + format + " " + width + "x" + height + " " + fps + " fps. Use ListFormats.");
            IMFMediaType output = null, actual = null;
            try
            {
                Native.Check(Native.MFCreateMediaType(out output), "Create RGB output");
                Native.Check(output.SetGUID(ref Native.MajorType, ref Native.VideoType), "Set video output");
                Native.Check(output.SetGUID(ref Native.Subtype, ref Native.Rgb32), "Set RGB32 output");
                Native.Check(reader.SetCurrentMediaType(Native.Video, IntPtr.Zero, output), "Use Windows video decoder");
                Native.Check(reader.GetCurrentMediaType(Native.Video, out actual), "Read negotiated output");
                Mode = VideoMode.Read(actual);
                if (Mode.Width != width || Mode.Height != height || Mode.Subtype != Native.Rgb32 || Math.Abs(Mode.Fps - fps) >= 0.1)
                    throw new InvalidOperationException("Windows negotiated a different capture mode.");
                uint stride;
                Stride = actual.GetUINT32(ref Native.DefaultStride, out stride) >= 0 ? unchecked((int)stride) : -checked(width * 4);
                int length = FrameImage.RequiredBytes(width, height, Stride);
                frameBytes = new byte[length];
                Console.WriteLine("Camera: " + format + " " + width + "x" + height + " " + Mode.Fps.ToString("0.###", CultureInfo.InvariantCulture) + " fps; RGB stride " + Stride);
            }
            finally { Native.Release(output); Native.Release(actual); }
        }

        internal Bitmap ReadFrame()
        {
            uint stream, flags; long timestamp;
            IMFSample sample = null;
            IMFMediaBuffer buffer = null;
            bool locked = false;
            try
            {
                Native.Check(reader.ReadSample(Native.Video, 0, out stream, out flags, out timestamp, out sample), "Read camera frame");
                if ((flags & 3) != 0) throw new InvalidOperationException("Camera stream ended or reported an error.");
                if ((flags & 0x20) != 0) throw new InvalidOperationException("Camera output changed; reopen the preview.");
                if (sample == null) return null;
                Native.Check(sample.ConvertToContiguousBuffer(out buffer), "Read image buffer");
                IntPtr pointer; uint maximum, length;
                Native.Check(buffer.Lock(out pointer, out maximum, out length), "Lock image buffer");
                locked = true;
                if (pointer == IntPtr.Zero || length < frameBytes.Length || length > maximum)
                    throw new InvalidOperationException("Unexpected camera image buffer size.");
                Marshal.Copy(pointer, frameBytes, 0, frameBytes.Length);
                return FrameImage.FromBgr32(frameBytes, Mode.Width, Mode.Height, Stride);
            }
            finally
            {
                if (locked) buffer.Unlock();
                Native.Release(buffer); Native.Release(sample);
            }
        }

        public void Dispose()
        {
            // Called on the capture thread after ReadSample has returned.
            if (source != null) source.Shutdown();
            Native.Release(reader); reader = null;
            Native.Release(source); source = null;
        }
    }

    internal static class FrameImage
    {
        internal static int RequiredBytes(int width, int height, int stride)
        {
            long row = Math.Abs((long)stride), bytes = row * height;
            if (width <= 0 || height <= 0 || width > 8192 || height > 8192 || row < (long)width * 4 || bytes > 64 * 1024 * 1024)
                throw new InvalidOperationException("Unsupported image dimensions or stride.");
            return checked((int)bytes);
        }

        internal static Bitmap FromBgr32(byte[] bytes, int width, int height, int stride)
        {
            int length = RequiredBytes(width, height, stride);
            if (bytes.Length < length) throw new InvalidOperationException("Truncated image data.");
            var bitmap = new Bitmap(width, height, PixelFormat.Format32bppRgb);
            BitmapData data = null;
            try
            {
                data = bitmap.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
                int rowLength = checked(width * 4), pitch = Math.Abs(stride);
                for (int y = 0; y < height; y++)
                {
                    int sourceRow = stride < 0 ? height - 1 - y : y;
                    Marshal.Copy(bytes, checked(sourceRow * pitch), IntPtr.Add(data.Scan0, checked(y * data.Stride)), rowLength);
                }
                bitmap.UnlockBits(data); data = null;
                return bitmap;
            }
            catch { if (data != null) bitmap.UnlockBits(data); bitmap.Dispose(); throw; }
        }

        internal static void SaveNew(Bitmap bitmap, string path)
        {
            bool created = false;
            try
            {
                using (var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    created = true;
                    bitmap.Save(file, ImageFormat.Png);
                }
            }
            catch
            {
                // Only remove a partial file created by this call; never overwrite or delete an existing photo.
                if (created) { try { File.Delete(path); } catch { } }
                throw;
            }
        }

        internal static string NewPath(string folder)
        {
            Directory.CreateDirectory(folder);
            return Path.Combine(folder, "photo-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture) + "-" + Guid.NewGuid().ToString("N").Substring(0, 6) + ".png");
        }

        internal static void SelfTest()
        {
            // Distinct rows detect upside-down images; padding detects incorrect row copies.
            byte[] top = { 0,0,255,0, 0,255,0,0, 17,17,17,17, 255,0,0,0, 255,255,255,0, 18,18,18,18 };
            byte[] bottom = { 255,0,0,0, 255,255,255,0, 18,18,18,18, 0,0,255,0, 0,255,0,0, 17,17,17,17 };
            using (var a = FromBgr32(top, 2, 2, 12))
            using (var b = FromBgr32(bottom, 2, 2, -12))
            {
                if (a.GetPixel(0, 0).ToArgb() != Color.Red.ToArgb() || a.GetPixel(0, 1).ToArgb() != Color.Blue.ToArgb())
                    throw new Exception("RGB row or channel conversion failed.");
                for (int y=0; y<2; y++) for (int x=0; x<2; x++)
                    if (a.GetPixel(x,y) != b.GetPixel(x,y)) throw new Exception("Negative stride conversion failed.");
                using (var stream = new MemoryStream())
                {
                    a.Save(stream, ImageFormat.Png); stream.Position = 0;
                    using (var png = new Bitmap(stream))
                        if (png.Width != 2 || png.Height != 2 || png.GetPixel(0,0) != a.GetPixel(0,0)) throw new Exception("PNG round trip failed.");
                }
            }
            bool rejected = false;
            try { FromBgr32(new byte[1], 2, 2, 8); } catch (InvalidOperationException) { rejected = true; }
            if (!rejected) throw new Exception("Truncated data was accepted.");
            rejected = false;
            try { RequiredBytes(8192, 8192, 32768); } catch (InvalidOperationException) { rejected = true; }
            if (!rejected) throw new Exception("Oversized data was accepted.");
            Console.WriteLine("PASS: RGB channels, top/bottom row orientation, padding, PNG round trip, truncated/oversized buffers.");
        }
    }
}
