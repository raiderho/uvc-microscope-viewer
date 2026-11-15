using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace UvcViewer
{
    internal sealed class Options
    {
        internal string Mode, Device, Format, Output, Photos, Ready;
        internal int Number, Width, Height, Fps;
        internal static Options Parse(string[] args)
        {
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            var allowed = new HashSet<string>(new[] { "--mode", "--device", "--number", "--size", "--fps", "--format", "--output", "--photos", "--ready" });
            for (int i=0; i<args.Length; i+=2)
            {
                if (!allowed.Contains(args[i]) || i+1 >= args.Length || values.ContainsKey(args[i])) throw new ArgumentException("Invalid or duplicate command option.");
                values.Add(args[i], args[i+1]);
            }
            string mode;
            if (!values.TryGetValue("--mode", out mode)) throw new ArgumentException("--mode is required.");
            var o = new Options { Mode=mode };
            if (mode == "check" || mode == "selftest" || mode == "devices") return o;
            if (mode != "formats" && mode != "capture" && mode != "preview") throw new ArgumentException("Unsupported mode.");
            o.Device=values["--device"]; o.Number=int.Parse(values["--number"], CultureInfo.InvariantCulture);
            if (String.IsNullOrWhiteSpace(o.Device) || o.Number < 0 || o.Number > 99) throw new ArgumentException("Invalid camera selection.");
            if (mode == "formats") return o;
            string[] size=values["--size"].Split('x');
            if (size.Length != 2) throw new ArgumentException("Invalid frame size.");
            o.Width=int.Parse(size[0], CultureInfo.InvariantCulture); o.Height=int.Parse(size[1], CultureInfo.InvariantCulture);
            o.Fps=int.Parse(values["--fps"], CultureInfo.InvariantCulture); o.Format=values["--format"];
            FrameImage.RequiredBytes(o.Width, o.Height, checked(o.Width*4));
            if (o.Fps < 1 || o.Fps > 120 || (o.Format != "mjpeg" && o.Format != "yuyv422")) throw new ArgumentException("Unsupported capture mode.");
            if (mode == "capture") o.Output=Path.GetFullPath(values["--output"]);
            if (mode == "preview") { o.Photos=Path.GetFullPath(values["--photos"]); o.Ready=Path.GetFullPath(values["--ready"]); }
            return o;
        }
        internal CameraStream Open()
        {
            var camera = new CameraStream(CameraDevice.Find(Device, Number));
            try { camera.Configure(Format, Width, Height, Fps); return camera; }
            catch { camera.Dispose(); throw; }
        }
    }

    internal sealed class PreviewWindow : Form
    {
        private readonly Options options;
        private readonly PictureBox picture = new PictureBox();
        private readonly Label status = new Label();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        private readonly object gate = new object();
        private Bitmap pending;
        private string failure;
        private Thread worker;
        private volatile bool stopping;
        private bool warmed, readinessWritten;
        private readonly Stopwatch started = Stopwatch.StartNew();
        internal bool Failed { get; private set; }

        internal PreviewWindow(Options value)
        {
            options=value;
            Text=value.Device + " - UVC Microscope Viewer";
            ClientSize=new Size(960, 600); MinimumSize=new Size(480, 320);
            StartPosition=FormStartPosition.CenterScreen;
            Font=new Font("Microsoft JhengHei UI", 10);
            KeyPreview=true;
            var bar=new FlowLayoutPanel { Dock=DockStyle.Top, Height=44, Padding=new Padding(6) };
            var capture=new Button { Text="拍照（PNG）", AutoSize=true };
            capture.Click += delegate { SavePhoto(); };
            var photos=new Button { Text="查看照片", AutoSize=true };
            photos.Click += delegate {
                try {
                    Directory.CreateDirectory(options.Photos);
                    Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "explorer.exe"), Quote(options.Photos)) { UseShellExecute=false });
                } catch (Exception e) { status.Text=e.Message; }
            };
            bar.Controls.Add(capture); bar.Controls.Add(photos);
            status.Dock=DockStyle.Bottom; status.Height=42;
            status.Padding=new Padding(6); status.Text="正在開啟目鏡…";
            picture.Dock=DockStyle.Fill; picture.SizeMode=PictureBoxSizeMode.Zoom; picture.BackColor=Color.Black;
            Controls.Add(picture); Controls.Add(status); Controls.Add(bar);
            KeyDown += delegate(object sender, KeyEventArgs e) {
                if (e.KeyCode==Keys.Q || e.KeyCode==Keys.Escape) { e.SuppressKeyPress=true; Close(); }
                if (e.KeyCode==Keys.Space) { e.SuppressKeyPress=true; SavePhoto(); }
            };
            timer.Interval=33; timer.Tick += UpdateImage;
            Shown += delegate {
                worker=new Thread(ReadCamera) { IsBackground=true, Name="UVC video reader" };
                worker.SetApartmentState(ApartmentState.MTA); worker.Start(); timer.Start();
            };
            FormClosing += delegate { stopping=true; timer.Stop(); };
            FormClosed += delegate {
                if (worker != null) worker.Join(2000);
                lock (gate) { if (pending != null) pending.Dispose(); pending=null; }
                if (picture.Image != null) picture.Image.Dispose();
                timer.Dispose();
            };
        }

        private static string Quote(string path) { return "\"" + path + (path.EndsWith("\\", StringComparison.Ordinal) ? "\\" : "") + "\""; }

        private void ReadCamera()
        {
            bool initialized=false;
            try
            {
                Native.Check(Native.MFStartup(0x00020070, 0), "Start Windows camera platform"); initialized=true;
                using (var camera=options.Open())
                {
                    while (!stopping)
                    {
                        Bitmap next=camera.ReadFrame();
                        if (next == null) continue;
                        lock (gate)
                        {
                            if (stopping) { next.Dispose(); break; }
                            if (pending != null) pending.Dispose();
                            pending=next;
                        }
                    }
                }
            }
            catch (Exception e) { if (!stopping) { lock (gate) { failure=e.Message; } } }
            finally { if (initialized) Native.MFShutdown(); }
        }

        private void UpdateImage(object sender, EventArgs args)
        {
            Bitmap next;
            string error;
            lock (gate) { next=pending; pending=null; error=failure; }
            if (error != null)
            {
                if (next != null) next.Dispose();
                Failed=true; timer.Stop(); status.Text="目鏡已停止：" + error;
                Console.Error.WriteLine(error);
                if (!readinessWritten) Close();
                return;
            }
            if (next == null) return;
            Image previous=picture.Image;
            picture.Image=next;
            if (previous != null) previous.Dispose();
            if (!warmed && started.ElapsedMilliseconds >= 1000)
            {
                warmed=true;
                status.Text=options.Width + "×" + options.Height + " ／ 按「拍照」或空白鍵儲存 PNG；Q 關閉。";
            }
            if (!readinessWritten)
            {
                // The launcher sees readiness only after an actual frame reaches the preview control.
                string temporary=options.Ready+".tmp";
                File.WriteAllText(temporary, "Windows Media Foundation\n" + options.Width + "x" + options.Height + "\n");
                File.Move(temporary, options.Ready);
                readinessWritten=true;
            }
        }

        private void SavePhoto()
        {
            if (!warmed || picture.Image == null || Failed) { status.Text="尚未收到穩定影像，請稍候。"; return; }
            try
            {
                string path=FrameImage.NewPath(options.Photos);
                using (var bitmap=new Bitmap(picture.Image)) FrameImage.SaveNew(bitmap, path);
                status.Text="已儲存：" + path;
                Console.WriteLine("PHOTO " + path);
            }
            catch (Exception e) { status.Text="拍照失敗：" + e.Message; }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                Console.SetOut(new StreamWriter(Console.OpenStandardOutput(), new System.Text.UTF8Encoding(false)) { AutoFlush=true });
                Console.SetError(new StreamWriter(Console.OpenStandardError(), new System.Text.UTF8Encoding(false)) { AutoFlush=true });
                Options options=Options.Parse(args);
                if (options.Mode == "selftest") { FrameImage.SelfTest(); return 0; }
                if (options.Mode == "preview")
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    using (var window=new PreviewWindow(options))
                    { Application.Run(window); return window.Failed ? 1 : 0; }
                }
                RunMta(delegate {
                    switch (options.Mode)
                    {
                        case "check": Console.WriteLine("Windows Media Foundation ready; no FFmpeg, FFplay, network or microphone input."); break;
                        case "devices":
                            foreach (var device in CameraDevice.List()) Console.WriteLine(device.Number + "\t" + device.Name);
                            break;
                        case "formats":
                            using (var camera=new CameraStream(CameraDevice.Find(options.Device, options.Number)))
                                foreach (var mode in camera.Modes()) Console.WriteLine(mode);
                            break;
                        case "capture":
                            using (var camera=options.Open())
                            {
                                var elapsed=Stopwatch.StartNew();
                                while (elapsed.ElapsedMilliseconds < 15000)
                                {
                                    using (var frame=camera.ReadFrame())
                                    {
                                        if (frame == null || elapsed.ElapsedMilliseconds < 1000) continue;
                                        FrameImage.SaveNew(frame, options.Output);
                                        Console.WriteLine(options.Output); return;
                                    }
                                }
                                throw new TimeoutException("No usable camera frame within 15 seconds.");
                            }
                    }
                }, 20000);
                return 0;
            }
            catch (Exception e) { Console.Error.WriteLine(e.Message); return 1; }
        }

        private static void RunMta(Action action, int timeout)
        {
            Exception failure=null;
            var thread=new Thread(delegate() {
                bool initialized=false;
                try { Native.Check(Native.MFStartup(0x00020070, 0), "Start Windows camera platform"); initialized=true; action(); }
                catch (Exception e) { failure=e; }
                finally { if (initialized) Native.MFShutdown(); }
            }) { IsBackground=true };
            thread.SetApartmentState(ApartmentState.MTA); thread.Start();
            if (!thread.Join(timeout)) throw new TimeoutException("Camera operation timed out. Check connection and whether another app is using the device.");
            if (failure != null) throw failure;
        }
    }
}
