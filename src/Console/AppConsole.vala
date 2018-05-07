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
public const string AppVersion = "18.5";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

public class AppConsole : GLib.Object {

	public static int main (string[] args) {
		
		set_locale();

		log_msg("%s v%s".printf(AppShortName, AppVersion));

		init_tmp("ukuu");

		//check_if_admin();
		
		LOG_TIMESTAMP = false;

		App = new Main(args, false);
		
		var console =  new AppConsole();
		bool is_success = console.parse_arguments(args);

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
		msg += _("Syntax") + ": ukuu <command> [options]\n";
		msg += "\n";
		msg += _("Commands") + ":\n";
		msg += "\n";
		msg += "  --check             " + _("Check for kernel updates") + "\n";
		msg += "  --notify            " + _("Check for kernel updates and notify current user") + "\n";
		msg += "  --list              " + _("List all available mainline kernels") + "\n";
		msg += "  --list-installed    " + _("List installed kernels") + "\n";
		msg += "  --install-latest    " + _("Install latest mainline kernel") + "\n";
		msg += "  --install-point     " + _("Install latest point update for current series") + "\n";
		msg += "  --install <name>    " + _("Install specified mainline kernel") + "\n";
		msg += "  --remove <name>     " + _("Remove specified kernel") + "\n";
		msg += "  --purge-old-kernels " + _("Remove installed kernels older than running kernel") + "\n";
		msg += "  --download <name>   " + _("Download packages for specified kernel") + "\n";
		msg += "  --clean-cache       " + _("Remove files from application cache") + "\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --clean-cache     " + _("Remove files from application cache") + "\n";
		msg += "  --yes             " + _("Assume Yes for all prompts (non-interactive mode)") + "\n";
		msg += "\n";
		msg += "Notes:\n";
		msg += "1. Comma separated list of version strings can be specified for --remove and --download\n";
		return msg;
	}

	private static void check_if_admin(){
		
		if (get_user_id_effective() != 0) {

			log_msg(string.nfill(70,'-'));
			
			string msg = _("Admin access is required for running this application.");
			log_error(msg);
			
			msg = _("Run the application as admin with pkexec or sudo.");
			log_error(msg);
			
			exit(1);
		}
	}

	public bool parse_arguments(string[] args) {

		string txt = "ukuu ";
		for (int k = 1; k < args.length; k++) {
			txt += "'%s' ".printf(args[k]);
		}
		log_debug(txt);
		
		// check argument count -----------------
		
		if (args.length == 1) {
			//no args given
			log_msg(help_message());
			return false;
		}

		string cmd = "";
		string cmd_versions = "";
			
		// parse options first --------------
		
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {
			case "--debug":
				LOG_DEBUG = true;
				break;

			case "--yes":
				App.confirm = false;
				break;
				
			case "--user":
				if (++k < args.length){
					string custom_user_login = args[k];
					App.init_paths(custom_user_login);
					App.load_app_config();
				}
				break;

			case "--list":
			case "--list-installed":
			case "--check":
			case "--notify":
			case "--install-latest":
			case "--install-point":
			case "--purge-old-kernels":
			case "--clean-cache":
				cmd = args[k].down();
				break;
			
			case "--download":
			case "--install":
			case "--remove":
				cmd = args[k].down();
				
				if (++k < args.length){
					cmd_versions = args[k];
				}
				break;

			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				return true;
				
			default:
				// unknown option
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				log_error(_("Run 'ukuu --help' to list all options"));
				return false;
			}
		}

		log_msg(_("Cache") + ": %s".printf(LinuxKernel.CACHE_DIR));
		log_msg(_("Temp") + ": %s".printf(TEMP_DIR));

		// run command --------------------------------------
		
