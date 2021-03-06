$prg=${env:ProgramFiles}
$install_path=$prg+"\ScreenShoter\"
$FileName="screen.exe"
$FullFileName="`""+$install_path+$FileName+"`"";
$IniFileName="screen.ini"
$curDir = $MyInvocation.MyCommand.Definition | split-path -parent
$LogFile = $curDir+"\setup.log";
$RegPath="Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\"
$RegName="ScreenShoter"
$FullRegPath=$RegPath+$RegName;
$NetFileInstall=$curDir+"\dotNetFx40_Full_x86_x64.exe";
Set-Location $curDir
$InstallOrUninstall = Read-Host "Установить программу [y (установить)/ n (удалить)]";
if (Test-Path $LogFile) {
	Remove-Item $LogFile -Force | Out-Null
}
function Logi ($text) {
	Write-Host $text;
	Write-output $text | out-file "$LogFile" -APPEND

}
function SleepBreak {
	Logi ("Завершение программы")
	Start-Sleep -Seconds 20
	break
}
function KillProc ($NameProc){
	$NameProc=$NameProc.Replace(".exe","")
	try{
		$Process=Get-Process $NameProc -ErrorAction Stop
	} catch {
		Logi ($NameProc+" не запущен")	
	}
	if ($Process){
		If ( $Process.Path -eq ($install_path+$NameProc) ){
			Logi ($NameProc+" процесс найден")
			try{
				Stop-Process $Process.id -ErrorAction Stop
			} catch {
				Logi ($NameProc+" не удалось остановить")
				Logi ("	Завершите процесс вручную")
				SleepBreak
			}
		}else{
			Logi ($NameProc+" путь к файлу не соответствует, завершите процесс вручную") 
			SleepBreak
		}
	}

}
function UnInstall{
	#Удаляем папку
	KillProc ($FileName)
	KillProc ($FileName.Replace(".exe","_debug.exe"))

	if (Test-Path $install_path){
		try{
			Remove-Item $install_path -Recurse -Force -ErrorAction Stop
		}
		catch {
			Logi ("	Не удалось удалить файлы программы")
			Logi ("	Run As Administrator!")
			SleepBreak
		}
		Logi ("	Файлы программы удалены")
	}else{
		Logi ("	Папки "+$install_path+" не существует!")
	}
	#Удаляем запись в реестре
	try{
		$CheckReg=Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Stop
	}catch{
		$CheckReg=$null
	}
	If (!$CheckReg){
		Logi ("	Записи в реестре не существует!!!")
	}else{
		try{
			Remove-ItemProperty -Path $RegPath -Name $RegName -Force -ErrorAction Stop
		}
		catch {
			Logi ("	Не удалось удалить запись в реестре")
			Logi ("	Run As Administrator!")
			SleepBreak
		}
		Logi ("	Запись реестра удалена")
	}
	Logi ("Деинсталляция завершена")
	SleepBreak
}

if ($InstallOrUninstall -eq "n"){
	Logi ("Деинсталляция продукта")
	UnInstall
	SleepBreak
}else{
	$InstallDebug = Read-Host "Debug [y/n]";
}
if ($InstallDebug -eq "y"){
	$install_path=$prg+"\ScreenShoter\"
	$FileName="screen_debug.exe"
	$FullFileName="`""+$install_path+$FileName+"`"";
}
function CreatePath{
	try{
		New-Item -Path $install_path -Type directory -Force -ErrorAction Stop | Out-Null
	}
	catch {
		Logi ("	Папка не создана!")
		Logi ("	Run As Administrator!")
		SleepBreak
	}
}

function CopyInPath{
	param([string]$file)
	try{
		Copy-Item $file $install_path -Force -ErrorAction Stop
	}
	catch {
		Logi ("	Файлы программы не скопированны!")
		Logi ("	Run As Administrator")
		SleepBreak
	}
}
function CreateRegParam{
	try{
		New-ItemProperty -Path $RegPath -Name $RegName -PropertyType String -Value ($FullFileName+" -Arguments -File") -Force -ErrorAction Stop | Out-Null
	}
	catch {
		Logi ("	Не удалось выполнить добавление записи в реестр")
		Logi ("	Run As Administrator")
		SleepBreak
	}	

}
if (Test-Path $install_path) {
	Logi ("	Директория существует.")
} else {
	CreatePath
}

CopyInPath -file $FileName
CopyInPath -file ($FileName+".config")
CopyInPath -file ($IniFileName)

if (Test-Path $IniFileName) {
	Logi ("")
	Logi ("Чтение файла настроек...")
	$SetupIni=Get-Content $IniFileName;
	for ($i=0; $i -lt $SetupIni.count; $i++ ){
		if ($SetupIni[$i] -like "Path=*") {
			$PathFromScreen=$SetupIni[$i].Replace("Path=","");
			Logi ("	Место сохранения скриншотов: "+$PathFromScreen);
		}elseif ($SetupIni[$i] -like "Interval=*") {
			$IntervalFromScreen=$SetupIni[$i].Replace("Interval=","");
			Logi ("	Интервал съемки: "+$IntervalFromScreen+" сек.");
		}elseif ($SetupIni[$i] -like "ScreenFormat=*") {
			$ScreenFormatFromScreen=$SetupIni[$i].Replace("ScreenFormat=","");
			Logi ("	Формат файла: "+$ScreenFormatFromScreen);
		}
	}
}else{
	Logi ($IniFileName+" не найден, установка прервана");
	SleepBreak
}

Logi ("")
Logi ("Добавление записи в реестр")
CreateRegParam
Logi ("	Запись добавлена")
Logi ("")
#Logi ("Поиск установленого .NET FrameWork 4.x")
#$NetCheck=gwmi win32_product -Filter "Name like 'Microsoft .NET Framework 4%'"
#if (!$NetCheck){
#	Logi ("	.NET FrameWork 4.x не установлен!");
#	if (Test-Path $NetFileInstall) {
#		$NetParams = @("/norestart")
#		Start-Process $NetFileInstall -ArgumentList $NetParams -Wait
#	}else{
#		Logi ("	Файл установщика .NET FrameWork 4.x не найден:")
#		Logi ($NetFileInstall)
#	}
#}else{
#	Logi ("	.NET FrameWork 4.x уже установлен!")
#}
logi ("Запуск программы")
	#$NetParams = @("-Arguments -Path `"$PathFromScreen`" -Interval `"$IntervalFromScreen`" -ScreenFormat `"$ScreenFormatFromScreen`"")
	$NetParams = @("-Arguments -File")
	Start-Process ($install_path+$FileName) -ArgumentList $NetParams
Logi ("Завершение установки...")
SleepBreak