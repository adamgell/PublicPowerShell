class IntuneDevice {
    [string]$Manufacturer
    [string]$Model
    [string]$OriginalModel
    [string]$FriendlyName

    IntuneDevice([string]$manufacturer, [string]$model) {
        $this.Manufacturer = $manufacturer
        $this.Model = $model
        $this.OriginalModel = $model
        $this.FriendlyName = $this.GetFriendlyName()
    }

    [string] GetFriendlyName() {
        # Logic to generate friendly name based on manufacturer and model
        if ($this.Manufacturer -like "*Lenovo*" -and $this.Model -match '^\w{4}') {
            return Get-LenovoFriendlyName -MTM $this.Model.Substring(0,4)
        }
        return $this.Model
    }
}