# Import/Install Modules --------------------------------------------------------
Import-Module Posh-Git

# Setup Prompt -----------------------------------------------------------------
$GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

# PSReadline Mappings ----------------------------------------------------------
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord "Ctrl-n" -Function NextHistory
Set-PSReadLineKeyHandler -Chord "Ctrl-p" -Function PreviousHistory
Set-PSReadLineOption -PredictionSource None

# Remove Some Built-In Aliases -------------------------------------------------
Remove-Item alias:gc -Force
Remove-Item alias:gl -Force
Remove-Item alias:gp -Force
Remove-Item alias:sl -Force

# Misc -------------------------------------------------------------------------

# Stop highlighting directories, instead just change their colour
$PSStyle.FileInfo.Directory = "`e[32;1m";
$PSStyle.FileInfo.SymbolicLink = "`e[35;6m";

# Environment Variables --------------------------------------------------------
$vimrc = "~\Appdata\Local\nvim\init.lua"
$dotfiles = "~\projects\minimaleffort\dotfiles"

# System Aliases ---------------------------------------------------------------
Set-Alias -Name gh -Value Get-Help
Set-Alias -Name celar -Value clear
Set-Alias -Name claer -Value clear
Set-Alias -Name clea -Value clear
Set-Alias -Name celer -Value clear
Set-Alias -Name c -Value clear
Set-Alias -Name cls -Value clear
Set-Alias -Name sl -Value ls
Set-Alias -Name l -Value ls

# RC Aliases -------------------------------------------------------------------
function Edit-Profile() { nvim $profile }
Set-Alias -Name rc -Value Edit-Profile

function Edit-Vimrc() { nvim $vimrc }
Set-Alias -Name vimrc -Value Edit-Vimrc

function Update-Dotfiles() { Push-Location $dotfiles; git add -u; git commit -m "update dotfiles"; git pull; git push; Pop-Location; }

# Git Aliases ------------------------------------------------------------------
Set-Alias -Name g -Value git

function Invoke-GitStatus { git status }
Set-Alias -Name gst -Value Invoke-GitStatus

function Invoke-GitAdd { git add $args }
Set-Alias -Name ga -Value Invoke-GitAdd

function Invoke-GitCommit { git commit $args }
Set-Alias -Name gc -Value Invoke-GitCommit

function Invoke-GitPull { git pull $args }
Set-Alias -Name gl -Value Invoke-GitPull

function Invoke-GitPush { git push $args }
Set-Alias -Name gp -Value Invoke-GitPush

# Python Aliases ---------------------------------------------------------------
function Enter-VirtualEnv() {
    $venvpath = $(find -HI activate.ps1)
    if ( $venvpath ) {
        if ( ( $venvpath | Measure-Object | Select-Object Count ).Count -gt 1 ) {
            Write-Output "Enter number to select virtual environment: "
            $count = 1
            $venvpath | ForEach-Object { Write-Output "$count $_"; $count += 1; }
            $option = Read-Host
            Write-Output $venvpath[$option-1]
            Invoke-Expression "$venvpath[$option-1]"
        } else {
            Invoke-Expression "$venvpath"
        }
    } else { 
        Write-Output "Dind't find venv";
    }
}
Set-Alias -Name venv -Value Enter-VirtualEnv

# Vim Aliases ------------------------------------------------------------------
Set-Alias -Name v -Value nvim
Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim
Set-Alias -Name cim -Value nvim

# Misc Aliases ------------------------------------------------------------------
function Invoke-RipGrep() { rg -H --hidden --no-ignore $args }
Set-Alias -Name grep -Value Invoke-RipGrep

function Invoke-Find() { fd.exe -HIi $args }
Set-Alias -Name find -Value Invoke-FInd
