
using TeeJee.Logging;
using TeeJee.FileSystem;
//using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
//using TeeJee.Multimedia;
//using TeeJee.System;
using TeeJee.Misc;

public class DownloadManager : GLib.Object{
	public string name = "";
	public string file_name = "";
	public string download_dir = "";
	public string partial_dir = "";
	public string source_uri = "";
	public int64 size = 0;
	public int64 download_rate = 0;
	public int connect_timeout_secs = 60;
	public int timeout_secs = 60;
	public string md5hash = "";
	public Status status = Status.PENDING;

	public Gee.ArrayList<string> stdout_lines;
	public Gee.ArrayList<string> stderr_lines;
	
	public Pid proc_id;
	public DataInputStream dis_out;
	public DataInputStream dis_err;
	public int64 progress_count = 0;
	public int64 progress_total = 0;
	public double progress_percent = 0.0;
	public string eta = "";
	
	public bool is_running = false;
	public string temp_dir = "";
	public string command = "";
	public string err_line = "";
	public string out_line = "";
	public string status_line = "";

	private static int _download_count = 0;

	// settings
	public bool status_in_kb = false;
	
	// exit status
	public int status_code = 0;
	public string status_message = "";
	
	private Regex regex = null;
	private MatchInfo match;

	Pid child_pid;
	int input_fd;
	int output_fd;
	int error_fd;
	
	public signal void download_complete();
	
	public enum Status{
		PENDING,
		STARTED,
		FINISHED,
		ERROR
	}
	
