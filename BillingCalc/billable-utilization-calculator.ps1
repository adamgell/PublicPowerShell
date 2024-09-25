# Load necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Billable Utilization Calculator"
$form.Size = New-Object System.Drawing.Size(400,400)
$form.StartPosition = "CenterScreen"

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

# Create calculate button
$btnCalculate = New-Object System.Windows.Forms.Button
$btnCalculate.Location = New-Object System.Drawing.Point(150,80)
$btnCalculate.Size = New-Object System.Drawing.Size(100,30)
$btnCalculate.Text = "Calculate"
$btnCalculate.Add_Click({
    $currentHours = [double]$txtCurrentHours.Text
    $targetUtilization = [double]$txtTargetUtilization.Text / 100

    $currentDate = Get-Date
    $firstDayOfMonth = Get-Date -Year $currentDate.Year -Month $currentDate.Month -Day 1
    $lastDayOfMonth = $firstDayOfMonth.AddMonths(1).AddDays(-1)
    $workingDays = 0
    $remainingWorkingDays = 0

    for ($day = $firstDayOfMonth; $day -le $lastDayOfMonth; $day = $day.AddDays(1)) {
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

    $lblResult.Text = "Month: $($currentDate.ToString('MMMM yyyy'))`n"
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
$lblResult.Location = New-Object System.Drawing.Point(10,120)
$lblResult.Size = New-Object System.Drawing.Size(380,250)
$lblResult.Text = "Results will appear here."
$form.Controls.Add($lblResult)

# Show the form
$form.ShowDialog()
