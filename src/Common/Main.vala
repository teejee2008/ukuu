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

		load_app_config();

		Package.initialize();
		
		LinuxKernel.initialize();
	}

	// helpers ------------
	
	public static bool check_dependencies(out string msg) {
		string[] dependencies = { "aptitude", "apt-get", "aria2c", "dpkg", "uname", "lsb_release",  };

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

	private void init_members(){
		//
	}
	
	private void init_paths(){
		// TEMP_DIR 
		init_tmp(AppShortName);

		// APP_CONFIG_FILE
		string home = Environment.get_home_dir();
		APP_CONFIG_FILE = home + "/.config/ukuu.json";
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
	}

	public void exit_app(){
		save_app_config();
		Gtk.main_quit();
	}

	// begin ------------

	public void notify_user(){
		var kern_running = new LinuxKernel.from_version(LinuxKernel.RUNNING_KERNEL);
		foreach(var kern in LinuxKernel.kernel_list){
			// skip invalid
			if (!kern.is_valid){
				continue;
			}
			// skip unstable
			if (kern.is_unstable){
				continue;
			}

			if (!notify_major && !notify_minor){
				log_msg(_("Notifications are disabled"));
				break;
			}
			
			bool major_available = false;
			bool minor_available = false;
			
			string[] arr = kern.version_main.split_set (".-");
			string[] arr_r = kern_running.version_main.split_set (".-");

			if (arr[0] > arr_r[0]){
				major_available = true;
			}
			else if (arr[0] == arr_r[0]){
				if (arr[1] > arr_r[1]){
					major_available = true;
				}
				else if (arr[1] == arr_r[1]){
					if (arr[2] > arr_r[2]){
						minor_available = true;
					}
				}
			}
			
			if (major_available && notify_major){
				var title = "Linux %s Available".printf(kern.version_main);
				var message = "Running kernel is %s".printf(kern_running.version_main);
				OSDNotify.notify_send(title,"\n" + message,3000,"normal","info");
				log_msg(title);
				log_msg(message);
				break;
			}
			
			if (minor_available && notify_minor && !notify_major){
				var title = "Linux %s Available".printf(kern.version_main);
				var message = "Running kernel is %s".printf(kern_running.version_main);
				message += "\nInstalling this update is recommended";
				OSDNotify.notify_send(title,"\n" + message,3000,"normal","info");
				log_msg(title);
				log_msg(message);
				break;
			}
		}
	}

	public void update_cron_jobs(){
		if (notify_major || notify_minor){
			CronTab.add_job(get_crontab_entry_scheduled());
			CronTab.add_job(get_crontab_entry_boot());
		}
		else{
			CronTab.remove_job(get_crontab_entry_scheduled());
			CronTab.remove_job(get_crontab_entry_boot());
		}
	}

	private string get_crontab_entry_scheduled(){
		return "@daily ukuu --notify";
	}

	private string get_crontab_entry_boot(){
		return "@reboot sleep %dm && ukuu --notify".printf(20);
	}
}