	public DownloadManager(
		string _file_name,
		string _download_dir,
		string? _partial_dir ,
		string _source_uri){
			
		file_name = _file_name;
		download_dir = _download_dir;
		partial_dir = (_partial_dir == null) ? create_temp_subdir() : _partial_dir;
		source_uri = _source_uri;
		name = _file_name.split("_")[0];

		try {
			//Sample:
			//[#4df0c7 19283968B/45095814B(42%) CN:1 DL:105404B ETA:4m4s]
			regex = new Regex("""^[^ \t]+[ \t]+([0-9]+)B\/([0-9]+)B\(([0-9]+)%\)[ \t]+[^ \t]+[ \t]+DL\:([0-9]+)B[ \t]+ETA\:([^ \]]+)]""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	private string build_command_string(){
		string cmd = "";

		var command = "wget";
		var cmd_path = get_cmd_path ("aria2c");
		if ((cmd_path != null) && (cmd_path.length > 0)) {
			command = "aria2c";
		}

		if (command == "aria2c"){
			cmd += "aria2c";
			cmd += " -d '%s'".printf(partial_dir);
			cmd += " -o '%s'".printf(file_name);
			cmd += " --show-console-readout=false";
			cmd += " --summary-interval=1";
			cmd += " --human-readable=false";
			cmd += " --allow-overwrite";
			cmd += " --connect-timeout=%d".printf(connect_timeout_secs);
			cmd += " --timeout=%d".printf(timeout_secs);
			//cmd += " --direct-file-mapping=false";
			cmd += " '%s'".printf(source_uri);
		}

		log_debug(cmd);

		//cmd = "apt-get update";
		
		return cmd;
	}
	
	private string save_script(string cmd){
		var script = new StringBuilder();
		script.append ("#!/bin/bash\n");
		script.append ("\n");
		script.append ("LANG=C\n");
		script.append ("\n");
		script.append ("%s\n".printf(cmd));
		script.append ("\n\nexitCode=$?\n");
		script.append ("echo ${exitCode} > ${exitCode}\n");
		script.append ("echo ${exitCode} > status\n");

		temp_dir = "%s/%s%ld".printf(TEMP_DIR, timestamp_for_path(), GLib.Random.next_int());
		
		var script_file = temp_dir + "/script.sh";
		//log_msg("%s: %s".printf(name,script_file));
		dir_create (temp_dir);
		
		try {
			// create new script file
			var file = File.new_for_path(script_file);
			var file_stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream(file_stream);
			data_stream.put_string(script.str);
			data_stream.close();
			data_stream = null;
			
			//set execute permission
			chmod(script_file, "u+x");
		}
		catch (Error e) {
			log_error (e.message);
		}

		return script_file;
	}

	public bool download_begin() {

		lock (_download_count) {
			_download_count++;
		}

		status = DownloadManager.Status.STARTED;

		dir_create(partial_dir);
		dir_create(download_dir);

		string src_path = "%s/%s".printf(partial_dir,file_name);
		string dst_path = "%s/%s".printf(download_dir,file_name);
		
		if (file_exists(src_path)){
			file_delete(src_path);
		}
		
		if (file_exists(dst_path)){
			file_delete(dst_path);
		}
		
		string[] argv = new string[1];
		string cmd = build_command_string();
		argv[0] = save_script(cmd);

		progress_count = 0;
		progress_total = size;
		
		try {
			//execute script file
			Process.spawn_async_with_pipes(
			    temp_dir, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    out child_pid,
			    out input_fd,
			    out output_fd,
			    out error_fd);

			is_running = true;
			
			//create stream readers
			UnixInputStream uis_out = new UnixInputStream(output_fd, false);
			UnixInputStream uis_err = new UnixInputStream(error_fd, false);
			dis_out = new DataInputStream(uis_out);
			dis_err = new DataInputStream(uis_err);
			dis_out.newline_type = DataStreamNewlineType.ANY;
			dis_err.newline_type = DataStreamNewlineType.ANY;

			//progress_count = 0;
			stdout_lines = new Gee.ArrayList<string>();
			stderr_lines = new Gee.ArrayList<string>();

			try {
				//start thread for reading output stream
				Thread.create<void> (read_output_line, true);
			} catch (Error e) {
				log_error (e.message);
			}

			try {
				//start thread for reading error stream
				Thread.create<void> (read_error_line, true);
			} catch (Error e) {
				log_error (e.message);
			}

			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	private void read_error_line() {
		try {
			err_line = dis_err.read_line (null);
			while (err_line != null) {
				if (err_line.length > 0){
					//stderr_lines.add(err_line);
					//status_line = err_line;
					log_msg("E: %s".printf(err_line));
				}
				err_line = dis_err.read_line (null); //read next
			}

			// dispose stderr
			dis_err.close();
			dis_err = null;
			GLib.FileUtils.close(error_fd);
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	private void read_output_line() {
		try {
			out_line = dis_out.read_line (null);
			while (out_line != null) {
				if (out_line.length > 0){
					//log_msg("%s".printf(out_line));
					parse_output();
				}
				out_line = dis_out.read_line (null);  //read next
			}

			//log_msg("exit thread");
			
			progress_count = size;
			progress_percent = 100;

			// cleanup -----------------

			// dispose stdout
			GLib.FileUtils.close(output_fd);
			dis_out.close();
			dis_out = null;

			// dispose stdin
			GLib.FileUtils.close(input_fd);

			// dispose child process
			Process.close_pid(child_pid); //required on Windows, doesn't do anything on Unix

			// finish ------------------
			
			verify_and_copy();
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void parse_output() {
		if (status != Status.STARTED){
			return;
		}
		if ((out_line == null) || (out_line.length == 0)){
			return;
		}
		
		if (regex.match(out_line, 0, out match)) {
			progress_count = long.parse(match.fetch(1).strip());
			size = long.parse(match.fetch(2).strip());
			progress_percent = double.parse(match.fetch(3).strip());
			download_rate = long.parse(match.fetch(4).strip());
			eta = match.fetch(5).strip();

			if (status_in_kb){
				status_line = "%s / %s, %s/s (%s)".printf(
					format_file_size(progress_count, false, "", true, 1),
					format_file_size(size, false, "", true, 1),
					format_file_size(download_rate, false, "", true, 1),
					eta).replace("\n","");
			}
			else{
				status_line = "%s / %s, %s/s (%s)".printf(
					format_file_size(progress_count),
					format_file_size(size),
					format_file_size(download_rate),
					eta).replace("\n","");
			}
					
			//log_msg(status_line);
		}
	}

	public int read_status(){
		var path = temp_dir + "/status";
		var f = File.new_for_path(path);
		if (f.query_exists()){
			var txt = file_read(path);
			return int.parse(txt);
		}
		return -1;
	}

	private void verify_and_copy() {
		status_code = read_status();
		
		if (status_code == 0){
			string src_path = "%s/%s".printf(partial_dir,file_name);
			string dst_path = "%s/%s".printf(download_dir,file_name);
			if (file_exists(src_path)){
				file_move(src_path,dst_path);
			}
			else{
				log_error("Download Manager: " + _("File not found") + ": '%s'".printf(src_path));
			}
			
			//log_debug("\nMoving '%s' to '%s'".printf(src_path, dst_path));
			status_line = "OK";
			status = DownloadManager.Status.FINISHED;
		}
		else{
			//leave the partial file
			switch(status_code){
			case 1:
				status_line = "ERROR: Unknown";
				break;
			case 2:
				status_line = "ERROR: Network Time-out";
				break;
			case 3:
				status_line = "ERROR: 404 Not Found";
				break;
			case 6:
				status_line = "ERROR: Network Problem";
				break;
			default:
				status_line = "ERROR: Unknown";
				break;
			}
			
			status = DownloadManager.Status.ERROR;
		}

		status_message = status_line;

		lock (_download_count) {
			_download_count--;
		}
		
		download_complete(); //signal

		is_running = false;
	}

	public static int download_count{
		get {
			int count = 0;
			lock (_download_count) {
				count = _download_count;
			}
			return count;
		}
	}

	public static void reset_counter(){
		lock (_download_count) {
			_download_count = 0;
		}
	}
}

public class DownloadItem : GLib.Object
{


}
