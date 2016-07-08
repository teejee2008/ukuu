/*
 * MainWindow.vala
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

public class MainWindow : Gtk.Window{
	
	private Gtk.Box vbox_main;
	private Gtk.TreeView tv;
	private Gtk.Button btn_install;
	private Gtk.Button btn_remove;
	private Gtk.Button btn_changes;
	private Gtk.InfoBar infobar;
	private Gtk.Label lbl_info;
	
	// helper members

	private int window_width = 550;
	private int window_height = 400;
	private uint tmr_init = -1;

	private LinuxKernel selected_kernel;
	
	public MainWindow() {
		title = "%s (Ukuu) v%s".printf(AppName, AppVersion);
        window_position = WindowPosition.CENTER;
        icon = get_app_icon(16,".svg");

        // vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 6);
        vbox_main.margin = 6;
        vbox_main.set_size_request(window_width, window_height);
        add (vbox_main);
		
        init_ui();

		tmr_init = Timeout.add(100, init_delayed);
	}

	private bool init_delayed() {
		
		/* any actions that need to run after window has been displayed */
		
		if (tmr_init > 0) {
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		refresh_cache();

		tv_refresh();

		selected_kernel = null;

		if (App.INSTALL_MODE){
			LinuxKernel kern_requested = null;
			foreach(var kern in LinuxKernel.kernel_list){
				if (kern.name == App.requested_version){
					kern_requested = kern;
					break;
				}
			}

			if (kern_requested == null){
				var msg = _("Could not find requested version");
				msg += ": %s".printf(App.requested_version);
				log_error(msg);
				
				exit(1);
			}
			else{
				install(kern_requested);
			}
		}
		
		return false;
	}

	private void init_ui(){
		init_treeview();
		init_actions();
		init_infobar();
	}
	
	private void init_treeview(){
		//add treeview
		tv = new TreeView();
		tv.get_selection().mode = SelectionMode.SINGLE;
		tv.headers_visible = true;
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);
			
		var scrollwin = new ScrolledWindow(tv.get_hadjustment(), tv.get_vadjustment());
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		vbox_main.add(scrollwin);
		
		//column
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.min_width = 150;
		tv.append_column(col);
		
		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 2;
		col.pack_start (cell_pix, false);
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter)=>{
			Gdk.Pixbuf pix;
			model.get (iter, 1, out pix, -1);
			(cell as Gtk.CellRendererPixbuf).pixbuf = pix;
			//(cell as Gtk.CellRendererPixbuf).visible = !(App.hide_unstable);

			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
			
			if (odd_row){
				(cell as Gtk.CellRendererPixbuf).cell_background = "#F4F6F7";
			}
			else{
				(cell as Gtk.CellRendererPixbuf).cell_background = "#FFFFFF";
			}
		});
		
		//cell text
		var cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = "Linux " + kern.version_main;

			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
			
			if (odd_row){
				(cell as Gtk.CellRendererText).background = "#F4F6F7";
			}
			else{
				(cell as Gtk.CellRendererText).background = "#FFFFFF";
			}
		});

		//column
		col = new TreeViewColumn();
		col.title = _("Version");
		col.resizable = true;
		col.min_width = 150;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = kern.name;

			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
			
			if (odd_row){
				(cell as Gtk.CellRendererText).background = "#F4F6F7";
			}
			else{
				(cell as Gtk.CellRendererText).background = "#FFFFFF";
			}
		});
		
		//column
		col = new TreeViewColumn();
		col.title = _("Status");
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = kern.is_running ? "Running" : (kern.is_installed ? "Installed" : "");

			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
			
			if (odd_row){
				(cell as Gtk.CellRendererText).background = "#F4F6F7";
			}
			else{
				(cell as Gtk.CellRendererText).background = "#FFFFFF";
			}
		});
		
		//column
		col = new TreeViewColumn();
		col.title = "";
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.width = 10;
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);

		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
			
			if (odd_row){
				(cell as Gtk.CellRendererText).background = "#F4F6F7";
			}
			else{
				(cell as Gtk.CellRendererText).background = "#FFFFFF";
			}
		});
	}

	private void tv_row_activated(TreePath path, TreeViewColumn column){
		TreeIter iter;
		tv.model.get_iter_from_string(out iter, path.to_string());
		LinuxKernel kern;
		tv.model.get (iter, 0, out kern, -1);

		selected_kernel = kern;
		
		set_button_state();
	}

	private void tv_selection_changed(){
		var sel = tv.get_selection();

		if (sel.count_selected_rows() != 1){
			return;
		}
		
		TreeModel model;
		TreeIter iter;
		sel.get_selected (out model, out iter);
		
		LinuxKernel kern;
		model.get (iter, 0, out kern, -1);

		selected_kernel = kern;
		
		set_button_state();
	}

	private void tv_refresh(){
		var model = new Gtk.ListStore(3, typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(bool));

		Gdk.Pixbuf pix_ubuntu = null;
		Gdk.Pixbuf pix_mainline = null;
		Gdk.Pixbuf pix_mainline_rc = null;
		
		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file ("/usr/share/ukuu/images/ubuntu-logo.png");

			pix_mainline = new Gdk.Pixbuf.from_file ("/usr/share/ukuu/images/tux.png");

			pix_mainline_rc = new Gdk.Pixbuf.from_file ("/usr/share/ukuu/images/tux-red.png");
		}
		catch (Error e) {
			log_error (e.message);
		}

		var kern_4 = new LinuxKernel.from_version("4.0");
		
		TreeIter iter;
		bool odd_row = false;
		foreach(var kern in LinuxKernel.kernel_list) {
			if (!kern.is_valid){
				continue;
			}
			if (App.hide_unstable && kern.is_unstable){
				continue;
			}
			if (App.hide_older && (kern.compare_to(kern_4) < 0)){
				continue;
			}

			odd_row = !odd_row;
			
			//add row
			model.append(out iter);
			model.set (iter, 0, kern);

			if (kern.is_mainline){
				if (kern.is_unstable){
					model.set (iter, 1, pix_mainline_rc);
				}
				else{
					model.set (iter, 1, pix_mainline);
				}
			}
			else{
				model.set (iter, 1, pix_ubuntu);
			}

			model.set (iter, 2, odd_row);
		}

		tv.set_model(model);
		tv.columns_autosize();

		selected_kernel = null;
		set_button_state();

		set_infobar();
	}

	private void set_button_state(){
		if (selected_kernel == null){
			btn_install.sensitive = false;
			btn_remove.sensitive = false;
			btn_changes.sensitive = false;
		}
		else{
			btn_install.sensitive = !selected_kernel.is_installed;
			btn_remove.sensitive = selected_kernel.is_installed && !selected_kernel.is_running;
			btn_changes.sensitive = file_exists(selected_kernel.changes_file);
		}
	}

	
	private void init_actions(){
		var hbox = new Box (Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		// install
		var button = new Gtk.Button.with_label (_("Install"));
		hbox.pack_start (button, true, true, 0);
		btn_install = button;
		
		button.clicked.connect(() => {
			if (selected_kernel != null){
				install(selected_kernel);
			}
		});

		// remove
		button = new Gtk.Button.with_label (_("Remove"));
		hbox.pack_start (button, true, true, 0);
		btn_remove = button;
		
		button.clicked.connect(() => {
			if (selected_kernel != null){
				var term = new TerminalWindow.with_parent(this, false, true);
				
				term.script_complete.connect(()=>{
					term.allow_window_close();
				});
				
				term.destroy.connect(()=>{
					this.present();
					refresh_cache();
					tv_refresh();
				});

				string sh = "";
				sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY";
				sh += " ukuu --user %s".printf(App.user_login);
				if (LOG_DEBUG){
					sh += " --debug";
				}
				sh += " --remove %s\n".printf(selected_kernel.name);
					
				sh += "echo ''\n";
				sh += "echo 'Close window to exit...'\n";

				this.hide();
				
				term.execute_script(save_bash_script_temp(sh));
			}
		});

		// changes
		button = new Gtk.Button.with_label (_("Changes"));
		hbox.pack_start (button, true, true, 0);
		btn_changes = button;
		
		button.clicked.connect(() => {
			if ((selected_kernel != null) && file_exists(selected_kernel.changes_file)){
				exo_open_textfile(selected_kernel.changes_file);
			}
		});

		// settings
		button = new Gtk.Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(() => {

			bool prev_hide_older = App.hide_older;
			bool prev_hide_unstable = App.hide_unstable
			;
			var dlg = new SettingsDialog.with_parent(this);
			dlg.run();
			dlg.destroy();

			if (((prev_hide_older == true) && (App.hide_older == false))
				|| ((prev_hide_unstable == true) && (App.hide_unstable == false))){
				refresh_cache();
			}
			
			tv_refresh();
		});

		// donate
		button = new Gtk.Button.with_label (_("Donate"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(() => {
			var dlg = new DonationWindow();
			dlg.set_transient_for(this);
			dlg.show_all();
			dlg.run();
			dlg.destroy();
		});

		// about
		button = new Gtk.Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(btn_about_clicked);
	}

	private void btn_about_clicked () {
		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.third_party = {
			"Elementary project (various icons):https://github.com/elementary/icons",
			"Tango project (various icons):http://tango.freedesktop.org/Tango_Desktop_Project"
		};
		
		dialog.translators = {

		};

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _("Kernel upgrade utility for Ubuntu-based distributions");
		dialog.copyright = "Copyright © 2016 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}

	private void refresh_cache(bool download_index = true){

		if (!check_internet_connectivity()){
			gtk_messagebox("",_("Internet connection is not active"),this,true);
			exit(1);
		}
		
		string message = _("Refreshing...");
		var dlg = new ProgressWindow.with_parent(this, message, false);
		dlg.show_all();
		gtk_do_events();
		
		LinuxKernel.query(false);

		var timer = timer_start();

		App.progress_total = 1;
		App.progress_count = 0;

		string msg_remaining = "";
		long count = 0;
		
		while (LinuxKernel.task_is_running) {
			App.status_line = LinuxKernel.status_line;
			App.progress_total = LinuxKernel.progress_total;
			App.progress_count = LinuxKernel.progress_count;

			ulong ms_elapsed = timer_elapsed(timer, false);
			int remaining_count = App.progress_total - App.progress_count;
			ulong ms_remaining = (ulong)((ms_elapsed * 1.0) / App.progress_count) * remaining_count;

			if ((count % 5) == 0){
				msg_remaining = format_time_left(ms_remaining);
			}

			if (App.progress_total > 0){
				dlg.update_message(
					message + " %ld/%ld (%s)".printf(
						App.progress_count,
						App.progress_total,
						msg_remaining));
			}
					
			dlg.update_status_line();
			dlg.update_progressbar();
			dlg.sleep(200);
			gtk_do_events();

			count++;
		}

		timer_elapsed(timer, true);

		dlg.destroy();
		gtk_do_events();
	}


	private void init_infobar(){
		infobar = new Gtk.InfoBar ();
		infobar.message_type = MessageType.INFO;
		//infobar.show_close_button = true;
		infobar.close.connect(()=>{
			infobar.visible = false;
		});
		vbox_main.add(infobar);
		
		lbl_info = new Gtk.Label("");
		lbl_info.set_use_markup(true);
		
		var content = infobar.get_content_area();
		content.add(lbl_info);
	}

	private void set_infobar(){
		if (LinuxKernel.kernel_active != null){
			lbl_info.label = "Running <b>Linux %s</b>".printf(
				LinuxKernel.kernel_active.version_main);

			if (LinuxKernel.kernel_active.is_mainline){
				lbl_info.label += " (mainline)";
			}
			else{
				lbl_info.label += " (ubuntu)";
			}
			
			if (LinuxKernel.kernel_latest_stable.compare_to(LinuxKernel.kernel_active) > 0){
				lbl_info.label += " ~ <b>Linux %s</b> available".printf(
					LinuxKernel.kernel_latest_stable.version_main);
			}
		}
		else{
			lbl_info.label = "Running <b>Linux %s</b>".printf(LinuxKernel.RUNNING_KERNEL);
		}
	}

	public void install(LinuxKernel kern){

		// check if installed
		if (kern.is_installed){
			gtk_messagebox("", _("This kernel is already installed."), this, true);
			return;
		}
		
		this.hide();
		
		var term = new TerminalWindow.with_parent(this, false, true);
				
		term.script_complete.connect(()=>{
			term.allow_window_close();
		});
		
		term.destroy.connect(()=>{
			if (App.INSTALL_MODE){
				this.close();
				//Gtk.main_quit();
				//exit(0);
			}
			else{
				this.present();
				refresh_cache();
				tv_refresh();
			}
		});

		string sh = "";
		sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY";
		sh += " ukuu --user %s".printf(App.user_login);
		if (LOG_DEBUG){
			sh += " --debug";
		}
		sh += " --install %s\n".printf(kern.name);
			
		sh += "echo ''\n";
		sh += "echo 'Close window to exit...'\n";

		term.execute_script(save_bash_script_temp(sh));
	}
}

