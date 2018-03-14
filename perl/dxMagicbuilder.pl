use strict;
use warnings;
use POSIX qw(strftime);
use English qw(-no_match_vars);
use Carp;
use IPC::Open2;

# floss1138 ta liamg tod moc
# COPYRIGHT AND LICENSE
# Copyright (C) 2015, floss1138.

# This program is free software; you
# can redistribute it and/or modify it under the same terms
# as Perl 5.14.0.

# This program is distributed in the hope that it will be
# useful, but without any warranty; without even the implied
# warranty of merchantability or fitness for a particular purpose.

our $VERSION = '0.0.54';

# SERVER BUILD SCRIPT FOR dbDotCad & dxMagic  RUNNING ON Ubuntu server 12.04 to 16.04
# Installs mongodb, adds required perl modules, other Linux commands and Samba
# Creates a new Unix user $user and exports a Samba share for this users home directory
# THIS IS A BUILD SCRIPT AND IS INTENDED TO ONLY BE RUN ONCE
# run as root

## USER DEFINED VARIABLES HERE ##

# Specify user name used to create both a local (Unix) account and a samba user
my $user = 'alice';

# Specify the path to the appropriate required mongodb binary here:
# (check https://www.mongodb.org/downloads for the latest)
# For legacy Linux (that old laptop) https://fastdl.mongodb.org/linux/mongodb-linux-i686-3.0.2.tgz
my $mongodb_latest =
  'https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu1404-3.6.2.tgz';

#  Enable for dreamfactory 
# my $dream_bitnami = 
#  'https://bitnami.com/redirect/to/109810/bitnami-dreamfactory-2.2.0-0-linux-x64-installer.run'; 
#  'https://bitnami.com/redirect/to/124564/bitnami-dreamfactory-2.11.0-0-linux-x64-installer.run';

# Specify the names of ddc scripts to be downloaded
# $ddc_read is the script used to read attributes into the database
my $ddc_read = 'ddc_read32.pl';

# Specify the path to reach the above file on Github:
my $git_path =
  'https://raw.githubusercontent.com/floss1138/dbDotCad/master/perl/';

# Specify path to smb.conf
my $smb_conf = '/etc/samba/smb.conf';

## SAMBA SHARE CONFIGURATION

# Add [global] parameters here:
# Create a variable containing smb.conf additions (substituted  by matching on [global])

my $globaladditions = << "GLOBAL";
[global]
   follow symlinks = yes
   wide links = yes
   unix extensions = no
GLOBAL

# Specify samba share additions, these are added at the end of the smb.conf file
# /home/$user will be created by this script and shared by samba

my $smb_additions = << "ADDITIONS";

[$user]
   path = /home/$user/MyCAD
# dxMagic and dbDotCad are beneath the users home directory ~/MyCAD, so ~/ contents are not visible
   comment = $user user home directory
   writeable = yes
   valid users = $user

ADDITIONS

## STARTUP FILE

# Create a startup script file in /root for mongodb and other perl scripts
# To automate at boot add  '@reboot /root/startup.sh' to crontab

my $startup = << "START";
#!/bin/bash
sudo /root/mongodb/bin/mongod -f /root/mongodb/mongod.conf &
# sudo perl /home/user/script1.pl &
# sudo perl /home/user/script2.pl &

START

## --------------------------------------------------------------##
## PROGRAM STARTS HERE, DONT MESS WITH VARIABLES BELOW THIS LINE ##

## subroutine to change Apache document root

