# UVC Microscope Viewer

Windows 上用來**看 USB 電子目鏡畫面、拍 PNG、設定照片存放位置**的小型可攜工具。

輕量版直接使用 **Windows Media Foundation** 讀取相機，使用 Windows／.NET 的影像功能顯示及存檔。**不再需要 FFmpeg、FFplay、原廠 StrangeView 或額外影音套件**。自己的相機執行檔約 30 KiB，原始碼在本倉庫；不是把大型依賴搬到別處或改成線上下載。

名稱採通用 UVC；`TN2.0M-D` 是預設及已實測型號，其他型號可以改設定。**UVC 是 USB 影像標準；只有 UAC 音訊功能的裝置不能提供目鏡畫面。**

## 快速開始

1. 將本倉庫 ZIP 解壓縮到可寫入的資料夾。
2. 將電子目鏡接到 USB，關閉其他占用同一台相機的程式。
3. 雙擊 **`01_開啟電子目鏡.cmd`**。
4. 在影像視窗按 **「拍照（PNG）」** 或**空白鍵**拍照；按 **「查看照片」** 打開儲存資料夾。
5. 按 **Q／Esc** 或關閉影像視窗，停止預覽。

第一次啟動會用 Windows 內建 .NET Framework 編譯器，在本資料夾產生 `bin/UvcCapture.exe`，通常只需數秒，**不連網、不下載、不需管理員權限**。之後直接使用；原始碼更新後會重新編譯。請使用 CMD 入口，不要直接雙擊內部的 EXE。

| 入口 | 功能 |
| --- | --- |
| `00_UVC_Microscope_Viewer.cmd` | 控制面板 |
| `01_開啟電子目鏡.cmd` | 即時預覽，視窗內可直接拍照 |
| `02_拍照.cmd` | 拍一張 PNG；若已有預覽，短暫停止並恢復 |
| `03_查看照片.cmd` | 開啟目前的照片資料夾 |
| `04_設定.cmd` | 設定裝置、影像模式與照片位置 |
| `05_停止預覽.cmd` | 關閉本工具自己的預覽 |

影像視窗內拍照不需停止預覽。控制面板或 `02_拍照.cmd` 使用獨立擷取流程，會暫停並恢復預覽。只關閉控制面板會保留影像視窗。

## 照片位置與設定

預設存到程式資料夾下的 **`photos`**。「查看照片」開啟資料夾後，雙擊 PNG 即可用 Windows 圖片程式觀看。

雙擊 `04_設定.cmd`，在「照片儲存位置」輸入路徑或選擇資料夾，再儲存。更改設定會關閉預覽，重新開啟即可使用。位置變更只影響之後的照片，舊照片不搬移、不刪除。

| 設定 | 意義 |
| --- | --- |
| `photos` | 預設，跟著整個程式資料夾搬移 |
| `captures/sample-a` | 自訂相對資料夾，同樣可以攜帶 |
| `E:\MicroscopePhotos` | 指定本機磁碟；換電腦需確認位置仍可使用 |

不接受網址或 UNC 分享路徑；相對路徑不能用 `..` 逃出程式資料夾，也不能選程式保留目錄。雲端同步或映射磁碟的行為由作業系統管理。

個人設定在 `settings.json`，缺少時讀取 `settings.example.json`：

```json
{
  "schemaVersion": 1,
  "deviceName": "TN2.0M-D",
  "deviceNumber": 0,
  "resolution": "1920x1080",
  "fps": 30,
  "inputFormat": "mjpeg",
  "photoDirectory": "photos"
}
```

照片以時間加隨機尾碼命名，不覆寫舊檔。個人設定、照片與執行記錄都不提交到 Git。

## 適用條件與功能範圍

- **Windows 10／11 x64**，具 Media Foundation、Windows PowerShell 5.1、.NET Framework 4.x／Windows Forms。實測 Windows 11 x64；缺媒體元件的 Windows N 或精簡系統不保證可用。
- Windows 允許桌面程式使用相機，程式與照片資料夾可寫入，政策允許已審查的本機腳本。
- 電子目鏡以標準 UVC 驅動工作，且本工具的 `ListDevices` 能列出它。
- 支援 **MJPEG（`mjpeg`）或 YUY2（`yuyv422`）**，所選解析度與 fps 組合在 `ListFormats` 清單內。
- USB 線、轉接器、頻寬與供電足夠，相機未被其他程式獨占。
- 只測 USB 連線、預覽及存檔時，不必裝上顯微鏡。要看樣本，才需適合的光學接口、照明及對焦。

目前提供預覽與單張 PNG；沒有錄影、量測、比例尺校正、標註、景深合成或專用曝光／白平衡介面。

### 已測試的 TN2.0M-D