		switch (cmd) {
		case "--list":
		
			check_if_internet_is_active(false);
			
			LinuxKernel.query(true);
			
			LinuxKernel.print_list();

			break;

		case "--list-installed":
		
			LinuxKernel.check_installed();
			
			break;

		case "--check":

			print_updates();

			break;

		case "--notify":

			notify_user();
			
			break;

		case "--install-latest":

			check_if_admin();

			check_if_internet_is_active(true);

			LinuxKernel.install_latest(false, App.confirm);
			
			break;

		case "--install-point":

			check_if_admin();

			check_if_internet_is_active(true);

			LinuxKernel.install_latest(true, App.confirm);

			break;

		case "--purge-old-kernels":

			check_if_admin();

			LinuxKernel.purge_old_kernels(App.confirm);

			break;
			
		case "--clean-cache":

			LinuxKernel.clean_cache();
			
			break;

		case "--download":
		case "--install":
		case "--remove":

			check_if_admin();

			if ((cmd == "--install") || (cmd == "--download")){
				check_if_internet_is_active();
			}
			
			LinuxKernel.query(true);

			if (cmd_versions.length == 0){
				log_error(_("No kernels specified"));
				exit(1);
			}

			string[] requested_versions = cmd_versions.split(",");
			if ((requested_versions.length > 1) && (cmd == "--install")){
				log_error(_("Multiple kernels selected for installation. Select only one."));
				exit(1);
			}

			var list = new Gee.ArrayList<LinuxKernel>();

			foreach(string requested_version in requested_versions){
				
				LinuxKernel kern_requested = null;
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

				list.add(kern_requested);
			}

			if (list.size == 0){
				log_error(_("No kernels specified"));
				exit(1);
			}

			switch(cmd){
			case "--download":
				return LinuxKernel.download_kernels(list);
	
			case "--remove":
				return LinuxKernel.remove_kernels(list);
				
			case "--install":
				return list[0].install(true);
			}

			break;
			
		default:
			// unknown option
			log_error(_("Command not specified"));
			log_error(_("Run 'ukuu --help' to list all commands"));
			break;
		}

		return true;
	}

	private void print_updates(){

		check_if_internet_is_active(false);
				
		LinuxKernel.query(true);

		LinuxKernel.check_updates();

		var kern_major = LinuxKernel.kernel_update_major;
		
		if (kern_major != null){
			var message = "%s: %s".printf(_("Latest update"), kern_major.version_main);
			log_msg(message);
		}

		var kern_minor = LinuxKernel.kernel_update_minor;

		if (kern_minor != null){
			var message = "%s: %s".printf(_("Latest point update"), kern_minor.version_main);
			log_msg(message);
		}

		if ((kern_major == null) && (kern_minor == null)){
			log_msg(_("No updates found"));
		}

		log_msg(string.nfill(70, '-'));
	}

	private void notify_user(){

		check_if_internet_is_active(false);
				
		LinuxKernel.query(true);

		LinuxKernel.check_updates();

		var kern = LinuxKernel.kernel_update_major;
		
		if ((kern != null) && App.notify_major){
			
			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Major update available for installation";

			if (App.notify_bubble){
				OSDNotify.notify_send(title,message,3000,"normal","info");
			}

			log_msg(title);
			log_msg(message);
			
			if (App.notify_dialog){
				exec_script_async("ukuu-gtk --notify");
				exit(0);
			}

			return;
		}

		kern = LinuxKernel.kernel_update_minor;
		
		if ((kern != null) && App.notify_minor){
			
			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Minor update available for installation";

			if (App.notify_bubble){
				OSDNotify.notify_send(title,message,3000,"normal","info");
			}

			log_msg(title);
			log_msg(message);
			
			if (App.notify_dialog){				
				exec_script_async("ukuu-gtk --notify");
				exit(0);
			}

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

	public void check_if_internet_is_active(bool exit_app = true){
		
		if (!check_internet_connectivity()){
			
			App.fix_startup_script_error();
			
			if (exit_app){
				exit(1);
			}
		}
	}

}