sub old_doc_root {
# For backward compatibility keep the old (Ubuntu 12) apache document root
# Change this back to /var/www in the conf file if its /var/www/html 

my $new_conf; # variable to hold config 
if ( !open my $DOCROOT, '<', '/etc/apache2/sites-available/000-default.conf' ) {
    print "\n /etc/apache2/sites-available/000-default.conf  would not open for reading \n";
    return '1';
}   
else {
    print "\n reading /etc/apache2/sites-available/000-default.conf \n";
    # slurp conf into $new_conf
    $new_conf = do {local $/ = undef; <$DOCROOT>} ;
    # replace /var/www/html with /var/www 
    $new_conf =~ s!/var/www/html!/var/www!xms;

    # if required print the new file content to screen
    # print "New conf is:\n$new_conf";
    
    close $DOCROOT or carp "Unable to close new_conf ";
    }
#  Now overwrite the file
if ( !open my $NEWROOT, '>', '/etc/apache2/sites-available/000-default.conf' ) {
    print "\n /etc/apache2/sites-available/000-default.conf  would not open for writing \n";

}
else {
    print "\n writing /etc/apache2/sites-available/000-default.conf with doc root /var/www\n";
    print $NEWROOT "$new_conf";
close $NEWROOT or carp "Unable to close new_conf ";
return '2';
    }
return '0';
}
# end of sub old_doc_root

# variable to hold contents of smb.conf file
my $smbconf;

# Find local ip address using hostname -I, and remove the new line

open2 my $out, my $in, "hostname -I"
  or die "hostname could not run";

my $ipaddress = <$out>;

# Remove any new line and space
chomp $ipaddress;
$ipaddress =~ s/\s+$//;

# date stamp when run to use as file name suffix
my $date_stamp = strftime( '%d%m%Y_%H%M%S', localtime );

# check the server build, just to terminal for reference
print "\n  ---- Local OS is ---\n";
system("lsb_release -a");
print "\n  --------------------\n";

print << "GREETINGS";
   
      *** WELCOME TO dxMagic & dbDotCad ****
         
   This script $PROGRAM_NAME V$VERSION 
   sets up an environment for dxMagic & dbDotCad running on Ubuntu.
   $PROGRAM_NAME is about to install dbdotcad onto host address: $ipaddress
   Created and tested for Ubuntu 12.04 64 bit server 
   14.04 32 bit desktop, 64 bit server & 15.04 & 16.04 64 bit server.
   MongoDB will be installed from: \n   $mongodb_latest \n
   The user, $user, will be created. Edit the \$user variable if you don't like $user ... 
   It is necessary to create passwords for the user account and share access.
   The script will pause at these points.  Account and samba passwords can be the same.
   Run this script as root.  If not already doing so,
   consider capturing the script output to a file e.g. 'script build_capture.txt'
   Press enter to continue or Ctrl C to bail ...
  
GREETINGS

local $| = 1;    # Flush STDIO prior to wait
my $wait = <STDIN>;    # Wait for Enter response

# CREATE A USER
# Check if the user already exists - if it does this script has been run before!
# In this case there should be a bail out option.

# check group file for user
open my $GROUPFILE, "<", "/etc/group" or die "Cannot open /etc/group: $!";
while (<$GROUPFILE>) {
    if ( $_ =~ m/($user)/ ) {
        print
"\n $user user already exist - this setup script has probably been run before.\n At the risk of mangling the current installation with repeated configuration, press Enter to continue or ctrl C to cancel > \n\n";
        close($GROUPFILE);
        $wait = <STDIN>;
    }
}

# Create the $user, -m to create a new home directory and -G to add to secondary group
system("sudo useradd -m $user -G users");
print
"\n $user user created & added to users group.\n The home directory /home/$user was also created \n";

# CREATE DIRECTORIES

print "\n creating local directories within /home/$user/";

# /media/data is the automounted partition - called data.
# These directories are symlinked later.  Using UPPERCASE for symlinked directories
# Create the directory where mongodb binaries will reside:
# system ("mkdir /root/mongodb"); # This is now created by renaming the extracted mongodb directory
# Create the user directories
# mkdir -p will create the intermediate directories, -m sets the mode using the same arguments as the chmod command