- VID/PID `055E:A165`，影像介面 `MI_00`，Microsoft `usbvideo` 功能驅動。
- 新版已實機取得 **MJPEG 1920×1080／30 fps**、**YUY2 640×480／30 fps** 的 PNG。
- 已驗證可見預覽、視窗拍照按鈕、查看照片、CMD 拍照後恢復預覽、含空白的自訂照片路徑。
- YUY2 的 1080p 只有 5 fps，不能套用 MJPEG 的 30 fps。
- 30 fps 是要求及協商的輸入模式，未驗證長時間零掉幀或顯微成像品質。完整狀態見 [測試記錄](docs/testing.md)。

VID/PID 是識別資訊，不代表一定要另裝驅動。這支目鏡已能透過標準介面工作。

## 使用其他型號

先在程式資料夾執行：

```powershell
powershell -NoProfile -File .\viewer.ps1 -Action ListDevices
```

在設定中填入精確名稱；同名裝置由 `deviceNumber` 區分，從 0 開始。再執行：

```powershell
powershell -NoProfile -File .\viewer.ps1 -Action ListFormats
```

選擇清單中的 MJPEG／YUY2、解析度及 fps。其他列出的格式目前不提供設定選項。找不到指定目鏡時會報錯，**不會自動改用內建攝影機**。

裝置及模式清單寫在 `runtime/logs/devices.stdout.txt`、`formats.stdout.txt`；錯誤在對應的 `.stderr.txt`。

## 可攜使用與容量

關閉預覽與控制面板後，複製整個程式資料夾到符合條件的 Windows 電腦即可。不需安裝路徑、PATH 設定、登錄修改或管理員權限。照片使用相對路徑時會一起搬移。

乾淨版本可直接下載 GitHub 原始碼 ZIP，第一次啟動在本機編譯；已編譯的 `bin` 也能一起攜帶。

舊版約 439 MiB，其中完整靜態版 FFmpeg／FFplay 合計約 435 MiB。新版已移除依賴，程式碼、文件與自己的執行檔為**百餘 KiB 等級**；照片和 Git 歷史另計。

原廠 StrangeView 主程式約 1.6 MiB，但另附約 42 MiB 的 FFmpeg DLL，壓縮後安裝檔約 18 MiB，不代表它沒有影音依賴。

## Android／iPad

本程式是 Windows 版，CMD 和 EXE 不能在平板執行。這項改動不改目鏡韌體，也不影響以後把標準 UVC 目鏡接上平板。條件和既有 App 候選見 [平板說明](docs/tablets.md)。

## 排除問題

| 情況 | 處理 |
| --- | --- |
| 找不到相機 | 接回 USB，確認 ListDevices 的名稱與同名序號 |
| 模式不支援 | 使用 ListFormats 列出的格式／解析度／fps |
| 開啟失敗 | 關閉其他相機程式，確認桌面程式相機權限與 USB |
| 腳本被政策擋住 | 確認來源及組織政策；本程式不用 Bypass，也不改執行原則 |
| 缺編譯器或媒體元件 | 使用含 .NET Framework 4.x 與 Media Foundation 的 Windows x64 |
| 執行檔已改變 | 審查本地來源、關閉預覽，執行 build.ps1 重建 |
| 紅色／模糊畫面 | 可能是桌面、未對準樣本或未對焦，請確認光路 |
| 拍照失敗 | 檢查 runtime/logs/capture.stderr.txt 與照片位置 |

## 開發與重跑測試

```powershell
# 本機編譯，不下載套件
powershell -NoProfile -File .\build.ps1

# 不開相機，完成後清掉測試目錄
powershell -NoProfile -File .\tests\smoke.ps1

# 選用：先接上設定中的目鏡並關閉預覽
powershell -NoProfile -File .\tests\camera.ps1 -IncludePreview

# TN2.0M-D 的額外 YUY2 實測
powershell -NoProfile -File .\tests\camera.ps1 -IncludePreview -TestYuy2
```

`src` 包含 Media Foundation 介面、影像轉換及預覽視窗；`viewer-core.ps1` 管理設定、CMD 動作與程序；`viewer-ui.ps1` 提供設定及控制面板。建置雜湊避免誤用過期或異動產物，不取代來源信任或數位簽章。

沒有網路上傳、自動更新、遙測、音訊擷取、驅動安裝或解除安裝刪資料功能；仍使用 Windows 媒體元件及裝置驅動。

API 參考：[Microsoft 相機擷取](https://learn.microsoft.com/en-us/windows/win32/medfound/video-capture)、[Source Reader](https://learn.microsoft.com/en-us/windows/win32/medfound/source-reader)、[影像 stride](https://learn.microsoft.com/en-us/windows/win32/medfound/image-stride)。

本倉庫採 [MIT License](LICENSE)，與電子目鏡製造商及 StrangeView 無隸屬關係。