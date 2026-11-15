# 舊影音工具已移除

新版直接使用 Windows Media Foundation，不需要此資料夾內的任何 EXE 或 DLL，也不會從 PATH 或其他目錄尋找 FFmpeg／FFplay。

第一次啟動會用 Windows 內建 .NET Framework 編譯器，把本專案的 `src/*.cs` 編譯到 `bin/UvcCapture.exe`。也可在專案根目錄執行：

```powershell
powershell -NoProfile -File .\build.ps1
```

條件見主 [README](../README.md)。歷史 FFmpeg 建置的來源與雜湊可於 Git 提交 `62bcf3b9cd9e60788a80fdccfdc604d50390cf1d` 查到；日常使用不需保留那兩個共約 435 MiB 的 EXE。