# All dbdotcad paths will need to change to be witn MyCAD
system("mkdir -p -m 755 /home/$user/MyCAD/dbdotcad");
system("mkdir -p -m 755 /home/$user/MyCAD/dxMagic");
system("mkdir -p -m 755 /home/$user/MyCAD/dbdotcad/attout_to_db");
# dxMagic will create the sub directories so may be no need to have them here:
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_pass");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_fail");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_xlsx");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_attin");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_attout");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_dxf4insert");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_insert_WATCH");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_extract_WATCH");
system("mkdir -m 755 /home/$user/MyCAD/dxMagic/dx_xlsx2txt_WATCH");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/done");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/failed");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/attout_to_xlsx");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/xlsx");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/attin");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/attvalid");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/send_for_review");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/TESTFILES");
system("mkdir -m 755 /home/$user/MyCAD/dbdotcad/TEMPLATES");
system("mkdir -p -m 755 /media/data/TESTFILES");
system("mkdir -p -m 755 /media/data/TEMPLATES");

# create symlinks from media mount point to local /home/$user - this is just for testing if smb can follow symlinks
system(
"sudo ln -s /media/data/TESTFILES/ /home/$user/dbdotcad/media_TESTFILES && sudo ln -s /media/data/TEMPLATES/ /home/$user/dbdotcad/media_TEMPLATES"
);

# change permissions (this will not change the symlink permissions itself, but the file pointed to, use chown -h for that)

system("sudo chown $user:$user /home/$user/MyCAD/dxMagic/*");
system("sudo chown $user:$user /home/$user/MyCAD/dbdotcad/*");
system("sudo chown $user:$user /home/$user/dbdotcad/*");
system("sudo chown $user:$user /media/data/*");
system("ls -al /home/$user");

# UNIX ENVIRONMENT - UPGRADE AND ADDITIONS

# install hh command, hstr https://github.com/dvorka/hstr, bash search history on steroids
print "\n Adding repository for hh\n";
system ("add-apt-repository ppa:ultradvorka/ppa");
# to make this active, apt-get update at some point before install hh

print "\n Updating with apt-get\n";
system("apt-get update");

print "\n Installing hh\n";
system ("apt-get install hh");

print "\n Now upgrading..... \n";
system("apt-get upgrade");

print "\n Installing tree command\n";
system("apt-get install tree");

print "\n Installing ssh (openssh-server\n";
system ("apt-get install openssh-server");
# dont seem to need "ufw allow 22"

print "\n Installing git-core\n";
system("sudo apt-get install git-core");

# git-core has been renamed to just git

print "\n Installing apache2\n";
system("apt-get install apache2");

# create log and cad file directores visible to apache
# by sym-linking into /var/www
# Then add an Alias in apache conf, making it look like /home/$user
# /var/www is created with the apache install above
# could try brace expansion, system("mkdir -m 755 /var/www/{ddclog,cad}");
system("mkdir -m 755 /var/www/ddclog");
system("mkdir -m 755 /var/www/cad");
system("ln -s /var/www/ddclog/ /home/alice/dbdotcad/ddclog");
system("ln -s /var/www/cad /home/alice/dbdotcad/cad");

# Add alias to make web url for log and cad files look like /home/user
# Apache on Ubuntu 12.04 worked with the alias in httpd.conf, later
# versions reqired this to be in apache2.conf, so here we do both ...
print "\n Adding Alias in apache2.conf & httpd.conf for log directory\n";
system(
"echo 'Alias /home/$user/dbdotcad/ddclog /var/www/ddclog' >> /etc/apache2/httpd.conf"
);

system(
"echo 'Alias /home/$user/dbdotcad/cad /var/www/cad' >> /etc/apache2/httpd.conf"
);
# Append to apaceh2.conf, echo. is used to add a blank line
system(
" echo '# Alias to user log and cad files' >> /etc/apache2/apache2.conf"
);

