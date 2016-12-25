
/*
 * Version.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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


using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Misc;

namespace TeeJee {
	
	public class Version : GLib.Object, Gee.Comparable<Version> {

		public string version = "";
		public Gee.ArrayList<int> version_numbers;
		
		public Version(string version_string){
			version = version_string;
			version_numbers = new Gee.ArrayList<int>();

			string[] arr = version.split_set (".-_");

			foreach(var part in arr){
				if (is_numeric(part)){
					version_numbers.add(int.parse(part));
				}
				else{
					break;
				}
			}
		}

		public int compare_to(Version b){
			Version a = this;
			int i = 0;

			// while both arrays have an element
			while ((i < a.version_numbers.size) && (i < b.version_numbers.size)){

				// continue if equal
				if (a.version_numbers[i] == b.version_numbers[i]){
					i++;
					continue;
				}
				
				// return difference
				return a.version_numbers[i] - b.version_numbers[i];
			}

			// one array has less parts than the other and all corresponding parts are equal

			// larger array is larger version
			return a.version_numbers.size - b.version_numbers.size; 
		}

		public bool is_minimum(string version_string){
			Version a = this;
			Version b = new Version(version_string);
			return a.compare_to(b) >= 0;
		}

		public bool is_maximum(string version_string){
			Version a = this;
			Version b = new Version(version_string);
			return a.compare_to(b) <= 0;
		}
		
		public bool is_equal(string version_string){
			Version a = this;
			Version b = new Version(version_string);
			return a.compare_to(b) == 0;
		}
	}
}
