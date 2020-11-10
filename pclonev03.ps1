# Workingdir pour tempporary files
$scriptpath = "c:\scripts\nsr\"
# Nombre de tape drives a utiliser
$parralelism = 4
# Pool de destination
$clonepool = "Tape Pool"
# Mettre a "yes" pour classer les SSIds par tailles et envoyer les plus gros de front en round robin sur lecteurs
$OptimizeBackupWindow = "yes"
# A separer avec des virgules si > 1
$storagenode = "localhost", "2iemehost"

# C'est ici qu'il faut composer la commande "mminfo" qui nous donne les SSID a prendre en backup  
# Voir: https://nsrd.info/blog/2019/11/13/basics-diving-into-networker-virtual-machine-backup-details/
# et DELL EMC docu89898 "Command Reference Guide 302-004-422 REV 01"
# $NouveauBackups = 'mminfo -q "savetime>=48 hours ago,pool=Default" -r ssid'
   
# Si on desire classer les savesets en ordre decroissant par taille et ainsi sassurer de l'envoi des gros savesets sur differents lecteurs
# Desavatange: Risque accrus de placer deux systemes de fichier du meme serveur sur cartouches differentes
IF ($OptimizeBackupWindow -eq 'yes'){
    $NouveauBackups = 'mminfo -q "savetime<=4 hours ago,pool=Default" -r "ssid" -o lR'
}

ELSE{
    $NouveauBackups = 'mminfo -q "savetime>=48 hours ago,pool=Default" -r ssid'
}
$2 = Invoke-Expression $NouveauBackups


# Fonction pour répartir les ssid en plusieurs listes
function Split-array 
{

  param($inArray,[int]$parts,[int]$size)
  
  if ($parts) {
    $PartSize = [Math]::Ceiling($inArray.count / $parts)
  } 
  if ($size) {
    $PartSize = $size
    $parts = [Math]::Ceiling($inArray.count / $size)
  }

  $outArray = New-Object 'System.Collections.Generic.List[psobject]'

  for ($i=1; $i -le $parts; $i++) {
    $start = (($i-1)*$PartSize)
    $end = (($i)*$PartSize) - 1
    if ($end -ge $inArray.count) {$end = $inArray.count -1}
	$outArray.Add(@($inArray[$start..$end]))
  }
  return ,$outArray

}


# Utilisation de la fonction Split-Array pour séparer les ssid en nombres de listes spécifié par la variable
# $parralelism. Output un Array de Array accessible par $s[0-n] Permet de lancer les processus nsrclone paralèlles.
$s = Split-array -inArray $2 -parts $parralelism 
Write-Host "Utilisation de [$parralelism] lecteurs LTO en parralele."



$i = 0
Foreach ($element in $s){
    
    # $tapelist = $($s[$i] -join ' ')
    $tapelist = $($s[$i])
    New-Item -path $scriptpath$i.ps1 -Force | Out-Null
    # Write-Host "tapelist= $tapelist"
            
    # Construire la commande nsrclone et ecriture sur disque
    # Permet la repartition des SSIDs sur plusieurs storages nodes en round dobin
    IF($i % 2 -eq 0)
        {write-host "Loop $i est PAIR"
        write-host "Storagenode: storagenode1"
        $cmd =  "nsrclone -b '$clonepool' -J storagenode1 -S $tapelist"}
    ELSE
        {write-host "Loop $i est IMPAIR"
        $cmd =  "nsrclone -b '$clonepool' -J storagenode2 -S $tapelist"
        write-host "Storagenode: storagenode2"}

    
    #$cmd =  "nsrclone -n -b 'Tape Pool' -S $tapelist"
    #$cmd =  "nsrclone -b '$clonepool' -S $tapelist"
    Write-Host "cmd: $cmd"
    $cmd | Out-File -FilePath $scriptpath$i.ps1

    # Lancement du clonage en arriere plan
    #Invoke-Command -FilePath "$scriptpath\$i.ps1" -ComputerName localhost -AsJob
    #Write-Output $

    $i++   
}