system(
"echo 'Alias /home/$user/dbdotcad/ddclog /var/www/ddclog' >> /etc/apache2/apache2.conf"
);

system(
"echo 'Alias /home/$user/dbdotcad/cad /var/www/cad' >> /etc/apache2/apache2.conf"
);


print
"\n Changing the dark blue characters in the shell terminal to cyan for ls (configured with /etc/DIR_COLORS)\n";

# This is .dir_colors on some other systems
system("echo 'DIR 01;36' >> /root/.dircolors");

# Hash this bit out if you dont use vim...
print "\n Installing vim\n";
system 'apt-get install vim';

print "\n Setting up vimrc for numbering and colorscheme ron \n";
system("echo 'set nu' >> /root/.vimrc");

# colourscheme(s) ron and elflord seem to work with perl
system("echo 'colorscheme ron' >> /root/.vimrc");

print "\n Changing the shell for $user to bash \n";
system("chsh -s /bin/bash $user");

print "\n Copying the root user .bashrc and .dircolors to /home/$user \n";

# Config files for new users could be put in /etc/skel - need to test this
system("cp /root/.bashrc /home/$user");
system("cp /root/.dircolors /home/$user");
system("cp /root/ .vimrc /home/$user");
system("chown $user:$user /home/$user/.bashrc");
system("chown $user:$user /home/$user/.profile");

print "\n Listing the $user home directory \n";
system(" ls -aln /home/$user; tree /home/$user");

print "\n Install docker \n";
system("apt install docker.io");


# PERL ENVIRONMENT

print "\n Setting up Perl Tidy\n";
system("apt-get install perltidy");

print "\n Setting up Perl Critic\n";
# system("apt-get install perl-Task-Perl-Critic");
# 14.04 and above use libperl-critic-perl
system("apt-get install libperl-critic-perl");

print "\n Installing cpanm\n";
system("apt-get install cpanminus");

# some server builds do not have 'make' by default
# the following modules require make to build
# apt-get will install a later version over an existing version if present

print "\n Installing 'make'\n";
system("apt-get install make");

print "\n Installing rxrx\n";
system("cpanm Regexp::Debugger");

# Install perldoc, handy to check installed modules with perldoc perllocal
print "\n Install perldoc\n";
system("apt-get install perl-doc");

# John McNamaras create XLSX format spreadsheets
print "\n Install Excel::Writer\n";
system("cpanm Excel::Writer::XLSX");

print "\n Install Spreadsheet::XLSX\n";
system("cpanm Spreadsheet::XLSX");

print "\n Install Spreadsheet::Read";
# The Read module had to be forced if an earlier version was present
system("cpanm Spreadsheet::Read");

# The Read module requires Spreadsheet::ParseXLSX to be installed 
system("cpanm -f Spreadsheet::ParseXLSX");

print "\n Install JSON module\n";
system("cpanm JSON"); 
 

# SAMBA ENVIRONMENT

print
  "\n Adding or updating, SMB/CIFS protocol for Windows interoperability \n";
system("apt-get install samba");

print "\n Provides SMB/CIFS file sharing with samba-common-bin \n";
system("apt-get install samba-common-bin");

print "\n Starting samba... \n";
system("service smbd start");

print "\n Make a copy of the /etc/samba/smb.conf file\n";
system("cp /etc/samba/smb.conf /etc/samba/smb.conf.$date_stamp");

print "\nSet smb passwd for $user\n";
system("sudo smbpasswd -a $user");

print "\nsmb password set for $user\n";
print "\nSet Unix password for $user\n";

system("sudo passwd $user");
print "\nUnix password set for $user\n";

# MODIFY smb.conf FILE
print "Adding global config for symlinks to smb.conf \n\n $globaladditions \n";

