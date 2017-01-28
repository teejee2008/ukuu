/*
 * AptikConsole.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using GLib;
using Gtk;
using Gee;
using Soup;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Ubuntu Kernel Update Utility";
public const string AppShortName = "ukuu";
public const string AppVersion = "17.2";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

public class AppConsole : GLib.Object {

	public static int main (string[] args) {
		set_locale();

		Gtk.init(ref args);

		init_tmp(AppShortName);

		//check_if_admin();
		
		LOG_TIMESTAMP = false;

		App = new Main(args, false);
		
		var console =  new AppConsole();
		bool is_success = console.parse_arguments(args);
		//App.exit_app();

		App.fix_startup_script_error();

		return (is_success) ? 0 : 1;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "ukuu");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	private static string help_message() {
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejeetech@gmail.com)" + "\n";
		msg += "\n";
		msg += _("Syntax") + ": ukuu [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --check           " + _("Check for kernel updates") + "\n";
		msg += "  --notify          " + _("Notify if kernel update is available") + "\n";
		msg += "  --list            " + _("List all available mainline kernels") + "\n";
		msg += "  --install <name>  " + _("Install specified mainline kernel") + "\n";
		msg += "  --remove <name>   " + _("Remove specified mainline kernel") + "\n";
		msg += "  --download <name> " + _("Download packages for specified kernel") + "\n";
		msg += "  --user <username> " + _("Use specified user's cache directory") + "\n";
		msg += "  --clean-cache     " + _("Remove files from application cache") + "\n";
		msg += "\n";
		return msg;
	}

	private static void check_if_admin(){
		if (!user_is_admin()) {
			string msg = _("Admin access is required for running this application.") + "\n";
			msg += _("Run the application as root or using gksu/sudo.");
			log_msg(msg);
			exit(0);
		}
	}

	public bool parse_arguments(string[] args) {

		bool show_desc = false;
		bool no_prompt = false;
		bool ok = false;

		// check argument count -----------------
		
		if (args.length == 1) {
			//no args given
			log_msg(help_message());
			return false;
		}

		// parse options first --------------
		
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {
			case "--debug":
				LOG_DEBUG = true;
				break;
			case "--user":
				string custom_user_login = args[++k];
				App.init_paths(custom_user_login);
				App.load_app_config();
				break;
			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				return true;
			}
		}

		log_msg(_("Using cache directory") + ": %s".printf(LinuxKernel.CACHE_DIR));

		// then parse commands ---------------------------
		
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {

			// commands ------------------------------------
			
			case "--check":
			case "--list":
			
				check_if_internet_is_active();
				
				LinuxKernel.query(true);
				
				LinuxKernel.print_list();

				break;

			case "--notify":

				check_if_internet_is_active();
				
				LinuxKernel.query(true);
				
				notify_user();
				
				break;

			case "--clean-cache":

				LinuxKernel.clean_cache();
				
				break;

			case "--download":
			case "--install":
			case "--remove":

				check_if_admin();

				check_if_internet_is_active();
				
				LinuxKernel.query(true);
			
				k++;

				LinuxKernel kern_requested = null;
				string requested_version = args[k];
				foreach(var kern in LinuxKernel.kernel_list){
					if (kern.name == requested_version){
						kern_requested = kern;
						break;
					}
				}

				if (kern_requested == null){
					
					var msg = _("Could not find requested version");
					msg += ": %s".printf(requested_version);
					log_error(msg);
					
					log_error(_("Run 'ukuu --list' and use the version string listed in first column"));
					
					exit(1);
				}

				if (args[k-1] == "--remove"){
					return kern_requested.remove(true);
				}
				else if (args[k-1] == "--install"){
					return kern_requested.install(true);
				}
				else{
					return kern_requested.download_packages();
				}

			// options without argument --------------------------
			
			case "--option-without-argument": //dummy
			case "--help":
			case "--h":
			case "-h":
			case "--debug":
				// already handled - do nothing
				break;

			// options with argument --------------------------

			case "--option-with-argument": //dummy
			case "--user":
				k += 1;
				// already handled - do nothing
				break;

			default:
				//unknown option - show help and exit
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				log_msg(help_message());
				return false;
			}
		}

		return true;
	}

	private void notify_user(){

		LinuxKernel.check_updates();

		var kern = LinuxKernel.kernel_update_major;
		if ((kern != null) && App.notify_major){
			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Major update available for installation";

			if (App.notify_bubble){
				OSDNotify.notify_send(title,message,3000,"normal","info");
			}
			
			if (App.notify_dialog){
				
				var win = new UpdateNotificationWindow(
					AppName,
					"<span size=\"large\" weight=\"bold\">%s</span>\n\n%s".printf(title, message),
					null,
					kern);
					
				win.destroy.connect(()=>{
					log_debug("UpdateNotificationWindow destroyed");
					Gtk.main_quit();
				});
				
				Gtk.main(); // start event loop
			}
			
			log_msg(title);
			log_msg(message);
			return;
		}

		kern = LinuxKernel.kernel_update_minor;
		if ((kern != null) && App.notify_minor){
			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Minor update available for installation";

			if (App.notify_bubble){
				OSDNotify.notify_send(title,message,3000,"normal","info");
			}
			
			if (App.notify_dialog){
				
				var win = new UpdateNotificationWindow(
					AppName,
					"<span size=\"large\" weight=\"bold\">%s</span>\n\n%s".printf(title, message),
					null,
					kern);
					
				win.destroy.connect(()=>{
					log_debug("UpdateNotificationWindow destroyed");
					Gtk.main_quit();
				});
				
				Gtk.main(); // start event loop
			}
			
			log_msg(title);
			log_msg(message);
			return;
		}

		// dummy

		/*
		var title = "Linux v4.7 Available";
		var message = "Minor update available for installation";
		
		if (App.notify_bubble){
			OSDNotify.notify_send(title,message,3000,"normal","info");
		}
		
		if (App.notify_dialog){
			
			var win = new UpdateNotificationWindow(
					AppName,
					"<span size=\"large\" weight=\"bold\">%s</span>\n\n%s".printf(title, message),
					null);
					
			win.destroy.connect(Gtk.main_quit);
			Gtk.main(); // start event loop
		}
		* */

		log_msg(_("No updates found"));
	}


	public void check_if_internet_is_active(){
		if (!check_internet_connectivity()){
			log_error(_("Internet connection is not active"));
			App.fix_startup_script_error();
			exit(1);
		}
	}
}

