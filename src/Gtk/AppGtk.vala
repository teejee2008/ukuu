/*
 * AppGtk.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Ubuntu Kernel Update Utility";
public const string AppShortName = "ukuu";
public const string AppVersion = "16.7.2";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

public class AppGtk : GLib.Object {

	public static int main (string[] args) {
		set_locale();

		Gtk.init(ref args);

		init_tmp(AppShortName);
		
		//check_if_admin();

		LOG_TIMESTAMP = false;

		//check dependencies
		string message;
		if (!Main.check_dependencies(out message)) {
			gtk_messagebox("", message, null, true);
			exit(0);
		}

		App = new Main(args, true);
		parse_arguments(args);

		var window = new MainWindow ();
		window.destroy.connect(()=>{
			log_debug("MainWindow destroyed");
			Gtk.main_quit();
		});
		window.delete_event.connect((event)=>{
			log_debug("MainWindow closed");
			Gtk.main_quit();
			return true;
		});
		
		if (!App.INSTALL_MODE){
			window.show_all();
		}

		//start event loop
		Gtk.main();

		App.save_app_config();

		return 0;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "ukuu");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public static void check_if_admin(){
		if (!user_is_admin()) {
			string msg = _("Root access is required for running this application.") + "\n";
			msg += _("Run the application as root or using gksu/sudo.");
			string title = _("Root Access Required");
			gtk_messagebox(title, msg, null, true);
			exit(0);
		}
	}

	public static bool parse_arguments(string[] args) {

		log_msg(_("Using cache directory") + ": %s".printf(LinuxKernel.CACHE_DIR));
		
		//parse options
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {
			case "--debug":
				LOG_DEBUG = true;
				break;
			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				exit(0);
				return true;
			}
		}

		log_msg(_("Using cache directory") + ": %s".printf(LinuxKernel.CACHE_DIR));

		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {

			// commands ------------------------------------

			case "--install":
			
				App.INSTALL_MODE = true;
				App.requested_version = args[++k];
				break;

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

	public static string help_message() {
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejeetech@gmail.com)" + "\n";
		msg += "\n";
		msg += _("Syntax") + ": ukuu-gtk [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --debug      " + _("Print debug information") + "\n";
		msg += "  --h[elp]     " + _("Show all options") + "\n";
		msg += "\n";
		return msg;
	}
}