# open smb.conf for reading
if ( !open my $SMBCONF, '<', '/etc/samba/smb.conf' ) {
    print "\n  smb.conf would not open for reading \n";
}
else {
    print "\n reading smb.conf \n";

    # slurp smb.conf into $smbconf
    $/ = undef;

    $smbconf = <$SMBCONF>;

    # replace [global] with [global] and our additions
    $smbconf =~ s/\[global\]/$globaladditions/;

    # if required print the new file content to screen
    # print "$smbconf";

    close $SMBCONF or carp "Unable to close /etc/samba/smb.conf";

}

# Append $user share configuraton to smb.conf file

print
  "\n Adding $user additions: \n$smb_additions \n to end of smb.conf file \n\n";
$smbconf = $smbconf . $smb_additions;

# if required print the new file content to screen aganin...
print "$smbconf";

# open smb.conf for writing (overwriting the whole file) with the new content

print "\n Replacing smb.conf file.... \n\n";
if ( !open my $SMBCONF, '>', '/etc/samba/smb.conf' ) {
    print "\n  smb.conf would not open for writing\n";
}
else {

    # write new $smbconf  to the file handle
    print $SMBCONF "$smbconf";
    close $SMBCONF or carp "Unable to close /etc/samba/smb.conf";
}

# Restart samba to make new user config and password active

# On a RPi
# On Ubuntu server
# system ("sudo /etc/init.d/samba restart");
system("service smbd restart");
print "\nSamba restarted\n";

# MONGODB

# This script does not use apt-get, so the very latest build can be used
# This is installed to /root/mongodb and run stand alone
# This is not the way it should be run in production !
# It wont start from boot so add an @reboot to crontab if you need that

print "\n Now to download mongodb to /root/downloads, creating directory... \n";
system("mkdir -p /root/downloads && chmod 755 /root/downloads");

print "\n Fetching the latest mongo build with wget as mongodb.tgz \n";
system("wget -O /root/downloads/mongodb.tgz $mongodb_latest");

# Enable for dreamfactory
#print "\n Fetching the latest bitnami DreamFactory image with wget as dreamfactory.tgz \n";
#system("wget -O /root/downloads/dreamfactory $dream_bitnami");
#system("chmod 755 /root/downloads/dreamfactory");

print
"\n gunzipping the mongodb.tgz and extract mongodb.tar \n (creates directory names from within the tar name) \n\n";

# Extract the tar from the tgz
system("gunzip /root/downloads/mongodb.tgz; ");

# Extract the tar to /root/original_tarred_names
print "\n Extracting tar as /root/mongodb.tar \n";
system("tar -xvf /root/downloads/mongodb.tar -C /root");

# This extracts with the original name mongodb-linux-x86 etc, so for ease of use find the new name and change it to mongodb
# Note this will clutter your root directory !!  Will use the standard apt-get when V3 is available
print "\n Searching for mongodb-linux- directory\n  ";

opendir( DIR, "/root" );
while ( my $mongodir = readdir DIR ) {
    next if ( $mongodir eq "." or $mongodir eq ".." );

    if ( $mongodir =~ m/^mongodb-linux-/xsm ) {
        rename( "/root/$mongodir", '/root/mongodb' );
        print " Renamed extracted mongodb-linux- to mongodb...\n";
    }

}

print "\n mongodb binaries are in /root/mongodb,\n now creating /data/db \n";

system("mkdir -p /data/db && chmod 755 /data/db ");

print
  "\n Creating a specific directory for the mongod logs: /var/log/mongod/ \n";
system("mkdir /var/log/mongod");

print "\n Now creating mongo config file: /root/mongodb/mongod.conf \n";
system(
"echo 'httpinterface=true' >> /root/mongodb/mongod.conf; echo 'rest=true' >> /root/mongodb/mongod.conf; echo 'fork=true' >> /root/mongodb/mongod.conf; echo 'logpath=/var/log/mongod/mongod.log' >> /root/mongodb/mongod.conf"
);

