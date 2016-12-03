using TeeJee.Logging;
using TeeJee.FileSystem;
//using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
//using TeeJee.Multimedia;
//using TeeJee.System;
using TeeJee.Misc;

public class Package : GLib.Object {
	public string id = "";
	public string name = "";
	public string description = "";
	public string server = "";
	public string repo = "";
	public string repo_section = "";
	public string arch = "";
	public string status = "";
	public string section = "";
	public string version = "";
	public string version_installed = "";
	public string version_available = "";
	public string depends = "";
	
	public string deb_file_name = "";
	public string deb_uri = "";
	public int64 deb_size = 0;
	public string deb_md5hash = "";
	
	public bool is_selected = false;
	public bool is_available = false;
	public bool is_installed = false;
	public bool is_default = false;
	public bool is_automatic = false;
	public bool is_manual = false;
	public bool is_deb = false;
	
	//convenience members
	public bool is_visible = false;
	public bool in_backup_list = false;

	public static string NATIVE_ARCH = "";

	public static void initialize(){
		string std_out, std_err;
		int status = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((status == 0) && (std_out != null)){
			NATIVE_ARCH = std_out.strip();
		}
	}
	
	public Package(string _name){
		name = _name;
	}

	public bool is_foreign(){
		if (check_if_foreign(arch)){
			return true;
		}
		else{
			return false;
		}
	}

	public static string get_id(string _name, string _arch){
		string str = "";
		str = "%s".printf(_name);
		if (check_if_foreign(_arch)){
			str = str + ":%s".printf(_arch); //make it unique
		}
		return str;
	}
	
	public static bool check_if_foreign(string architecture){
		if ((architecture.length > 0) && (architecture != NATIVE_ARCH) && (architecture != "all") && (architecture != "any")){
			return true;
		}
		else{
			return false;
		}
	}

	public static Gee.HashMap<string,Package> query_installed_packages() {

		var list = new Gee.HashMap<string,Package>();

		string temp_file = get_temp_file_path();
		
		// get installed packages from aptitude --------------
		
		string std_out, std_err;
		int status = exec_sync("aptitude search --disable-columns -F '%p|%v|%M|%d' '?installed'", out std_out, out std_err);
		file_write(temp_file, std_out);

		// parse ------------------------

		try {
			string line;
			var file = File.new_for_path (temp_file);
			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read());
				while ((line = dis.read_line (null)) != null) {
					string[] arr = line.split("|");
					if (arr.length != 4) {
						continue;
					}

					string name = arr[0].strip();
					string arch = (name.contains(":")) ? name.split(":")[1].strip() : "";
					if (name.contains(":")) { name = name.split(":")[0]; }
					string version = arr[1].strip();
					string auto = arr[2].strip();
					string desc = arr[3].strip();
					
					string id = Package.get_id(name,arch);

					Package pkg = null;
					if (!list.has_key(id)) {
						pkg = new Package(name);
						pkg.arch = arch;
						pkg.description = desc;
						pkg.id = Package.get_id(pkg.name,pkg.arch);
						list[pkg.id] = pkg;
					}

					if (pkg != null){
						pkg.is_installed = true;
						pkg.is_automatic = (auto == "A");
						pkg.version_installed = version;
					}
				}
			}
			else {
				log_error (_("File not found: %s").printf(temp_file));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		return list;
	}

	public static Gee.HashMap<string,Package> query_available_packages(string search_string) {

		var list = new Gee.HashMap<string,Package>();

		string temp_file = get_temp_file_path();
		
		// get installed packages from aptitude --------------
		
		string std_out, std_err;
		string cmd = "aptitude search --disable-columns -F '%p|%v|%M|%d' '!installed ?architecture(native) %s".printf(search_string);
		int status = exec_sync(cmd, out std_out, out std_err);
		file_write(temp_file, std_out);

		// parse ------------------------

		try {
			string line;
			var file = File.new_for_path (temp_file);
			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read());
				while ((line = dis.read_line (null)) != null) {
					string[] arr = line.split("|");
					if (arr.length != 4) {
						continue;
					}

					string name = arr[0].strip();
					string arch = (name.contains(":")) ? name.split(":")[1].strip() : "";
					if (name.contains(":")) { name = name.split(":")[0]; }
					string version = arr[1].strip();
					string auto = arr[2].strip();
					string desc = arr[3].strip();
					
					string id = Package.get_id(name,arch);

					Package pkg = null;
					if (!list.has_key(id)) {
						pkg = new Package(name);
						pkg.arch = arch;
						pkg.description = desc;
						pkg.id = Package.get_id(pkg.name,pkg.arch);
						list[pkg.id] = pkg;
					}

					if (pkg != null){
						pkg.is_installed = true;
						pkg.is_automatic = (auto == "A");
						pkg.version_installed = version;
					}
				}
			}
			else {
				log_error (_("File not found: %s").printf(temp_file));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		return list;
	}
}
