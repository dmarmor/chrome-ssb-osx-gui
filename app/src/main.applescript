(*
 *
 *  main.applescript: An AppleScript GUI for creating Epichrome apps.
 *
 *  Copyright (C) 2020  David Marmor
 *
 *  https://github.com/dmarmor/epichrome
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *)


-- VERSION

local myVersion
set myVersion to "EPIVERSION"


-- MISC CONSTANTS
local promptNameLoc
set promptNameLoc to "Select name and location for the app."
local appDefaultURL
set appDefaultURL to "https://www.google.com/mail/"
local iconPrompt
set iconPrompt to "Select an image to use as an icon."
local iconTypes
set iconTypes to {"public.jpeg", "public.png", "public.tiff", "com.apple.icns"}

local engineBuiltin
local engineExternal
set engineBuiltin to {id:"internal|com.brave.Browser", buttonName:"Built-In (Brave)"}
set engineExternal to {id:"external|com.google.Chrome", buttonName:"External (Google Chrome)"}


-- USEFUL UTILITY VARIABLES

local errStr
local errNum
local dlgResult


-- SET UP ENVIRONMENT TO EXPORT TO SCRIPTS THAT LOAD CORE.SH

local scriptEnv
set scriptEnv to "logNoStderr='1'"


-- GET MY ICON FOR DIALOG BOXES
local myIcon
set myIcon to path to resource "applet.icns"


-- GET PATHS TO USEFUL RESOURCES IN THIS APP
local coreScript
set coreScript to quoted form of (POSIX path of (path to resource "core.sh" in directory "Runtime/Contents/Resources/Scripts"))
local buildScript
set buildScript to quoted form of (POSIX path of (path to resource "build.sh" in directory "Scripts"))
local pathInfoScript
set pathInfoScript to quoted form of (POSIX path of (path to resource "pathinfo.sh" in directory "Scripts"))
local updateCheckScript
set updateCheckScript to quoted form of (POSIX path of (path to resource "updatecheck.sh" in directory "Scripts"))


-- INITIALIZE LOGGING & DATA DIRECTORY


local coreOutput
local myDataPath
local myLogFile

-- run core.sh to initialize logging & get key paths
try
	set coreOutput to do shell script scriptEnv & " /bin/bash -c 'source '" & quoted form of coreScript & "' --inepichrome ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; else initlogfile ; echo \"$myDataPath\" ; echo \"$myLogFile\" ; fi'"
	set myDataPath to paragraph 1 of coreOutput
	set myLogFile to paragraph 2 of coreOutput
	set scriptEnv to scriptEnv & " myLogFile=" & (quoted form of myLogFile)
on error errStr number errNum
	display dialog "Non-fatal error initializing log: " & errStr & " Logging will not work." with title "Warning" with icon caution buttons {"OK"} default button "OK"
end try

-- ensure we have a data directory
try
	do shell script "if [[ ! -w " & (quoted form of myDataPath) & " ]] ; then false ; fi"
on error errStr number errNum
	display dialog "Error accessing application data folder: " & errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
	return
end try


-- SETTINGS FILE

local mySettingsFile
set mySettingsFile to myDataPath & "/epichrome.plist"


-- PERSISTENT PROPERTIES

local epichromeState
local appState
set epichromeState to {lastIconPath:"", lastAppPath:"", updateCheckDate:(current date) - (1 * days), updateCheckVersion:""}
set appState to {appNameBase:"My Epichrome App", appStyle:"App Window", appURLs:{}, doRegisterBrowser:"No", doCustomIcon:"Yes", appEngineType:id of engineBuiltin}


-- WRITEPROPERTIES: write properties back to plist file
on writeProperties(mySettingsFile, epichromeState, appState)

	local myProperties

	tell application "System Events"

		try
			-- create empty plist file
			set myProperties to make new property list file with properties {contents:make new property list item with properties {kind:record}, name:mySettingsFile}

			-- fill property list with epichromeState
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastIconPath", value:lastIconPath of epichromeState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastAppPath", value:lastAppPath of epichromeState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:date, name:"updateCheckDate", value:updateCheckDate of epichromeState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"updateCheckVersion", value:updateCheckVersion of epichromeState}

			-- fill property list with appState
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"appStyle", value:appStyle of appState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doRegisterBrowser", value:doRegisterBrowser of appState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doCustomIcon", value:doCustomIcon of appState}
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"appEngineType", value:appEngineType of appState}
		on error errStr number errNum
			-- ignore errors, we just won't have persistent properties
		end try
	end tell