# run mongodb with the --config or -f option to load the specified conf file, e.g. mongod --config /root/mongodb/mongod.conf
# $PATH is shell variable, from perl you should use it as perl variable $ENV{PATH}

# Set the path for mongodb
print "\n Adding /root/mongodb/bin to the path \n";

# THIS MIGHT NOT WORK FROM WITHIN THE SCRIPT
system("export PATH=/root/mongodb/bin:\$PATH");

# Add this to bashrc for next time...
system("echo 'export PATH=/root/mongodb/bin:\$PATH' >> /root/.bashrc");

# Now for a finishing message

print << "MESSAGE";

     ** About to start mongodb **
 Will now run mongod -f /root/mongodb/mongod.conf
 This forks the mongod daemon with:
 httpinterface enabled on localhost:28017
 Logging to /var/log/mongod/mongod.log

 If the log file cannot be created, the mongod fork will not work.
 This will exit with a general error,
 ERROR: child process failed, exited with error number 1
 If there is a mongod process already running, there will be an error 100
 ERROR: child process failed, exited with error number 100
 Journal directory is created when run, journal dir=/data/db/journal

 To stop the mongo process: mongod --shutdown
 To CIFS connect from Windows to $user home folder,
 click Start & in the search bar:

 \\\\$ipaddress\\$user

 or paste this into Windows Exporer, 
 user name $user & password will be required.
 reset the samba share password wth with: smbpasswd -a $user

 You might want to remove components left by the installation 
 rm -r /root/downloads
MESSAGE

print "\n Starting mongod \n";
system("/root/mongodb/bin/mongod -f /root/mongodb/mongod.conf");

print "Waiting a few seconds for mongod to start before testing ... \n";
sleep 3;

print "\n Test local conection \n";
system("nc -zvv localhost 27017");

print "\n Check smbstatus \n";
system("smbstatus");

# CREATE WEB INDEX PAGE
# dont expect the link back into user directories to work without more effort

# SUB TO CREATE INDEX
sub indexhtml {

    my $index_html = << "INDEX";
<head>
<meta http-equiv="X-Clacks-Overhead" content="GNU Terry Pratchett" />
<title>Welcome to dbBotCad</title>
</head>
<html><body>
<!-- <h1>Welcome to dbDotCad</h1> -->
<p>Server build created with  $PROGRAM_NAME V$VERSION </p>
<p>MongoDB installed from <br>$mongodb_latest</p>
<p><a href="/home/$user/dbdotcad/ddclog">users log files</a></p>
<p><a href="/home/$user/dbdotcad/cad">users cad files</a></p>
<p>To access SAMBA share from Windows, copy this link:</p><p>  \\\\$ipaddress\\$user </p>
<p>and paste into Windows Explorer (Windows key + E)<br> or <br> Click Start, then into 'Search programs and files' <br>
Now paste in the above link and press return. 
After AD and Provider Order time outs (corporate connections) the 'Enter Network Password' box should open <br>
After validation, the Explorer Window should show the users home directory. </p>
<p>To create a shortcut, hover over the folder icon in the Explorer window address bar and drag to Desktop, or drag to Favourites</p>
<p>In Windows, the shortcut link is a file so trying to save directly to the link has the side effect of giving the saved file the name of the folder by default<p>
<p>To preserve the original file name (in cases where the document/filename is not in the metadata) save attributes to a local folder then drag and drop into the shortcut<p>
<p>On a Mac, Open Finder > Go, Connect to Server (Command + K), use the following link:</p>
<p>   smb://$ipaddress/$user</p><p>Verify user name and password.
</body></html>

INDEX

    # open index.html for writing
    if ( !open my $INDEX_HTML, '>', '/var/www/index.html' ) {
        print "\n  index.html would not open for reading \n";
    }
    else {
        print "\n Writing index.html - check it out at http://$ipaddress/\n";
        print $INDEX_HTML "$index_html";

        close $INDEX_HTML or carp "Unable to close /var/www/index.html";

    }
}

