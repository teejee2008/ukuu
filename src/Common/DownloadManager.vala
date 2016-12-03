
using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;


public class DownloadTask : AsyncTask{
	public string name = "";
	public string file_name = "";
	public string download_dir = "";
	public string partial_dir = "";
	public string source_uri = "";
	public int64 size = 0;
	public int64 download_rate = 0;
	public string md5hash = "";

	// settings
	public bool status_in_kb = false;
	public int connect_timeout_secs = 60;
	public int timeout_secs = 60;

	public Gee.ArrayList<DownloadItem> downloads;

	protected Gee.HashMap<string,Regex> regex = null;

	public DownloadTask(){

		base();
		
		downloads = new Gee.ArrayList<DownloadItem>();

		regex = new Gee.HashMap<string,Regex>();
		
		try {
			//Sample:
			//[#4df0c7 19283968B/45095814B(42%) CN:1 DL:105404B ETA:4m4s]
			regex["file-progress"] = new Regex("""^[^ \t]+[ \t]+([0-9]+)B\/([0-9]+)B\(([0-9]+)%\)[ \t]+[^ \t]+[ \t]+DL\:([0-9]+)B[ \t]+ETA\:([^ \]]+)]""");

			//12/03 21:15:33 [NOTICE] Download complete: /home/teejee/.cache/ukuu/v4.7.8/CHANGES
			regex["file-complete"] = new Regex("""[0-9A-Z\/: ]*\[NOTICE\] Download complete\: (.*)""");

			//8ae3a3|OK  |    16KiB/s|/home/teejee/.cache/ukuu/v4.0.7-wily/index.html
			//bea740|OK  |        n/a|/home/teejee/.cache/ukuu/v4.0.9-wily/CHANGES
			regex["file-status"] = new Regex("""^([0-9A-Za-z]+)\|(OK|ERR)[ ]*\|[ ]*(n\/a|[0-9.]+[A-Za-z\/]+)\|(.*)""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	// execution ----------------------------

	public void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public void prepare() {
		string script_text = build_script();
		save_bash_script_temp(script_text, script_file);
	}

	private string build_script() {
		string cmd = "";
		
		var command = "wget";
		var cmd_path = get_cmd_path ("aria2c");
		if ((cmd_path != null) && (cmd_path.length > 0)) {
			command = "aria2c";
		}

		if (command == "aria2c"){

			string list = "";
			string list_file = path_combine(working_dir, "download.list");
			foreach(var item in downloads){
				list += "%s\n".printf(item.source_uri);
				list += "  dir=%s\n".printf(item.download_dir);
				list += "  out=%s\n".printf(item.file_name);
				dir_create(item.download_dir);
			}
			file_write(list_file, list);
			
			cmd += "aria2c";
			cmd += " -i '%s'".printf(escape_single_quote(list_file));
			cmd += " --show-console-readout=false";
			cmd += " --summary-interval=1";
			cmd += " --human-readable=false";
			cmd += " --enable-color=false";
			cmd += " --allow-overwrite";
			cmd += " --connect-timeout=%d".printf(connect_timeout_secs);
			cmd += " --timeout=%d".printf(timeout_secs);
			//cmd += " --summary-interval=2";
			cmd += " --max-concurrent-downloads=20";
			//cmd += " --optimize-concurrent-downloads=true";
			//cmd += " -l download.log";
			//cmd += " --direct-file-mapping=false";
		}

		log_debug(cmd);

		return cmd;
	}
	
	public override void parse_stdout_line(string out_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {
		if ((line == null) || (line.length == 0)) {
			return true;
		}

		MatchInfo match;
		
		if (regex["file-complete"].match(line, 0, out match)) {
			//log_msg("match: file-complete: " + line);
			prg_count++;
		}
		else if (regex["file-status"].match(line, 0, out match)) {

			// always display
			log_msg(line);
			
			string hash = match.fetch(1).strip();
			string status = match.fetch(2).strip();
			//string rate = match.fetch(3).strip();
			string file = match.fetch(4).strip();
			foreach(var item in downloads){
				if (item.file_path == file){
					item.hash = hash;
					item.status = status;
					break;
				}
			}
		}
		else if (regex["file-progress"].match(line, 0, out match)) {

			//log_msg("match: file-status: " + line);
			
			/*prg_count = long.parse(match.fetch(1).strip());
			size = long.parse(match.fetch(2).strip());
			percent = double.parse(match.fetch(3).strip());
			download_rate = long.parse(match.fetch(4).strip());
			eta = match.fetch(5).strip();

			if (status_in_kb){
				status_line = "%s / %s, %s/s (%s)".printf(
					format_file_size(prg_count, false, "", true, 1),
					format_file_size(size, false, "", true, 1),
					format_file_size(download_rate, false, "", true, 1),
					eta).replace("\n","");
			}
			else{
				status_line = "%s / %s, %s/s (%s)".printf(
					format_file_size(prg_count),
					format_file_size(size),
					format_file_size(download_rate),
					eta).replace("\n","");
			}*/
					
			//log_msg(status_line);
		}
		else {
			//log_msg("unmatched: '%s'".printf(line));
		}
		
		return true;
	}

	protected override void finish_task(){
		
		verify();

		dir_delete(working_dir);
	}

	private void verify() {
		foreach(var item in downloads){
			if (item.status != "OK"){
				file_delete(item.file_path);
			}
		}
	}

	public int read_status(){
		var status_file = working_dir + "/status";
		var f = File.new_for_path(status_file);
		if (f.query_exists()){
			var txt = file_read(status_file);
			return int.parse(txt);
		}
		return -1;
	}
}


public class DownloadItem : GLib.Object
{
	public string file_name = "";
	public string download_dir = "";
	public string partial_dir = "";
	public string source_uri = "";
	public int64 size = 0;
	public int64 downloaded_bytes = 0;
	public string hash = "";
	public string status = "";

	public string file_path{
		owned get{
			return path_combine(download_dir, file_name);
		}
	}
	
	public DownloadItem(
		string _source_uri,
		string _download_dir,
		string _file_name
		){
			
		file_name = _file_name;
		download_dir = _download_dir;
		partial_dir = create_temp_subdir();
		source_uri = _source_uri;
	}
}
