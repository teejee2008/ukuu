## Selene Media Encoder

https://github.com/teejee2008/ukuu-media-converter

Selene is an audio/video converter for converting files to OGG/OGV/ MKV/MP4/WEBM/OPUS/AAC/FLAC/MP3/WAV formats. It aims to provide a simple GUI for converting files to popular formats along with powerful command-line options for automated/unattended encoding.  

## Features

*   Encode videos to MKV/MP4/OGV/WEBM formats.
*   Encode music to MP3/AAC/OGG/OPUS/FLAC/WAV formats.
*   Option to pause/resume encoding
*   Option to run in background and shutdown PC after encoding
*   Bash scripts can be written to control the encoding process
*   Commandline interface for unattended/automated encoding

## Screenshots

[![](http://4.bp.blogspot.com/-BWt4pvz8R8g/Vp-msmtA7AI/AAAAAAAADJA/U-_21n8zOWQ/s1600/Selene%2Bv2.6.1_048.png)](http://2.bp.blogspot.com/-UxD9mXgVBVQ/Vp-pl6D8JXI/AAAAAAAADJY/pCHkiNLuGIU/s1600/Preset_051.png)  
Main Window

[![](http://4.bp.blogspot.com/-NzQd2Lo-Pz8/Vp-oeWMNuHI/AAAAAAAADJU/pp9aEQRqq68/s1600/Selene%2Bv2.6.1_050.png)](http://4.bp.blogspot.com/-NzQd2Lo-Pz8/Vp-oeWMNuHI/AAAAAAAADJU/pp9aEQRqq68/s1600/Selene%2Bv2.6.1_050.png)  
Edit Preset

[![](http://2.bp.blogspot.com/-UxD9mXgVBVQ/Vp-pl6D8JXI/AAAAAAAADJY/pCHkiNLuGIU/s1600/Preset_051.png)](http://2.bp.blogspot.com/-UxD9mXgVBVQ/Vp-pl6D8JXI/AAAAAAAADJY/pCHkiNLuGIU/s1600/Preset_051.png)  
File Format Options

[![](http://3.bp.blogspot.com/-k-szDBOY2Q4/Vp-poa_vRKI/AAAAAAAADJg/c4eyonTPG0c/s1600/Preset_052.png)](http://3.bp.blogspot.com/-k-szDBOY2Q4/Vp-poa_vRKI/AAAAAAAADJg/c4eyonTPG0c/s1600/Preset_052.png)  
Audio Codec Options

[![](http://4.bp.blogspot.com/-QdLefZxWCu4/Vp-qrUxvM0I/AAAAAAAADJs/20A1TRqAYr4/s1600/Preset_054.png)](http://4.bp.blogspot.com/-QdLefZxWCu4/Vp-qrUxvM0I/AAAAAAAADJs/20A1TRqAYr4/s1600/Preset_054.png)  
SOX Audio Processing Options

[![](http://1.bp.blogspot.com/-qDYKAkW4mPo/Vp-qqq6hF4I/AAAAAAAADJo/ExmwI8E3bT0/s1600/Preset_053.png)](http://1.bp.blogspot.com/-qDYKAkW4mPo/Vp-qqq6hF4I/AAAAAAAADJo/ExmwI8E3bT0/s1600/Preset_053.png)  
Video Codec Settings

[![](http://3.bp.blogspot.com/-hJnbTOw5SoE/Vp-nrafetPI/AAAAAAAADJI/rHCIsNCY8C8/s1600/CPU%253A%2B95.00%2B-_049.png)](http://3.bp.blogspot.com/-hJnbTOw5SoE/Vp-nrafetPI/AAAAAAAADJI/rHCIsNCY8C8/s1600/CPU%253A%2B95.00%2B-_049.png)  
Progress Window

## Installation

### Ubuntu-based Distributions (Ubuntu, Linux Mint, etc)  
Packages are available in launchpad for supported Ubuntu releases.
Run the following commands in a terminal window:  

    sudo apt-add-repository -y ppa:teejee2008/ppa
    sudo apt-get update
    sudo apt-get install ukuu

For older Ubuntu releases which have reached end-of-life, you can install Selene using the DEB files linked below.    
[ukuu-latest-i386.deb](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-i386.deb?dl=1) (32-bit)  
[ukuu-latest-amd64.deb](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-amd64.deb?dl=1) (64-bit)  

### Debian
DEB files are available from following links:   
[ukuu-latest-i386.deb](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-i386.deb?dl=1) (32-bit)  
[ukuu-latest-amd64.deb](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-amd64.deb?dl=1) (64-bit)  

### Other Linux Distributions  
An installer is available from following links:   
[ukuu-latest-i386.run](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-i386.run?dl=1) (32-bit)  
[ukuu-latest-amd64.run](http://dl.dropbox.com/u/67740416/linux/ukuu-latest-amd64.run?dl=1) (64-bit)

Run it from a terminal window with the following commands:  

    sh ./ukuu-latest-i386.run  #32-bit
    sh ./ukuu-latest-amd64.run  #64-bit

Depending on the distribution that you are using, you may need to install packages for the following dependencies:  

    Required: libgtk-3 libgee2 libjson-glib rsync realpath libav-tools mediainfo
    Optional: vorbis-tools, opus-tools, vpx-tools, x264, lame, mkvtoolnix, ffmpeg2theora, gpac, sox 


## Source 
Selene is written using Vala and GTK. Source code is available from the project hosting page at Github:  
https://github.com/teejee2008/ukuu-media-converter

## AAC Encoding

For encoding to AAC/MP4 format you need to install the _NeroAAC_ encoder. Run the following commands in a terminal window. It will download and install the binaries for Nero AAC.  

    cd /tmp
    wget http://ftp6.nero.com/tools/NeroAACCodec-1.5.1.zip
    unzip -j NeroAACCodec-1.5.1.zip linux/neroAacEnc
    sudo install -m 0755 neroAacEnc /usr/bin
    sudo apt-get install gpac

## Usage

Drag audio/video files to the main window, select a script or preset from the drop-down and click 'Start' to begin. The progress window will display the progress for each file along with options to pause/resume encoding. Right-click on files in the main window for more options.  
Running the app in admin mode (using sudo or gksu) will enable additional options for running the conversion process with lower priority (background mode) and for shutting down the system after encoding.  

## Command-line Options

Selene can also be used as a normal command-line utility. Run Selene with the '--help' argument to see the full list of options.  

[![](http://1.bp.blogspot.com/-SR1Wk_3NGik/UfzUgy8NqTI/AAAAAAAABAk/XUxlyNdCPCU/s600/console_2.2.png)](http://1.bp.blogspot.com/-SR1Wk_3NGik/UfzUgy8NqTI/AAAAAAAABAk/XUxlyNdCPCU/s1600/console_2.2.png)  

## Using bash scripts for encoding

Bash scripts can be written for controlling the encoding process.  For example:

    x264 -o "${outDir}/${title}.mkv" "${inFile}"
    
This script converts any given input file to an MKV file using the x264 encoder.  
${inFile}, ${outDir}, ${title} are variables which refer to the input file. These variables will be inserted into the script before execution. It is mandatory to use these variables instead of hard-coding the input file names. This is the only restriction.  

The script can use _any_ command line utility (like ffmpeg, x264, etc) for converting the files. The progress percentage will be calculated automatically from the console output.  

If the encoding tool is a common tool (like ffmpeg or x264), ukuu will provide some additional features:  

*   The console output displayed in the statusbar will be pretty-formatted
*   The input files can be auto-cropped by replacing the cropping parameters specified in the script.  

## AutoCropping

For auto-cropping the input files:

1.  Select one or more files from the input list
2.  Right-click and select the AutoCrop option. This will automatically detect the black borders in the video and set the cropping parameters for the file.
3.  Select any preset, OR
4.  Select any script that uses avconv, x264 or ffmpeg2theora for encoding. The script must use the cropping option for the encoder that is used. For example, we can use:

        x264 --vf crop:0,0,0,0 -o "${outDir}/${title}.mkv" "${inFile}"

    The cropping values specified in the script will be replaced with the calculated values before the script is executed.

After using the 'AutoCrop' option, the output can be previewed by right-clicking the file and selecting the 'Preview Output' option. The values can be edited directly from the input file list. Clear the values to disable the cropping option.  

## Support This Project

This software is free for personal and commercial use and is licensed under the GNU General Public License. If you find this software useful and wish to support its development, please consider leaving a donation using the PayPal link below.  


This application is completely free and will continue to remain that way. Your contributions will help in keeping this project alive and improving it further. Feel free to send me an email if you find any issues in this application or if you need any changes. Suggestions and feedback are always welcome.

If you want to buy me a coffee or send some donations my way, you can use Google wallet or Paypal to send a donation to **teejeetech at gmail dot com**.  

[Donate with Paypal](https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Selene%20Donation)

[Donate with Google Wallet](https://support.google.com/mail/answer/3141103?hl=en)
