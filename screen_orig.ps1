#path - путь сохранения настроек
#Interval - в секундах между снимками
#ScreenFormat - расширение файла (jpeg,png,gif)
Param (
[string]$Path,
[string]$Interval,
[string]$ScreenFormat,
[switch]$File
)
#Переменные
$prg=${env:ProgramFiles}
$install_path=$prg+"\ScreenShoter\"
$IniFileName="screen.ini"
$LogFile = $install_path+"screen.log";
$pcName=$env:computername;
#При каждом запуске удаляем лог файл
if (Test-Path $LogFile) {
	Remove-Item $LogFile -Force | Out-Null
	New-Item -ItemType file $LogFile -Force | Out-Null
}else {
	try{
		new-item -path $install_path -name "screen.log" -type "file" -ErrorAction Stop
	}
	catch{
		Write-Host ("Не удалось создать файл лога. Журнал не ведется!!!")
	}
}
#Простая функция логирования текст на монитор и в файл
function Logi ($text) {
	Write-Host $text;
	if (Test-Path $LogFile) {
		Write-output $text | out-file "$LogFile" -APPEND
	}
}
#Паузе перед сбросом скрипта
function SleepBreak {
	Logi ("Завершение программы")
	Start-Sleep -Seconds 20
	break
}
#Если $File истина загрузить настройки из файла, иначе загрузить из параметров, иначе установить по умолчанию.
#Если файл не найден сброс
if ($File -eq $true) {
	if (Test-Path ($install_path+$IniFileName)) {
		Logi ("")
		Logi ("Чтение файла настроек...")
		$SetupIni=Get-Content ($install_path+$IniFileName);
		for ($i=0; $i -lt $SetupIni.count; $i++ ){
			if ($SetupIni[$i] -like "Path=*") {
				$Path=$SetupIni[$i].Replace("Path=","");
				Logi ("	Место сохранения скриншотов: "+$Path);
			}elseif ($SetupIni[$i] -like "Interval=*") {
				$Interval=$SetupIni[$i].Replace("Interval=","");
				Logi ("	Интервал съемки: "+$Interval+" сек.");
			}elseif ($SetupIni[$i] -like "ScreenFormat=*") {
				$ScreenFormat=$SetupIni[$i].Replace("ScreenFormat=","");
				Logi ("	Формат файла: "+$ScreenFormat);
			}
		}
	}else{
		Logi ($IniFileName+" не найден, работа прервана");
		SleepBreak
	}
}else{
	if ($Path -eq ""){
		$Path=$env:HOMEDRIVE;
		Logi("Программе не передан путь сохранения, будет использован стандартный: "+$Path)
	}

	if ($Interval -eq ""){
		$Interval=10;
		Logi("Программе не передан интервал сохранения, будет использован стандартный: "+$Interval)
	}

	if ($ScreenFormat -eq ""){
		$ScreenFormat="png";
		Logi("Программе не передан формат сохранения, будет использован стандартный: "+$ScreenFormat)
	}
}


[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
function screenshot{
	#Имя файла обновляется каждый вызов функции
	#будка_25-10-2015_22h12m08s123ms.jpg
	#$date_time = get-date -uformat "%Y.%m.%d_%H.%M%S";
	$date_time = (get-date -uformat "%d-%m-%Y_%Hh%Mm%Ss")+(get-date -Format "fff")+"ms";
	if ($ScreenFormat -eq "jpeg") {
		$ExtFile="jpg";
	}else{
		$ExtFile=$ScreenFormat;
	}
	$FullFileName=$Path+"\"+$pcName+"_"+$date_time+"."+$ExtFile;
	#Получаем размеры экрана
	$size = [Windows.Forms.SystemInformation]::VirtualScreen
	#Создаем объект, куда поместим картинку
	$bitmap = new-object Drawing.Bitmap $size.width, $size.height
	#Создаем объект Графики с привязкой к BitMap
	$graphics = [Drawing.Graphics]::FromImage($bitmap)
	#Попытка скопировать побитно экран в объект Графики
	try {
		$graphics.CopyFromScreen($size.location,[Drawing.Point]::Empty,$size.size)
		$bitmap.Save($FullFileName,[System.Drawing.Imaging.ImageFormat]::$ScreenFormat)
	}
	catch [System.Management.Automation.MethodInvocationException]{
		$except=$_;
		if (($except.InvocationInfo.Line).Replace("`t","") -eq '$bitmap.Save($FullFileName)'){
			if ($except.Exception.InnerException -like "*В GDI+ возникла ошибка общего вида.*") {
				Logi ($date_time+"	Ошибка записи")
			} else {
				Logi ($date_time+"	возникла другая ошибка при записи")
				Logi ($except.Exception.InnerException)
			}
		} elseif (($except.InvocationInfo.Line).Replace("`t","") -eq '$graphics.CopyFromScreen($size.location,[Drawing.Point]::Empty,$size.size)'){
			if ($except.Exception.InnerException -like "*Неверный дескриптор*") {
				Logi ($date_time+"	сеанс неактивен")
			} else {
				Logi ($date_time+"	непредвиденная ошибка снятия скриншота")
				Logi ($except.Exception.InnerException)
			}
		} else {
			Logi ("Возникла другая ошибка в строке: "+$except.InvocationInfo.Line)
		}
	}	catch {
		Logi ($date_time+"	возникла незарегистрированная ошибка")
		Logi ($_.Exception.InnerException)
	}	finally {
		#Зачистка памяти
		$graphics.Dispose()
		$bitmap.Dispose()
		[gc]::collect()
	}
}
#Получение скриншота при первом запуске программы
screenshot
#Бесконечный цикл
do{
	Start-Sleep -s $Interval.REplace("""","")
	screenshot
}while(0 -eq 0)
