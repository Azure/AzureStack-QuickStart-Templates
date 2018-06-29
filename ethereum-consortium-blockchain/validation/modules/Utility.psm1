function GeneratePrefix()
{
	$seed = [guid]::NewGuid()
	return "e"+$seed.ToString().Substring(0,5)
}

function DownloadFile(
					[String] $Uri,
					[String] $Destination
					)
{
	$webclient = New-Object System.Net.WebClient
	$webclient.DownloadFile($Uri,$Destination)
}