end writeProperties


-- READ PROPERTIES FROM USER DATA OR INITIALIZE THEM IF NONE FOUND

tell application "System Events"

	local myProperties

	-- read in the file
	try
		set myProperties to property list file mySettingsFile
	on error
		set myProperties to null
	end try

	-- set properties from the file & if anything went wrong, initialize any unset properties

	-- lastIconPath
	try
		set lastIconPath of epichromeState to (value of (get property list item "lastIconPath" of myProperties) as text)
	on error
		set lastIconPath of epichromeState to ""
	end try

	-- lastAppPath
	try
		set lastAppPath of epichromeState to (value of (get property list item "lastAppPath" of myProperties) as text)
	on error
		set lastAppPath of epichromeState to ""
	end try

	-- updateCheckDate
	try
		set updateCheckDate of epichromeState to (value of (get property list item "updateCheckDate" of myProperties) as date)
	on error
		set updateCheckDate of epichromeState to (current date) - (1 * days)
	end try

	-- updateCheckVersion
	try
		set updateCheckVersion of epichromeState to (value of (get property list item "updateCheckVersion" of myProperties) as string)
	on error
		set updateCheckVersion of epichromeState to ""
	end try

	-- appStyle
	try
		set appStyle of appState to (value of (get property list item "appStyle" of myProperties) as text)
	on error
		set appStyle of appState to "App Window"
	end try

	-- doRegisterBrowser
	try
		set doRegisterBrowser of appState to (value of (get property list item "doRegisterBrowser" of myProperties) as text)
	on error
		set doRegisterBrowser of appState to "No"
	end try

	-- doCustomIcon
	try
		set doCustomIcon of appState to (value of (get property list item "doCustomIcon" of myProperties) as text)
	on error
		set doCustomIcon of appState to "Yes"
	end try

	-- appEngineType
	try
		set appEngineType of appState to (value of (get property list item "appEngineType" of myProperties) as text)
		if appEngineType of appState starts with "external" then
			set appEngineType of appState to (id of engineExternal)
		else
			set appEngineType of appState to (id of engineBuiltin)
		end if
	on error
		set appEngineType of appState to (id of engineBuiltin)
	end try

end tell


-- NUMBER OF STEPS IN THE PROCESS
local curStep
set curStep to 1
on step(curStep)
	return "Step " & curStep & " of 8 | Epichrome EPIVERSION"
end step


-- BUILD REPRESENTATION OF BROWSER TABS
on tablist(tabs, tabnum)
	local ttext
	local t
	local ti

	if (count of tabs) is 0 then
		return "No tabs specified.

Click \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
	else
		set ttext to (count of tabs) as text
		if ttext is "1" then
			set ttext to ttext & " tab"
		else
			set ttext to ttext & " tabs"
		end if
		set ttext to ttext & " specified:
"

		-- add tabs themselves to the text
		set ti to 1
		repeat with t in tabs
			if ti is tabnum then
				set ttext to ttext & "
  *  [the tab you are editing]"
			else
				set ttext to ttext & "
  -  " & t
			end if
			set ti to ti + 1
		end repeat
		if ti is tabnum then
			set ttext to ttext & "
  *  [new tab will be added here]"
		end if
		return ttext
	end if
end tablist


-- CHECK FOR UPDATES TO EPICHROME

local curDate
set curDate to current date

