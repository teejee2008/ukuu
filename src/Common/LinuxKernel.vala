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

	public int version_maj;
	public int version_min;
	public int version_point;
	
	public Gee.HashMap<string,string> deb_list = new Gee.HashMap<string,string>();
	public Gee.HashMap<string,string> apt_pkg_list = new Gee.HashMap<string,string>();

	public static Gee.HashMap<string,Package> pkg_list_installed;
	
	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = false;
	public bool is_mainline_package = false; // TODO: remove this
	
	public string deb_header = "";
	public string deb_header_all = "";
	public string deb_image = "";
	public string deb_image_extra = "";
	
	// static
	
	public static const string URI_KERNEL_UBUNTU_MAINLINE = "http://kernel.ubuntu.com/~kernel-ppa/mainline/";
	public static string CACHE_DIR = "/var/cache/ukuu";
	public static string NATIVE_ARCH = "";
	public static string LINUX_DISTRO = "";
	public static string RUNNING_KERNEL = "";
	public static string CURRENT_USER = "";
	public static string CURRENT_USER_HOME = "";
	public static bool skip_older = true;
	public static bool skip_unstable = true;

	public static LinuxKernel kernel_active = null;
	public static LinuxKernel kernel_update_major = null;
	public static LinuxKernel kernel_update_minor = null;
	public static LinuxKernel kernel_latest_stable = null;
	
	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();
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
		new LinuxKernel("", false); // instance must be created before setting static members

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
		log_debug(std_out);
		
		ver = std_out.strip().replace("\n","");
		log_msg("Running kernel" + ": %s".printf(ver));

		exec_sync("uname -a", out std_out, null);
		log_debug(std_out);

		string[] arr = std_out.split(ver);
		if (arr.length > 0){
			string[] parts = arr[1].strip().split_set(" -_");
			string partnum = parts[0].strip();
			if (partnum.has_prefix("#")){
				partnum = partnum[1:partnum.length];
				if (is_numeric(partnum) && (partnum.length <= 3)){
					var kern = new LinuxKernel.from_version(ver);
					ver = "%s.%s".printf(kern.version_main, partnum);
				}
			}
		}

		log_msg("Kernel version" + ": %s".printf(ver));
		
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

	public static void clean_cache(){
		if (dir_exists(CACHE_DIR)){
			bool ok = dir_delete(CACHE_DIR);
			if (ok){
				log_msg("Removed cached files in '%s'".printf(CACHE_DIR));
			}
		}
	}
	
	// contructor
	
	public LinuxKernel(string _name, bool _is_mainline){

		if (_name.has_suffix("/")){
			this.name = _name[0: _name.length - 1];
		}
		else{
			this.name = _name;
		}

		// parse version string ---------

		version = this.name;

		// remove "v"
		if (version.has_prefix("v")){
			version = version[1:version.length];
		}
		
		split_version_string(version, out version_main, out version_extra);

		// set page URI -----------
		
		page_uri = "%s%s".printf(URI_KERNEL_UBUNTU_MAINLINE, _name);

		is_mainline = _is_mainline;
	}

	public LinuxKernel.from_version(string version){
	
		name = "v" + version;

		split_version_string(version, out version_main, out version_extra);

		page_uri = "";
	}
	
	// static
	
	public static void query(bool wait){

		check_if_initialized();

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

		log_debug("query: skip_older: %s".printf(skip_older.to_string()));
		log_debug("query: skip_unstable: %s".printf(skip_unstable.to_string()));

		LinuxKernel.download_count = 0;

		bool refresh = false;
		var one_hour_before = (new DateTime.now_local()).add_hours(-1);
		if (last_refreshed_date.compare(one_hour_before) < 0){
			refresh = true;
			log_debug(_("Index is stale"));
		}
		else{
			log_debug(_("Index is fresh"));
		}

		if (refresh){
			download_index();
		}

		load_index();

		var kern_4 = new LinuxKernel.from_version("4.0");
		
		status_line = "";
		progress_total = 0;
		progress_count = 0;
		foreach(var kern in kernel_list){
			if (skip_older && (kern.compare_to(kern_4) < 0)){
				continue;
			}

			if (skip_unstable && kern.is_unstable){
				continue;
			}
			
			if (kern.is_valid && !kern.cached_page_exists){
				progress_total++;
			}
		}

		foreach(var kern in kernel_list){
			if (cancelled){
				break;
			}

			if (kern.cached_page_exists){
				//log_debug("cached page exists: %s".printf(kern.version_main));
				kern.load_cached_page();
				continue;
			}

			if (!kern.is_valid){
				//log_debug("invalid: %s".printf(kern.version_main));
				continue;
			}

			if (skip_older && (kern.compare_to(kern_4) < 0)){
				//log_debug("older than 4.0: %s".printf(kern.version_main));
				continue;
			}

			if (skip_unstable && kern.is_unstable){
				//log_debug("not stable: %s".printf(kern.version_main));
				continue;
			}
		
			if (!kern.cached_page_exists){
				while (LinuxKernel.download_count > 3){
					sleep(100); // wait for counter to decrease
				}
				kern.download_cached_page(false);
				progress_count++;
			}
		}

		// No need to wait for downloads to complete
		// Cached index files will be loaded once downloads is complete

		if (LinuxKernel.download_count > 0){
			sleep(1000); // wait a sec
		}

		check_installed();

		check_updates();
		
		task_is_running = false;
	}
	
	private static bool download_index(){

		check_if_initialized();
		
		// fetch index.html --------------------------------------

		dir_create(file_parent(index_page));
		
		if (file_exists(index_page)){
			file_delete(index_page);
		}
		
		var mgr = new DownloadManager(
			"index.html",
			CACHE_DIR,
			create_temp_subdir(),
			URI_KERNEL_UBUNTU_MAINLINE);
			
		mgr.download_begin();

		var msg = _("Fetching index from kernel.ubuntu.com...");
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

	private static void load_index(){

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
					
					var kern = new LinuxKernel(match.fetch(1), true);
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

		log_debug("check_installed");
		
		foreach(var kern in kernel_list){
			kern.is_installed = false;
			kern.is_running = false;
		}

		pkg_list_installed = Package.query_installed_packages();

		var pkg_versions = new Gee.ArrayList<string>();
		
		foreach(var pkg in pkg_list_installed.values){
			if (pkg.name.contains("linux-image")){
				if (!pkg_versions.contains(pkg.version_installed)){
					
					pkg_versions.add(pkg.version_installed);
					log_msg("Found installed" + ": %s".printf(pkg.version_installed));

					string kern_name = "v%s".printf(pkg.version_installed);
					var kern = new LinuxKernel(kern_name, false);
					kern.is_installed = true;
					kern.set_apt_pkg_list();
					
					if (kern.is_mainline_package){
						continue;
					}
					
					bool found = false;
					foreach(var kernel in kernel_list){
						if (kernel.name == kern.name){
							found = true;
							break;
						}
					}
					
					if (!found){
						kernel_list.add(kern);
					}
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

		// Find and tag the running kernel in list ------------------
		
		// Running: 4.2.7-040207-generic
		// Package: 4.2.7-040207.201512091533

		// Running: 4.4.0-28-generic
		// Package: 4.4.0-28.47
		
		string ver_running = RUNNING_KERNEL.replace("-generic","");
		var kern_running = new LinuxKernel.from_version(ver_running);
		kernel_active = null;
		
		foreach(var kern in kernel_list){
			if (!kern.is_valid){
				continue;
			}

			// check mainline kernels only
			if (!kern.is_mainline){
				continue;
			}

			// compare version_package strings for mainline kernels
			if (kern.version_package.length > 0) {
				string ver_pkg_short = kern.version_package[0 : kern.version_package.last_index_of(".")];

				if (ver_pkg_short == ver_running){
					kern.is_running = true;
					kern.is_installed = true;
					kernel_active = kern;
					break;
				}
			}
		}

		if (kernel_active == null){
			foreach(var kern in kernel_list){
				if (!kern.is_valid){
					continue;
				}

				// check ubuntu kernels only
				if (kern.is_mainline){
					continue;
				}

				if (kern_running.version_main == kern.version_main){
					kern.is_running = true;
					kern.is_installed = true;
					kernel_active = kern;
					break;
				}
			}
		}
		
		kernel_list.sort((a,b)=>{
			return a.compare_to(b) * -1;
		});
	}

	public static void check_available(){

		log_debug("check_available");
		
		var list = Package.query_available_packages("^linux-'");

		var pkg_versions = new Gee.ArrayList<string>();
		
		foreach(var pkg in list.values){
			if (pkg.name.contains("linux-image")){
				if (!pkg_versions.contains(pkg.version_installed)){
					
					pkg_versions.add(pkg.version_installed);
					log_msg("Found upgrade" + ": %s".printf(pkg.version_installed));

					string kern_name = "v%s".printf(pkg.version_installed);
					var kern = new LinuxKernel(kern_name, false);
					kern.is_installed = false;

					if (kern.is_mainline_package){
						continue;
					}
					
					bool found = false;
					foreach(var kernel in kernel_list){
						if (kernel.name == kern.name){
							found = true;
							break;
						}
					}
					
					if (!found){
						kernel_list.add(kern);
					}
				}
			}
		}

		kernel_list.sort((a,b)=>{
			return a.compare_to(b) * -1;
		});
	}

	public static void check_updates(){

		log_debug("check_updates");
		
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_stable = null;
		
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

			if (kernel_latest_stable == null){
				kernel_latest_stable = kern;
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
			
			if (major_available && (kernel_update_major == null)){
				kernel_update_major = kern;
			}
			
			if (minor_available && (kernel_update_minor == null)){
				kernel_update_minor = kern;
			}

			if ((kernel_update_major != null)
				&& (kernel_update_minor != null)
				&& (kernel_latest_stable != null)){
					
				break;
			}
		}
	}

	// helpers
	
	public void split_version_string(
		string version_string,
		out string ver_main,
		out string ver_extra){

		string[] arr = version_string.split_set (".-_");

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

		// append all numbers which are 3 digits or less
		while (i < arr.length){
			if (is_numeric(arr[i]) && (arr[i].length <= 3)){
				ver_main += ".%s".printf(arr[i++]);
			}
			else{
				break;
			}
		}
		
		// v3.11-rc1-saucy
		if (i < arr.length){
			// append rc number
			if (arr[i].contains("rc")){
				ver_main += "-%s".printf(arr[i++]);
			}
		}

		// v3.16.7-ckt26-trusty
		if (i < arr.length){
			if (arr[i].contains("ckt")){
				ver_main += ".%s".printf(arr[i++].replace("ckt",""));
			}
		}
		
		// 4.6.3-040603.201606241434
		// this version string is the package version of a mainline kernel
		
		if ((i < arr.length) && ((i+1) < arr.length)){
			if (is_numeric(arr[i]) && (arr[i].length == 6)
				&& is_numeric(arr[i+1]) && (arr[i+1].length == 12)){
					
				ver_main += ".%s".printf(arr[i++]);
				ver_main += ".%s".printf(arr[i++]);
				is_mainline_package = true;
			}
		}

		// get remaining part
		ver_extra = "";
		if (i < arr.length){
			for(; i < arr.length; i++){
				ver_extra += "-%s".printf(arr[i]);
			}
		}

		//log_debug("split: %s, version_main: %s".printf(version_string, ver_main));
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

	public void mark_invalid(){
		string file = "%s/invalid".printf(cache_subdir);
		if (!file_exists(file)){
			file_write(file, "1");
		}
	}

	public void set_apt_pkg_list(){
		foreach(var pkg in pkg_list_installed.values){
			if (!pkg.name.has_prefix("linux-")){
				continue;
			}
			if (pkg.version_installed == version){
				apt_pkg_list[pkg.name] = pkg.name;
				log_debug("Package: %s".printf(pkg.name));
			}
		}
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

	public bool is_valid {
		get {
			return !file_exists("%s/invalid".printf(cache_subdir));
		}
	}
	
	public static string index_page{
		owned get {
			return "%s/index.html".printf(CACHE_DIR);
		}
	}

	public static DateTime last_refreshed_date{
		owned get{
			if (file_get_size(index_page) < 300000){
				return (new DateTime.now_local()).add_years(-1);
			}
			else{
				return file_get_modified_date(index_page);
			}
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
	
	private bool download_cached_page(bool wait){
		
		// fetch index-<version>.html --------------------------------------

		dir_create(file_parent(cached_page));
		
		if (file_exists(cached_page)){
			return true; // do not download again
		}
		else if (!is_valid){
			return true; 
		}

		var mgr = new DownloadManager(
			file_basename(cached_page),
			cache_subdir,
			create_temp_subdir(),
			page_uri);
		
		mgr.download_complete.connect(() => {
			if (mgr.status_code == 0){
				load_cached_page();
				download_changes_file();
			}
			else if (mgr.status_code == 3){
				file_write("%s/index.html.404".printf(cache_subdir), "");
				mark_invalid();
			}
			else{
				file_write("%s/index.html.%d".printf(cache_subdir, mgr.status_code), "");
				mark_invalid();
			}
		});

		mgr.connect_timeout_secs = 10;
		mgr.timeout_secs = 10;
		
		mgr.download_begin();

		var msg = "%-60s".printf(_("Fetching index for") + " '%s'... ".printf(name));
		log_msg(msg);
		status_line = "> Linux %s".printf(name);

		return true;	
	}

	private bool download_changes_file(){

		// fetch file --------------------------------------

		dir_create(file_parent(changes_file));
		
		if (file_exists(changes_file)){
			return true; // do not download again
		}

		var mgr = new DownloadManager(
			file_basename(changes_file),
			file_parent(changes_file),
			create_temp_subdir(),
			"%s%s".printf(page_uri, "CHANGES"));
		
		mgr.download_complete.connect(() => {
			if (mgr.status_code == 0){
				// do nothing
			}
			else if (mgr.status_code == 3){
				file_write("%s.%s".printf(changes_file, "404"), "");
				mark_invalid();
			}
			else{
				file_write("%s.%d".printf(changes_file, mgr.status_code), "");
				mark_invalid();
			}
		});

		mgr.connect_timeout_secs = 10;
		mgr.timeout_secs = 10;
		
		mgr.download_begin();

		var msg = "%-60s".printf(_("Fetching changelog for") + " '%s'... ".printf(name));
		log_msg(msg);
		status_line = "> Linux %s".printf(name);

		return true;	
	}

	// load
	
	private void load_cached_page(){
		
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
				mark_invalid();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		deb_list = list;
	}

	private void get_package_version(){

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

		var kern_4 = new LinuxKernel.from_version("4.0");
		foreach(var kern in kernel_list){
			if (!kern.is_valid){
				continue;
			}
			if (skip_unstable && kern.is_unstable){
				continue;
			}
			if (skip_older && (kern.compare_to(kern_4) < 0)){
				continue;
			}
			
			var extra = kern.version_extra;
			extra = extra.has_prefix("-") ? extra[1:extra.length] : extra;
			var desc = kern.is_running ? _("Running") : (kern.is_installed ? _("Installed") : "");
			
			log_msg("%-30s %-15s %-15s %s".printf(kern.name, kern.version_main, extra, desc));
		}
	}

	// dep: aria2c
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
				
				if (user_is_admin()){
					chown(file_path, CURRENT_USER, CURRENT_USER);
				}
			}
			else{
				stdout.printf("\r%-70s\n".printf(_("ERROR")));
				stdout.flush();
				ok = false;
			}
		}
		
		return ok;
	}

	// dep: dpkg
	public bool install(bool write_to_terminal){

		// check if installed
		if (is_installed){
			log_error(_("This kernel is already installed."));
			return false;
		}
					
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
				log_msg(_("Installation completed. A reboot is required to use the new kernel."));
			}
			else{
				log_error(_("Installation completed with errors"));
			}
		}

		return ok;
	}

	// dep: dpkg
	public bool remove(bool write_to_terminal){
		bool ok = true;
		int status = -1;

		// check if running
		if (is_running){
			log_error(_("This kernel is currently running and cannot be removed.\n Install another kernel before removing this one."));
			return false;
		}
					
		log_msg("Preparing to remove '%s'".printf(name));
		
		var cmd = "dpkg -r ";

		if (apt_pkg_list.size > 0){
			foreach(var pkg_name in apt_pkg_list.values){
				if (!pkg_name.has_prefix("linux-tools")
					&& !pkg_name.has_prefix("linux-libc")){
						
					cmd += "'%s' ".printf(pkg_name);
				}
			}
		}
		else if (deb_list.size > 0){
			// get package names from deb file names
			foreach(string file_name in deb_list.keys){
				cmd += "'%s' ".printf(file_name.split("_")[0]);
			}
		}
		else{
			stdout.printf("");
			log_error("Could not find the packages to remove!");
			return false;
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
			log_msg(_("Un-install completed"));
		}
		else{
			log_error(_("Un-install completed with errors"));
		}

		return ok;
	}



}

