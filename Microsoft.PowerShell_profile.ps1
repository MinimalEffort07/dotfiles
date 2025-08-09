# Import/Install Modules --------------------------------------------------------
try {
    Import-Module Posh-Git
} catch {
    echo "Posh-Git is not installed, installing.."
    Install-Module posh-git -Scope CurrentUser -force
    Import-Module Posh-Git
}

# Setup Prompt -----------------------------------------------------------------
$GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true

# PSReadline Mappings ----------------------------------------------------------
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord "Ctrl-n" -Function NextHistory
Set-PSReadLineKeyHandler -Chord "Ctrl-p" -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord 'j' -ScriptBlock {
  if ([Microsoft.PowerShell.PSConsoleReadLine]::InViInsertMode()) {
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.Character -eq 'k') {
      [Microsoft.PowerShell.PSConsoleReadLine]::ViCommandMode()
    }
    else {
      [Microsoft.Powershell.PSConsoleReadLine]::Insert('j')
      [Microsoft.Powershell.PSConsoleReadLine]::Insert($key.Character)
    }
  }
}
Set-PSReadLineOption -PredictionSource None

# Remove Some Built-In Aliases -------------------------------------------------
del alias:gc -Force
del alias:gl -Force
del alias:gp -Force

# Misc -------------------------------------------------------------------------

# Stop highlighting directories, instead just change their colour
$PSStyle.FileInfo.Directory = "`e[32;1m";
$PSStyle.FileInfo.SymbolicLink = "`e[35;6m";

# Environment Variables --------------------------------------------------------
$vimrc = "~\Appdata\Local\nvim\init.lua"
$dotfiles = "~\projects\minimaleffort\dotfiles"

# System Aliases ---------------------------------------------------------------
Set-Alias -Name gh -Value Get-Help
Set-Alias -Name find -Value fd.exe
Set-Alias -Name celar -Value clear
Set-Alias -Name claer -Value clear
Set-Alias -Name celer -Value clear
Set-Alias -Name cls -Value clear

# RC Aliases -------------------------------------------------------------------
function Edit-Profile() { nvim $profile }
Set-Alias -Name rc -Value Edit-Profile

function Edit-Vimrc() { nvim $vimrc }
Set-Alias -Name vimrc -Value Edit-Vimrc

function Update-Dotfiles() { pushd $dotfiles; git add -u; git commit -m "update dotfiles"; git push; popd; }

# Git Aliases ------------------------------------------------------------------
Set-Alias -Name g -Value git

function Git-Status { git status }
Set-Alias -Name gst -Value Git-Status

function Git-Add { git add $args }
Set-Alias -Name ga -Value Git-Add

function Git-Commit { git commit $args }
Set-Alias -Name gc -Value Git-Commit

function Git-Pull { git pull $args }
Set-Alias -Name gl -Value Git-Pull

function Git-Push { git push $args }
Set-Alias -Name gp -Value Git-Push

# Python Aliases ---------------------------------------------------------------
function Enter-VirtualEnv() { $(find activate.ps1) }


# Vim Aliases ------------------------------------------------------------------
Set-Alias -Name v -Value nvim
Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim
