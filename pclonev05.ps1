# Workingdir pour tempporary files
$scriptPath = "c:\scripts\nsr\"
# Nombre de tape drives a utiliser
$parralelism = 4
# Pool de destination
$clonePool = "Tape Pool"
# Mettre a "yes" pour classer les SSIds par tailles et envoyer les plus gros de front en round robin sur lecteurs
$optimizeBackupWindow = "yes"
# A separer avec des virgules si plus de un storagenode ex. "1", "2", "3" etc.
#$storageNodes = "localhost"
$storageNodes = "localhost", "localhost2"
$storageNodesLength = $storageNodes.length



# C'est ici qu'il faut composer la commande "mminfo" qui nous donne les SSID a prendre en backup  
# Voir: https://nsrd.info/blog/2019/11/13/basics-diving-into-networker-virtual-machine-backup-details/
# et DELL EMC docu89898 "Command Reference Guide 302-004-422 REV 01"
# $NouveauBackups = 'mminfo -q "savetime>=48 hours ago,pool=Default" -r ssid'
   
# Si on desire classer les savesets en ordre decroissant par taille et ainsi sassurer de l'envoi des gros savesets sur differents lecteurs
# Desavatange: Risque accrus de placer deux systemes de fichier du meme serveur sur des cartouches differentes. (-(o)rder)
IF ($optimizeBackupWindow -eq 'yes'){
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
$storageNodeCompteur = 0
Foreach ($element in $s){
        
    $tapelist = $($s[$i])    
    # Write-Host "tapelist= $tapelist"
          
    # Algorithme de selection de storage node. On selectionne la premiere storage node, incremente le compteur 
    # soit la variable "storageNodeCompteur" de 1, et recommence. "storageNodeCompteur" est reinitialisé si son compte est plus 
    # grand que le nombre d'elements dans la liste de storage nodes disponible
    IF ($storageNodesLength -ge 2){
        #Write-host "i:$i,  storageNodeCompteur:$storageNodeCompteur"
        $myStorageNode=$($storageNodes[$storageNodeCompteur])
        Write-host "Plusieurs stgnode: $myStorageNode"
                
        $cmd =  "nsrclone -b '$clonepool' -J $myStorageNode -S $tapelist `n" 
            

        $storageNodeCompteur++
        If ($storageNodeCompteur -eq $storageNodesLength){
            $storageNodeCompteur = 0
        }
    # Si il y seulment un storage node, creation de la commande normalement
    ELSE{
        Write-Host "Un seul storage node: $storageNodes"
        $cmd =  "nsrclone -b '$clonepool' -J $storageNodes -S $tapelist"     
    }
    }

    
    Write-Host "cmd: $cmd"
    New-Item -path $scriptPath$i.ps1 -Force | Out-Null
    $cmd | Out-File -FilePath $scriptPath$i.ps1

    # Lancement du clonage en arriere plan
    #Invoke-Command -FilePath "$scriptpath\$i.ps1" -ComputerName localhost -AsJob
    #Write-Output $

    $i++   
}



