Add-Type -AssemblyName PresentationCore, PresentationFramework

# init synchronized hashtable
$Sync = [HashTable]::Synchronized(@{})

#region GUI
[Xml]$WpfXml = @"
<Window x:Name="WpfGuiTemplate" x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp1"
        mc:Ignorable="d"
        Title="WPF XAML Template" WindowStartupLocation="CenterScreen" Visibility="Visible" ResizeMode="CanMinimize" Height="500" Width="500">
    <DockPanel>
        <Menu DockPanel.Dock="Top">
            <MenuItem Header="_File">
                <MenuItem
                    x:Name="mnuItem"
                    Header="_Item"/>
                <Separator />
            </MenuItem>
        </Menu>
        <Grid>

        </Grid>
    </DockPanel>
</Window>
"@

# these attributes can disturb powershell's ability to load XAML, so remove them
$WpfXml.Window.RemoveAttribute('x:Class')
$WpfXml.Window.RemoveAttribute('mc:Ignorable')

# add namespaces for later use if needed
$WpfNs = New-Object -TypeName Xml.XmlNamespaceManager -ArgumentList $WpfXml.NameTable
$WpfNs.AddNamespace('x', $WpfXml.DocumentElement.x)
$WpfNs.AddNamespace('d', $WpfXml.DocumentElement.d)
$WpfNs.AddNamespace('mc', $WpfXml.DocumentElement.mc)

$Sync.Gui = @{}

# Read XAML markup
try {
    $Sync.Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $WpfXml))
} catch {
    Write-Host $_ -ForegroundColor Red
    Exit
}

#===================================================
# Retrieve a list of all GUI elements
#===================================================
$WpfXml.SelectNodes('//*[@x:Name]', $WpfNs) | ForEach-Object {
    $Sync.Gui.Add($_.Name, $Sync.Window.FindName($_.Name))
}
#endregion

#region Form element event handlers

#endregion

#region Window event handlers
$Sync.Window.add_Loaded({

})

$Sync.Window.add_Closing({

})

$Sync.Window.add_Closed({

})
#endregion

# display the form
[void]$Sync.Window.ShowDialog()