# run-ipconfig.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:mask = "255.255.255.255"
$global:gateway = "192.168.44.1"
$global:selectProcess = ""
$global:inputType = ""
$global:inputAddress = ""
$global:ipAddresses = @()
$global:delType = ""
$global:delAddress = ""
$global:runMode = $env:RUN_MODE
$global:interfaceIndex = (
	Get-NetAdapter |
	Where-Object { $_.Name -like "Bluetooth*" } |
	Select-Object -First 1
).ifIndex
$global:networkProfile = (
	Get-NetConnectionProfile |
	Where-Object { $_.InterfaceAlias -like "Bluetooth*" } |
	Select-Object -First 1
)
$global:networkCategory = (
	Get-NetConnectionProfile |
	Where-Object { $_.InterfaceAlias -like "Bluetooth*" } |
	Select-Object -First 1
).NetworkCategory
$global:interfaceMetric = (
	Get-NetIPInterface |
	Where-Object { $_.InterfaceAlias -like "Bluetooth*" } |
	Select-Object -First 1
).InterfaceMetric

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [string] GetNetworkOrder() {
		try {
			$result = (
				Get-NetIPInterface |
				Sort-Object ifIndex |
				Select-Object ifIndex, InterfaceAlias, AddressFamily, InterfaceMetric |
				ForEach-Object {
					([T]::TextFormat("$($_.ifIndex)", 3)) +
					"  │  " +
					([T]::TextFormat("$($_.InterfaceAlias)", 25)) +
					"  │  " +
					([T]::TextFormat("$($_.AddressFamily)", 5)) +
					"  │  " +
					([T]::TextFormat("$($_.InterfaceMetric)", 3))
				} |
				Out-String
			)
			return $result
		}
		catch {
			[T]::PrintExit("Red", "! 네트워크 목록 조회 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
			return ""
		}
	}

	static [string] GetNetworkAllowList() {
		try {
			$result = (
				Get-NetRoute -AddressFamily IPv4 |
				Where-Object { $_.NextHop -eq $global:gateway -and $_.InterfaceIndex -eq $global:interfaceIndex } |
				ForEach-Object {
					([T]::TextFormat("$($_.DestinationPrefix)", 20)) +
					"  │  " +
					([T]::TextFormat("$($_.NextHop)", 15)) +
					"  │  " +
					([T]::TextFormat("$($_.InterfaceIndex)", 3))
				} |
				Out-String
			)
			return $result
		}
		catch {
			[T]::PrintExit("Red", "! 네트워크 허용목록 조회 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
			return ""
		}
	}

	static [array] GetIpFromDomain(
		[string]$inputDomain
	) {
		try {
			$domains = $inputDomain -split ",\s*" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
			$ipAddresses = @()
			foreach ($domain in $domains) {
				if (-not $domain) {
					continue
				}
				try {
					$ips = (Resolve-DnsName -Name $domain -Type A -ErrorAction SilentlyContinue).IPAddress
					if ($ips) {
						$ipAddresses += $ips
					}
					else {
						[T]::PrintText("Red", "▶ 도메인 [$domain] 에 대한 IP를 찾을 수 없습니다.")
					}
				}
				catch {
					[T]::PrintText("Red", "▶ 도메인 [$domain] 조회 오류")
				}
			}
			return $ipAddresses
		}
		catch {
			[T]::PrintExit("Red", "! 도메인 → IP 변환 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
			return @()
		}
	}

	static [array] GetIpFromAddress(
		[string]$inputAddress
	) {
		try {
			$ipAddresses = $inputAddress -split ",\s*" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
			return $ipAddresses
		}
		catch {
			[T]::PrintExit("Red", "! IP주소 파싱 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
			return @()
		}
	}

	static [void] SetNetworkMetricLast() {
		try {
			$btList = (
				Get-NetIPInterface |
				Where-Object { $_.InterfaceAlias -like "Bluetooth*" }
			)
			foreach ($item in $btList) {
				try {
					Set-NetIPInterface `
					-InterfaceIndex $item.ifIndex `
					-AddressFamily $item.AddressFamily `
					-InterfaceMetric 1
				}
				catch {
					[T]::PrintExit("Red", "! Bluetooth 인터페이스 메트릭 설정 중 오류")
				}
			}
		}
		catch {
			[T]::PrintExit("Red", "! Bluetooth 인터페이스 목록 조회 중 오류")
		}
	}

	static [void] SetNetworkCategoryPrivate() {
		try {
			$btList = (
				Get-NetConnectionProfile |
				Where-Object { $_.InterfaceAlias -like "Bluetooth*" }
			)
			foreach ($item in $btList) {
				try {
					Set-NetConnectionProfile `
					-InterfaceIndex $item.InterfaceIndex `
					-NetworkCategory Private
				}
				catch {
					[T]::PrintExit("Red", "! Bluetooth 네트워크 카테고리 설정 중 오류")
				}
			}
		}
		catch {
			[T]::PrintExit("Red", "! Bluetooth 네트워크 카테고리 목록 조회 중 오류")
		}
	}

	static [void] SetDefaultRoute() {
		try {
			$btInterfaces = Get-NetIPInterface | Where-Object {
				$_.InterfaceAlias -like "Bluetooth*" -and $_.AddressFamily -eq "IPv4"
			}
			if (-not $btInterfaces -or $btInterfaces.Count -eq 0) {
				[T]::PrintExit("Yellow", "! Bluetooth 인터페이스를 찾을 수 없습니다.")
			}
			foreach ($iface in $btInterfaces) {
				for ($i = 1; $i -le 3; $i++) {
					$routes = Get-NetRoute | Where-Object {
						$_.InterfaceIndex -eq $iface.InterfaceIndex -and
						(
							$_.DestinationPrefix -eq "0.0.0.0/0" -or
							$_.DestinationPrefix -eq "0.0.0.0/32"
						)
					}
					if ($routes.Count -eq 0) {
						if ($i -eq 1) {
							[T]::PrintText("DarkGray", "▶ 제거할 기본 경로가 없습니다. (IF: $($iface.InterfaceIndex))")
						}
						break
					}
					else {
						foreach ($route in $routes) {
							try {
								Remove-NetRoute `
								-DestinationPrefix $route.DestinationPrefix `
								-InterfaceIndex $route.InterfaceIndex `
								-Confirm:$false
								[T]::PrintText("Green", "▶ 기본 경로 제거 완료 (IF: $($route.InterfaceIndex), $($route.DestinationPrefix))")
							}
							catch {
								[T]::PrintText("Red", "▶ 기본 경로 제거 중 오류 발생: $($_.Exception.Message) (IF: $($route.InterfaceIndex), $($route.DestinationPrefix))")
							}
						}
					}
					Start-Sleep -Milliseconds 300
				}
			}
		}
		catch {
			[T]::PrintExit("Red", "! 경로 제거 처리 중 예외 발생")
		}
	}

	static [void] SetRegistryItem() {
		try {
			$ethernet = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*이더넷*" }
			$ipAddress = $null
			if ($ethernet) {
				$ipAddress = (Get-NetIPAddress -InterfaceIndex $ethernet.ifIndex -AddressFamily IPv4).IPAddress
				[T]::PrintText("Cyan", "▶ 활성화된 이더넷 어댑터 사용: $($ethernet.Name)")
			}
			else {
				$wifi = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }
				if ($wifi) {
					$ipAddress = (Get-NetIPAddress -InterfaceIndex $wifi.ifIndex -AddressFamily IPv4).IPAddress
					[T]::PrintText("Yellow", "▶ 이더넷 없음, Wi-Fi 어댑터 사용: $($wifi.Name)")
				}
				else {
					[T]::PrintExit("Red", "! 활성화된 이더넷 또는 Wi-Fi 어댑터를 찾을 수 없습니다.")
				}
			}
			if (-not $ipAddress) {
				[T]::PrintExit("Red", "! IP 주소를 가져올 수 없습니다.")
			}
			$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
			$currentValue = (Get-ItemProperty -Path $regPath).DhcpNameServer
			[T]::PrintText("Yellow", "▶ 기존 DhcpNameServer 값: $currentValue")
			Set-ItemProperty -Path $regPath -Name "DhcpNameServer" -Value $ipAddress
			[T]::PrintText("Green", "▶ 변경된 DhcpNameServer 값: $ipAddress")
			$iface = Get-NetIPInterface | Where-Object { $_.InterfaceMetric -eq 1 }
			if ($iface) {
				$iface = $iface | Sort-Object InterfaceIndex -Unique
				foreach ($i in $iface) {
					$guid = (Get-NetAdapter -InterfaceIndex $i.InterfaceIndex).InterfaceGuid
					$ifaceRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
					if (-not (Test-Path $ifaceRegPath)) {
						New-Item -Path $ifaceRegPath | Out-Null
					}
					$existingValue = (Get-ItemProperty -Path $ifaceRegPath -ErrorAction SilentlyContinue).DisableDefaultRoutes
					if ($existingValue -eq 1) {
						[T]::PrintText("Yellow", "▶ 이미 설정됨: DisableDefaultRoutes ($($i.InterfaceAlias))")
					}
					else {
						New-ItemProperty -Path $ifaceRegPath -Name "DisableDefaultRoutes" -PropertyType DWord -Value 1 -Force | Out-Null
						[T]::PrintText("Cyan", "▶ DisableDefaultRoutes 추가됨: $($i.InterfaceAlias) (GUID: $guid)")
					}
				}
			}
			else {
				[T]::PrintText("Yellow", "▶ 메트릭 값이 1인 인터페이스를 찾을 수 없습니다.")
			}
		}
		catch {
			[T]::PrintExit("Red", "! 레지스트리 변경 중 오류 발생: $($_.Exception.Message)")
		}
	}

	static [void] AddAllowListSpecific(
		[object]$inputAddress,
		[int]$interfaceIndex,
		[string]$gateway,
		[int]$metric
	) {
		try {
			if ($null -eq $inputAddress) {
				[T]::PrintExit("Red", "! 입력된 IP 주소가 없습니다.")
			}
			$ipAddresses = $inputAddress -is [Array] ? $inputAddress : @($inputAddress)
			foreach ($net in $ipAddresses) {
				$trimNet = $net.Trim()
				if (-not $trimNet) {
					continue
				}
				try {
					$finalNet = $trimNet -notmatch "/" ? "$trimNet/32" : $trimNet
					New-NetRoute `
					-DestinationPrefix $finalNet `
					-InterfaceIndex $interfaceIndex `
					-NextHop $gateway `
					-RouteMetric $metric `
					-Confirm:$false
				}
				catch {
					[T]::PrintExit("Red", "! IP [$trimNet] 추가 중 오류")
				}
			}
		}
		catch {
			[T]::PrintExit("Red", "! IP 주소 추가 중 오류")
		}
	}

	static [void] RemoveAllowListAll() {
		try {
			$routes = (
				Get-NetRoute -AddressFamily IPv4 |
				Where-Object { $_.NextHop -eq $global:gateway -and $_.InterfaceIndex -eq $global:interfaceIndex }
			)
			foreach ($route in $routes) {
				Remove-NetRoute `
				-DestinationPrefix $route.DestinationPrefix `
				-NextHop $route.NextHop `
				-InterfaceIndex $route.InterfaceIndex `
				-Confirm:$false
			}
		}
		catch {
			[T]::PrintExit("Red", "! 전체 허용목록 삭제 중 오류")
		}
	}

	static [void] RemoveAllowListSpecific(
		[object]$delAddress
	) {
		try {
			$targets = $delAddress -is [Array] ? $delAddress : @($delAddress)
			foreach ($target in $targets) {
				$delTarget = $target.Trim()
				if (-not $delTarget) {
					continue
				}
				$finalTarget = $delTarget -notmatch "/" ? "$delTarget/32" : $delTarget
				$routes = (
					Get-NetRoute -AddressFamily IPv4 |
					Where-Object {
						$_.NextHop -eq $global:gateway -and
						$_.DestinationPrefix -eq $finalTarget -and
						$_.InterfaceIndex -eq $global:interfaceIndex
					}
				)
				foreach ($route in $routes) {
					Remove-NetRoute `
					-DestinationPrefix $route.DestinationPrefix `
					-NextHop $route.NextHop `
					-InterfaceIndex $route.InterfaceIndex `
					-Confirm:$false
				}
			}
		}
		catch {
			[T]::PrintExit("Red", "! 특정 IP 허용목록 삭제 중 오류")
		}
	}
}

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ BlueTooth 테더링 네트워크 설정을 시작합니다")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
	[T]::PrintText("Cyan", "▶ 현재 실행 모드: [$global:runMode]")
}

# 4. 메인 로직 실행 ---------------------------------------------------------------------------
& {
	if (-not $global:networkProfile) {
		[T]::PrintExit("Red", "! BlueTooth 테더링 연결이 없습니다.")
	}
	[T]::PrintLine("Yellow")
	if ($global:interfaceIndex -and $global:networkProfile) {
		[T]::PrintText("Yellow", "▶ BlueTooth 인터페이스 메트릭 재설정 : 1")
		[M]::SetNetworkMetricLast()
		[T]::PrintText("Yellow", "▶ BlueTooth 네트워크 카테고리 재설정 : Private")
		[M]::SetNetworkCategoryPrivate()
		[T]::PrintText("Yellow", "▶ BlueTooth 네트워크 기본 경로 제거  : 0.0.0.0/0")
		[M]::SetDefaultRoute()
	}
	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", "▶ 현재 BlueTooth 테더링 게이트웨이 : $global:gateway")
	[T]::PrintText("Yellow", "▶ 현재 BlueTooth 테더링 마스크     : $global:mask")
	[T]::PrintText("Yellow", "▶ 현재 BlueTooth 네트워크 카테고리 : $global:networkCategory")
	[T]::PrintText("Yellow", "▶ 현재 BlueTooth 인터페이스 인덱스 : $global:interfaceIndex")
	[T]::PrintText("Yellow", "▶ 현재 BlueTooth 인터페이스 메트릭 : $global:interfaceMetric")
	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", [M]::GetNetworkOrder())
	if ($global:runMode -eq "AUTO") {
		$global:selectProcess = "1"
	}
	else {
		[T]::PrintLine("Green")
		[T]::TextInput("Green", "▶ 프로세스 방식을 입력하세요 (1:조회/2:추가/3:삭제):", [ref]$global:selectProcess)
	}
	if ($global:selectProcess -eq "1") {
		[T]::PrintLine("Cyan")
		$allowList = [M]::GetNetworkAllowList()
		if (-not $allowList -or $allowList.Trim() -eq "") {
			[T]::PrintExit("Yellow", "! 등록된 IP 주소가 없습니다.")
		}
		else {
			[T]::PrintText("Cyan", $allowList)
			[T]::PrintExit("Green", "✓ 조회가 완료되었습니다.")
		}
	}
	elseif ($global:selectProcess -eq "2") {
		[T]::TextInput("Green", "▶ 추가 방법을 선택하세요 (1:도메인/2:IP주소):", [ref]$global:inputType)
		try {
			if ($global:inputType -eq "1") {
				[T]::TextInput("Green", "▶ 추가할 도메인을 입력하세요 (여러개: google.com,naver.com):", [ref]$global:inputAddress)
				$global:ipAddresses = [M]::GetIpFromDomain($global:inputAddress)
				if (-not $global:ipAddresses -or $global:ipAddresses.Count -eq 0) {
					[T]::PrintExit("Red", "! 입력 도메인에 대한 IP 주소를 찾을 수 없습니다.")
				}
				else {
					[M]::AddAllowListSpecific($global:ipAddresses, $global:interfaceIndex, $global:gateway, $global:interfaceMetric)
					[T]::PrintText("Green", "▶ 도메인에 해당하는 IP [" + ($global:ipAddresses -join ", ") + "] 추가완료.")
				}
			}
			elseif ($global:inputType -eq "2") {
				[T]::TextInput("Green", "▶ 추가할 IP주소를 입력하세요 (여러개: 1.1.1.1, 8.8.8.8):", [ref]$global:inputAddress)
				$global:ipAddresses = [M]::GetIpFromAddress($global:inputAddress)
				if (-not $global:ipAddresses -or $global:ipAddresses.Count -eq 0) {
					[T]::PrintExit("Red", "! IP주소 입력이 잘못되었습니다.")
				}
				else {
					[M]::AddAllowListSpecific($global:ipAddresses, $global:interfaceIndex, $global:gateway, $global:interfaceMetric)
					[T]::PrintText("Green", "▶ IP주소 [" + ($global:ipAddresses -join ", ") + "] 추가완료.")
				}
			}
			else {
				[T]::PrintExit("Red", "! 잘못된 입력입니다.")
			}
		}
		catch {
			[T]::PrintExit("Red", "! 추가 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
		}
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", [M]::GetNetworkAllowList())
		[T]::PrintExit("Green", "✓ 추가가 완료되었습니다.")
	}
	elseif ($global:selectProcess -eq "3") {
		[T]::TextInput("Green", "▶ 삭제 방법을 선택하세요 (1:전체/2:특정):", [ref]$global:delType)
		[T]::PrintLine("Green")
		try {
			if ($global:delType -eq "1") {
				[M]::RemoveAllowListAll()
				[T]::PrintText("Green", "▶ 전체 허용목록 삭제 완료.")
			}
			elseif ($global:delType -eq "2") {
				[T]::TextInput("Green", "▶ 삭제할 IP주소를 입력하세요 (여러개: 1.1.1.1, 8.8.8.8):", [ref]$global:delAddress)
				$delAddresses = [M]::GetIpFromAddress($global:delAddress)
				if (-not $delAddresses -or $delAddresses.Count -eq 0) {
					[T]::PrintExit("Red", "! 삭제할 IP 주소 입력이 잘못되었습니다.")
				}
				else {
					[M]::RemoveAllowListSpecific($delAddresses)
					[T]::PrintText("Green", "▶ IP주소 [" + ($delAddresses -join ", ") + "] 삭제완료.")
				}
			}
			else {
				[T]::PrintExit("Red", "! 잘못된 입력입니다.")
			}
		}
		catch {
			[T]::PrintExit("Red", "! 삭제 중 오류가 발생하였습니다.`n$($_.Exception.Message)")
		}
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", [M]::GetNetworkAllowList())
		[T]::PrintExit("Green", "✓ 삭제가 완료되었습니다.")
	}
	else {
		[T]::PrintExit("Red", "! 잘못된 입력입니다.")
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}