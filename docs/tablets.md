# Android 與 iPad

這份專案是 Windows 啟動器，不能直接在 Android 或 iPadOS 執行。硬體採標準 UVC 時，可改用平板上的既有軟體；不需要把這個啟動器重寫成大型跨平台 App，也不需要安裝 Windows 的 StrangeView。

## Android

- 平板需支援 [USB Host／OTG](https://developer.android.com/develop/connectivity/usb/host)，使用能傳資料的轉接器，供電足夠。不是所有 Android 平板都支援外接相機。
- 可評估 Google Play 的 [USB攝像頭Pro（ShenYao China）](https://play.google.com/store/apps/details?id=com.shenyaocn.android.usbcamerapro&hl=zh_TW)。官方列有 UVC、MJPG／YUY2、拍照與錄影；與 TN2.0M-D 已測的輸出格式相符，但本專案未在平板實測。
- 此為付費候選，未代購或安裝。官方資料安全標籤是開發者聲明，不代表本專案已審查二進位檔。
- 它另有 RTSP／HTTP 伺服器、直播、FTP 上傳、GPS 浮水印及循環刪檔功能。只看目鏡時不要啟用這些功能，保留本機預覽／拍照即可。

## iPad

- [Apple 的 UVC 外接相機支援說明](https://developer.apple.com/videos/play/wwdc2023/10106/)以 USB-C iPad 與 iPadOS 17 起的支援為基礎；App 可能要求更高版本。Lightning 機型不能只靠轉接頭保證相容。
- 可評估 [Camo Studio – Stream & Record](https://apps.apple.com/app/id6450313385)。[開發者文件](https://camo.com/support/camo-ipad/how-to-use-camo-ipad)說明可使用 USB 相機／webcam；此處指 iPad 的 Camo Studio，並非 Camo Camera。
- 本專案沒有安裝或審查此 App，也未確認它的單張照片功能；此候選主要作預覽及本機錄影使用。不需連結直播帳號或載入網路疊圖。

已輸出 UVC 的 USB 目鏡不需要 HDMI 擷取卡；若遇到供電不足，才考慮有外接電源的 USB Hub。

## 相容性邊界

使用 Windows 啟動器不會修改硬體韌體或識別碼，所以不會鎖死未來的平板用途。不過 Windows 成功，不能推論每款平板、系統、轉接器和 App 都成功。上述 App 僅是官方文件支持的功能候選，未被認證為零風險。

文件查核日期：2026-11-15。
