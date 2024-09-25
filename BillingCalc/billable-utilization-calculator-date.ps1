# Load necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Billable Utilization Calculator"
$form.Size = New-Object System.Drawing.Size(400,450)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Create labels
$lblCurrentHours = New-Object System.Windows.Forms.Label
$lblCurrentHours.Location = New-Object System.Drawing.Point(10,20)
$lblCurrentHours.Size = New-Object System.Drawing.Size(150,20)
$lblCurrentHours.Text = "Current Billable Hours:"
$form.Controls.Add($lblCurrentHours)

$lblTargetUtilization = New-Object System.Windows.Forms.Label
$lblTargetUtilization.Location = New-Object System.Drawing.Point(10,50)
$lblTargetUtilization.Size = New-Object System.Drawing.Size(150,20)
$lblTargetUtilization.Text = "Target Utilization (%):"
$form.Controls.Add($lblTargetUtilization)

$lblStartDate = New-Object System.Windows.Forms.Label
$lblStartDate.Location = New-Object System.Drawing.Point(10,80)
$lblStartDate.Size = New-Object System.Drawing.Size(150,20)
$lblStartDate.Text = "Start Date:"
$form.Controls.Add($lblStartDate)

$lblEndDate = New-Object System.Windows.Forms.Label
$lblEndDate.Location = New-Object System.Drawing.Point(10,110)
$lblEndDate.Size = New-Object System.Drawing.Size(150,20)
$lblEndDate.Text = "End Date:"
$form.Controls.Add($lblEndDate)

# Create text boxes
$txtCurrentHours = New-Object System.Windows.Forms.TextBox
$txtCurrentHours.Location = New-Object System.Drawing.Point(170,20)
$txtCurrentHours.Size = New-Object System.Drawing.Size(100,20)
$form.Controls.Add($txtCurrentHours)

$txtTargetUtilization = New-Object System.Windows.Forms.TextBox
$txtTargetUtilization.Location = New-Object System.Drawing.Point(170,50)
$txtTargetUtilization.Size = New-Object System.Drawing.Size(100,20)
$txtTargetUtilization.Text = "82"
$form.Controls.Add($txtTargetUtilization)

# Create date pickers
$dtpStartDate = New-Object System.Windows.Forms.DateTimePicker
$dtpStartDate.Location = New-Object System.Drawing.Point(170,80)
$dtpStartDate.Size = New-Object System.Drawing.Size(200,20)
$dtpStartDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
$dtpStartDate.Value = (Get-Date -Day 1)  # Set to the first day of the current month
$form.Controls.Add($dtpStartDate)

$dtpEndDate = New-Object System.Windows.Forms.DateTimePicker
$dtpEndDate.Location = New-Object System.Drawing.Point(170,110)
$dtpEndDate.Size = New-Object System.Drawing.Size(200,20)
$dtpEndDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
$dtpEndDate.Value = (Get-Date -Day 1).AddMonths(1).AddDays(-1)  # Set to the last day of the current month
$form.Controls.Add($dtpEndDate)

# Create calculate button
$btnCalculate = New-Object System.Windows.Forms.Button
$btnCalculate.Location = New-Object System.Drawing.Point(150,140)
$btnCalculate.Size = New-Object System.Drawing.Size(100,30)
$btnCalculate.Text = "Calculate"
$btnCalculate.Add_Click({
    $currentHours = [double]$txtCurrentHours.Text
    $targetUtilization = [double]$txtTargetUtilization.Text / 100

    $startDate = $dtpStartDate.Value
    $endDate = $dtpEndDate.Value
    $currentDate = Get-Date

    $workingDays = 0
    $remainingWorkingDays = 0

    for ($day = $startDate; $day -le $endDate; $day = $day.AddDays(1)) {
        if ($day.DayOfWeek -ne "Saturday" -and $day.DayOfWeek -ne "Sunday") {
            $workingDays++
            if ($day -ge $currentDate) {
                $remainingWorkingDays++
            }
        }
    }

    $totalHours = $workingDays * 8
    $targetHours = $totalHours * $targetUtilization
    $remainingHours = $targetHours - $currentHours

    $currentUtilization = ($currentHours / $totalHours) * 100

    $dailyHoursNeeded = if ($remainingWorkingDays -gt 0) { $remainingHours / $remainingWorkingDays } else { 0 }

    $lblResult.Text = "Date Range: $($startDate.ToString('MM/dd/yyyy')) - $($endDate.ToString('MM/dd/yyyy'))`n"
    $lblResult.Text += "Working Days: $workingDays`n"
    $lblResult.Text += "Remaining Working Days: $remainingWorkingDays`n"
    $lblResult.Text += "Total Working Hours: $totalHours`n"
    $lblResult.Text += "Current Utilization: $($currentUtilization.ToString("F2"))%`n"
    $lblResult.Text += "Target Hours: $($targetHours.ToString("F2"))`n"
    $lblResult.Text += "Remaining Hours: $($remainingHours.ToString("F2"))`n"
    $lblResult.Text += "Daily Hours Needed: $($dailyHoursNeeded.ToString("F2"))"
})
$form.Controls.Add($btnCalculate)

# Create result label
$lblResult = New-Object System.Windows.Forms.Label
$lblResult.Location = New-Object System.Drawing.Point(10,180)
$lblResult.Size = New-Object System.Drawing.Size(380,250)
$lblResult.Text = "Results will appear here."
$form.Controls.Add($lblResult)

# Show the form
$form.ShowDialog()