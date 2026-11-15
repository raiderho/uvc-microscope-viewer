// Windows SDK ABI declarations; no third-party assemblies or codecs.
// References: Microsoft Learn, IMFAttributes / IMFMediaType / IMFSample / IMFSourceReader.
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace UvcViewer
{
    [ComImport, Guid("2CD2D921-C447-44A7-A13C-4ADABFC247E3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFAttributes
    {
        [PreserveSig] int GetItem(ref Guid key, IntPtr value);
        [PreserveSig] int GetItemType(ref Guid key, out int type);
        [PreserveSig] int CompareItem(ref Guid key, IntPtr value, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int Compare(IMFAttributes other, int match, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int GetUINT32(ref Guid key, out uint value);
        [PreserveSig] int GetUINT64(ref Guid key, out ulong value);
        [PreserveSig] int GetDouble(ref Guid key, out double value);
        [PreserveSig] int GetGUID(ref Guid key, out Guid value);
        [PreserveSig] int GetStringLength(ref Guid key, out uint length);
        [PreserveSig] int GetString(ref Guid key, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, uint size, out uint length);
        [PreserveSig] int GetAllocatedString(ref Guid key, out IntPtr value, out uint length);
        [PreserveSig] int GetBlobSize(ref Guid key, out uint size);
        [PreserveSig] int GetBlob(ref Guid key, IntPtr buffer, uint size, out uint written);
        [PreserveSig] int GetAllocatedBlob(ref Guid key, out IntPtr buffer, out uint size);
        [PreserveSig] int GetUnknown(ref Guid key, ref Guid iid, out IntPtr value);
        [PreserveSig] int SetItem(ref Guid key, IntPtr value);
        [PreserveSig] int DeleteItem(ref Guid key);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid key, uint value);
        [PreserveSig] int SetUINT64(ref Guid key, ulong value);
        [PreserveSig] int SetDouble(ref Guid key, double value);
        [PreserveSig] int SetGUID(ref Guid key, ref Guid value);
        [PreserveSig] int SetString(ref Guid key, [MarshalAs(UnmanagedType.LPWStr)] string value);
        [PreserveSig] int SetBlob(ref Guid key, IntPtr buffer, uint size);
        [PreserveSig] int SetUnknown(ref Guid key, [MarshalAs(UnmanagedType.IUnknown)] object value);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetItemByIndex(uint index, out Guid key, IntPtr value);
        [PreserveSig] int CopyAllItems(IMFAttributes destination);
    }

    // Repeat inherited slots explicitly: COM interface inheritance is not C# inheritance.
    [ComImport, Guid("44AE0FA8-EA31-4109-8D2E-4CAE4997C555"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFMediaType
    {
        [PreserveSig] int GetItem(ref Guid key, IntPtr value);
        [PreserveSig] int GetItemType(ref Guid key, out int type);
        [PreserveSig] int CompareItem(ref Guid key, IntPtr value, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int Compare(IMFAttributes other, int match, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int GetUINT32(ref Guid key, out uint value);
        [PreserveSig] int GetUINT64(ref Guid key, out ulong value);
        [PreserveSig] int GetDouble(ref Guid key, out double value);
        [PreserveSig] int GetGUID(ref Guid key, out Guid value);
        [PreserveSig] int GetStringLength(ref Guid key, out uint length);
        [PreserveSig] int GetString(ref Guid key, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, uint size, out uint length);
        [PreserveSig] int GetAllocatedString(ref Guid key, out IntPtr value, out uint length);
        [PreserveSig] int GetBlobSize(ref Guid key, out uint size);
        [PreserveSig] int GetBlob(ref Guid key, IntPtr buffer, uint size, out uint written);
        [PreserveSig] int GetAllocatedBlob(ref Guid key, out IntPtr buffer, out uint size);
        [PreserveSig] int GetUnknown(ref Guid key, ref Guid iid, out IntPtr value);
        [PreserveSig] int SetItem(ref Guid key, IntPtr value);
        [PreserveSig] int DeleteItem(ref Guid key);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid key, uint value);
        [PreserveSig] int SetUINT64(ref Guid key, ulong value);
        [PreserveSig] int SetDouble(ref Guid key, double value);
        [PreserveSig] int SetGUID(ref Guid key, ref Guid value);
        [PreserveSig] int SetString(ref Guid key, [MarshalAs(UnmanagedType.LPWStr)] string value);
        [PreserveSig] int SetBlob(ref Guid key, IntPtr buffer, uint size);
        [PreserveSig] int SetUnknown(ref Guid key, [MarshalAs(UnmanagedType.IUnknown)] object value);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetItemByIndex(uint index, out Guid key, IntPtr value);
        [PreserveSig] int CopyAllItems(IMFAttributes destination);

        [PreserveSig] int GetMajorType(out Guid type);
        [PreserveSig] int IsCompressedFormat([MarshalAs(UnmanagedType.Bool)] out bool compressed);
        [PreserveSig] int IsEqual(IMFMediaType other, out uint flags);
        [PreserveSig] int GetRepresentation(Guid representation, out IntPtr value);
        [PreserveSig] int FreeRepresentation(Guid representation, IntPtr value);
    }

    [ComImport, Guid("C40A00F2-B93A-4D80-AE8C-5A1C634F58E4"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFSample
    {
        [PreserveSig] int GetItem(ref Guid key, IntPtr value);
        [PreserveSig] int GetItemType(ref Guid key, out int type);
        [PreserveSig] int CompareItem(ref Guid key, IntPtr value, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int Compare(IMFAttributes other, int match, [MarshalAs(UnmanagedType.Bool)] out bool result);
        [PreserveSig] int GetUINT32(ref Guid key, out uint value);
        [PreserveSig] int GetUINT64(ref Guid key, out ulong value);
        [PreserveSig] int GetDouble(ref Guid key, out double value);
        [PreserveSig] int GetGUID(ref Guid key, out Guid value);
        [PreserveSig] int GetStringLength(ref Guid key, out uint length);
        [PreserveSig] int GetString(ref Guid key, [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, uint size, out uint length);
        [PreserveSig] int GetAllocatedString(ref Guid key, out IntPtr value, out uint length);
        [PreserveSig] int GetBlobSize(ref Guid key, out uint size);
        [PreserveSig] int GetBlob(ref Guid key, IntPtr buffer, uint size, out uint written);
        [PreserveSig] int GetAllocatedBlob(ref Guid key, out IntPtr buffer, out uint size);
        [PreserveSig] int GetUnknown(ref Guid key, ref Guid iid, out IntPtr value);
        [PreserveSig] int SetItem(ref Guid key, IntPtr value);
        [PreserveSig] int DeleteItem(ref Guid key);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid key, uint value);
        [PreserveSig] int SetUINT64(ref Guid key, ulong value);
        [PreserveSig] int SetDouble(ref Guid key, double value);
        [PreserveSig] int SetGUID(ref Guid key, ref Guid value);
        [PreserveSig] int SetString(ref Guid key, [MarshalAs(UnmanagedType.LPWStr)] string value);
        [PreserveSig] int SetBlob(ref Guid key, IntPtr buffer, uint size);
        [PreserveSig] int SetUnknown(ref Guid key, [MarshalAs(UnmanagedType.IUnknown)] object value);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetItemByIndex(uint index, out Guid key, IntPtr value);
        [PreserveSig] int CopyAllItems(IMFAttributes destination);

        [PreserveSig] int GetSampleFlags(out uint flags);
        [PreserveSig] int SetSampleFlags(uint flags);
        [PreserveSig] int GetSampleTime(out long time);
        [PreserveSig] int SetSampleTime(long time);
        [PreserveSig] int GetSampleDuration(out long duration);
        [PreserveSig] int SetSampleDuration(long duration);
        [PreserveSig] int GetBufferCount(out uint count);
        [PreserveSig] int GetBufferByIndex(uint index, out IMFMediaBuffer buffer);
        [PreserveSig] int ConvertToContiguousBuffer(out IMFMediaBuffer buffer);
        [PreserveSig] int AddBuffer(IMFMediaBuffer buffer);
        [PreserveSig] int RemoveBufferByIndex(uint index);
        [PreserveSig] int RemoveAllBuffers();
        [PreserveSig] int GetTotalLength(out uint length);
        [PreserveSig] int CopyToBuffer(IMFMediaBuffer buffer);
    }

    [ComImport, Guid("045FA593-8799-42B8-BC8D-8968C6453507"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFMediaBuffer
    {
        [PreserveSig] int Lock(out IntPtr data, out uint maxLength, out uint currentLength);
        [PreserveSig] int Unlock();
        [PreserveSig] int GetCurrentLength(out uint length);
        [PreserveSig] int SetCurrentLength(uint length);
        [PreserveSig] int GetMaxLength(out uint length);
    }

    [ComImport, Guid("279A808D-AEC7-40C8-9C6B-A6B492C78A66"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFMediaSource
    {
        [PreserveSig] int GetEvent(uint flags, out IntPtr value);
        [PreserveSig] int BeginGetEvent(IntPtr callback, IntPtr state);
        [PreserveSig] int EndGetEvent(IntPtr result, out IntPtr value);
        [PreserveSig] int QueueEvent(int type, ref Guid extendedType, int status, IntPtr value);
        [PreserveSig] int GetCharacteristics(out uint flags);
        [PreserveSig] int CreatePresentationDescriptor(out IntPtr descriptor);
        [PreserveSig] int Start(IntPtr descriptor, ref Guid format, IntPtr position);
        [PreserveSig] int Stop();
        [PreserveSig] int Pause();
        [PreserveSig] int Shutdown();
    }

    [ComImport, Guid("70AE66F2-C809-4E4F-8915-BDCB406B7993"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFSourceReader
    {
        [PreserveSig] int GetStreamSelection(uint stream, [MarshalAs(UnmanagedType.Bool)] out bool selected);
        [PreserveSig] int SetStreamSelection(uint stream, [MarshalAs(UnmanagedType.Bool)] bool selected);
        [PreserveSig] int GetNativeMediaType(uint stream, uint index, out IMFMediaType type);
        [PreserveSig] int GetCurrentMediaType(uint stream, out IMFMediaType type);
        [PreserveSig] int SetCurrentMediaType(uint stream, IntPtr reserved, IMFMediaType type);
        [PreserveSig] int SetCurrentPosition(ref Guid format, IntPtr position);
        [PreserveSig] int ReadSample(uint stream, uint controlFlags, out uint actualStream, out uint flags, out long time, out IMFSample sample);
        [PreserveSig] int Flush(uint stream);
        [PreserveSig] int GetServiceForStream(uint stream, ref Guid service, ref Guid iid, out IntPtr value);
        [PreserveSig] int GetPresentationAttribute(uint stream, ref Guid key, IntPtr value);
    }

    internal static class Native
    {
        internal const uint Video = 0xFFFFFFFC, AllStreams = 0xFFFFFFFE;
        internal const int NoMoreTypes = unchecked((int)0xC00D36B9);
        internal static Guid SourceType = new Guid("C60AC5FE-252A-478F-A0EF-BC8FA5F7CAD3");
        internal static Guid VideoCapture = new Guid("8AC3587A-4AE7-42D8-99E0-0A6013EEF90F");
        internal static Guid FriendlyName = new Guid("60D0E559-52F8-4FA2-BBCE-ACDB34A8EC01");
        internal static Guid SymbolicLink = new Guid("58F0AAD8-22BF-4F8A-BB3D-D2C4978C6E2F");
        internal static Guid Processing = new Guid("0F81DA2C-B537-4672-A8B2-A681B17307A3"); // MF_SOURCE_READER_ENABLE_ADVANCED_VIDEO_PROCESSING
        internal static Guid MajorType = new Guid("48EBA18E-F8C9-4687-BF11-0A74C9F96A8F");
        internal static Guid Subtype = new Guid("F7E34C9A-42E8-4714-B74B-CB29D72C35E5");
        internal static Guid VideoType = new Guid("73646976-0000-0010-8000-00AA00389B71");
        internal static Guid Rgb32 = new Guid("00000016-0000-0010-8000-00AA00389B71");
        internal static Guid Mjpeg = new Guid("47504A4D-0000-0010-8000-00AA00389B71");
        internal static Guid Yuy2 = new Guid("32595559-0000-0010-8000-00AA00389B71");
        internal static Guid FrameSize = new Guid("1652C33D-D6B2-4012-B834-72030849A37D");
        internal static Guid FrameRate = new Guid("C459A2E8-3D2C-4E44-B132-FEE5156C7BB0");
        internal static Guid DefaultStride = new Guid("644B4E48-1E02-4516-B0EB-C01CA9D49AC6");

        // System32-only loading avoids resolving native DLLs beside the portable app.
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mfplat.dll", ExactSpelling=true)] internal static extern int MFStartup(uint version, uint flags);
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mfplat.dll", ExactSpelling=true)] internal static extern int MFShutdown();
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mfplat.dll", ExactSpelling=true)] internal static extern int MFCreateAttributes(out IMFAttributes attributes, uint initialSize);
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mfplat.dll", ExactSpelling=true)] internal static extern int MFCreateMediaType(out IMFMediaType type);
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mf.dll", ExactSpelling=true)] internal static extern int MFEnumDeviceSources(IMFAttributes attributes, out IntPtr devices, out uint count);
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mf.dll", ExactSpelling=true)] internal static extern int MFCreateDeviceSource(IMFAttributes attributes, out IMFMediaSource source);
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("mfreadwrite.dll", ExactSpelling=true)] internal static extern int MFCreateSourceReaderFromMediaSource(IMFMediaSource source, IMFAttributes attributes, out IMFSourceReader reader);

        internal static void Check(int hr, string operation)
        {
            if (hr < 0) throw new InvalidOperationException(operation + ": 0x" + hr.ToString("X8") + " " + Marshal.GetExceptionForHR(hr).Message);
        }
        internal static void Release(object value) { if (value != null && Marshal.IsComObject(value)) Marshal.ReleaseComObject(value); }
        internal static string StringValue(IMFAttributes attributes, ref Guid key)
        {
            IntPtr pointer = IntPtr.Zero; uint length;
            try { Check(attributes.GetAllocatedString(ref key, out pointer, out length), "Read device name"); return Marshal.PtrToStringUni(pointer, checked((int)length)); }
            finally { if (pointer != IntPtr.Zero) Marshal.FreeCoTaskMem(pointer); }
        }
    }
}