if (updateCheckDate of epichromeState) < curDate then
	-- set next update for 1 week from now
	set updateCheckDate of epichromeState to (curDate + (7 * days))

	-- run the update check script
	local updateCheckResult
	try
		set updateCheckResult to do shell script scriptEnv & " /bin/bash -c 'source '" & (quoted form of updateCheckScript) & "' '" & (quoted form of (quoted form of (updateCheckVersion of epichromeState))) & "' '" & (quoted form of (quoted form of myVersion)) & "' ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; fi'"
		set updateCheckResult to paragraphs of updateCheckResult
	on error errStr number errNum
		set updateCheckResult to {"ERROR", errStr}
	end try

	-- parse update check results

	if item 1 of updateCheckResult is "MYVERSION" then
		-- updateCheckVersion is older than the current version, so update it
		set updateCheckVersion of epichromeState to myVersion
		set updateCheckResult to rest of updateCheckResult
	end if

	if item 1 of updateCheckResult is "ERROR" then
		-- update check error: fail silently, but check again in 3 days instead of 7
		set updateCheckDate of epichromeState to (curDate + (3 * days))
	else
		-- assume "OK" status
		set updateCheckResult to rest of updateCheckResult

		if (count of updateCheckResult) is 1 then

			-- update check found a newer version on GitHub
			local newVersion
			set newVersion to item 1 of updateCheckResult
			try
				set dlgResult to button returned of (display dialog "A new version of Epichrome (" & newVersion & ") is available on GitHub." with title "Update Available" buttons {"Download", "Later", "Ignore This Version"} default button "Download" cancel button "Later" with icon myIcon)
			on error number -128
				-- Later: do nothing
				set dlgResult to false
			end try

			-- Download or Ignore
			if dlgResult is "Download" then
				open location "GITHUBUPDATEURL"
			else if dlgResult is "Ignore This Version" then
				set updateCheckVersion of epichromeState to newVersion
			end if
		end if -- (count of updateCheckResult) is 1
	end if -- item 1 of updateCheckResult is "ERROR"
end if


-- BUILD THE APP

