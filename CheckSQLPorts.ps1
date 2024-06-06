# Define SQL Servers
$RemoteServers = "Server1","Server2"
$InbndServer = "HomeServer"

# Define TCP ports
$TCPPorts   =  "53",
            "88",
            "135",
            "139",
            "162",
            "389",
            "445",
            "464",
            "636",
            "3268",
            "3269",
            "3343",
            "5985",
            "5986",
            "49152",
            "65535",
            "1433",
            "1434",
            "2383",
            "5022"

# Define UDP ports
$UDPPorts = "53",
            "88",
            "123",
            "137",
            "138",
            "161",
            "162",
            "389",
            "445",
            "464",
            "3343",
            "49152",
            "65535",
            "1434",
            "2382"
 
# Initialise output varliables
$TCPResults = @()

# Test TCP ports
$TCPResults = Invoke-Command $RemoteServers {param($InbndServer,$TCPPorts)
                $Object = New-Object PSCustomObject
                $Object | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $env:COMPUTERNAME
                $Object | Add-Member -MemberType NoteProperty -Name "Destination" -Value $InbndServer
                    Foreach ($P in $TCPPorts){
                        $PortCheck = (TNC -Port $p -ComputerName $InbndServer ).TcpTestSucceeded
                        If($PortCheck -notmatch "True|False"){$PortCheck = "ERROR"}
                        $Object | Add-Member Noteproperty "$("Port " + "$p")" -Value "$($PortCheck)"
                    }
                $Object
           } -ArgumentList $InbndServer,$TCPPorts | select * -ExcludeProperty runspaceid, pscomputername


# Output TCP test results
$TCPResults | Out-GridView -Title "AG and WFC TCP Port Test Results"
$TCPResults | Format-Table * #-AutoSize

# Test UDP ports
$UDPResults = Invoke-Command $RemoteServers {param($InbndServer,$UDPPorts)
                $test = New-Object System.Net.Sockets.UdpClient;
                $Object = New-Object PSCustomObject
                $Object | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $env:COMPUTERNAME
                $Object | Add-Member -MemberType NoteProperty -Name "Destination" -Value $InbndServer
                    Foreach ($P in $UDPPorts){
                        Try
                        {
                            $test.Connect($InbndServer, $P);
                            $PortCheck = "TRUE";
                            $Object | Add-Member Noteproperty "$("Port " + "$p")" -Value "$($PortCheck)"
                        }
                        Catch
                        {
                            $PortCheck = "ERROR";
                            $Object | Add-Member Noteproperty "$("Port " + "$p")" -Value "$($PortCheck)"
                        }
                    }
                $Object
            } -ArgumentList $InbndServer,$UDPPorts | select * -ExcludeProperty runspaceid, pscomputername
 
# Output UDP test results
$UDPResults | Out-GridView -Title "AG and WFC UDP Port Test Results"
$UDPResults | Format-Table * #-AutoSize