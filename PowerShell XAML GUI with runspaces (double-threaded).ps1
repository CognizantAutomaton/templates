Add-Type -AssemblyName PresentationCore, PresentationFramework

# init synchronized hashtable
$Sync = [HashTable]::Synchronized(@{})

#region Init Runspace
$Runspace = [RunspaceFactory]::CreateRunspace()
$Runspace.ApartmentState = [Threading.ApartmentState]::STA
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()

# provide the other thread with the synchronized hashtable (variable shared across threads)
$Runspace.SessionStateProxy.SetVariable("Sync", $Sync)
$Runspace.SessionStateProxy.SetVariable("MyPSPath", $PSScriptRoot)
#endregion

#region GUI
[Xml]$WpfXml = @"
<Window x:Name="WpfRunspaceTemplate" x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp1"
        mc:Ignorable="d"
        Title="XAML Runspace Template" WindowStartupLocation="CenterScreen" Visibility="Visible" ResizeMode="CanMinimize" Height="500" Width="500">
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
            <!-- Your XAML controls here -->
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

#region Form event handlers
$StartTask = {
    # add a script to run in the other thread
    $global:Session = [PowerShell]::Create().AddScript({
        #region Start of long-running task
        for ([int]$n = 1; $n -le 10; $n++) {
            # sample simulation of a long-running task
            Start-Sleep -Seconds 1

            # sample update the GUI on the main thread
            # from within the runspace session
            <#
            $Sync.Window.Dispatcher.Invoke([Action]{
                $Sync.Gui.txtOutput.Text = $n
            }, "Normal")
            #>
        }
        #endregion
    }, $true)

    # invoke the runspace session created above
    $Session.Runspace = $Runspace
    $global:Handle = $Session.BeginInvoke()
}
#endregion

#region Window event handlers
$Sync.Window.add_Loaded({

})

$Sync.Window.add_Closing({
    # if user triggers app close and runspace session not complete
    if (($null -ne $Session) -and ($Handle.IsCompleted -eq $false)) {
        # alert the user the command is still running
        [Windows.MessageBox]::Show('A command is still running.')
        # prevent exit
        $PSItem.Cancel = $true
    }
})

$Sync.Window.add_Closed({
    # end session and close runspace on window exit
    if ($null -ne $Session) {
        $Session.EndInvoke($Handle)
    }

    $Runspace.Close()
})
#endregion

# display the form
[void]$Sync.Window.ShowDialog()
