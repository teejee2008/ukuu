/*
 * UpdateNotificationWindow.vala
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
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public class UpdateNotificationWindow : Gtk.Window {
	private Gtk.Box vbox_main;
	private Gtk.Label lbl_msg;
	private Gtk.ScrolledWindow sw_msg;

	private string msg_title;
	private string msg_body;
	private Gtk.MessageType msg_type;

	private LinuxKernel kern_update;
	
	public UpdateNotificationWindow(
		string _msg_title, string _msg_body, Window? parent, LinuxKernel _kern_update) {
			
		set_transient_for(parent);
		set_modal(true);

		msg_title = _msg_title;
		msg_body = _msg_body;
		msg_type = Gtk.MessageType.INFO;
		kern_update = _kern_update;
		
		init_window();

		show_all();

		if (lbl_msg.get_allocated_height() > 400){
			sw_msg.vscrollbar_policy = PolicyType.AUTOMATIC;
			sw_msg.set_size_request(-1,400);
			lbl_msg.margin_right = 25;
		}
		else{
			sw_msg.vscrollbar_policy = PolicyType.NEVER;
		}
	}

	public void init_window () {
		title = msg_title;
		window_position = WindowPosition.CENTER_ON_PARENT;
		icon = get_app_icon(16);
		resizable = false;
		deletable = false;
		skip_taskbar_hint = true;
		skip_pager_hint = true;
		
		//vbox_main
		vbox_main = new Box (Orientation.VERTICAL, 6);
		vbox_main.margin = 6;
		add(vbox_main);
		
		//hbox_contents
		var hbox_contents = new Box (Orientation.HORIZONTAL, 6);
		hbox_contents.margin = 6;
		vbox_main.add (hbox_contents);

		string icon_name = "gtk-dialog-info";
		
		switch(msg_type){
		case Gtk.MessageType.INFO:
			icon_name = "gtk-dialog-info";
			break;
		case Gtk.MessageType.WARNING:
			icon_name = "gtk-dialog-warning";
			break;
		case Gtk.MessageType.QUESTION:
			icon_name = "gtk-dialog-question";
			break;
		case Gtk.MessageType.ERROR:
			icon_name = "gtk-dialog-error";
			break;
		}

		// img
		var img = new Image.from_icon_name(icon_name, Gtk.IconSize.DIALOG);
		img.margin_right = 12;
		hbox_contents.add(img);

		// vbox_msg
		var vbox_msg = new Box (Orientation.VERTICAL, 24);
		vbox_msg.margin_right = 6;
		hbox_contents.add(vbox_msg);

		// lbl_msg
		lbl_msg = new Gtk.Label(msg_body);
		lbl_msg.set_use_markup(true);
		lbl_msg.xalign = (float) 0.0;
		lbl_msg.max_width_chars = 70;
		lbl_msg.wrap = true;
		lbl_msg.wrap_mode = Pango.WrapMode.WORD;
		//hbox_contents.add(lbl_msg);

		// sw_msg
		sw_msg = new ScrolledWindow(null, null);
		//sw_msg.set_shadow_type (ShadowType.ETCHED_IN);
		sw_msg.add (lbl_msg);
		sw_msg.expand = true;
		sw_msg.hscrollbar_policy = PolicyType.NEVER;
		sw_msg.vscrollbar_policy = PolicyType.AUTOMATIC;
		//sw_msg.set_size_request();
		vbox_msg.add(sw_msg);

		// actions
		var hbox_actions = new Box (Orientation.HORIZONTAL, 6);
		vbox_msg.add (hbox_actions);

		// install
		var button = new Gtk.Button.with_label("    " + _("Install") + "    ");
		hbox_actions.add(button);

		button.clicked.connect(()=>{
			string sh = "ukuu-gtk";
			if (LOG_DEBUG){
				sh += " --debug";
			}
			sh += " --install %s".printf(kern_update.name);
			//sh += " &";
			exec_script_async(sh);
			Gtk.main_quit();
			//exit(0);
		});

		// open ukuu
		button = new Gtk.Button.with_label("    " + _("Run Ukuu") + "    ");
		hbox_actions.add(button);

		button.clicked.connect(()=>{
			string sh = "ukuu-gtk";
			if (LOG_DEBUG){
				sh += " --debug";
			}
			//sh += " &";
			exec_script_async(sh);
			Gtk.main_quit();
		});
		
		// ignore
		button = new Gtk.Button.with_label("    " + _("Cancel") + "    ");
		hbox_actions.add(button);

		button.clicked.connect(()=>{
			this.destroy();
		});
	}
}


