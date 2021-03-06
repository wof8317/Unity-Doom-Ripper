package;

import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

/**
 * ...
 * @author Kaelan 'kevans' Evans
 * 
 * This tool is merely meant to extract the IWAD from the unity versions of Doom that were
 * re-released in 2019. Primarily made since they cary unique assets with minor differences
 * from the original 1993 release. This tool, albeit impossible currently, should not be used
 * for the sake of piracy. Please do not distribute the wads this program extracts, I'm super
 * cereal, please don't.
 */
class Main 
{
	static var default_install_path:String = "C:/Program Files (x86)/Bethesda.net Launcher/games";
	static var d1_is_present:Bool = false;
	static var d2_is_present:Bool = false;
	static var d1_fileinput:FileInput;
	static var d2_fileinput:FileInput;
	static var d1_bytes:Bytes;
	static var d2_bytes:Bytes;
	
	static inline var oneHundoSlashes:String = "////////////////////////////////////////////////////////////////////////////////////////////////////";
	static inline var outputfolder:String = "udr_output";
	
	static function main() 
	{
		if (!FileSystem.isDirectory("./" + outputfolder)) FileSystem.createDirectory("./" + outputfolder);
		
		Sys.println("//Bethesda.net Doom wad ripper");
		Sys.println("//Program by kevansevans");
		Sys.println("//https://github.com/kevansevans/Unity-Doom-Ripper");
		
		Sys.println("");
		Sys.println("Please provide the directory where Unity Doom (Bethesda.net) is installed. Hit Enter to assume default path: ");
		Sys.println(default_install_path);
		Sys.print(":> ");
		
		var cmd = Sys.stdin().readLine();
		if (cmd == "" || cmd == null) {
			checkIfGamesAreThere(default_install_path);
		} else {
			checkIfGamesAreThere(cmd);
		}
		
		checkForAddonFolder();
		
		quit();
	}
	static function checkIfGamesAreThere(_path:String) {
		if (_path.toUpperCase() == "SKIP") {
			return;
		}
		Sys.println("Checking for Doom and Doom II...");
		if (FileSystem.exists(_path + "/DOOM_Classic_2019/DOOM_Data/StreamingAssets/doom_disk")) {
			d1_is_present = true;
			d1_fileinput = File.read(_path + "/DOOM_Classic_2019/DOOM_Data/StreamingAssets/doom_disk");
			Sys.println("Ultimate Doom has been found!");
		} else {
			Sys.println("Ultimate Doom is not present.");
		}
		if (FileSystem.exists(_path + "/DOOM_II_Classic_2019/DOOM II_Data/StreamingAssets/doom2_disk")) {
			d2_is_present = true;
			d2_fileinput = File.read(_path + "/DOOM_II_Classic_2019/DOOM II_Data/StreamingAssets/doom2_disk");
			Sys.println("Doom II has been found!");
		} else {
			Sys.println("Doom II is not present.");
		}
		
		if (!d1_is_present && !d2_is_present) {
			Sys.println("Doom games not found, try again? Type 'skip' to ignore this step");
			Sys.print(":> ");
			var cmd = Sys.stdin().readLine();
			checkIfGamesAreThere(cmd);
			return;
		} else if (d1_is_present || d2_is_present) {
			extract();
		}
	}
	
	static function extract() {
		
		if (d1_is_present) {
			Sys.println(oneHundoSlashes);
			Sys.println("Loading Ultimate Doom...");
			d1_fileinput.bigEndian = true;
			d1_bytes = d1_fileinput.readAll();
			unityTextAssetReader(d1_bytes);
			Sys.println("Ultimate Doom Extracted");
			Sys.println(oneHundoSlashes);
		}
		
		if (d2_is_present) {
			Sys.println("Loading Doom II...");
			d2_fileinput.bigEndian = true;
			d2_bytes = d2_fileinput.readAll();
			unityTextAssetReader(d2_bytes);
			Sys.println("Doom II Extracted");
			Sys.println(oneHundoSlashes);
		}
	}
	
