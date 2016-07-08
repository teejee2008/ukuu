/*
 * Utility.vala
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
using Json;
using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

/*
extern void exit(int exit_code);
*/

namespace TeeJee.Logging{

	/* Functions for logging messages to console and log files */

	using TeeJee.Misc;

	public DataOutputStream dos_log;
	public string err_log;
	public bool LOG_ENABLE = true;
	public bool LOG_TIMESTAMP = true;
	public bool LOG_COLORS = true;
	public bool LOG_DEBUG = false;
	public bool LOG_COMMANDS = false;

	public void log_msg (string message, bool highlight = false){

		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;34m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}

		msg += message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_error (string message, bool highlight = false, bool is_warning = false){
		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;160m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}

		string prefix = (is_warning) ? _("W") : _("E");

		msg += prefix + ": " + message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();
		
		try {
			string str = "[%s] %s: %s\n".printf(timestamp(), prefix, message);
			
			if (dos_log != null){
				dos_log.put_string (str);
			}

			if (err_log != null){
				err_log += "%s\n".printf(message);
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_debug (string message){
		if (!LOG_ENABLE) { return; }

		if (LOG_DEBUG){
			log_msg ("D: " + message);
		}

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_draw_line(){
		log_msg(string.nfill(70,'='));
	}

	public void clear_err_log(){
		err_log = "";
	}

	public void disable_err_log(){
		err_log = null;
	}
}

namespace TeeJee.FileSystem{

	/* Convenience functions for handling files and directories */

	using TeeJee.Logging;
	using TeeJee.ProcessManagement;
	using TeeJee.Misc;

	// path helpers ----------------------------
	
	public string file_parent(string file_path){
		return File.new_for_path(file_path).get_parent().get_path();
	}

	public string file_basename(string file_path){
		return File.new_for_path(file_path).get_basename();
	}

	// file helpers -----------------------------
	
	public bool file_exists (string file_path){
		/* Check if file exists */
		return ( FileUtils.test(file_path, GLib.FileTest.EXISTS) && FileUtils.test(file_path, GLib.FileTest.IS_REGULAR));
	}

	public bool file_delete(string file_path){

		/* Check and delete file */

		try {
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			return true;
		} catch (Error e) {
	        log_error (e.message);
	        log_error(_("Failed to delete file") + ": %s".printf(file_path));
	        return false;
	    }
	}

	public string? file_read (string file_path){

		/* Reads text from file */

		string txt;
		size_t size;

		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;
		}
		catch (Error e){
	        log_error (e.message);
	        log_error(_("Failed to read file") + ": %s".printf(file_path));
	    }

	    return null;
	}

	public bool file_write (string file_path, string contents){

		/* Write text to file */

		try{

			dir_create(file_parent(file_path));
			
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (contents);
			data_stream.close();
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to write file") + ": %s".printf(file_path));
			return false;
		}
	}

	public bool file_copy (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.copy(file_dest,FileCopyFlags.OVERWRITE,null,null);
				return true;
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to copy file") + ": '%s', '%s'".printf(src_file, dest_file));
		}

		return false;
	}

	public void file_move (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.move(file_dest,FileCopyFlags.OVERWRITE,null,null);
			}
			else{
				log_error(_("File not found") + ": '%s'".printf(src_file));
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to move file") + ": '%s', '%s'".printf(src_file, dest_file));
		}
	}

	
	// file info -----------------

	public int64 file_get_size(string file_path){
		try{
			File file = File.parse_name (file_path);
			if (FileUtils.test(file_path, GLib.FileTest.EXISTS)){
				if (FileUtils.test(file_path, GLib.FileTest.IS_REGULAR)
					&& !FileUtils.test(file_path, GLib.FileTest.IS_SYMLINK)){
					return file.query_info("standard::size",0).get_size();
				}
			}
		}
		catch(Error e){
			log_error (e.message);
		}

		return -1;
	}