# End of indexhtml subroutine

# call indexhtml creation subroutine
indexhtml;


#  Define Apache document root (as older /var/www used in Ubuntu 12)
old_doc_root ();
# Needs a restart or graceful reload...

# Reload apache to make any conf changes active
system("apache2ctl graceful");

# CREATE OTHER SCRIPTS

print "\n Creating a startup shell script as /root/startup.sh \n";

if ( !open my $STARTUP, '>', '/root/startup.sh' ) {
    print "\n  /root/startup.sh would not open for writing\n";
}

# write $startup to start.sh file and make it executable
# then edit crontab to run this @reboot

else {
    print $STARTUP "$startup";
    system("chmod 755 /root/startup.sh");
    close $STARTUP or carp "Unable to close /root/startup.sh";
}

print
" Editing crontab, use crontab -e to change \@reboot /root/startup.sh\n if required \n";

system("crontab -l > cronaddition");
system("echo '\@reboot /root/startup.sh' >> cronaddition");
system("crontab cronaddition");

# rm cronaddition if necessary

print
  "\n Creating javascript /root/mongodb/ddc_create.js to initialize database\n";

# SUB TO CREATE INITIALIZE JAVA SCRIPT

sub ddc_initialize {

# This script is used with the mongo command to create the ddc database
# printjson is required to see the output if calling script via 'mongo dbname script.js'
# usage, /pathto/mongo ddc /pathto/create_ddc.js
# dbname is specified after mongo command as defining this in the script e.g.
# db = getSiblingDB('ddc'); //use ddc// [must use single quotes around database name]
# does not work unless the database already exists
# db must contain an entry in order to display with show db, so insert dummy document(s) before show dbs
# my $ddc_create = 'some text string';

    my $ddc_create = << 'TAG';
    // create_ddc.js
    // -------//
    
    db.ddc_testblock.insert({"_id" : "'deleteme_id1", "author" : "floss1138", "language" : "javascript", "mission" : "Global domination"});
    db.ddc_testblock.insert({"_id" : "'deleteme_id2", "author" : "floss1139", "language" : "javascript", "mission" : "Global defence"});
    db.ddc_testblock.insert({"_id" : "'deleteme_id3", "author" : "floss1140", "language" : "javascript", "mission" : "Global destruction"});
    
    // now test to see if this worked
    printjson(db.adminCommand('listDatabases')); // show dbs
    printjson(db.getCollectionNames()); // show collections or tables
    
TAG

    # open ddc_create.js for writing
    if ( !open my $JS, '>', '/root/mongodb/ddc_create.js' ) {
        print "\n  ddc_create.js would not open for writing \n";
    }
    else {
        print "\n Writing ddc_create.js \n";
        print $JS "$ddc_create";

        close $JS or carp "Unable to close /root/mongodb/ddc_create.js\n";

    }
}

# End of ddc_initalize sub routine

ddc_initialize;

print
"ddc_create.js ready to run, running '/root/mongodb/bin/mongo ddcBLOCKS /root/mongodb/ddc_create.js' to create ddcBLOCK and ddcMBLOCK database...\n";

# print "I think ... this hung if executed after after a pause using <STDIN>\n";
system("/root/mongodb/bin/mongo ddcBLOCKS /root/mongodb/ddc_create.js");
system("/root/mongodb/bin/mongo ddcMBLOCKS /root/mongodb/ddc_create.js");

print "\nFetching dbdotcad read script $ddc_read from Git Hub\n";
my $fetch = $git_path . $ddc_read;
system("wget $fetch");

print "\nDownloading CAD files to /home/$user/dbdotcad/cad/ ...\n";

system(
"wget -P /home/$user/dbdotcad/cad/ https://github.com/floss1138/dbDotCad/blob/master/cad/0-0-0-0_A_ddc_title_and_filename_blocks.dwg"
);