	static function unityTextAssetReader(_data:Bytes) {
		
		var wadname:String = "";
		var wadsize:Int = 0;
		var wadout:FileOutput;
		
		for (byte in 0..._data.length) {
			
			if (byte + 4 >= _data.length) break;
			
			var wadcheck:String = _data.getString(byte, 4);
			var skip = false;
			
			if (wadcheck == ".wad") {
				
				/*
				 * This function parses through the byte data and finds wad names that denote the start of a wad.
				 * These names are listed twice within the file, so in order to check which is which, it reads the
				 * bytes until it hits 0x00 or "/". if it hits 0x00, we know we've found the start of a wad.
				 * If we find "/", then we know to skip it as that's metadata for Unity to use. Or something.
				 */
				
				var pos = byte;
				while (_data.get(pos) != 0x00) {
					--pos;
					if (String.fromCharCode(_data.get(pos)) == "/") {
						skip = true;
						break;
					}
				}
				++pos;
				if (skip) continue;
				
				wadname = _data.getString(pos, (byte - pos));
				
				/*
				 * The start of the actual wad and wad size is inconsistently placed after the wad name.
				 * Fortunately, the wad size is always the previous 4 bytes to the wad header.
				 * We read ahead until we find "IWAD" or "PWAD", then use the previous 4 bytes to get the size.
				 */
				
				pos = byte;
				while (_data.getString(pos, 4) != "IWAD" && _data.getString(pos, 4) != "PWAD") {
					++pos;
				}
				wadsize = _data.get(pos - 4) | _data.get(pos - 3) << 8 | _data.get(pos - 2) << 16 | _data.get(pos - 1) << 24;
				
				Sys.println("WAD Found: " + wadname + " @" + wadsize + " bytes");
				
				/*
				 * Wad data is stored plainly within the asset file, we just have to copy the byte range into the new file.
				 * We use the "UNITY" name to denote IWADS so other source ports can recognize them, as stated in the first
				 * comment, these IWADS have minor changes.
				 */
				
				if (_data.getString(pos, 4) == "IWAD") {
					wadout = File.write("./" + outputfolder + "/" + wadname.toUpperCase() + "UNITY.WAD");
					wadout.writeBytes(_data, pos, wadsize);
					wadout.close();
				} else if (_data.getString(pos, 4) == "PWAD") {
					wadout = File.write("./" + outputfolder + "/" + wadname.toUpperCase() + ".WAD");
					wadout.writeBytes(_data, pos, wadsize);
					wadout.close();
				}
			} 
		}
	}
	
	
	static function checkForAddonFolder() 
	{
		var d1_addon_path:Null<String> = null;
		var d2_addon_path:Null<String> = null; 
		var d1_onedrive_path:Null<String> = null; 
		var d2_onedrive_path:Null<String> = null; 
		Sys.println("Scanning for addons...");
		var folders:Array<String> = FileSystem.readDirectory("C:/Users");
		for (dir in folders) {
			if (FileSystem.isDirectory("C:/Users/" + dir + "/Saved Games/id Software")) {
				Sys.println("Addon directory found...");
				if (FileSystem.isDirectory("C:/Users/" + dir + "/Saved Games/id Software/DOOM Classic/WADs")) {
					d1_addon_path = "C:/Users/" + dir + "/Saved Games/id Software/DOOM Classic/WADs";
					Sys.println("Ultimate Doom addon directory found");
				}
				if (FileSystem.isDirectory("C:/Users/" + dir + "/OneDrive/Saved Games/id Software/DOOM Classic/WADs")) {
					d1_onedrive_path = "C:/Users/" + dir + "/OneDrive/Saved Games/id Software/DOOM Classic/WADs";
					Sys.println("Ultimate Doom addon directory found (Onedrive)");
				}
				if (FileSystem.isDirectory("C:/Users/" + dir + "/Saved Games/id Software/DOOM 2/WADs")) {
					d2_addon_path = "C:/Users/" + dir + "/Saved Games/id Software/DOOM 2/WADs";
					Sys.println("Doom II addon directory found");
				}
				if (FileSystem.isDirectory("C:/Users/" + dir + "/OneDriveSaved Games/id Software/DOOM 2/WADs")) {
					d2_onedrive_path = "C:/Users/" + dir + "/OneDrive/Saved Games/id Software/DOOM 2/WADs";
					Sys.println("Doom II addon directory found (Onedrive)");
				}
				if (d1_addon_path == null && d2_addon_path == null && d1_onedrive_path == null && d2_onedrive_path == null) {
					Sys.println("No addon folders found");
					Sys.println(oneHundoSlashes);
					return;
				} else {
					if (d1_addon_path != null) transfer_addons(d1_addon_path);
					if (d2_addon_path != null) transfer_addons(d2_addon_path);
					if (d1_onedrive_path != null) transfer_addons(d1_onedrive_path);
					if (d2_onedrive_path != null) transfer_addons(d2_onedrive_path);
				}
			}
		}
	}
	
	static function transfer_addons(_path:String) 
	{
		/*
		 * All we do here is scan the directories, then copy and paste the wads.
		 * Names are infered by their screenshot preview name, they seem to reflect the original distributed wad name.
		 * "UNITY" is appeneded to the Plutonia and TNT wads for the same reasons as stated above.
		 * AFAIK there's no need to actually check if these are IWADS since they get downloaded into their
		 * own respective folders, and I can assume wads will never replace a previous wad that's been downloaded.
		 */
		
		Sys.println("Starting search for addons in " + _path);
		var addons:Array<String>;
		addons = FileSystem.readDirectory(_path);
		var name:String;
		for (dir in addons) {
			
			if (!FileSystem.isDirectory(_path + "/" + dir)) continue;
			
			var items:Array<String> = FileSystem.readDirectory(_path + "/" + dir);
			name = items[2].substr(0, items[2].length - 5).toUpperCase();
			if (FileSystem.exists("./output/" + name + ".WAD") || FileSystem.exists("./" + outputfolder + "/" + name + "UNITY.WAD")) continue;
			else {
				Sys.println("Addon found:  " + name);
				if (name.toUpperCase() == "PLUTONIA" || name.toUpperCase() == "TNT") {
					File.copy(_path + "/" + dir + "/" + dir, "./" + outputfolder + "/" + name.toUpperCase() + "UNITY.WAD");
				} else {
					File.copy(_path + "/" + dir + "/" + dir, "./" + outputfolder + "/" + name.toUpperCase() + ".WAD");
				}
			}
		}
		Sys.println("Done transfering addons in " + _path);
		Sys.println(oneHundoSlashes);
	}
	static function quit() {
		Sys.println("Program has finished");
		Sys.println(oneHundoSlashes);
		Sys.println("//Bethesda.net Doom wad ripper");
		Sys.println("//Program by kevansevans");
		Sys.println("//https://github.com/kevansevans/Unity-Doom-Ripper");
		Sys.println(oneHundoSlashes);
		Sys.command("start", [outputfolder + "\\"]);
		var cmd = Sys.stdin().readLine();
	}
}