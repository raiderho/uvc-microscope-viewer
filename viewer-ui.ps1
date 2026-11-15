# Save this file as UTF-8 with BOM for Windows PowerShell 5.1.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

function Show-ViewerSettings {
    $settings = Get-ViewerSettings
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = 'UVC Microscope Viewer - 設定'
    $dialog.ClientSize = New-Object Drawing.Size(700,390)
    $dialog.Font = New-Object Drawing.Font('Microsoft JhengHei UI',10)
    $dialog.StartPosition = 'CenterScreen'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $fields = @{}
    $rows = @(
        @('deviceName','裝置名稱'), @('deviceNumber','同名裝置序號'),
        @('resolution','解析度'), @('fps','每秒影格'),
        @('inputFormat','影像格式'), @('photoDirectory','照片儲存位置')
    )
    for ($i=0; $i -lt $rows.Count; $i++) {
        $key = $rows[$i][0]
        $label = New-Object Windows.Forms.Label
        $label.Text = $rows[$i][1]
        $label.Location = New-Object Drawing.Point(20,(24+42*$i))
        $label.Size = New-Object Drawing.Size(145,28)
        $dialog.Controls.Add($label)
        if ($key -eq 'inputFormat') {
            $field = New-Object Windows.Forms.ComboBox
            $field.DropDownStyle = 'DropDownList'
            $field.Items.AddRange(@('mjpeg','yuyv422'))
            $field.SelectedItem = [string]$settings.$key
        } else {
            $field = New-Object Windows.Forms.TextBox
            $field.Text = [string]$settings.$key
        }
        $field.AccessibleName = $rows[$i][1]
        $field.Location = New-Object Drawing.Point(170,(20+42*$i))
        $field.Size = New-Object Drawing.Size(390,28)
        $fields[$key] = $field
        $dialog.Controls.Add($field)
    }
    $browse = New-Object Windows.Forms.Button
    $browse.Text = '選擇資料夾'
    $browse.Location = New-Object Drawing.Point(570,230)
    $browse.Size = New-Object Drawing.Size(115,30)
    $browse.Add_Click({
        $form = $this.FindForm()
        $picker = New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description = '選擇之後照片的存放位置；舊照片不會搬移。'
        try {
            try { $picker.SelectedPath = Resolve-PhotoDirectory $form.Tag.fields.photoDirectory.Text } catch { }
            if ($picker.ShowDialog($form) -eq 'OK') {
                $selected = $picker.SelectedPath
                if ($selected.StartsWith($script:ViewerRoot + '\',[StringComparison]::OrdinalIgnoreCase)) {
                    $selected = $selected.Substring($script:ViewerRoot.Length+1)
                }
                $form.Tag.fields.photoDirectory.Text = $selected
            }
        } finally { $picker.Dispose() }
    })
    $dialog.Controls.Add($browse)
    $note = New-Object Windows.Forms.Label
    $note.Text = "預設 photos。相對路徑會跟著程式資料夾搬移。`r`n可填本機完整路徑；舊照片留在原位置。儲存設定會停止目前預覽。"
    $note.Location = New-Object Drawing.Point(20,275)
    $note.Size = New-Object Drawing.Size(660,50)
    $dialog.Controls.Add($note)
    $save = New-Object Windows.Forms.Button
    $save.Text = '儲存設定'
    $save.Location = New-Object Drawing.Point(450,335)
    $save.Size = New-Object Drawing.Size(110,35)
    $save.Add_Click({
        $form = $this.FindForm()
        try {
            $f = $form.Tag.fields
            $updated = [pscustomobject][ordered]@{
                schemaVersion=1; deviceName=$f.deviceName.Text.Trim(); deviceNumber=[int]$f.deviceNumber.Text;
                resolution=$f.resolution.Text.Trim(); fps=[int]$f.fps.Text;
                inputFormat=$f.inputFormat.Text; photoDirectory=$f.photoDirectory.Text.Trim()
            }
            Assert-Settings $updated
            $null = Invoke-ViewerAction 'Stop'
            Save-ViewerSettings $updated
            $form.DialogResult = 'OK'
            $form.Close()
        } catch { $null = [Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'設定未儲存','OK','Warning') }
    })
    $dialog.Controls.Add($save)
    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = '取消'
    $cancel.DialogResult = 'Cancel'
    $cancel.Location = New-Object Drawing.Point(575,335)
    $cancel.Size = New-Object Drawing.Size(110,35)
    $dialog.Controls.Add($cancel)
    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel
    $dialog.Tag = @{fields=$fields}
    try { $null = $dialog.ShowDialog() } finally { $dialog.Dispose() }
}

function Show-ViewerMenu {
    $form = New-Object Windows.Forms.Form
    $form.Text = 'UVC Microscope Viewer'
    $form.ClientSize = New-Object Drawing.Size(640,370)
    $form.Font = New-Object Drawing.Font('Microsoft JhengHei UI',10)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $heading = New-Object Windows.Forms.Label
    $heading.Text = 'USB 電子目鏡 / UVC 相機'
    $heading.Font = New-Object Drawing.Font('Microsoft JhengHei UI',15,[Drawing.FontStyle]::Bold)
    $heading.Location = New-Object Drawing.Point(20,16)
    $heading.Size = New-Object Drawing.Size(600,38)
    $form.Controls.Add($heading)
    $status = New-Object Windows.Forms.TextBox
    $status.Multiline = $true
    $status.ReadOnly = $true
    $status.ScrollBars = 'Vertical'
    $status.Location = New-Object Drawing.Point(20,180)
    $status.Size = New-Object Drawing.Size(600,135)
    $settings = Get-ViewerSettings
    $status.Text = "裝置：$($settings.deviceName)  /  $($settings.resolution)  /  $($settings.fps) fps`r`n照片位置：$(Resolve-PhotoDirectory $settings.photoDirectory)`r`n按「拍照」儲存 PNG，再按「查看照片」開啟資料夾。"
    $form.Controls.Add($status)
    $buttons = New-Object Collections.Generic.List[Windows.Forms.Button]
    $items = @(@('Preview','開啟預覽'),@('Capture','拍照'),@('Photos','查看照片'),@('Settings','設定裝置 / 照片位置'),@('Stop','停止預覽'),@('Close','關閉控制面板'))
    for ($i=0; $i -lt $items.Count; $i++) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $items[$i][1]
        $button.Tag = $items[$i][0]
        $button.Location = New-Object Drawing.Point((20+205*($i%3)),(65+52*[Math]::Floor($i/3)))
        $button.Size = New-Object Drawing.Size(190,43)
        $button.Add_Click({
            $window = $this.FindForm()
            $action = [string]$this.Tag
            if ($action -eq 'Close') { $window.Close(); return }
            foreach ($b in $window.Tag.buttons) { $b.Enabled = $false }
            $window.UseWaitCursor = $true
            $window.Tag.status.Text = '處理中，請稍候…'
            $window.Refresh()
            try {
                if ($action -eq 'Settings') {
                    Show-ViewerSettings
                    $cfg = Get-ViewerSettings
                    $result = "裝置：$($cfg.deviceName)`r`n照片位置：$(Resolve-PhotoDirectory $cfg.photoDirectory)"
                } else {
                    $result = Invoke-ViewerAction $action
                    if ($action -eq 'Capture') { $result = "照片已儲存：`r`n$result`r`n按「查看照片」即可開啟資料夾。" }
                }
                $window.Tag.status.Text = [string]$result
            } catch {
                $window.Tag.status.Text = '未完成：' + $_.Exception.Message
            } finally {
                $window.UseWaitCursor = $false
                foreach ($b in $window.Tag.buttons) { $b.Enabled = $true }
            }
        })
        $buttons.Add($button)
        $form.Controls.Add($button)
    }
    $note = New-Object Windows.Forms.Label
    $note.Text = '面板拍照會暫停並恢復預覽；影像視窗也可直接拍照。關閉面板會保留預覽。'
    $note.Location = New-Object Drawing.Point(20,330)
    $note.Size = New-Object Drawing.Size(600,30)
    $form.Controls.Add($note)
    $form.Tag = @{status=$status;buttons=$buttons}
    Write-Output 'Control panel ready.'
    try { $null = $form.ShowDialog() } finally { $form.Dispose() }
}
