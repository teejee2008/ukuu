/*
 * Main.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

extern void exit(int exit_code);

public class Main : GLib.Object{

	// constants ----------
	
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public int startup_delay = 180;
	public string user_login = "";
	public string user_home = "";
	
	// global progress ----------------
	
	public string status_line = "";
	public int progress_total = 0;
	public int progress_count = 0;
	public bool cancelled = false;
	
	// state flags ----------
	
	public bool GUI_MODE = false;
	public bool notify_major = true;
	public bool notify_minor = true;
	public bool hide_unstable = true;
	public bool hide_older = true;
	
	// constructors ------------
	
	public Main(string[] arg0, bool _gui_mode){
		
		GUI_MODE = _gui_mode;
		
		LOG_TIMESTAMP = false;

		init_paths();

		Package.initialize();
		
		LinuxKernel.initialize();

		load_app_config();
	}

	// helpers ------------
	
	public static bool check_dependencies(out string msg) {
		string[] dependencies = { "aptitude", "apt-get", "aria2c", "dpkg", "uname", "lsb_release", "ping" };

		msg = "";
		
		string path;
		foreach(string cmd_tool in dependencies) {
			path = get_cmd_path (cmd_tool);
			if ((path == null) || (path.length == 0)) {
				msg += " * " + cmd_tool + "\n";
			}
		}

		if (msg.length > 0) {
			msg = _("Commands listed below are not available on this system") + ":\n\n" + msg + "\n";
			msg += _("Please install required packages and try again");
			log_msg(msg);
			return false;
		}
		else{
			return true;
		}
	}

	private void init_paths(){
		// temp dir 
		init_tmp(AppShortName);

		// user info
		user_login = get_user_login();
		user_home = get_user_home();

		// app config files
		APP_CONFIG_FILE = user_home + "/.config/ukuu.json";
		STARTUP_SCRIPT_FILE = user_home + "/.config/ukuu-notify.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/ukuu.desktop";
	}
	
	public void save_app_config(){
		var config = new Json.Object();
		config.set_string_member("notify_major", notify_major.to_string());
		config.set_string_member("notify_minor", notify_minor.to_string());
		config.set_string_member("hide_unstable", hide_unstable.to_string());
		config.set_string_member("hide_older", hide_older.to_string());

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try{
			json.to_file(APP_CONFIG_FILE);
		} catch (Error e) {
	        log_error (e.message);
	    }

		// change owner to current user so that ukuu can access in normal mode
	    chown(APP_CONFIG_FILE, user_login, user_login);

		//update_startup_script();
	    //update_startup_desktop_file();
	    remove_cron_jobs();
	}

	public void load_app_config(){
		var f = File.new_for_path(APP_CONFIG_FILE);
		if (!f.query_exists()) { return; }

		var parser = new Json.Parser();
        try{
			parser.load_from_file(APP_CONFIG_FILE);
		} catch (Error e) {
	        log_error (e.message);
	    }
        var node = parser.get_root();
        var config = node.get_object();

		notify_major = json_get_bool(config, "notify_major", true);
		notify_minor = json_get_bool(config, "notify_minor", true);
		hide_unstable = json_get_bool(config, "hide_unstable", true);
		hide_older = json_get_bool(config, "hide_older", true);

		LinuxKernel.skip_older = hide_older;
		LinuxKernel.skip_unstable = hide_unstable;
	}

	public void exit_app(){
		save_app_config();
		Gtk.main_quit();
	}

	// begin ------------

	public void notify_user(){

		LinuxKernel.check_updates();

		var kern = LinuxKernel.kernel_update_major;
		if ((kern != null) && notify_major){
			var title = "Linux %s Available".printf(kern.version_main);
			var message = "Running kernel is %s".printf(LinuxKernel.kernel_active.version_main);
			OSDNotify.notify_send(title,"\n" + message,3000,"normal","info");
			log_msg(title);
			log_msg(message);
			return;
		}

		kern = LinuxKernel.kernel_update_minor;
		if ((kern != null) && notify_minor && !notify_major){
			var title = "Linux %s Available".printf(kern.version_main);
			var message = "Running kernel is %s".printf(LinuxKernel.kernel_active.version_main);
			message += "\nInstalling this update is recommended";
			OSDNotify.notify_send(title,"\n" + message,3000,"normal","info");
			log_msg(title);
			log_msg(message);
			return;
		}
	}

	public void remove_cron_jobs(){
		CronTab.remove_job(get_crontab_entry_scheduled());
		CronTab.remove_job(get_crontab_entry_boot());
	}

	private string get_crontab_entry_scheduled(){
		return "@daily ukuu --notify";
	}

	private string get_crontab_entry_boot(){
		return "@reboot sleep %dm && ukuu --notify".printf(20);
	}

	private void update_startup_script(){

		string txt = "";
		txt += "sleep %ds\n".printf(startup_delay);
		txt += "ukuu --notify\n";
		
		if (file_exists(STARTUP_SCRIPT_FILE)){
			file_delete(STARTUP_SCRIPT_FILE);
		}

		if (notify_minor || notify_major){
			file_write(
				STARTUP_SCRIPT_FILE,
				txt);
		}
		else{
			file_write(
				STARTUP_SCRIPT_FILE,
				"# Notifications are disabled\n\nexit 0"); // write dummy script
		}

		chown(STARTUP_SCRIPT_FILE, user_login, user_login);
	}

	private void update_startup_desktop_file(){
		if (notify_minor || notify_major){
			
			string txt =
"""[Desktop Entry]
Type=Application
Exec={command}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_IN]=Ukuu Notification
Name=Ukuu Notification
Comment[en_IN]=Ukuu Notification
Comment=Ukuu Notification
""";

			txt = txt.replace("{command}", "sh \"%s\"".printf(STARTUP_SCRIPT_FILE));

			file_write(STARTUP_DESKTOP_FILE, txt);

			chown(STARTUP_DESKTOP_FILE, user_login, user_login);
		}
		else{
			file_delete(STARTUP_DESKTOP_FILE);
		}
	}
}

