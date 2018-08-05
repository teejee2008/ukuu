/*
 * TerminalWindow.vala
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


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class TerminalWindow : Gtk.Window {
	
	private Gtk.Box vbox_main;
	private Vte.Terminal term;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;
	private Gtk.ScrolledWindow scroll_win;

	private int def_width = 1100;
	private int def_height = 600;

	private Pid child_pid;
	private Gtk.Window parent_win = null;

	public bool cancelled = false;
	public bool is_running = false;
	
	public signal void script_complete();
	
	// init
	
	public TerminalWindow.with_parent(Gtk.Window? parent, bool fullscreen = false, bool show_cancel_button = false) {
		if (parent != null){
			set_transient_for(parent);
			parent_win = parent;
		}
		set_modal(true);
		window_position = WindowPosition.CENTER;

		if (fullscreen){
			this.fullscreen();
		}

		this.delete_event.connect(cancel_window_close);
		
		init_window();

		show_all();

		btn_cancel.visible = false;
		btn_close.visible = false;
		
		if (show_cancel_button){
			allow_cancel();
		}
	}

	public bool cancel_window_close(){
		// do not allow window to close 
		return true;
	}

	public void init_window () {
		
		title = "";
		icon = get_app_icon(16);
		resizable = true;
		deletable = false;
		
		// vbox_main ---------------
		
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.set_size_request (def_width, def_height);
		add (vbox_main);

		// terminal ----------------------
		
		term = new Vte.Terminal();
		term.expand = true;

		//sw_ppa
		scroll_win = new Gtk.ScrolledWindow(null, null);
		scroll_win.set_shadow_type (ShadowType.ETCHED_IN);
		scroll_win.add (term);
		scroll_win.expand = true;
		scroll_win.hscrollbar_policy = PolicyType.AUTOMATIC;
		scroll_win.vscrollbar_policy = PolicyType.AUTOMATIC;
		vbox_main.add(scroll_win);
		
		#if VTE_291
		
		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;
		term.rewrap_on_resize = true;
		
		#endif
		
		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = 100000;

		// colors -----------------------------
		
		#if VTE_291
		
		var color = Gdk.RGBA();
		color.parse("#FFFFFF");
		term.set_color_foreground(color);

		color.parse("#404040");
		term.set_color_background(color);
		
		#else
		
		Gdk.Color color;
		Gdk.Color.parse("#FFFFFF", out color);
		term.set_color_foreground(color);

		Gdk.Color.parse("#404040", out color);
		term.set_color_background(color);

		#endif
		
		// grab focus ----------------
		
		term.grab_focus();
		
		// add cancel button --------------

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.homogeneous = true;
		vbox_main.add (hbox);

		var label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);
		
		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);
		
		//btn_cancel
		var button = new Gtk.Button.with_label (_("Cancel"));
		hbox.pack_start (button, true, true, 0);
		btn_cancel = button;
		
		btn_cancel.clicked.connect(()=>{
			cancelled = true;
			terminate_child();
		});

		//btn_close
		button = new Gtk.Button.with_label (_("Close"));
		hbox.pack_start (button, true, true, 0);
		btn_close = button;
		
		btn_close.clicked.connect(()=>{
			this.destroy();
		});

		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);

		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);
	}

	public void start_shell(){
		string[] argv = new string[1];
		argv[0] = "/bin/sh";

		string[] env = Environ.get();
		
		try{

			is_running = true;
			
			#if VTE_291
			
			term.spawn_sync(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);

			#else

			term.fork_command_full(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid
			);

			#endif
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void terminate_child(){
		btn_cancel.sensitive = false;
		process_quit(child_pid);
	}
	
	public void execute_command(string command){
        string cmd = "%s\n".printf(command);
        term.feed_child((char[])cmd);
	}

	public void execute_script(string script_path, bool wait = false){
		string[] argv = new string[1];
		argv[0] = script_path;
		
		string[] env = Environ.get();

		try{

			is_running = true;
			
			#if VTE_291
			
			term.spawn_sync(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);

			#else

			term.fork_command_full(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD, //spawn_flags
				null, //child_setup
				out child_pid
			);

			#endif

			term.watch_child(child_pid);
	
			term.child_exited.connect(script_exit);

			if (wait){
				while (is_running){
					sleep(200);
					gtk_do_events();
				}
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	#if VTE_291
	public void script_exit(int status){
	#else
	public void script_exit(){
	#endif

		is_running = false;

		Process.close_pid(child_pid); //required on Windows, doesn't do anything on Unix

		btn_cancel.visible = false;
		btn_close.visible = true;

		script_complete();
	}

	public void allow_window_close(bool allow = true){
		if (allow){
			this.delete_event.disconnect(cancel_window_close);
			this.deletable = true;
		}
		else{
			this.delete_event.connect(cancel_window_close);
			this.deletable = false;
		}
	}

	public void allow_cancel(bool allow = true){
		if (allow){
			btn_cancel.visible = true;
			vbox_main.margin = 3;
		}
		else{
			btn_cancel.sensitive = false;
			vbox_main.margin = 3;
		}
	}
}