system(
"wget -P /home/$user/dbdotcad/cad/ https://github.com/floss1138/dbDotCad/blob/master/cad/cadfiles.zip"
);

print "\nRunning dbdotcad $ddc_read with the -c create conf option\n";
system("perl $ddc_read -c");

# Add the readme to the web page:
# system ("wget -P /var/www/  https://github.com/floss1138/dbDotCad/blob/master/README.md");

# Enable for dreamfactory
# print "\nNow setup DreamFactory - select 8080 for the web port and /opt/dreamfactory for the installation path\n";
# system ("/root/downloads/dreamfactory");


print << "GOODBYE";

*** THE END *** 

If capturing the script output, you may want to cancel that now ...
Reload the shell to take advantage of the new path  source ~/.bashrc 
The script should have created a test db, check and modify entries:
/root/mongodb/bin/mongo
use ddcBLOCKS
db.ddc_testblock.find()
db.ddc_testblock.update({ "_id" : "'deleteme_id1"}, { "mission" : "Local confusion" })

Check http://$ipaddress/
then run $ddc_read ...

To enable to root account on Ununtu Server, sudo passwd root.
To enable root ssh sudo vi /etc/ssh/sshd_config, PermitRootLogin yes, service ssh restart.
From /root, git clone https://ghithub.com/floss1138/dbDotCad 
Configure git:
git config --global email.address floss1138\@gmail.com
git config --global user.name "floss1138"

*** Live Long and Prosper ***

GOODBYE

# Check DreamFactory is running and set up the admin account on
# https://$ipaddress/:8080


exit 0;

__END__

POINTS OF NOTE:
If the path is not working, start mongodb as:
/root/mongodb/bin/mongod --config /root/mongodb/mongod.conf
-f can be used instead of --config

Edit the crontab to run the script at boot time, using crontab -e for the root user:
@reboot /home/user/startup.sh
and check it with crontab -l 

Dont try and use 'system' for cd or path changes as it only changes the sub shell running the script and not the root shell,
perl has its own chdir commands for that.

Consider samba security:
usershare allow guests = yes # change to no
#   security = user # enable as we are using a user account

Apaceh2
Apache2 document root is defined in:
/etc/apache2/sites-available/default
The default created by the installation is:
/var/www/index.html

TODO 

ADD SUB TO CREATE AN INITIAL WEB PAGE

sub indexhtml {

my $index_html = << "INDEX";
<html><body><h1>Welcome to dbDotCad</h1>
<p>Created with  $PROGRAM_NAME V$VERSION </p>
<a href="/sent_for_review/">Sent for review folder test link</a>
<p>Link to samba share:  \\\\$ipaddress\\$user </p>
</body></html>

INDEX


# open index.html for writing
if ( !open my $INDEX_HTML, '>', '/var/www/index.html' ) {
    print "\n  index.html would not open for reading \n";
}
else {
    print "\n Writing index.html \n";
 print $INDEX_HTML "$index_html";
 
    close $INDEX_HTML or carp "Unable to close /var/www/index.html";

}
}

REMOVE MONGO ERROR

WARNING: /sys/kernel/mm/transparent_hugepage/defrag is 'always'

Official MongoDB documentation gives several solutions for this issue. You can also try this solution, which worked for me:

1.Open /etc/init/mongod.conf file.

2.Add the lines below immediately after chown $DEAMONUSER /var/run/mongodb.pid and before end script.

3.Restart mongod (service mongod restart).
Here are the lines to add to /etc/init/mongod.conf:

if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

SCRIPT ERRORS

wget operations need a tidy up.  curl might be better.

APACHE2 DOCUMENT ROOT

Ubuntu 14 with apache2 has changes the document root to 
/var/www/html (created on install)
This can be changed back again in
/etc/apache2/sites-available/000-default.conf
after a apache2ctl restart
old_doc_root () sub routing added to achieve this.