	public DateTime file_get_modified_date(string file_path){
		try{
			FileInfo info;
			File file = File.parse_name (file_path);
			if (file.query_exists()) {
				info = file.query_info("%s".printf(FileAttribute.TIME_MODIFIED), 0);
				return (new DateTime.from_timeval_utc(info.get_modification_time())).to_local();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		return (new DateTime.from_unix_utc(0)); //1970
	}

	// dir helpers ----------------------
	
	public bool dir_exists (string dir_path){
		/* Check if directory exists */
		return ( FileUtils.test(dir_path, GLib.FileTest.EXISTS) && FileUtils.test(dir_path, GLib.FileTest.IS_DIR));
	}
	
	public bool dir_create (string dir_path){

		/* Creates a directory along with parents */

		try{
			var dir = File.parse_name (dir_path);
			if (dir.query_exists () == false) {
				dir.make_directory_with_parents (null);
			}
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to create dir") + ": %s".printf(dir_path));
			return false;
		}
	}

	public bool dir_delete (string dir_path){
		
		/* Recursively deletes directory along with contents */
		
		string cmd = "rm -rf '%s'".printf(escape_single_quote(dir_path));
		int status = exec_sync(cmd);
		return (status == 0);
	}

	public bool dir_is_empty (string dir_path){

		/* Check if directory is empty */

		try{
			bool is_empty = true;
			var dir = File.parse_name (dir_path);
			if (dir.query_exists()) {
				FileInfo info;
				var enu = dir.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
				while ((info = enu.next_file()) != null) {
					is_empty = false;
					break;
				}
			}
			return is_empty;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}


	public Gee.ArrayList<string> dir_list_names(string path){
		var list = new Gee.ArrayList<string>();
		
		try
		{
			File f_home = File.new_for_path (path);
			FileEnumerator enumerator = f_home.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			FileInfo file;
			while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				list.add(name);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		//sort the list
		CompareDataFunc<string> entry_compare = (a, b) => {
			return strcmp(a,b);
		};
		list.sort((owned) entry_compare);

		return list;
	}
	
	public bool dir_tar (string src_dir, string tar_file, bool recursion = true){
		if (dir_exists(src_dir)) {
			
			if (file_exists(tar_file)){
				file_delete(tar_file);
			}

			var src_parent = file_parent(src_dir);
			var src_name = file_basename(src_dir);
			
			string cmd = "tar cvf '%s' --overwrite --%srecursion -C '%s' '%s'\n".printf(
				escape_single_quote(tar_file),
				(recursion ? "" : "no-"),
				escape_single_quote(src_parent),
				escape_single_quote(src_name));

			log_debug(cmd);
			
			string stdout, stderr;
			int status = exec_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}
		else{
			log_error(_("Dir not found") + ": %s".printf(src_dir));
		}

		return false;
	}

	public bool dir_untar (string tar_file, string dst_dir){
		if (file_exists(tar_file)) {

			if (!dir_exists(dst_dir)){
				dir_create(dst_dir);
			}
			
			string cmd = "tar xvf '%s' --overwrite --same-permissions -C '%s'\n".printf(
				escape_single_quote(tar_file),
				escape_single_quote(dst_dir));

			log_debug(cmd);
			
			string stdout, stderr;
			int status = exec_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}
		else{
			log_error(_("File not found") + ": %s".printf(tar_file));
		}
		
		return false;
	}

	public bool chown(string dir_path, string user, string group = user){
		string cmd = "chown %s:%s -R '%s'".printf(user, group, escape_single_quote(dir_path));
		int status = exec_sync(cmd, null, null);
		log_debug(cmd);
		return (status == 0);
	}
	
	// dir info -------------------
	
	// dep: find wc    TODO: rewrite
	public long dir_get_count(string path){

		/* Return total count of files and directories */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "find '%s' | wc -l".printf(escape_single_quote(path));
		ret_val = exec_script_sync(cmd, out std_out, out std_err);
		return long.parse(std_out);
	}

	// dep: du
	public long dir_get_size_kb(string path){

		/* Returns size of files and directories in KB*/

		string cmd = "du -s '%s'".printf(escape_single_quote(path));
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		return long.parse(std_out.split("\t")[0]);
	}

	// archiving and encryption ----------------

	// dep: tar gzip gpg
	public bool file_tar_encrypt (string src_file, string dst_file, string password){
		if (file_exists(src_file)) {
			if (file_exists(dst_file)){
				file_delete(dst_file);
			}

			var src_dir = file_parent(src_file);
			var src_name = file_basename(src_file);

			var dst_dir = file_parent(dst_file);
			var dst_name = file_basename(dst_file);
			var tar_name = dst_name[0 : dst_name.index_of(".gpg")];
			var tar_file = "%s/%s".printf(dst_dir, tar_name);
			
			string cmd = "tar cvf '%s' --overwrite -C '%s' '%s'\n".printf(
				escape_single_quote(tar_file),
				escape_single_quote(src_dir),
				escape_single_quote(src_name));
				
			cmd += "gpg --passphrase '%s' -o '%s' --symmetric '%s'\n".printf(
				password,
				escape_single_quote(dst_file),
				escape_single_quote(tar_file));
				
			cmd += "rm -f '%s'\n".printf(escape_single_quote(tar_file));

			log_debug(cmd);
			
			string stdout, stderr;
			int status = exec_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}

		return false;
	}

	// dep: tar gzip gpg
	public string file_decrypt_untar_read (string src_file, string password){
		
		if (file_exists(src_file)) {
			
			//var src_name = file_basename(src_file);
			//var tar_name = src_name[0 : src_name.index_of(".gpg")];
			//var tar_file = "%s/%s".printf(TEMP_DIR, tar_name);
			//var temp_file = "%s/%s".printf(TEMP_DIR, random_string());

			string cmd = "";
			
			cmd += "gpg --quiet --no-verbose --passphrase '%s' -o- --decrypt '%s'".printf(
				password,
				escape_single_quote(src_file));
				
			cmd += " | tar xf - --to-stdout 2>/dev/null\n";
			cmd += "exit $?\n";
			
			log_debug(cmd);
			
			string std_out, std_err;
			int status = exec_script_sync(cmd, out std_out, out std_err);
			if (status == 0){
				return std_out;
			}
			else{
				log_error(std_err);
				return "";
			}
		}
		else{
			log_error(_("File is missing") + ": %s".printf(src_file));
		}

		return "";
	}

	// dep: tar gzip gpg
	public bool decrypt_and_untar (string src_file, string dst_file, string password){
		if (file_exists(src_file)) {
			if (file_exists(dst_file)){
				file_delete(dst_file);
			}

			var src_dir = file_parent(src_file);
			var src_name = file_basename(src_file);
			var tar_name = src_name[0 : src_name.index_of(".gpg")];
			var tar_file = "%s/%s".printf(src_dir, tar_name);

			string cmd = "";
			
			// gpg cannot overwrite - remove tar file if it exists
			cmd += "rm -f '%s'\n".printf(escape_single_quote(tar_file));
			
			cmd += "gpg --passphrase '%s' -o '%s' --decrypt '%s'\n".printf(
				password,
				escape_single_quote(tar_file),
				escape_single_quote(src_file));
				
			cmd += "status=$?; if [ $status -ne 0 ]; then exit $status; fi\n";
			
			cmd += "tar xvf '%s' --overwrite --same-permissions -C '%s'\n".printf(
				escape_single_quote(tar_file),
				escape_single_quote(file_parent(dst_file)));
				
			cmd += "rm -f '%s'\n".printf(escape_single_quote(tar_file));

			log_debug(cmd);
			
			string stdout, stderr;
			int status = exec_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_error(stderr);
				return false;
			}
		}
		else{
			log_error(_("File is missing") + ": %s".printf(src_file));
		}

		return false;
	}

	// hashing -----------
	
	private string hash_md5(string path){
		Checksum checksum = new Checksum (ChecksumType.MD5);
		FileStream stream = FileStream.open (path, "rb");

		uint8 fbuf[100];
		size_t size;
		while ((size = stream.read (fbuf)) > 0){
		  checksum.update (fbuf, size);
		}
		
		unowned string digest = checksum.get_string();

		return digest;
	}

	// misc --------------------

	public string format_file_size (uint64 size, bool binary_units = false, bool size_kb = false){
		int64 KB = binary_units ? 1024 : 1000;
		int64 MB = binary_units ? 1024 * KB : 1000 * KB;
		int64 GB = binary_units ? 1024 * MB : 1000 * MB;

		if (size_kb){
			return "%'0.0f %sB".printf(size/(1.0*KB), (binary_units)?"Ki":"K");
		}
		
		if (size > GB){
			return "%'0.1f %sB".printf(size/(1.0*GB), (binary_units)?"Gi":"G");
		}
		else if (size > MB){
			return "%'0.1f %sB".printf(size/(1.0*MB), (binary_units)?"Mi":"M");
		}
		else if (size > KB){
			return "%'0.0f %sB".printf(size/(1.0*KB), (binary_units)?"Ki":"K");
		}
		else{
			return "%'0lld B".printf(size);
		}
	}

	public string escape_single_quote(string file_path){
		return file_path.replace("'","'\\''");
	}


	// dep: chmod
	public int chmod (string file, string permission){

		/* Change file permissions */
		string cmd = "chmod %s '%s'".printf(permission, escape_single_quote(file));
		return exec_sync (cmd, null, null);
	}

	// dep: realpath
	public string resolve_relative_path (string filePath){

		/* Resolve the full path of given file using 'realpath' command */

		string filePath2 = filePath;
		if (filePath2.has_prefix ("~")){
			filePath2 = Environment.get_home_dir () + "/" + filePath2[2:filePath2.length];
		}

		try {
			string output = "";
			string cmd = "realpath '%s'".printf(escape_single_quote(filePath2));
			Process.spawn_command_line_sync(cmd, out output);
			output = output.strip ();
			if (FileUtils.test(output, GLib.FileTest.EXISTS)){
				return output;
			}
		}
		catch(Error e){
	        log_error (e.message);
	    }

	    return filePath2;
	}

	public int rsync (string sourceDirectory, string destDirectory, bool updateExisting, bool deleteExtra){

		/* Sync files with rsync */

		string cmd = "rsync -avh";
		cmd += updateExisting ? "" : " --ignore-existing";
		cmd += deleteExtra ? " --delete" : "";
		cmd += " '%s'".printf(escape_single_quote(sourceDirectory) + "//");
		cmd += " '%s'".printf(escape_single_quote(destDirectory));
		return exec_sync (cmd, null, null);
	}
}

namespace TeeJee.JSON{

	using TeeJee.Logging;

	/* Convenience functions for reading and writing JSON files */

	public string json_get_string(Json.Object jobj, string member, string def_value){
		if (jobj.has_member(member)){
			return jobj.get_string_member(member);
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public bool json_get_bool(Json.Object jobj, string member, bool def_value){
		if (jobj.has_member(member)){
			return bool.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public int json_get_int(Json.Object jobj, string member, int def_value){
		if (jobj.has_member(member)){
			return int.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public Gee.ArrayList<string> json_get_array(
		Json.Object jobj,
		string member,
		Gee.ArrayList<string> def_value){
			
		if (jobj.has_member(member)){
			var jarray = jobj.get_array_member(member);
			var list = new Gee.ArrayList<string>();
			foreach(var node in jarray.get_elements()){
				list.add(node.get_string());
			}
			return list;
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

}

namespace TeeJee.ProcessManagement{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	public string TEMP_DIR;

	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------
	
    public static void init_tmp(string subdir_name){
		string std_out, std_err;

		TEMP_DIR = Environment.get_tmp_dir() + "/" + subdir_name + "/" + random_string();
		dir_create(TEMP_DIR);

		exec_script_sync("echo 'ok'",out std_out,out std_err, true);
		if ((std_out == null)||(std_out.strip() != "ok")){
			TEMP_DIR = Environment.get_home_dir() + "/.temp/" + subdir_name + "/" + random_string();
			exec_sync("rm -rf '%s'".printf(TEMP_DIR), null, null);
			dir_create(TEMP_DIR);
		}

		//log_debug("TEMP_DIR=" + TEMP_DIR);
	}

	public string create_temp_subdir(){
		var temp = "%s/%s".printf(TEMP_DIR, random_string());
		dir_create(temp);
		return temp;
	}
	
	public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){

		/* Executes single command synchronously.
		 * Pipes and multiple commands are not supported.
		 * std_out, std_err can be null. Output will be written to terminal if null. */

		try {
			int status;
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
	        return status;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}
	
	public int exec_script_sync (string script,
		out string? std_out = null, out string? std_err = null,
		bool supress_errors = false, bool run_as_admin = false,
		bool cleanup_tmp = true){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * std_out, std_err can be null. Output will be written to terminal if null.
		 * */

		string sh_file = save_bash_script_temp(script, null, supress_errors);
		string sh_file_main = "";
		if (run_as_admin){
			string script_main = "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY";
			script_main += " '%s'".printf(escape_single_quote(sh_file));
			string dir = file_parent(sh_file);
			sh_file_main = GLib.Path.build_filename(dir,"script-admin.sh");
			save_bash_script_temp(script_main, sh_file_main);
		}

		try {
			string[] argv = new string[1];
			if (run_as_admin){
				argv[0] = sh_file_main;
			}
			else{
				argv[0] = sh_file;
			}

			string[] env = Environ.get();
			
			int exit_code;

			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    env, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    out std_out,
			    out std_err,
			    out exit_code
			    );

			if (cleanup_tmp){
				file_delete(sh_file);
				if (run_as_admin){
					file_delete(sh_file_main);
				}
			}
			
			return exit_code;
		}
		catch (Error e){
			if (!supress_errors){
				log_error (e.message);
			}
			return -1;
		}
	}

	public int exec_script_async (string script){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * Return value indicates if script was started successfully.
		 *  */

		try {

			string scriptfile = save_bash_script_temp (script);

			string[] argv = new string[1];
			argv[0] = scriptfile;

			string[] env = Environ.get();
			
			Pid child_pid;
			Process.spawn_async_with_pipes(
			    TEMP_DIR, //working dir
			    argv, //argv
			    env, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);

			return 0;
		}
		catch (Error e){
	        log_error (e.message);
	        return 1;
	    }
	}

	public string? save_bash_script_temp (string commands, string? script_path = null,
		bool force_locale = true, bool supress_errors = false){

		string sh_path = script_path;

		/* Creates a temporary bash script with given commands
		 * Returns the script file path */

		var script = new StringBuilder();
		script.append ("#!/bin/bash\n");
		script.append ("\n");
		if (force_locale){
			script.append ("LANG=C\n");
		}
		script.append ("\n");
		script.append ("%s\n".printf(commands));
		script.append ("\n\nexitCode=$?\n");
		script.append ("echo ${exitCode} > ${exitCode}\n");
		script.append ("echo ${exitCode} > status\n");
		
		if ((sh_path == null) || (sh_path.length == 0)){
			sh_path = get_temp_file_path() + ".sh";
		}

		try{
			//write script file
			var file = File.new_for_path (sh_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (script.str);
			data_stream.close();

			// set execute permission
			chmod (sh_path, "u+x");

			return sh_path;
		}
		catch (Error e) {
			if (!supress_errors){
				log_error (e.message);
			}
		}

		return null;
	}

	public string get_temp_file_path(){

		/* Generates temporary file path */

		return TEMP_DIR + "/" + timestamp_numeric() + (new Rand()).next_int().to_string();
	}

	// find process -------------------------------
	
	// dep: which
	public string get_cmd_path (string cmd){

		/* Returns the full path to a command */

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd, out stdout, out stderr, out exitCode);
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	// dep: pidof, TODO: Rewrite using /proc
	public int get_pid_by_name (string name){

		/* Get the process ID for a process with given name */

		string std_out, std_err;
		exec_sync("pidof \"%s\"".printf(name), out std_out, out std_err);
		
		if (std_out != null){
			string[] arr = std_out.split ("\n");
			if (arr.length > 0){
				return int.parse (arr[0]);
			}
		}

		return -1;
	}

	public int get_pid_by_command(string cmdline){

		/* Searches for process using the command line used to start the process.
		 * Returns the process id if found.
		 * */
		 
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name ("/proc");

			enumerator = file.enumerate_children ("standard::name", 0);
			while ((info = enumerator.next_file()) != null) {
				try {
					string io_stat_file_path = "/proc/%s/cmdline".printf(info.get_name());
					var io_stat_file = File.new_for_path(io_stat_file_path);
					if (file.query_exists()){
						var dis = new DataInputStream (io_stat_file.read());

						string line;
						string text = "";
						size_t length;
						while((line = dis.read_until ("\0", out length)) != null){
							text += " " + line;
						}

						if ((text != null) && text.contains(cmdline)){
							return int.parse(info.get_name());
						}
					} //stream closed
				}
				catch(Error e){
					// do not log
					// some processes cannot be accessed by non-admin user
				}
			}
		}
		catch(Error e){
		  log_error (e.message);
		}

		return -1;
	}

	public void get_proc_io_stats(int pid, out int64 read_bytes, out int64 write_bytes){

		/* Returns the number of bytes read and written by a process to disk */
		
		string io_stat_file_path = "/proc/%d/io".printf(pid);
		var file = File.new_for_path(io_stat_file_path);

		read_bytes = 0;
		write_bytes = 0;

		try {
			if (file.query_exists()){
				var dis = new DataInputStream (file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.has_prefix("rchar:")){
						read_bytes = int64.parse(line.replace("rchar:","").strip());
					}
					else if(line.has_prefix("wchar:")){
						write_bytes = int64.parse(line.replace("wchar:","").strip());
					}
				}
			} //stream closed
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	// dep: ps TODO: Rewrite using /proc
	public bool process_is_running(long pid){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}

	// dep: pgrep TODO: Rewrite using /proc
	public bool process_is_running_by_name(string proc_name){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "pgrep -f '%s'".printf(proc_name);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}
	
	// dep: ps TODO: Rewrite using /proc
	public int[] get_process_children (Pid parent_pid){

		/* Returns the list of child processes spawned by given process */

		string std_out, std_err;
		exec_sync("ps --ppid %d".printf(parent_pid), out std_out, out std_err);

		int pid;
		int[] procList = {};
		string[] arr;

		foreach (string line in std_out.split ("\n")){
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }

			pid = 0;
			pid = int.parse (arr[0]);

			if (pid != 0){
				procList += pid;
			}
		}
		return procList;
	}

	// manage process ---------------------------------
	
	public void process_quit(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGTERM to the process to allow it to quit gracefully.
		 * */

		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGTERM);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGTERM);
			}
		}
	}
	
	public void process_kill(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGKILL to the process to kill it forcefully.
		 * It is recommended to use the function process_quit() instead.
		 * */
		
		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGKILL);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGKILL);
			}
		}
	}

	// dep: kill
	public int process_pause (Pid procID){

		/* Pause/Freeze a process */

		return exec_sync ("kill -STOP %d".printf(procID), null, null);
	}

	// dep: kill
	public int process_resume (Pid procID){

		/* Resume/Un-freeze a process*/

		return exec_sync ("kill -CONT %d".printf(procID), null, null);
	}

	// dep: ps TODO: Rewrite using /proc
	public void process_quit_by_name(string cmd_name, string cmd_to_match, bool exact_match){

		/* Kills a specific command */
		
		string std_out, std_err;
		exec_sync ("ps w -C '%s'".printf(cmd_name), out std_out, out std_err);
		//use 'ps ew -C conky' for all users

		string pid = "";
		foreach(string line in std_out.split("\n")){
			if ((exact_match && line.has_suffix(" " + cmd_to_match))
			|| (!exact_match && (line.index_of(cmd_to_match) != -1))){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}

	// process priority ---------------------------------------
	
	public void process_set_priority (Pid procID, int prio){

		/* Set process priority */

		if (Posix.getpriority (Posix.PRIO_PROCESS, procID) != prio)
			Posix.setpriority (Posix.PRIO_PROCESS, procID, prio);
	}

	public int process_get_priority (Pid procID){

		/* Get process priority */

		return Posix.getpriority (Posix.PRIO_PROCESS, procID);
	}

	public void process_set_priority_normal (Pid procID){

		/* Set normal priority for process */

		process_set_priority (procID, 0);
	}

	public void process_set_priority_low (Pid procID){

		/* Set low priority for process */

		process_set_priority (procID, 5);
	}

}

namespace TeeJee.Multimedia{

	using TeeJee.Logging;

	/* Functions for working with audio/video files */

	public long get_file_duration(string filePath){

		/* Returns the duration of an audio/video file using MediaInfo */

		string output = "0";

		try {
			Process.spawn_command_line_sync("mediainfo \"--Inform=General;%Duration%\" \"" + filePath + "\"", out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return long.parse(output);
	}

	public string get_file_crop_params (string filePath){

		/* Returns cropping parameters for a video file using avconv */

		string output = "";
		string error = "";

		try {
			Process.spawn_command_line_sync("avconv -i \"%s\" -vf cropdetect=30 -ss 5 -t 5 -f matroska -an -y /dev/null".printf(filePath), out output, out error);
		}
		catch(Error e){
	        log_error (e.message);
	    }

	    int w=0,h=0,x=10000,y=10000;
		int num=0;
		string key,val;
	    string[] arr;

	    foreach (string line in error.split ("\n")){
			if (line == null) { continue; }
			if (line.index_of ("crop=") == -1) { continue; }

			foreach (string part in line.split (" ")){
				if (part == null || part.length == 0) { continue; }

				arr = part.split (":");
				if (arr.length != 2) { continue; }

				key = arr[0].strip ();
				val = arr[1].strip ();

				switch (key){
					case "x":
						num = int.parse (arr[1]);
						if (num < x) { x = num; }
						break;
					case "y":
						num = int.parse (arr[1]);
						if (num < y) { y = num; }
						break;
					case "w":
						num = int.parse (arr[1]);
						if (num > w) { w = num; }
						break;
					case "h":
						num = int.parse (arr[1]);
						if (num > h) { h = num; }
						break;
				}
			}
		}

		if (x == 10000 || y == 10000)
			return "%i:%i:%i:%i".printf(0,0,0,0);
		else
			return "%i:%i:%i:%i".printf(w,h,x,y);
	}

	public string get_mediainfo (string filePath){

		/* Returns the multimedia properties of an audio/video file using MediaInfo */

		string output = "";

		try {
			Process.spawn_command_line_sync("mediainfo \"%s\"".printf(filePath), out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return output;
	}

}

namespace TeeJee.System{

	using TeeJee.ProcessManagement;
	using TeeJee.Logging;

	// user ---------------------------------------------------
	
	public bool user_is_admin (){

		/* Check if current application is running with admin priviledges */

		try{
			// create a process
			string[] argv = { "sleep", "10" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);

			// try changing the priority
			Posix.setpriority (Posix.PRIO_PROCESS, procId, -5);

			// check if priority was changed successfully
			if (Posix.getpriority (Posix.PRIO_PROCESS, procId) == -5)
				return true;
			else
				return false;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	// dep: whoami
	public string get_user_login(){
		/*
		Returns Login ID of current user.
		If running as 'sudo' it will return Login ID of the actual user.
		*/

		string cmd = "echo ${SUDO_USER:-$(whoami)}";
		string std_out;
		string std_err;
		int ret_val;
		ret_val = exec_script_sync(cmd, out std_out, out std_err);

		string user_name;
		if ((std_out == null) || (std_out.length == 0)){
			user_name = "root";
		}
		else{
			user_name = std_out.strip();
		}

		return user_name;
	}

	public string get_user_home(string custom_user_login = ""){
		string user_login = get_user_login();

		if (custom_user_login.length > 0){
			user_login = custom_user_login;
		}
		
		if (user_login == "root"){
			return "/root";
		}
		else{
			return "/home/%s".printf(user_login);
		}
	}

	// dep: id
	public int get_user_id(string user_login){
		/*
		Returns UID of specified user.
		*/

		int uid = -1;
		string cmd = "id %s -u".printf(user_login);
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		if ((std_out != null) && (std_out.length > 0)){
			uid = int.parse(std_out);
		}

		return uid;
	}

	// application -----------------------------------------------
	
	public string get_app_path(){

		/* Get path of current process */

		try{
			return GLib.FileUtils.read_link ("/proc/self/exe");
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public string get_app_dir(){

		/* Get parent directory of current process */

		try{
			return (File.new_for_path (GLib.FileUtils.read_link ("/proc/self/exe"))).get_parent ().get_path ();
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	// system ------------------------------------

	// dep: cat TODO: rewrite
	public double get_system_uptime_seconds(){

		/* Returns the system up-time in seconds */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "cat /proc/uptime";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			string uptime = std_out.split(" ")[0];
			double secs = double.parse(uptime);
			return secs;
		}
		catch(Error e){
			log_error (e.message);
			return 0;
		}
	}

	public bool check_internet_connectivity(){
		bool connected = false;
		connected = check_internet_connectivity_test1();

		if (connected){
			return connected;
		}
		
		if (!connected){
			connected = check_internet_connectivity_test2();
		}

	    return connected;
	}

	public bool check_internet_connectivity_test1(){
		int exit_code = -1;
		string std_err;
		string std_out;

		string cmd = "ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3`\n";
		cmd += "exit $?";
		exit_code = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (exit_code == 0);
	}

	public bool check_internet_connectivity_test2(){
		int exit_code = -1;
		string std_err;
		string std_out;

		string cmd = "ping -q -w 1 -c 1 google.com\n";
		cmd += "exit $?";
		exit_code = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (exit_code == 0);
	}
	
	public bool shutdown (){

		/* Shutdown the system immediately */

		try{
			string[] argv = { "shutdown", "-h", "now" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	 // open files -----------------------------------
	 
	public bool xdg_open (string file){
		string path = get_cmd_path ("xdg-open");
		if ((path != null)&&(path != "")){
			string cmd = "xdg-open '%s'".printf(escape_single_quote(file));
			int status = exec_script_async(cmd);
			return (status == 0);
		}
		return false;
	}

	public bool exo_open_folder (string dir_path, bool xdg_open_try_first = true){

		/* Tries to open the given directory in a file manager */

		/*
		xdg-open is a desktop-independent tool for configuring the default applications of a user.
		Inside a desktop environment (e.g. GNOME, KDE, Xfce), xdg-open simply passes the arguments
		to that desktop environment's file-opener application (gvfs-open, kde-open, exo-open, respectively).
		We will first try using xdg-open and then check for specific file managers if it fails.
		*/

		string path;
		int status;
		
		if (xdg_open_try_first){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				string cmd = "xdg-open '%s'".printf(escape_single_quote(dir_path));
				status = exec_script_async (cmd);
				return (status == 0);
			}
		}

		foreach(string app_name in
			new string[]{ "nemo", "nautilus", "thunar", "pantheon-files", "marlin"}){
				
			path = get_cmd_path (app_name);
		if ((path != null)&&(path != "")){
				string cmd = "%s '%s'".printf(app_name, escape_single_quote(dir_path));
				status = exec_script_async (cmd);
			return (status == 0);
		}
		}

		if (xdg_open_try_first == false){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				string cmd = "xdg-open '%s'".printf(escape_single_quote(dir_path));
				status = exec_script_async (cmd);
				return (status == 0);
			}
		}

		return false;
	}

	public bool exo_open_textfile (string txt_file){

		/* Tries to open the given text file in a text editor */

		string path;
		int status;
		string cmd;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			cmd = "exo-open '%s'".printf(escape_single_quote(txt_file));
			status = exec_script_async (cmd);
			return (status == 0);
		}

		path = get_cmd_path ("gedit");
		if ((path != null)&&(path != "")){
			cmd = "gedit --new-document '%s'".printf(escape_single_quote(txt_file));
			status = exec_script_async (cmd);
			return (status == 0);
		}

		return false;
	}

	public bool exo_open_url (string url){

		/* Tries to open the given text file in a text editor */

		string path;
		int status;
		string cmd;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("exo-open \"" + url + "\"");
			return (status == 0);
		}

		path = get_cmd_path ("firefox");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("firefox \"" + url + "\"");
			return (status == 0);
		}

		path = get_cmd_path ("chromium-browser");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("chromium-browser \"" + url + "\"");
			return (status == 0);
		}

		return false;
	}

	// timers --------------------------------------------------
	
	public GLib.Timer timer_start(){
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}

	public string timer_elapsed_string(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return "%.0f ms".printf((seconds * 1000 ) + microseconds/1000);
	}

	public void timer_elapsed_print(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		log_msg("%s %lu\n".printf(seconds.to_string(), microseconds));
	}

	public class LinuxDistro : GLib.Object{

		/* Class for storing information about Linux distribution */

		public string dist_id = "";
		public string description = "";
		public string release = "";
		public string codename = "";

		public LinuxDistro(){
			dist_id = "";
			description = "";
			release = "";
			codename = "";
		}

		public string full_name(){
			if (dist_id == ""){
				return "";
			}
			else{
				string val = "";
				val += dist_id;
				val += (release.length > 0) ? " " + release : "";
				val += (codename.length > 0) ? " (" + codename + ")" : "";
				return val;
			}
		}

		public static LinuxDistro get_dist_info(string root_path){

			/* Returns information about the Linux distribution
			 * installed at the given root path */

			LinuxDistro info = new LinuxDistro();

			string dist_file = root_path + "/etc/lsb-release";
			var f = File.new_for_path(dist_file);
			if (f.query_exists()){

				/*
					DISTRIB_ID=Ubuntu
					DISTRIB_RELEASE=13.04
					DISTRIB_CODENAME=raring
					DISTRIB_DESCRIPTION="Ubuntu 13.04"
				*/

				foreach(string line in file_read(dist_file).split("\n")){

					if (line.split("=").length != 2){ continue; }

					string key = line.split("=")[0].strip();
					string val = line.split("=")[1].strip();

					if (val.has_prefix("\"")){
						val = val[1:val.length];
					}

					if (val.has_suffix("\"")){
						val = val[0:val.length-1];
					}

					switch (key){
						case "DISTRIB_ID":
							info.dist_id = val;
							break;
						case "DISTRIB_RELEASE":
							info.release = val;
							break;
						case "DISTRIB_CODENAME":
							info.codename = val;
							break;
						case "DISTRIB_DESCRIPTION":
							info.description = val;
							break;
					}
				}
			}
			else{

				dist_file = root_path + "/etc/os-release";
				f = File.new_for_path(dist_file);
				if (f.query_exists()){

					/*
						NAME="Ubuntu"
						VERSION="13.04, Raring Ringtail"
						ID=ubuntu
						ID_LIKE=debian
						PRETTY_NAME="Ubuntu 13.04"
						VERSION_ID="13.04"
						HOME_URL="http://www.ubuntu.com/"
						SUPPORT_URL="http://help.ubuntu.com/"
						BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
					*/

					foreach(string line in file_read(dist_file).split("\n")){

						if (line.split("=").length != 2){ continue; }

						string key = line.split("=")[0].strip();
						string val = line.split("=")[1].strip();

						switch (key){
							case "ID":
								info.dist_id = val;
								break;
							case "VERSION_ID":
								info.release = val;
								break;
							//case "DISTRIB_CODENAME":
								//info.codename = val;
								//break;
							case "PRETTY_NAME":
								info.description = val;
								break;
						}
					}
				}
			}

			return info;
		}

		public static string get_running_desktop_name(){

			/* Return the names of the current Desktop environment */

			int pid = -1;

			pid = get_pid_by_name("cinnamon");
			if (pid > 0){
				return "Cinnamon";
			}

			pid = get_pid_by_name("xfdesktop");
			if (pid > 0){
				return "Xfce";
			}

			pid = get_pid_by_name("lxsession");
			if (pid > 0){
				return "LXDE";
			}

			pid = get_pid_by_name("gnome-shell");
			if (pid > 0){
				return "Gnome";
			}

			pid = get_pid_by_name("wingpanel");
			if (pid > 0){
				return "Elementary";
			}

			pid = get_pid_by_name("unity-panel-service");
			if (pid > 0){
				return "Unity";
			}

			pid = get_pid_by_name("plasma-desktop");
			if (pid > 0){
				return "KDE";
			}

			return "Unknown";
		}

	}


	// dep: notify-send
	public class OSDNotify : GLib.Object {
		private static DateTime dt_last_notification = null;
		public static const int NOTIFICATION_INTERVAL = 3;
		
		public static int notify_send (
			string title, string message, int durationMillis,
			string urgency = "low", // low, normal, critical
			string dialog_type = "info" //error, info, warning
			){ 

			/* Displays notification bubble on the desktop */

			int retVal = 0;

			switch (dialog_type){
				case "error":
				case "info":
				case "warning":
					//ok
					break;
				default:
					dialog_type = "info";
					break;
			}

			long seconds = 9999;
			if (dt_last_notification != null){
				DateTime dt_end = new DateTime.now_local();
				TimeSpan elapsed = dt_end.difference(dt_last_notification);
				seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
			}

			if (seconds > NOTIFICATION_INTERVAL){
				string s = "notify-send -t %d -u %s -i %s \"%s\" \"%s\"".printf(durationMillis, urgency, "gtk-dialog-" + dialog_type, title, message);
				retVal = exec_sync (s, null, null);
				dt_last_notification = new DateTime.now_local();
			}

			return retVal;
		}

		public static bool is_supported(){
			string path = get_cmd_path ("notify-send");
			if ((path != null) && (path.length > 0)){
				return true;
			}
			else{
				return false;
			}
		}
	}
	
	public class ProcStats : GLib.Object {
		public double user = 0;
		public double nice = 0;
		public double system = 0;
		public double idle = 0;
		public double iowait = 0;

		public double user_delta = 0;
		public double nice_delta = 0;
		public double system_delta = 0;
		public double idle_delta = 0;
		public double iowait_delta = 0;

		public double usage_percent = 0;

		public static ProcStats stat_prev = null;

		public ProcStats(string line){
			string[] arr = line.split(" ");
			int col = 0;
			if (arr[col++] == "cpu"){
				if (arr[col].length == 0){ col++; };

				user = double.parse(arr[col++]);
				nice = double.parse(arr[col++]);
				system = double.parse(arr[col++]);
				idle = double.parse(arr[col++]);
				iowait = double.parse(arr[col++]);

				if (ProcStats.stat_prev != null){
					user_delta = user - ProcStats.stat_prev.user;
					nice_delta = nice - ProcStats.stat_prev.nice;
					system_delta = system - ProcStats.stat_prev.system;
					idle_delta = idle - ProcStats.stat_prev.idle;
					iowait_delta = iowait - ProcStats.stat_prev.iowait;

					usage_percent = (user_delta + nice_delta + system_delta) * 100 / (user_delta + nice_delta + system_delta + idle_delta);
				}
				else{
					usage_percent = 0;

				}

				ProcStats.stat_prev = this;
			}
		}
		
		//returns 0 when it is called first time
		public static double get_cpu_usage(){
			string txt = file_read("/proc/stat");
			foreach(string line in txt.split("\n")){
				string[] arr = line.split(" ");
				if (arr[0] == "cpu"){
					ProcStats stat = new ProcStats(line);
					return stat.usage_percent;
				}
			}
			return 0;
		}
	}

	public class SystemUser : GLib.Object {
		public string name = "";
		public string password = "";
		public int uid = -1;
		public int gid = -1;
		public string user_info = "";
		public string home_path = "";
		public string shell_path = "";

		public string full_name = "";
		public string room_num = "";
		public string phone_work = "";
		public string phone_home = "";
		public string other_info = "";

		//public string
		public string shadow_line = "";
		public string pwd_hash = "";
		public string pwd_last_changed = "";
		public string pwd_age_min = "";
		public string pwd_age_max = "";
		public string pwd_warning_period = "";
		public string pwd_inactivity_period = "";
		public string pwd_expiraton_date = "";
		public string reserved_field = "";
		
		public bool is_selected = false;

		public static Gee.HashMap<string,SystemUser> all_users;

		public SystemUser(string name){
			this.name = name;
		}

		public static void query_users(){
			all_users = read_users_from_file("/etc/passwd","/etc/shadow","");
		}

		public bool is_installed{
			get {
				return SystemUser.all_users.has_key(name);
			}
		}

		public static Gee.HashMap<string,SystemUser> read_users_from_file(
			string passwd_file, string shadow_file, string password){
			
			var list = new Gee.HashMap<string,SystemUser>();

			// read 'passwd' file ---------------------------------
			
			string txt = "";

			if (passwd_file.has_suffix(".tar.gpg")){
				txt = file_decrypt_untar_read(passwd_file, password);
			}
			else{
				txt = file_read(passwd_file);
			}

			if (txt.length == 0){
				return list;
			}

			foreach(string line in txt.split("\n")){
				if ((line == null) || (line.length == 0)){
					continue;
				}
				var user = parse_line_passwd(line);
				if (user != null){
					list[user.name] = user;
				}
			}


			// read 'shadow' file ---------------------------------
			
			txt = "";
			
			if (shadow_file.has_suffix(".tar.gpg")){
				txt = file_decrypt_untar_read(shadow_file, password);
			}
			else{
				txt = file_read(shadow_file);
			}

			if (txt.length == 0){
				return list;
			}

			foreach(string line in txt.split("\n")){
				if ((line == null) || (line.length == 0)){
					continue;
				}
				parse_line_shadow(line, list);
			}

			return list;
		}

		private static SystemUser? parse_line_passwd(string line){
			if ((line == null) || (line.length == 0)){
				return null;
			}
			
			SystemUser user = null;

			//teejee:x:504:504:Tony George:/home/teejee:/bin/bash
			string[] fields = line.split(":");

			if (fields.length == 7){
				user = new SystemUser(fields[0].strip());
				user.password = fields[1].strip();
				user.uid = int.parse(fields[2].strip());
				user.gid = int.parse(fields[3].strip());
				user.user_info = fields[4].strip();
				user.home_path = fields[5].strip();
				user.shell_path = fields[6].strip();

				string[] arr = user.user_info.split(",");
				if (arr.length >= 1){
					user.full_name = arr[0];
				}
				if (arr.length >= 2){
					user.room_num = arr[1];
				}
				if (arr.length >= 3){
					user.phone_work = arr[2];
				}
				if (arr.length >= 4){
					user.phone_home = arr[3];
				}
				if (arr.length >= 5){
					user.other_info = arr[4];
				}
			}
			else{
				log_error("'passwd' file contains a record with non-standard fields" + ": %d".printf(fields.length));
				return null;
			}
			
			return user;
		}

		private static SystemUser? parse_line_shadow(string line, Gee.HashMap<string,SystemUser> list){
			if ((line == null) || (line.length == 0)){
				return null;
			}
			
			SystemUser user = null;

			//root:$1$Etg2ExUZ$F9NTP7omafhKIlqaBMqng1:15651:0:99999:7:::
			//<username>:$<hash-algo>$<salt>$<hash>:<last-changed>:<change-interval-min>:<change-interval-max>:<change-warning-interval>:<disable-expired-account-after-days>:<days-since-account-disbaled>:<not-used>

			string[] fields = line.split(":");

			if (fields.length == 9){
				string user_name = fields[0].strip();
				if (list.has_key(user_name)){
					user = list[user_name];
					user.shadow_line = line;
					user.pwd_hash = fields[1].strip();
					user.pwd_last_changed = fields[2].strip();
					user.pwd_age_min = fields[3].strip();
					user.pwd_age_max = fields[4].strip();
					user.pwd_warning_period = fields[5].strip();
					user.pwd_inactivity_period = fields[6].strip();
					user.pwd_expiraton_date = fields[7].strip();
					user.reserved_field = fields[8].strip();
					return user;
				}
				else{
					log_error("user in file 'shadow' does not exist in file 'passwd'" + ": %s".printf(user_name));
					return null;
				}
			}
			else{
				log_error("'shadow' file contains a record with non-standard fields" + ": %d".printf(fields.length));
				return null;
			}
		}

		public static int add_user(string user_name, bool system_account = false){
			string std_out, std_err;
			string cmd = "adduser%s --gecos '' --disabled-login %s".printf((system_account ? " --system" : ""), user_name);
			log_debug(cmd);
			int status = exec_sync(cmd, out std_out, out std_err);
			if (status != 0){
				log_error(std_err);
			}
			else{
				//log_msg(std_out);
			}
			return status;
		}

		public int add(){
			return add_user(name, is_system);
		}
		
		public bool is_system{
			get {
				return (uid < 1000);
			}
		}

		public string group_names{
			owned get {
				return "";
			}
		}

		public bool update_passwd_file(){
			string file_path = "/etc/passwd";
			string txt = file_read(file_path);
			
			var txt_new = "";
			foreach(string line in txt.split("\n")){
				if (line.strip().length == 0) {
					continue;
				}
				
				string[] parts = line.split(":");

				if (parts.length != 7){
					log_error("'passwd' file contains a record with non-standard fields" + ": %d".printf(parts.length));
					return false;
				}
				
				if (parts[0].strip() == name){
					txt_new += get_passwd_line() + "\n";
				}
				else{
					txt_new += line + "\n";
				}
			}

			file_write(file_path, txt_new);
			
			log_msg("Updated user settings in /etc/passwd" + ": %s".printf(name));
			
			return true;
		}

		public string get_passwd_line(){
			string txt = "";
			txt += "%s".printf(name);
			txt += ":%s".printf(password);
			txt += ":%d".printf(uid);
			txt += ":%d".printf(gid);
			txt += ":%s".printf(user_info);
			txt += ":%s".printf(home_path);
			txt += ":%s".printf(shell_path);
			return txt;
		}
		
		public bool update_shadow_file(){
			string file_path = "/etc/shadow";
			string txt = file_read(file_path);
			
			var txt_new = "";
			foreach(string line in txt.split("\n")){
				if (line.strip().length == 0) {
					continue;
				}
				
				string[] parts = line.split(":");

				if (parts.length != 9){
					log_error("'shadow' file contains a record with non-standard fields" + ": %d".printf(parts.length));
					return false;
				}
				
				if (parts[0].strip() == name){
					txt_new += get_shadow_line() + "\n";
				}
				else{
					txt_new += line + "\n";
				}
			}

			file_write(file_path, txt_new);
			
			log_msg("Updated user settings in /etc/shadow" + ": %s".printf(name));
			
			return true;
		}

		public string get_shadow_line(){
			string txt = "";
			txt += "%s".printf(name);
			txt += ":%s".printf(pwd_hash);
			txt += ":%s".printf(pwd_last_changed);
			txt += ":%s".printf(pwd_age_min);
			txt += ":%s".printf(pwd_age_max);
			txt += ":%s".printf(pwd_warning_period);
			txt += ":%s".printf(pwd_inactivity_period);
			txt += ":%s".printf(pwd_expiraton_date);
			txt += ":%s".printf(reserved_field);
			return txt;
		}
	}

	public class SystemGroup : GLib.Object {
		public string name = "";
		public string password = "";
		public int gid = -1;
		public string user_names = "";

		public string shadow_line = "";
		public string password_hash = "";
		public string admin_list = "";
		public string member_list = "";

		public bool is_selected = false;
		public Gee.ArrayList<string> users;
		
		public static Gee.HashMap<string,SystemGroup> all_groups;

		public SystemGroup(string name){
			this.name = name;
			this.users = new Gee.ArrayList<string>();
		}

		public static void query_groups(){
			all_groups = read_groups_from_file("/etc/group","/etc/gshadow", "");
		}

		public bool is_installed{
			get{
				return SystemGroup.all_groups.has_key(name);
			}
		}

		public static Gee.HashMap<string,SystemGroup> read_groups_from_file(string group_file, string gshadow_file, string password){
			var list = new Gee.HashMap<string,SystemGroup>();

			// read 'group' file -------------------------------
			
			string txt = "";
			
			if (group_file.has_suffix(".tar.gpg")){
				txt = file_decrypt_untar_read(group_file, password);
			}
			else{
				txt = file_read(group_file);
			}
			
			if (txt.length == 0){
				return list;
			}
			
			foreach(string line in txt.split("\n")){
				if ((line == null) || (line.length == 0)){
					continue;
				}
				
				var group = parse_line_group(line);
				if (group != null){
					list[group.name] = group;
				}
			}

			// read 'gshadow' file -------------------------------

			txt = "";
			
			if (gshadow_file.has_suffix(".tar.gpg")){
				txt = file_decrypt_untar_read(gshadow_file, password);
			}
			else{
				txt = file_read(gshadow_file);
			}
			
			if (txt.length == 0){
				return list;
			}
			
			foreach(string line in txt.split("\n")){
				if ((line == null) || (line.length == 0)){
					continue;
				}
				
				parse_line_gshadow(line, list);
			}

			return list;
		}

		private static SystemGroup? parse_line_group(string line){
			if ((line == null) || (line.length == 0)){
				return null;
			}
			
			SystemGroup group = null;

			//cdrom:x:24:teejee,user2
			string[] fields = line.split(":");

			if (fields.length == 4){
				group = new SystemGroup(fields[0].strip());
				group.password = fields[1].strip();
				group.gid = int.parse(fields[2].strip());
				group.user_names = fields[3].strip();
				foreach(string user_name in group.user_names.split(",")){
					group.users.add(user_name);
				}
			}
			else{
				log_error("'group' file contains a record with non-standard fields" + ": %d".printf(fields.length));
				return null;
			}
			
			return group;
		}

		private static SystemGroup? parse_line_gshadow(string line, Gee.HashMap<string,SystemGroup> list){
			if ((line == null) || (line.length == 0)){
				return null;
			}
			
			SystemGroup group = null;

			//adm:*::syslog,teejee
			//<groupname>:<encrypted-password>:<admins>:<members>
			string[] fields = line.split(":");

			if (fields.length == 4){
				string group_name = fields[0].strip();
				if (list.has_key(group_name)){
					group = list[group_name];
					group.shadow_line = line;
					group.password_hash = fields[1].strip();
					group.admin_list = fields[2].strip();
					group.member_list = fields[3].strip();
					return group;
				}
				else{
					log_error("group in file 'gshadow' does not exist in file 'group'" + ": %s".printf(group_name));
					return null;
				}
			}
			else{
				log_error("'gshadow' file contains a record with non-standard fields" + ": %d".printf(fields.length));
				return null;
			}
		}

		public static int add_group(string group_name, bool system_account = false){
			string std_out, std_err;
			string cmd = "groupadd%s %s".printf((system_account)? " --system" : "", group_name);
			int status = exec_sync(cmd, out std_out, out std_err);
			if (status != 0){
				log_error(std_err);
			}
			else{
				//log_msg(std_out);
			}
			return status;
		}

		public int add(){
			return add_group(name,is_system);
		}

		public static int add_user_to_group(string user_name, string group_name){
			string std_out, std_err;
			string cmd = "adduser %s %s".printf(user_name, group_name);
			log_debug(cmd);
			int status = exec_sync(cmd, out std_out, out std_err);
			if (status != 0){
				log_error(std_err);
			}
			else{
				//log_msg(std_out);
			}
			return status;
		}

		public int add_to_group(string user_name){
			return add_user_to_group(user_name, name);
		}
		
		public bool is_system{
			get {
				return (gid < 1000);
			}
		}

		public bool update_group_file(){
			string file_path = "/etc/group";
			string txt = file_read(file_path);
			
			var txt_new = "";
			foreach(string line in txt.split("\n")){
				if (line.strip().length == 0) {
					continue;
				}

				string[] parts = line.split(":");
				
				if (parts.length != 4){
					log_error("'group' file contains a record with non-standard fields" + ": %d".printf(parts.length));
					return false;
				}

				if (parts[0].strip() == name){
					txt_new += get_group_line() + "\n";
				}
				else{
					txt_new += line + "\n";
				}
			}

			file_write(file_path, txt_new);
			
			log_msg("Updated group settings in /etc/group" + ": %s".printf(name));
			
			return true;
		}

		public string get_group_line(){
			string txt = "";
			txt += "%s".printf(name);
			txt += ":%s".printf(password);
			txt += ":%d".printf(gid);
			txt += ":%s".printf(user_names);
			return txt;
		}
	
		public bool update_gshadow_file(){
			string file_path = "/etc/gshadow";
			string txt = file_read(file_path);
			
			var txt_new = "";
			foreach(string line in txt.split("\n")){
				if (line.strip().length == 0) {
					continue;
				}

				string[] parts = line.split(":");
				
				if (parts.length != 4){
					log_error("'gshadow' file contains a record with non-standard fields" + ": %d".printf(parts.length));
					return false;
				}

				if (parts[0].strip() == name){
					txt_new += get_gshadow_line() + "\n";
				}
				else{
					txt_new += line + "\n";
				}
			}

			file_write(file_path, txt_new);
			
			log_msg("Updated group settings in /etc/gshadow" + ": %s".printf(name));
			
			return true;
		}

		public string get_gshadow_line(){
			string txt = "";
			txt += "%s".printf(name);
			txt += ":%s".printf(password_hash);
			txt += ":%s".printf(admin_list);
			txt += ":%s".printf(member_list);
			return txt;
		}
	}
}

namespace TeeJee.Misc {

	/* Various utility functions */

	using Gtk;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;

	// color format -------------------
	
	public static Gdk.RGBA hex_to_rgba (string hex_color){

		/* Converts the color in hex to RGBA */

		string hex = hex_color.strip().down();
		if (hex.has_prefix("#") == false){
			hex = "#" + hex;
		}

		Gdk.RGBA color = Gdk.RGBA();
		if(color.parse(hex) == false){
			color.parse("#000000");
		}
		color.alpha = 255;

		return color;
	}

	public static string rgba_to_hex (Gdk.RGBA color, bool alpha = false, bool prefix_hash = true){

		/* Converts the color in RGBA to hex */

		string hex = "";

		if (alpha){
			hex = "%02x%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)),
									(uint)(Math.round(color.alpha*255)))
									.up();
		}
		else {
			hex = "%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)))
									.up();
		}

		if (prefix_hash){
			hex = "#" + hex;
		}

		return hex;
	}

	// timestamp ----------------
	
	public string timestamp (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%H:%M:%S");
	}

	public string timestamp_numeric (){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp_for_path (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
	}

	// string formatting -------------------------------------------------
	
	public string format_duration (long millis){

		/* Converts time in milliseconds to format '00:00:00.0' */

	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);

        return "%02.0lf:%02.0lf:%02.0lf".printf (hr, min, sec);
	}

	public double parse_time (string time){

		/* Converts time in format '00:00:00.0' to milliseconds */

		string[] arr = time.split (":");
		double millis = 0;
		if (arr.length >= 3){
			millis += double.parse(arr[0]) * 60 * 60;
			millis += double.parse(arr[1]) * 60;
			millis += double.parse(arr[2]);
		}
		return millis;
	}

	public string string_replace(
		string str, string search, string replacement, int count = -1){
			
		string[] arr = str.split(search);
		string new_txt = "";
		bool first = true;
		
		foreach(string part in arr){
			if (first){
				new_txt += part;
			}
			else{
				if (count == 0){
					new_txt += search;
					new_txt += part;
				}
				else{
					new_txt += replacement;
					new_txt += part;
					count--;
				}
			}
			first = false;
		}

		return new_txt;
	}
	
	public string escape_html(string html){
		return html
		.replace("&","&amp;")
		.replace("\"","&quot;")
		//.replace(" ","&nbsp;") //pango markup throws an error with &nbsp;
		.replace("<","&lt;")
		.replace(">","&gt;")
		;
	}

	public string unescape_html(string html){
		return html
		.replace("&amp;","&")
		.replace("&quot;","\"")
		//.replace("&nbsp;"," ") //pango markup throws an error with &nbsp;
		.replace("&lt;","<")
		.replace("&gt;",">")
		;
	}

	public DateTime datetime_from_string (string date_time_string){

		/* Converts date time string to DateTime
		 * 
		 * Supported inputs:
		 * 'yyyy-MM-dd'
		 * 'yyyy-MM-dd HH'
		 * 'yyyy-MM-dd HH:mm'
		 * 'yyyy-MM-dd HH:mm:ss'
		 * */

		string[] arr = date_time_string.replace(":"," ").replace("-"," ").strip().split(" ");

		int year  = (arr.length >= 3) ? int.parse(arr[0]) : 0;
		int month = (arr.length >= 3) ? int.parse(arr[1]) : 0;
		int day   = (arr.length >= 3) ? int.parse(arr[2]) : 0;
		int hour  = (arr.length >= 4) ? int.parse(arr[3]) : 0;
		int min   = (arr.length >= 5) ? int.parse(arr[4]) : 0;
		int sec   = (arr.length >= 6) ? int.parse(arr[5]) : 0;

		return new DateTime.utc(year,month,day,hour,min,sec);
	}

	public string break_string_by_word(string input_text){
		string text = "";
		string line = "";
		foreach(string part in input_text.split(" ")){
			line += part + " ";
			if (line.length > 50){
				text += line.strip() + "\n";
				line = "";
			}
		}
		if (line.length > 0){
			text += line;
		}
		if (text.has_suffix("\n")){
			text = text[0:text.length-1].strip();
		}
		return text;
	}

	public string[] array_concat(string[] a, string[] b){
		string[] c = {};
		foreach(string str in a){ c += str; }
		foreach(string str in b){ c += str; }
		return c;
	}

	public string random_string(
		int length = 8,
		string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"){

		string random = "";

		for(int i=0;i<length;i++){
			int random_index = Random.int_range(0,charset.length);
			string ch = charset.get_char(charset.index_of_nth_char(random_index)).to_string();
			random += ch;
		}

		return random;
	}

	public bool is_numeric(string text){
		for (int i = 0; i < text.length; i++){
			if (!text[i].isdigit()){
				return false;
			}
		}
		return true;
	}

	public string format_time_left(ulong millis){
		double mins = (millis * 1.0) / 60000;
		double secs = ((millis * 1.0) % 60000) / 1000;
		string txt = "";
		if (mins >= 1){
			txt += "%.0fm ".printf(mins);
		}
		txt += "%.0fs".printf(secs);
		return txt;
	}
}