repeat
	-- STEP 1: SELECT APPLICATION NAME & LOCATION
	repeat
		try
			display dialog "Click OK to select a name and location for the app." with title step(curStep) with icon myIcon buttons {"OK", "Quit"} default button "OK" cancel button "Quit"
			exit repeat
		on error number -128
			try
				display dialog "The app has not been created. Are you sure you want to quit?" with title "Confirm" with icon myIcon buttons {"No", "Yes"} default button "Yes" cancel button "No"
				writeProperties(mySettingsFile, epichromeState, appState)
				return -- QUIT
			on error number -128
			end try
		end try
	end repeat


	-- APPLICATION FILE SAVE DIALOGUE
	repeat
		-- CHOOSE WHERE TO SAVE THE APP

		local appPath
		set appPath to false
		local tryAgain
		set tryAgain to true

		repeat while tryAgain
			set tryAgain to false -- assume we'll succeed

			-- show file selection dialog
			local lastAppPathAlias
			try
				set lastAppPathAlias to ((lastAppPath of epichromeState) as alias)
			on error
				set lastAppPathAlias to ""
			end try
			try
				if lastAppPathAlias is not "" then
					set appPath to (choose file name with prompt promptNameLoc default name (appNameBase of appState) default location lastAppPathAlias) as text
				else
					set appPath to (choose file name with prompt promptNameLoc default name (appNameBase of appState)) as text
				end if
			on error number -128
				exit repeat
			end try

			-- break down the path & canonicalize app name
			local appInfo
			try
				set appInfo to do shell script pathInfoScript & " app " & quoted form of (POSIX path of appPath)
			on error errStr number errNum
				display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
				writeProperties(mySettingsFile, epichromeState, appState)
				return -- QUIT
			end try

			local appDir
			set appDir to (paragraph 1 of appInfo)
			set appNameBase of appState to (paragraph 2 of appInfo)
			local appShortName
			set appShortName to (paragraph 3 of appInfo)
			local appName
			set appName to (paragraph 4 of appInfo)
			set appPath to (paragraph 5 of appInfo)
			local appExtAdded
			set appExtAdded to (paragraph 6 of appInfo)

			-- update the last path info
			set lastAppPath of epichromeState to (((POSIX file appDir) as alias) as text)


			-- check if we have permission to write to this directory
			if (do shell script "#!/bin/bash
if [[ -w \"" & appDir & "\" ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") is not "Yes" then
				display dialog "You don't have permission to write to that folder. Please choose another location for your app." with title "Error" with icon stop buttons {"OK"} default button "OK"
				set tryAgain to true
			else
				-- if no ".app" extension was given, check if they accidentally chose an existing app without confirming
				if appExtAdded is "TRUE" then
					-- see if an app with the given base name exists
					local appExists
					set appExists to false
					tell application "Finder"
						try
							if exists ((POSIX file appPath) as alias) then set appExists to true
						end try
					end tell
					if appExists then
						try
							display dialog "A file or folder named \"" & appName & "\" already exists. Do you want to replace it?" with icon caution buttons {"Cancel", "Replace"} default button "Cancel" cancel button "Cancel" with title "File Exists"
						on error number -128
							set tryAgain to true
						end try
					end if
				end if
			end if
		end repeat

		if appPath is false then
			exit repeat
		end if

		set curStep to curStep + 1

		repeat

			-- STEP 2: SHORT APP NAME

			local appShortNamePrompt
			set appShortNamePrompt to "Enter the app name that should appear in the menu bar (16 characters or less)."

			set tryAgain to true

			local appShortNameCanceled
			local appShortNamePrev
			repeat while tryAgain
				set tryAgain to false
				set appShortNameCanceled to false
				set appShortNamePrev to appShortName
				try
					set appShortName to text returned of (display dialog appShortNamePrompt with title step(curStep) with icon myIcon default answer appShortName buttons {"OK", "Back"} default button "OK" cancel button "Back")
				on error number -128 -- Back button
					set appShortNameCanceled to true
					set curStep to curStep - 1
					exit repeat
				end try

				if (count of appShortName) > 16 then
					set tryAgain to true
					set appShortNamePrompt to "That name is too long. Please limit the name to 16 characters or less."
					set appShortName to ((characters 1 thru 16 of appShortName) as text)
				else if (count of appShortName) < 1 then
					set tryAgain to true
					set appShortNamePrompt to "No name entered. Please try again."
					set appShortName to appShortNamePrev
				end if
			end repeat

			if appShortNameCanceled then
				exit repeat
			end if

			-- STEP 3: CHOOSE APP STYLE
			set curStep to curStep + 1

			repeat
				try
					set appStyle of appState to button returned of (display dialog "Choose App Style:

APP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)

BROWSER TABS - The app will display a full browser window with the given tabs." with title step(curStep) with icon myIcon buttons {"App Window", "Browser Tabs", "Back"} default button (appStyle of appState) cancel button "Back")

				on error number -128 -- Back button
					set curStep to curStep - 1
					exit repeat
				end try

				-- STEP 4: CHOOSE URLS
				set curStep to curStep + 1

				-- initialize URL list
				if (appURLs of appState is {}) and (appStyle of appState is "App Window") then
					set appURLs of appState to {appDefaultURL}
				end if

				repeat
					if appStyle of appState is "App Window" then
						-- APP WINDOW STYLE
						try
							set (item 1 of (appURLs of appState)) to text returned of (display dialog "Choose URL:" with title step(curStep) with icon myIcon default answer (item 1 of (appURLs of appState)) buttons {"OK", "Back"} default button "OK" cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try
					else
						-- BROWSER TABS
						local curTab
						set curTab to 1
						repeat
							if curTab > (count of (appURLs of appState)) then
								try
									set dlgResult to display dialog tablist(appURLs of appState, curTab) with title step(curStep) with icon myIcon default answer appDefaultURL buttons {"Add", "Done (Don't Add)", "Back"} default button "Add" cancel button "Back"
								on error number -128 -- Back button
									set dlgResult to "Back"
								end try

								if dlgResult is "Back" then
									if curTab is 1 then
										set curTab to 0
										exit repeat
									else
										set curTab to curTab - 1
									end if
								else if (button returned of dlgResult) is "Add" then
									-- add the current text to the end of the list of URLs
									set (end of (appURLs of appState)) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Done (Don't Add)"
									-- we're done, don't add the current text to the list
									exit repeat
								end if
							else
								local backButton
								set backButton to 0
								if curTab is 1 then
									try
										set dlgResult to display dialog tablist(appURLs of appState, curTab) with title step(curStep) with icon myIcon default answer (item curTab of (appURLs of appState)) buttons {"Next", "Remove", "Back"} default button "Next" cancel button "Back"
									on error number -128
										set backButton to 1
									end try
								else
									set dlgResult to display dialog tablist(appURLs of appState, curTab) with title step(curStep) with icon myIcon default answer (item curTab of (appURLs of appState)) buttons {"Next", "Remove", "Previous"} default button "Next"
								end if

								if (backButton is 1) or ((button returned of dlgResult) is "Previous") then
									if backButton is 1 then
										set curTab to 0
										exit repeat
									else
										set (item curTab of (appURLs of appState)) to text returned of dlgResult
										set curTab to curTab - 1
									end if
								else if (button returned of dlgResult) is "Next" then
									set (item curTab of (appURLs of appState)) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Remove"
									if curTab is 1 then
										set appURLs of appState to rest of (appURLs of appState)
									else if curTab is (count of (appURLs of appState)) then
										set appURLs of appState to (items 1 thru -2 of (appURLs of appState))
										set curTab to curTab - 1
									else
										set appURLs of appState to ((items 1 thru (curTab - 1) of (appURLs of appState))) & ((items (curTab + 1) thru -1 of (appURLs of appState)))
									end if
								end if
							end if
						end repeat

						if curTab is 0 then
							-- we hit the back button
							set curStep to curStep - 1
							exit repeat
						end if
					end if

					-- STEP 5: REGISTER AS BROWSER?
					set curStep to curStep + 1

					repeat
						try
							set doRegisterBrowser of appState to button returned of (display dialog "Register app as a browser?" with title step(curStep) with icon myIcon buttons {"No", "Yes", "Back"} default button (doRegisterBrowser of appState) cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try

						-- STEP 6: SELECT ICON FILE
						set curStep to curStep + 1

						repeat
							try
								set doCustomIcon of appState to button returned of (display dialog "Do you want to provide a custom icon?" with title step(curStep) with icon myIcon buttons {"Yes", "No", "Back"} default button (doCustomIcon of appState) cancel button "Back")
							on error number -128 -- Back button
								set curStep to curStep - 1
								exit repeat
							end try

							repeat
								if doCustomIcon of appState is "Yes" then

									-- CHOOSE AN APP ICON

									-- show file selection dialog
									local lastIconPathAlias
									try
										set lastIconPathAlias to ((lastIconPath of epichromeState) as alias)
									on error
										set lastIconPathAlias to ""
									end try

									local appIconSrc
									try
										if lastIconPathAlias is not "" then

											set appIconSrc to choose file with prompt iconPrompt of type iconTypes default location lastIconPathAlias without invisibles
										else
											set appIconSrc to choose file with prompt iconPrompt of type iconTypes without invisibles
										end if

									on error number -128
										exit repeat
									end try

									-- get icon path info
									set appIconSrc to (POSIX path of appIconSrc)
									-- break down the path & canonicalize icon name
									try
										set appInfo to do shell script pathInfoScript & " icon " & quoted form of appIconSrc
									on error errStr number errNum
										display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
										writeProperties(mySettingsFile, epichromeState, appState)
										return -- QUIT
									end try

									set lastIconPath of epichromeState to (((POSIX file (paragraph 1 of appInfo)) as alias) as text)
									local appIconName
									set appIconName to (paragraph 2 of appInfo)

								else
									set appIconSrc to ""
								end if

								-- STEP 7: SELECT ENGINE
								set curStep to curStep + 1

								-- initialize engine choice buttons
								local appEngineButton
								if appEngineType of appState starts with "external" then
									set appEngineButton to buttonName of engineExternal
								else
									set appEngineButton to buttonName of engineBuiltin
								end if

								repeat
									try
										set appEngineButton to button returned of (display dialog "Use built-in app engine, or external browser engine?

NOTE: If you don't know what this question means, choose Built-In.

In almost all cases, using the built-in engine will result in a more functional app. Using an external browser engine has several disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.

The main reason to choose the external browser engine is if your app must run on a signed browser (for things like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension)." with title step(curStep) with icon myIcon buttons {buttonName of engineBuiltin, buttonName of engineExternal, "Back"} default button appEngineButton cancel button "Back")
									on error number -128 -- Back button
										set curStep to curStep - 1
										exit repeat
									end try

									-- set app engine
									if appEngineButton is (buttonName of engineExternal) then
										set appEngineType of appState to (id of engineExternal)
									else
										set appEngineType of appState to (id of engineBuiltin)
									end if



									-- STEP 8: CREATE APPLICATION
									set curStep to curStep + 1

									-- create summary of the app
									local appSummary
									set appSummary to "Ready to create!

App: " & appName & "

Menubar Name: " & appShortName & "

Path: " & appDir & "

"
									if appStyle of appState is "App Window" then
										set appSummary to appSummary & "Style: App Window

URL: " & (item 1 of (appURLs of appState))
									else
										set appSummary to appSummary & "Style: Browser Tabs

Tabs: "
										if (count of (appURLs of appState)) is 0 then
											set appSummary to appSummary & "<none>"
										else
											repeat with t in (appURLs of appState)
												set appSummary to appSummary & "
  -  " & t
											end repeat
										end if
									end if
									set appSummary to appSummary & "

Register as Browser: " & doRegisterBrowser of appState & "

Icon: "
									if appIconSrc is "" then
										set appSummary to appSummary & "<default>"
									else
										set appSummary to appSummary & appIconName
									end if

									set appSummary to appSummary & "

App Engine: "
									set appSummary to appSummary & appEngineButton

									-- set up Chrome command line
									local appCmdLine
									set appCmdLine to ""
									if appStyle of appState is "App Window" then
										set appCmdLine to quoted form of ("--app=" & (item 1 of (appURLs of appState)))
									else if (count of (appURLs of appState)) > 0 then
										repeat with t in (appURLs of appState)
											set appCmdLine to appCmdLine & " " & quoted form of t
										end repeat
									end if

									repeat
										try
											display dialog appSummary with title step(curStep) with icon myIcon buttons {"Create", "Back"} default button "Create" cancel button "Back"
										on error number -128 -- Back button
											set curStep to curStep - 1
											exit repeat
										end try


										-- CREATE THE APP

										repeat
											local creationSuccess
											set creationSuccess to false
											try
												do shell script scriptEnv & " /bin/bash -c 'source '" & (quoted form of buildScript) & "' '" & (quoted form of (quoted form of appPath)) & "' '" & (quoted form of (quoted form of (appNameBase of appState))) & "' '" & (quoted form of (quoted form of appShortName)) & "' '" & (quoted form of (quoted form of appIconSrc)) & "' '" & (quoted form of (quoted form of (doRegisterBrowser of appState))) & "' '" & (quoted form of (quoted form of (appEngineType of appState))) & "' '" & (quoted form of appCmdLine) & "' ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; fi'"
												set creationSuccess to true
											on error errStr number errNum

												-- unable to create app due to permissions
												if errStr is "PERMISSION" then
													set errStr to "Unable to write to \"" & appDir & "\"."
												end if

												if not creationSuccess then
													local dlgButtons
													try
														set dlgButtons to {"Quit", "Back"}
														try
															((POSIX file myLogFile) as alias)
															copy "View Log & Quit" to end of dlgButtons
														end try
														set dlgResult to button returned of (display dialog "Creation failed: " & errStr with icon stop buttons dlgButtons default button "Quit" cancel button "Back" with title "Application Not Created")
														if dlgResult is "View Log & Quit" then
															tell application "Finder" to reveal ((POSIX file myLogFile) as alias)
															tell application "Finder" to activate
														end if
														writeProperties(mySettingsFile, epichromeState, appState) -- Quit button
														return -- QUIT
													on error number -128 -- Back button
														exit repeat
													end try
												end if
											end try

											-- SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
											try
												set dlgResult to button returned of (display dialog "Created Epichrome app \"" & appNameBase of appState & "\".

IMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it." with title "Success!" buttons {"Launch Now", "Reveal in Finder", "Quit"} default button "Launch Now" cancel button "Quit" with icon myIcon)
											on error number -128
												writeProperties(mySettingsFile, epichromeState, appState) -- "Quit" button
												return -- QUIT
											end try

											-- launch or reveal
											if dlgResult is "Launch Now" then
												delay 1
												try
													do shell script "/usr/bin/open " & quoted form of (POSIX path of appPath)
													--tell application appName to activate
												on error
													writeProperties(mySettingsFile, epichromeState, appState)
													return -- QUIT
												end try
											else
												--if (button returned of dlgResult) is "Reveal in Finder" then
												tell application "Finder" to reveal ((POSIX file appPath) as alias)
												tell application "Finder" to activate
											end if

											writeProperties(mySettingsFile, epichromeState, appState) -- We're done!
											return -- QUIT

										end repeat

									end repeat

								end repeat

								exit repeat -- We always kick back to the question of whether to use a custom icon
							end repeat

						end repeat

					end repeat

				end repeat

			end repeat

		end repeat

		exit repeat -- always kick back to the first dialogue (instead of the file save dialog)

	end repeat

end repeat
