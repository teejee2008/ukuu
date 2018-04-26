### Ubuntu Kernel Update Utility (Ukuu)

This is a tool for installing the latest mainline Linux kernel on Ubuntu-based distributions.

![](https://2.bp.blogspot.com/-76C_l3BcJyg/WNdzTpSoiKI/AAAAAAAAGKs/xOvB-LCH2cYiDpdbqWkeOLhY9I7TVACJwCLcB/s1600/ukuu_main_window.png)

### Features

*   Fetches list of kernels from [kernel.ubuntu.com](http://kernel.ubuntu.com/~kernel-ppa/mainline/)
*   Displays notifications when a new kernel update is available.
*   Downloads and installs packages automatically

### Screenshots

![](https://2.bp.blogspot.com/-76C_l3BcJyg/WNdzTpSoiKI/AAAAAAAAGKs/xOvB-LCH2cYiDpdbqWkeOLhY9I7TVACJwCLcB/s1600/ukuu_main_window.png)
_Main Window_

![](https://2.bp.blogspot.com/-ATv4vsOVOnc/WNdztEZHJNI/AAAAAAAAGKw/1pOIuyu8ITo4z8mnMK6MfCZ3T_Nd4gQNQCLcB/s1600/ukuu_settings.png)
_Settings Window_

![](https://4.bp.blogspot.com/-Y-1zhHcpk1M/WNd42_ybTyI/AAAAAAAAGLE/gLaBdWpoh54OGrvF81Ka1bCVJjZ0WqKrQCLcB/s1600/ukuu_console_options.png)
_Console Options_

### Installation

#### Ubuntu-based Distributions (Ubuntu, Linux Mint, Elementary, etc)  
Packages are available in Launchpad PPA for supported Ubuntu releases.
Run the following commands in a terminal window:  

    sudo apt-add-repository -y ppa:teejee2008/ppa
    sudo apt-get update
    sudo apt-get install ukuu

Ukuu should not be used on older Ubuntu systems as upgrading to very new kernels can break older systems.


#### Debian & Other Linux Distributions
This application fetches kernels from [kernel.ubuntu.com](http://kernel.ubuntu.com/~kernel-ppa/mainline/) which are provided by Canonical and meant for installation on Ubuntu-based distributions. These should not be used on Debian and other non-Ubuntu distributions such as Arch Linux, Fedora, etc.


### Downloads & Source Code 
Ukuu is written using Vala and GTK3 toolkit. Source code and binaries are available from the [GitHub project page](https://github.com/teejee2008/ukuu).

### Build instruction

#### Ubuntu-based Distributions (Ubuntu, Linux Mint, Elementary, etc)  

 in a terminal window:  

    sudo apt-get update libgee-0.8-dev libjson-glib-dev libvte-2.91-dev valac
    git clone https://github.com/teejee2008/ukuu.git
    cd ukuu
    make all
    sudo make install


### Support This Project

This software is free for personal and commercial use and is licensed under the GNU General Public License. If you find this software useful, you can buy me a coffee or make a donation via Paypal to show your support. This application is completely free and will continue to remain that way. Your contributions will help in keeping this project alive and developing it further. 

[![Donate with Paypal](https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg)](https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Ukuu%20Donation)

[![Become a Patron](https://2.bp.blogspot.com/-DNeWEUF2INM/WINUBAXAKUI/AAAAAAAAFmw/fTckfRrryy88pLyQGk5lJV0F0ESXeKrXwCLcB/s200/patreon.png)](https://www.patreon.com/bePatron?u=3059450)

Bitcoin: `13yAonCVMbBJ3imgPvB6qf9xyrqpoi6Dt5`

[![](https://4.bp.blogspot.com/-SyKu_mpsPRU/WNYU4qRbUtI/AAAAAAAAGKI/Gaq_AaWnjcQ9MOs55rG9T6U4TvqTitd3gCLcB/s1600/TeeJeeTech-19PWRpwfYA9Fgv6mwWTWGmESAiD5PtWuVJ.png)](bitcoin:13yAonCVMbBJ3imgPvB6qf9xyrqpoi6Dt5?message=Ukuu%20Donation&time=1490517862)

