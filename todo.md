1) Rename install.sh to dotfiles and as part of install symlink it into /usr/bin 
or /usr/local/bin on mac.

2) Implement cli option parsing with optarg and compartmentalise some of the 
steps that don't need to be run every single time. As well as extra steps such 
as purging all the gnu-mv backup files which you only want to run when 
explicitly specified. 

3) Write brief description in the read me as to the different steps that the 
script takes to install and setup the system. 

3) Update all the existing 'mv' commands to use the GNU mv command with the 
backup flag. 
