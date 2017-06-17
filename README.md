# DAVify - A WebDAV server for Codea

## Features 
#### Simple and easy two way file transfer between Codea and PC over Wi-Fi
* Import project source code and assets directly from your PC into Codea
* Backup projects and assets easily without extracting files from iTunes backups
* WebDAV is widely supported by major operating systems
  * Windows 10, 8 & 7
  * Mac OSx
  * Linux

#### Effortlessly manage your projects and assets in the way that suits you
* Remotely access projects, project collections and assets (Documents & Dropbox) with full control (create, modify, rename and delete)
* Supports all standard project and asset file types
  * Project source files (*.lua, Info.plist)
     * Info.plist is updated automatically when lua files are created, renamed or deleted. 
  * Models (*.obj, modelAssetName.mtl, modelAssetName.obj.mtl) - *Codea Craft required
  * Music (*.m4a, *.wav)
  * Sounds (*.caf)
  * Sprites (*.png, *.pdf)
  * Text (*.txt)
  * Shaders (Fragment.fsh, Vertex.vsh and Info.plist) 

## Installation and setup
#### Codea
* Install DAVify using [Working Copy](https://workingcopyapp.com) 
 * Clone this repository
 * Navigate into the **DAVify.codea** folder
 * **Actions->Copy as Codea project** then open Codea
 * Press and hold **New Project** then press **Paste into project**

#### Windows 10, 8 & 7
* Open **Computer** click **Map network drive**
* Click **Connect to a Web site that you can use to store your documents and pictures**
* Select **Choose a custom network location** click **Next**
* Enter full server url including the port e.g. `http://192.168.0.2:8080`
* Click **Next** then **Finish**
* The Windows DAV client may need some tweaking to get working.
 * If you are experiencing dropouts followed by problems reconnecting try disabling caching with the following reg key.
     *  HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WebClient\Parameters\
     * **FileNotFoundCacheLifeTimeInSec** = 0
     * Don't forget to restart your computer afterwards.
 * If you are experiencing slow connectivity try temporarily disabling automatic proxy detection in Control Panel.
     * **Internet Options->Connections->LAN settings** . 
* You can find a good troubleshooting guide at [http://sabre.io/dav/clients/windows/](http://sabre.io/dav/clients/windows/).

#### Mac OSx
* **Finder -> Go -> Connect to server**
* Enter full server url including the port e.g. `http://192.168.0.2:8080`
* Click **Connect**

#### Linux
* GNOME Files
  * **File -> Connect to server**
  * Enter full server url including the port e.g. `http://192.168.0.2:8080`
  * Click **Connect**

For a list of 3rd party clients see [Comparison of WebDAV software (Wikipedia)](https://en.m.wikipedia.org/wiki/Comparison_of_WebDAV_software).

## Constraints and limitations
* No concurrency control 
   * Avoid concurrent modification of files see [The lost update problem (Wikipedia)](https://en.m.wikipedia.org/w/index.php?title=Concurrency_control&action=edit&section=3)
* Projects
    * Collections must contain at least one project to be persisted
    * Collections cannot contain files
* Assets
	* Codea's standard asset folders cannot be accessed.
* Shaders
    * Can only be created or deleted in Codea
* Sprites
    * Must not exceed Codea's maximum image size (2048x2048) but this isn't validated