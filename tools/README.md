# 影像工具

程式只執行此資料夾內的 `ffmpeg.exe` 與 `ffplay.exe`，不搜尋 PATH、不下載、不安裝、不使用 StrangeView 的元件。每次執行之前都核對 `checksums.json` 的 SHA-256；雜湊不符即停止。雜湊用來固定已選定的版本，**不等於惡意程式安全認證**。

## 本機與公開倉庫的差別

- 維護者的本機可攜資料夾已放入先前安裝及測試過的 FFmpeg／FFplay，並保留該套件的 LICENSE 與 README。
- GitHub 原始碼倉庫**不附執行檔**。下載 GitHub ZIP 後，需先自行準備工具，才能開啟相機。
- 配置完成後，`tools` 跟著整個資料夾搬到另一台相容 Windows 電腦即可，不依賴原電腦帳號、WinGet 路徑或 PATH。

## 自行準備

1. 從 [FFmpeg 官方下載頁](https://ffmpeg.org/download.html) 指向的 Windows 建置提供者，例如 [Gyan](https://www.gyan.dev/ffmpeg/builds/)，取得 Windows x64 的 **static build**，包含 `ffmpeg.exe`、`ffplay.exe` 及 DirectShow 支援。
2. 先核對下載來源、該下載套件的發布者校驗值與版本。**不要從待審安裝包複製 DLL 或 EXE**。
3. 將兩個 EXE 放到本資料夾，保留該建置的授權及來源說明。Shared build 另需 DLL；本專案未測試這種部署方式。
4. 目前 `checksums.json` 固定的是本機已測試的 **Gyan FFmpeg 8.1.1 full build**：其他版本或 essentials build 的雜湊會不同。確認新來源後，計算兩個檔案的雜湊，手動更新對應欄位。

   ```powershell
   Get-FileHash .\tools\ffmpeg.exe -Algorithm SHA256
   Get-FileHash .\tools\ffplay.exe -Algorithm SHA256
   powershell -NoProfile -File .\viewer.ps1 -Action Check
   ```

5. 之後再測試預覽與拍照。更換工具後的相容性與安全性需重新評估；程式不會自行接受新雜湊。

本機測試建置是 GPL v3，來源版本及組態記錄在原建置的 README。啟動程式的 MIT 授權不涵蓋 FFmpeg；若另行公開散布第三方執行檔，應遵循該建置自己的授權要求。本倉庫僅公開啟動程式及文件。
