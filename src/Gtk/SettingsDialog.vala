/*
 * OneClickSettingsDialog.vala
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

public class SettingsDialog : Gtk.Dialog {

	private Gtk.TreeView tv;
	private Gtk.CheckButton chk_notify_major;
	private Gtk.CheckButton chk_notify_minor;
	private Gtk.CheckButton chk_hide_unstable;
	private Gtk.CheckButton chk_hide_older;
		
	public SettingsDialog.with_parent(Window parent) {
		set_transient_for(parent);
		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = false;
		resizable = false;
		
		icon = get_app_icon(16,".svg");

		title = _("Settings");
		
		// get content area
		var vbox_main = get_content_area();
		vbox_main.spacing = 6;
		vbox_main.margin = 12;
		//vbox_main.margin_bottom = 12;
		vbox_main.set_size_request(400,400);

		// notification
		var label = new Label("<b>" + _("Notification") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox_main.add (label);
		
		// chk_notify_major
		var chk = new Gtk.CheckButton.with_label(_("Notify if a major kernel release is available"));
		chk.active = App.notify_major;
		chk.margin_left = 6;
		vbox_main.add(chk);
		chk_notify_major = chk;

		chk.toggled.connect(()=>{
			App.notify_major = chk_notify_major.active;
		});
		
		// chk_notify_minor
		chk = new Gtk.CheckButton.with_label(_("Notify if a point release is available for current kernel"));
		chk.active = App.notify_minor;
		chk.margin_left = 6;
		vbox_main.add(chk);
		chk_notify_minor = chk;
		
		chk.toggled.connect(()=>{
			App.notify_minor = chk_notify_minor.active;
		});

		// display
		label = new Label("<b>" + _("Display") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox_main.add (label);

		// chk_hide_unstable
		chk = new CheckButton.with_label(_("Hide unstable and RC releases"));
		chk.active = App.hide_unstable;
		chk.margin_left = 6;
		vbox_main.add(chk);
		chk_hide_unstable = chk;
		
		chk.toggled.connect(()=>{
			App.hide_unstable = chk_hide_unstable.active;
		});

		// chk_hide_older
		chk = new CheckButton.with_label(_("Hide kernels older than 4.0"));
		chk.active = App.hide_older;
		chk.margin_left = 6;
		vbox_main.add(chk);
		chk_hide_older = chk;
		
		chk.toggled.connect(()=>{
			App.hide_older = chk_hide_older.active;
		});
		
		// actions -------------------------
		
		// ok
        var button = (Button) add_button ("gtk-ok", Gtk.ResponseType.ACCEPT);
        button.clicked.connect(()=>{
			this.close();
		});

		this.destroy.connect(btn_ok_click);
		
        show_all();
	}

	private void btn_ok_click(){
		App.update_cron_jobs();
		App.save_app_config();
	}
}


