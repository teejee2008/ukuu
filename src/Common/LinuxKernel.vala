using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.System;
using TeeJee.Misc;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {
	public string name = "";
	public string version = "";
	public string version_main = "";
	public string version_extra = "";
	public string version_package = "";
	public string type = "";
	public string page_uri = "";
	
	public Gee.HashMap<string,string> deb_list = new Gee.HashMap<string,string>();

	public bool is_valid = true;
	public bool is_installed = false;
	public bool is_running = false;

	public string deb_header = "";
	public string deb_header_all = "";
	public string deb_image = "";
	public string deb_image_extra = "";
	
	// static
	
	public static const string URI_KERNEL_UBUNTU_MAINLINE = "http://kernel.ubuntu.com/~kernel-ppa/mainline/";
	public static const string CACHE_DIR = "/var/cache/ukuu";
	public static string NATIVE_ARCH = "";
	public static string LINUX_DISTRO = "";
	public static string RUNNING_KERNEL = "";
	
	public static Gee.ArrayList<LinuxKernel> kernel_list;
	public static int download_count = 0;

	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
		
	// global progress  ------------
	public static string status_line = "";
	public static int progress_total = 0;
	public static int progress_count = 0;
	public static bool cancelled = false;
	public static bool task_is_running = false;
	public static bool _temp_refresh = false;

	// class initialize
	
	public static void initialize(){
		new LinuxKernel("",""); // instance must be created before setting static members

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel();
		initialize_regex();
	}

	// dep: lsb_release
	public static string check_distribution(){
		string dist = "";
		
		string std_out, std_err;
		int status = exec_sync("lsb_release -sd", out std_out, out std_err);
		if ((status == 0) && (std_out != null)){
			dist = std_out.strip();
			log_msg(_("Distribution") + ": %s".printf(dist));
		}
		
		return dist;
	}

	// dep: dpkg
	public static string check_package_architecture(){
		string arch = "";
		
		string std_out, std_err;
		int status = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((status == 0) && (std_out != null)){
			arch = std_out.strip();
			log_msg(_("System architecture") + ": %s".printf(arch));
		}

		return arch;
	}

	// dep: uname
	public static string check_running_kernel(){
		string ver = "";
		
		string std_out;
		exec_sync("uname -r", out std_out, null);
		ver = std_out.strip().replace("\n","");
		log_msg("Running kernel" + ": %s".printf(ver));

		return ver;
	}

	public static void initialize_regex(){
		try{
			//linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_header = new Regex("""linux-headers-[a-zA-Z0-9.\-_]*generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all = new Regex("""linux-headers-[a-zA-Z0-9.\-_]*_all.deb""");

			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("""linux-image-[a-zA-Z0-9.\-_]*generic_([a-zA-Z0-9.\-]*)_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image_extra = new Regex("""linux-image-extra-[a-zA-Z0-9.\-_]*generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public static bool check_if_initialized(){
		bool ok = (NATIVE_ARCH.length > 0);
		if (!ok){
			log_error("LinuxKernel: Class should be initialized before use!");
			exit(1);
		}
		return ok;
	}

	// contructor
	
	public LinuxKernel(string name, string subdir_path){

		if (name.has_suffix("/")){
			this.name = name[0: name.length - 1];
		}
		else{
			this.name = name;
		}

		// parse version string ---------

		version = name;

		// remove "v"
		if (version.has_prefix("v")){
			version = version[1:version.length];
		}
		
		split_version_string(version, out version_main, out version_extra);

		// set page URI -----------
		
		page_uri = "%s%s".printf(URI_KERNEL_UBUNTU_MAINLINE, subdir_path);
	}

	public LinuxKernel.from_version(string version){
	
		name = "v" + version;

		split_version_string(version, out version_main, out version_extra);

		page_uri = "";
	}
	
	// static
	
	public static void query(bool refresh, bool wait){

		check_if_initialized();
		
		var yesterday = (new DateTime.now_local()).add_days(-1);
		if (last_refreshed_date.compare(yesterday) < 0){
			refresh = true;
		}

		_temp_refresh = refresh;
		
		try {
			task_is_running = true;
			cancelled = false;
			Thread.create<void> (query_thread, true);
		} catch (ThreadError e) {
			task_is_running = false;
			log_error (e.message);
		}
		
		if (wait){
			while (task_is_running){
				sleep(500); //wait
			}
		}
	}

	private static void query_thread() {
		if (_temp_refresh){
			download_index();
		}

		load_index();

		status_line = "";
		progress_total = kernel_list.size;
		progress_count = 0;
		
		foreach(var kern in kernel_list){
			if (cancelled){
				break;
			}

			if (file_exists(kern.cached_page + ".404")){
				kern.is_valid = false; // invalid
				continue;
			}
		
			if (!kern.cached_page_exists){
				while (LinuxKernel.download_count > 20){
					sleep(100); // wait
				}
				kern.download_cached_page(false);
			}

			kern.load_cached_page();
			
			progress_count++;
		}

		while (LinuxKernel.download_count > 0){
			sleep(500); // wait
		}

		check_installed();

		task_is_running = false;
	}
	
	public static bool download_index(){

		check_if_initialized();
		
		// fetch index.html --------------------------------------

		dir_create(file_parent(index_page));
		
		if (file_exists(index_page)){
			file_delete(index_page);
		}
		
		var mgr = new DownloadManager("index.html", CACHE_DIR, create_temp_subdir(), URI_KERNEL_UBUNTU_MAINLINE);
		mgr.download_begin();

		var msg = _("Fetching index from site") + " '%s' ...".printf(URI_KERNEL_UBUNTU_MAINLINE);
		log_msg(msg);
		status_line = msg.strip();

		while (mgr.is_running){
			sleep(500);
		}

		//log_debug(index_page);
		
		if (file_exists(index_page)){
			log_msg("OK");
			return true;
		}
		else{
			log_error("ERR");
			return false;
		}
	}

	public static void load_index(){

		var list = new Gee.ArrayList<LinuxKernel>();

		if (!file_exists(index_page)){
			return;
		}

		string txt = file_read(index_page);
		
		// parse index.html --------------------------

		try{
			//<a href="v3.0.16-oneiric/">v3.0.16-oneiric/</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-._\/]+)">([a-zA-Z0-9\-._]+)[\/]*<\/a>""");

			MatchInfo match;

			foreach(string line in txt.split("\n")){
				if (rex.match(line, 0, out match)){
					if (!match.fetch(2).has_prefix("v")){
						continue;
					}
					
					var kern = new LinuxKernel(match.fetch(2),match.fetch(1));
					list.add(kern);
				}
			}

			list.sort((a,b)=>{
				return a.compare_to(b) * -1;
			});
		}
		catch (Error e) {
			log_error (e.message);
		}

		kernel_list = list;
	}

	public static void check_installed(){

		foreach(var kern in kernel_list){
			kern.is_installed = false;
			kern.is_running = false;
		}

		// Running: 4.2.7-040207-generic
		// Package: 4.2.7-040207.201512091533
		
		string ver_running = RUNNING_KERNEL.replace("-generic","");
		
		foreach(var kern in kernel_list){
			if (!kern.is_valid){
				continue;
			}

			string ver_pkg_short = kern.version_package[0 : kern.version_package.last_index_of(".")];

			if (ver_pkg_short == ver_running){
				kern.is_running = true;
				kern.is_installed = true;
				break;
			}
		}

		var list = Package.query_installed_packages();

		var pkg_versions = new Gee.ArrayList<string>();
		
		foreach(var pkg in list.values){
			if (pkg.name.contains("linux-image")){
				if (!pkg_versions.contains(pkg.version_installed)){
					pkg_versions.add(pkg.version_installed);
					log_msg("Found installed" + ": %s".printf(pkg.version_installed));
				}
			}
		}

		foreach (string pkg_version in pkg_versions){
			foreach(var kern in kernel_list){
				if (kern.version_package == pkg_version){
					kern.is_installed = true;
				}
			}
		}
	}

	// helpers
	
	public static void split_version_string(string version_string, out string ver_main, out string ver_extra){
		string[] arr = version_string.split("-");

		if (arr.length == 0){
			ver_main = "";
			ver_extra = "";
			return;
		}
		
		int i = 0;

		// take first part
		ver_main = arr[i++];

		// remove "v"
		if (ver_main.has_prefix("v")){
			ver_main = ver_main[1:ver_main.length];
		}

		// append rc number
		if (arr.length >= 2){
			if (arr[i].contains("rc")){
				ver_main += "-%s".printf(arr[i++]);
			}

			if (arr[i].contains("ckt")){
				ver_main += ".%s".printf(arr[i++].replace("ckt",""));
			}
		}

		// get remaining part
		ver_extra = "";
		for(; i < arr.length; i++){
			ver_extra += "-%s".printf(arr[i]);
		}
	}

	public int compare_to(LinuxKernel b){
		LinuxKernel a = this;
		string[] arr_a = a.version_main.split_set (".-_");
		string[] arr_b = b.version_main.split_set (".-_");

		int i = 0;
		int x, y;

		// while both arrays have an element
		while ((i < arr_a.length) && (i < arr_b.length)){

			// continue if equal
			if (arr_a[i] == arr_b[i]){
				i++;
				continue;
			}
			
			// check if number
			x = int.parse(arr_a[i]);
			y = int.parse(arr_b[i]);
			if ((x > 0) && (y > 0)){
				// both are numbers
				return (x - y);
			}
			else if ((x == 0) && (y == 0)){
				// both are strings
				return strcmp(arr_a[i], arr_b[i]);
			}
			else{
				if (x > 0){
					return 1;
				}
				else{
					return -1;
				}
			}
		}

		// one array has less parts than the other and all corresponding parts are equal

		if (i < arr_a.length){
			x = int.parse(arr_a[i]);
			if (x > 0){
				return 1;
			}
			else{
				return -1;
			}
		}

		if (i < arr_b.length){
			y = int.parse(arr_b[i]);
			if (y > 0){
				return -1;
			}
			else{
				return 1;
			}
		}

		return (arr_a.length - arr_b.length) * -1; // smaller array is larger version
	}
	 
	// properties

	public bool is_rc{
		get {
			return version.contains("-rc");
		}
	}

	public bool is_unstable{
		get {
			return version.contains("-rc") || version.contains("-unstable");
		}
	}
	
	public static string index_page{
		owned get {
			return "%s/index.html".printf(CACHE_DIR);
		}
	}

	public static DateTime last_refreshed_date{
		owned get{
			return file_get_modified_date(index_page);
		}
	}

	public string cache_subdir{
		owned get {
			return "%s/%s".printf(CACHE_DIR, name);
		}
	}
	
	public string cached_page{
		owned get {
			return "%s/index.html".printf(cache_subdir);
		}
	}

	public string changes_file{
		owned get {
			return "%s/CHANGES".printf(cache_subdir);
		}
	}
	
	public bool cached_page_exists{
		get {
			return file_exists(cached_page);
		}
	}

	public string major_version{
		owned get {
			string[] parts = version_main.split(".");
			if (parts.length >= 2){
				return "%s.%s".printf(parts[0],parts[1]);
			}
			return version_main;
		}
	}

	public string minor_version{
		owned get {
			string[] parts = version_main.split(".");
			if (parts.length >= 3){
				return "%s.%s.%s".printf(parts[0],parts[1],parts[2]);
			}
			return version_main;
		}
	}
	
	// download
	
	public bool download_cached_page(bool wait){
		
		// fetch index-<version>.html --------------------------------------

		dir_create(file_parent(cached_page));
		
		if (file_exists(cached_page)){
			return true; // do not download again
		}
		else if (file_exists(cached_page + ".404")){
			is_valid = false; // invalid
			return true; 
		}

		var mgr = new DownloadManager(file_basename(cached_page), cache_subdir, create_temp_subdir(), page_uri);
		
		LinuxKernel.download_count++;
		
		mgr.download_complete.connect(() => {
			LinuxKernel.download_count--;
	
			if (mgr.status_code == 0){
				load_cached_page();
				download_changes_file();
			}
			else if (mgr.status_code == 3){
				file_write("%s/index.html.404".printf(cache_subdir), "");
				is_valid = false;
			}
			else{
				file_write("%s/index.html.%d".printf(cache_subdir, mgr.status_code), "");
				is_valid = false;
			}
		});
		
		mgr.download_begin();

		var msg = "%-60s".printf(_("Fetching index for") + " '%s'... ".printf(name));
		log_msg(msg);
		status_line = "Linux %s ...".printf(name);

		return true;	
	}

	private bool download_changes_file(){

		// fetch file --------------------------------------

		dir_create(file_parent(changes_file));
		
		if (file_exists(changes_file)){
			return true; // do not download again
		}

		var mgr = new DownloadManager(file_basename(changes_file), file_parent(changes_file), create_temp_subdir(), "%s%s".printf(page_uri, "CHANGES"));
		
		LinuxKernel.download_count++;
		
		mgr.download_complete.connect(() => {
			LinuxKernel.download_count--;
	
			if (mgr.status_code == 0){
				// do nothing
			}
			else if (mgr.status_code == 3){
				file_write("%s/%s.%s".printf(cache_subdir, file_basename(changes_file), "404"), "");
				is_valid = false;
			}
			else{
				file_write("%s/%s.%d".printf(cache_subdir, file_basename(changes_file), mgr.status_code), "");
				is_valid = false;
			}
		});
		
		mgr.download_begin();

		var msg = "%-60s".printf(_("Fetching changelog for") + " '%s'... ".printf(name));
		log_msg(msg);
		status_line = "Linux %s ...".printf(name);

		return true;	
	}

	public bool download_packages(){
		bool ok = true;

		check_if_initialized();

		foreach(string file_name in deb_list.keys){
			string file_path = "%s/%s/%s".printf(cache_subdir, NATIVE_ARCH, file_name);

			if (file_exists(file_path)){
				continue;
			}

			dir_create(file_parent(file_path));

			stdout.printf("\n" + _("Downloading") + ": '%s'... \n".printf(file_name));
			stdout.flush();
			
			var mgr = new DownloadManager(file_basename(file_path), file_parent(file_path), TEMP_DIR, deb_list[file_name]);
			mgr.status_in_kb = true;
			mgr.download_begin();

			while (mgr.is_running){
				sleep(200);

				stdout.printf("\r%-70s".printf(mgr.status_line));
				stdout.flush();
			}

			if (file_exists(file_path)){
				stdout.printf("\r%-70s\n".printf(_("OK")));
				stdout.flush();
			}
			else{
				stdout.printf("\r%-70s\n".printf(_("ERROR")));
				stdout.flush();
				ok = false;
			}
		}
		
		return ok;
	}

	// load
	
	public void load_cached_page(){
		
		var list = new Gee.HashMap<string,string>();

		if (!file_exists(cached_page)){
			log_error("load_cached_page: " + _("File not found") + ": %s".printf(cached_page));
			return;
		}

		string txt = file_read(cached_page);
		
		// parse index.html --------------------------

		try{
			//<a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-._]+)">([a-zA-Z0-9\-._]+)<\/a>""");
			MatchInfo match;

			foreach(string line in txt.split("\n")){
				if (rex.match(line, 0, out match)){
					string file_name = match.fetch(2);
					string file_uri = "%s%s".printf(page_uri, match.fetch(1));

					bool add = false;
					
					if (rex_header.match(file_name, 0, out match)){
						deb_header = file_name;
						add = true;
					}

					if (rex_header_all.match(file_name, 0, out match)){
						deb_header_all = file_name;
						add = true;
					}

					if (rex_image.match(file_name, 0, out match)){
						deb_image = file_name;
						add = true;
						
						version_package = match.fetch(1);
					}

					if (rex_image_extra.match(file_name, 0, out match)){
						deb_image_extra = file_name;
						add = true;
					}

					if (add){
						list[file_name] = file_uri; // add to list
					}
				}
			}

			if ((deb_header.length == 0) || (deb_header_all.length == 0) || (deb_image.length == 0)){
				is_valid = false;
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		deb_list = list;
	}

	public void get_package_version(){

		if (NATIVE_ARCH.length == 0){
			log_error("Native architecture is unknown!");
			exit(1);
		}

		//linux_image_pkg_version
		Regex rex_image = null;
		MatchInfo match;
		
		try{
			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("""linux-image-[0-9.\-_]*generic_([0-9.\-]*)_""" + NATIVE_ARCH + ".deb");
		}
		catch (Error e) {
			log_error (e.message);
		}

		foreach(string file_name in deb_list.keys){
			if (rex_image.match(file_name, 0, out match)) {
				
				continue;
			}
		}
	}
	
	// actions

	public static void print_list(){
		log_msg("");
		log_draw_line();
		log_msg(_("Available Kernels"));
		log_draw_line();
		
		foreach(var kern in kernel_list){
			var extra = kern.version_extra;
			extra = extra.has_prefix("-") ? extra[1:extra.length] : extra;
			var desc = kern.is_running ? _("Running") : (kern.is_installed ? _("Installed") : "");
			
			log_msg("%-30s %-15s %-15s %s".printf(kern.name, kern.version_main, extra, desc));
		}
	}

	public bool install(bool write_to_terminal){
		bool ok = download_packages();
		int status = -1;
		
		if (ok){

			log_msg("Preparing to install '%s'".printf(name));
			
			var cmd = "cd '%s/%s' && dpkg -i ".printf(cache_subdir, NATIVE_ARCH);

			foreach(string file_name in deb_list.keys){
				cmd += "'%s' ".printf(file_name);
			}
			
			if (write_to_terminal){
				log_msg("");
				status = Posix.system(cmd); // execute
				log_msg("");
			}
			else{
				status = exec_script_sync(cmd); // execute
			}

			ok = (status == 0);
			if (ok){
				log_msg(_("Installation completed"));
			}
			else{
				log_error(_("Installation completed with errors"));
			}
		}

		return ok;
	}

	public bool remove(bool write_to_terminal){
		bool ok = true;
		int status = -1;
		
		log_msg("Preparing to remove '%s'".printf(name));
		
		var cmd = "dpkg -r ";
		
		// get package names from deb file names
		foreach(string file_name in deb_list.keys){
			cmd += "'%s' ".printf(file_name.split("_")[0]);
		}

		if (write_to_terminal){
			log_msg("");
			status = Posix.system(cmd); // execute
			log_msg("");
		}
		else{
			status = exec_script_sync(cmd); // execute
		}

		ok = (status == 0);
		if (ok){
			log_msg(_("Installation completed"));
		}
		else{
			log_error(_("Installation completed with errors"));
		}

		return ok;
	}

}

