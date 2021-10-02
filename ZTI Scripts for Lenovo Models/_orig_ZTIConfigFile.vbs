
' // ***************************************************************************
' // 
' // Copyright (c) Microsoft Corporation.  All rights reserved.
' // 
' // Microsoft Deployment Toolkit Solution Accelerator
' //
' // File:      ZTIConfigFile.wsf
' // 
' // Version:   6.3.8456.1000
' // 
' // Purpose:   Common Routines for processing MDT XML files
' // 
' // ***************************************************************************


Option Explicit


Class ConfigFile

	'
	' Public Classes
	' 
	Public ROOT_FOLDER_GUID
	Public HIDDEN_FOLDER_GUID

	Public sFileType
	Public sSelectionProfile
	Public sCustomSelectionProfile
	Public sGroupList
	Public bMustSucceed
	Public bEnabled
	Public bHidden

	' HTML Related Properties
	Public sEnabledElements
	Public sButtonStyle
	Public sItemIcon
	Public sHTMLPropertyHook
	
	Public fnCustomFilter


	'
	' Private Classes
	' 

	Private g_oGroupControlFile
	Private g_oControlFile
	
	Private g_dFolders
	Private g_dElementsToFolders
	Private g_dEnabled
	Private g_xPath
	Private g_dSelections
	Private g_GetChildFolders
	Private g_FindAllItems
	Private g_FindFilteredItems
	

	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'
	' Support routines
	'

	Private Function GetChildFolders ( sParent )  ' AS DictionaryObject

		Dim sXPath
		Dim sNewPath
		Dim sNewParent
		Dim bFound
		Dim bSubFolder

		If g_GetChildFolders is nothing then

			set g_GetChildFolders = CreateObject("Scripting.Dictionary")
			'TestAndFail not ( GetChildFolders is nothing), 10103, "Create Scripting Object"
			g_GetChildFolders.CompareMode = vbTextCompare 


			For each sNewPath in dFolders
			
				sNewParent = oFSO.GetParentFolderName(sNewPath)
				
				If ucase(sNewPath) <> "HIDDEN" and ucase(sNewPath) <> "DEFAULT" then
					while  sNewPath <> ""

						If not g_GetChildFolders.exists(sNewParent) then
							g_GetChildFolders.Add  sNewParent, sNewPath
						Else
							bFound = False
							for each bSubFolder in split(g_GetChildFolders.Item(sNewParent), vbTab )
								If ucase(bSubFolder) = ucase(sNewPath) then
									bFound = True
									Exit for
								End if
							next
							If not bFound then
								g_GetChildFolders.Item(sNewParent) = g_GetChildFolders.Item(sNewParent) & vbTab & sNewPath
							End if
						End if
				
						sNewPath = sNewParent
						sNewParent = oFSO.GetParentFolderName(sNewPath)

					wend
				End if
				
			next
			
			If g_GetChildFolders.exists("") and not g_GetChildFolders.exists("default") then
				g_GetChildFolders.add "default", g_GetChildFolders.item("") 
			End if
			
			oLogging.CreateEntry "GetChildFolders Dictionary Object Created, count = " & g_GetChildFolders.count, LogTypeVerbose
			for each sNewPath in g_GetChildFolders
				' oLogging.CreateEntry vbTab & " GetChildFolders(" & sNewPath & ") = [" & g_GetChildFolders.Item(sNewPath) & "]" , LogTypeVerbose
			next

		End if
		
		GetChildFolders = split(g_GetChildFolders.item(sParent), vbTab )

	End function


	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

	Public Function FindAllItems

		Dim sGuid
		Dim oItem
		
		If g_FindAllItems is nothing then
		
			set g_FindAllItems = CreateObject("Scripting.Dictionary")
			'TestAndLog not ( g_FindAllItems is nothing), 10101, "Create Scripting Object"
			g_FindAllItems.CompareMode = vbTextCompare

			' Open file and query nodes
			oLogging.CreateEntry "FindAllItems File:(" & sFileType & ") xPathFilter: /*/*" , LogTypeVerbose

			' Open the XML Collection and parse through each object
			for each oItem in oControlFile.SelectNodes("/*/*")
				sGuid = oItem.getAttribute("guid")
				If not g_FindAllItems.Exists( sGuid )  then
					g_FindAllItems.Add sGuid, oItem
				End if
			next
			
			oLogging.CreateEntry "FindAllItems(" & sFileType & ") size: " & g_FindAllItems.Count, LogTypeVerbose
			
		End if
		
		set FindAllItems = g_FindAllItems

	End function 
	
	
	Public Function FindFilteredItems

		Dim sGuid
		Dim oItem
		
		If g_FindFilteredItems is nothing then
		
			set g_FindFilteredItems = CreateObject("Scripting.Dictionary")
			'TestAndLog not ( g_FindFilteredItems is nothing), 10101, "Create Scripting Object"
			g_FindFilteredItems.CompareMode = vbTextCompare

			' Open file and query nodes
			oLogging.CreateEntry "FindFilteredItems File:(" & sFileType & ") xPathFilter: " & xPathFilter , LogTypeVerbose

			' Open the XML Collection and parse through each object
			for each oItem in oControlFile.SelectNodes(xPathFilter)
				sGuid = oItem.getAttribute("guid")
				If not g_FindFilteredItems.Exists( sGuid )  then
					g_FindFilteredItems.Add sGuid, oItem
				Else
					oLogging.CreateEntry "Integrity Error: FindFilteredItems: " & sGuid, LogTypeWarning
				End if
			next
			
			oLogging.CreateEntry "FindAllItems(" & sFileType & ") size: " & g_FindFilteredItems.Count, LogTypeVerbose
			
		End if
		
		set FindFilteredItems = g_FindFilteredItems

	End function


	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	
	Private Function FindItemsByFolderEx ( oFolder, byref dApprovedList, bFilter )
	
		DIm sFound
		Dim sName
		Dim oGroupList
		Dim oGroupItem
		Dim sGuid
		Dim oMember
	
		sName = oUtility.SelectSingleNodeString(oFolder,"Name")
		
		set oGroupList = oEnvironment.ListItem( sGroupList )
		oLogging.CreateEntry "Filter [" & sName & "] on Selection Profile: '" & sSelectionProfile & "' and GroupList('" & sGroupList & "').Count = " & oGroupList.Count, LogTypeVerbose

		' Filter out Folders by Selection Profile and/or Group
		If (ucase(sSelectionProfile) = "EVERYTHING" or ucase(sSelectionProfile) = "" or bFilter) and (sCustomSelectionProfile = "") then
			sFound = "Selection Profile: Everything"
			oLogging.CreateEntry "Selection Profile: Everything", LogTypeVerbose
		Else

			If TestProfile( sName ) <> "" then
				sFound = "Selection Profile: " & sName
			
			ElseIf oGroupList.Count > 0 then
				If oGroupList.Exists(sName) then
					sFound = "Group: " & sName
					
				ElseIf len(sName) > 1 and ucase(oEnvironment.Item("SkipGroupSubFolders")) <> "YES" then
					' If it is a subfolder of the group.
					for each oGroupItem in oGroupList
						If InStr(1,sName & "\", oGroupItem, vbTextCompare ) <> 0 then
							sFound = "Group(Sub): " & sName
						End if
					next
				End if
			End if
		End if
		
		If sFound = "" then
			oLogging.CreateEntry "No matching Selection Profiles and/or Groups found.", LogTypeVerbose
			Exit function
		End if
		
		oLogging.CreateEntry "FindItemsByFolderEx: " & sFound, LogTypeVerbose

		' Open the XML Collection and parse through each object
		for each oMember in oFolder.SelectNodes("./Member")
			sGuid = oMember.text
			
			If FindFilteredItems.Exists(sGuid) then

				' Filter items from a custom filter
				If sGuid <> "" then
					If not isempty(fnCustomFilter) then

						If not FnCustomFilter( sGuid, FindFilteredItems.Item(sGuid) ) then
							oLogging.CreateEntry "Remove( CustomFn ): " & sGuid, LogTypeVerbose
							sGuid = ""
						End if
					End if
				End if
				
				If sGuid <> "" then
					oLogging.CreateEntry "Found ID: " & sGuid, LogTypeVerbose
					If not dApprovedList.Exists( sGuid )  then
						dApprovedList.Add sGuid, FindFilteredItems.Item(sGuid)
					End if
				End if
			Else
			
				oLogging.CreateEntry "Remove ( FilterX ): " & sGuid, LogTypeVerbose
			End if

		next

		oLogging.CreateEntry "   FindItemsByFolder(" & sName & ") size: " & dApprovedList.Count, LogTypeVerbose

	End function
	
	
	Private Function FindItemsByFolder ( oFolder ) ' AS DictionaryObject

		Dim sGuid
		Dim oItem
		Dim oMember
		
		set FindItemsByFolder = CreateObject("Scripting.Dictionary")
		'TestAndFail not ( FindItemsByFolder is nothing), 10101, "Create Scripting Object"
		FindItemsByFolder.CompareMode = vbTextCompare

		FindItemsByFolderEx oFolder, FindItemsByFolder, False
		
		oLogging.CreateEntry "FindItemsByFolder(" & sFileType & ") size: " & FindItemsByFolder.Count, LogTypeVerbose

	End function 
	

	
	Public Function FindItemsExFull ' AS DictionaryObject
	
		Dim oFolder
		
		set FindItemsExFull = CreateObject("Scripting.Dictionary")
		'TestAndFail not ( FindItemsExFull is nothing), 10101, "Create Scripting Object"
		FindItemsExFull.CompareMode = vbTextCompare
		
		
		for each oFolder in dFolders.Items
			FindItemsByFolderEx  oFolder, FindItemsExFull, False
		next

		oLogging.CreateEntry "FindItemsExFull(" & sFileType & ") size: " & FindItemsExFull.Count, LogTypeVerbose

	End function 

	
	' Wrapper functions

	Function FindItemsEx( NewxPathFilter ) 
	
		g_xPath = NewxPathFilter
		set FindItemsEx = FindItemsExFull
		
	End function

	Function FindItemsFull ( NewxPathFilter, sNewFileType, sNewSelectionProfile, sNewGroupList, bNewMustSucceed )
	
		sFileType = sNewFileType
		sSelectionProfile = sNewSelectionProfile
		sGroupList = sNewGroupList
		bMustSucceed = bNewMustSucceed
		g_xPath = NewxPathFilter
		
		set FindItemsFull = FindItemsExFull
	End function 
	
	Function FindItems
		' Typical Settings (Enabled = True, Hidden = False)
		set FindItems = FindItemsExFull
	End function
	

	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'
	' Build HTML Representation of XML list
	'
	
	Function GetHTML  ' AS String
	
		Dim oFolder
		
		set oFolder = oGroupControlFile.SelectSingleNode("/*/*[@guid='" & ROOT_FOLDER_GUID & "']")
		TestAndLog not ( oFolder is nothing ), "oGroupControlFile.SelectSingleNode(...Root...)"
		
		If not oFolder is nothing then
			GetHTML = BuildHTML_Folder ( oFolder , 0)
		End if 
	
	End function 
	
	
	Function GetHTMLEx ( sNewButtonStyle, sNewEnabledElements )  ' AS String
	
		sButtonStyle = sNewButtonStyle
		sEnabledElements = sNewEnabledElements
	
		GetHTMLEx = GetHTML
	
	End function 
	

	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'
	' Stateful File handles
	'
	
	Public Property Get xPathFilter
	
		If isempty(g_xPath) then		
			g_xPath = "/*/*[" & XPathFilterString( bEnabled, bHidden ) & "]"
		End if
		
		xPathFilter = g_xPath
		
	End Property
	
	Public Property Let xPathFilter(newxPath)
	
		g_xPath = newxPath
		
	end Property 
	
	Private Function oGroupControlFile  ' AS DOMDocument
	
		If g_oGroupControlFile is nothing then
			oLogging.CreateEntry vbTab & "Open Control File: " & sFileType, LogTypeInfo
		
			set g_oGroupControlFile = oUtility.LoadConfigFileEx (Left(sFileType, len(sFileType)-1) + "groups.xml", false )
		End if
		
		set oGroupControlFile = g_oGroupControlFile
		
	End function
	
	Public Function oControlFile  ' AS DOMDocument
	
		If g_oControlFile is nothing then
			set g_oControlFile = oUtility.LoadConfigFileEx (sFileType + ".xml", bMustSucceed )
			g_oControlFile.setProperty "SelectionLanguage", "XPath"
		End if
		
		set oControlFile = g_oControlFile
	
	End function
	
	Private Function dFolders   ' AS DictionaryObject
		Dim oItem
		Dim sXPath
	
		If g_dFolders is nothing then
		
			oLogging.CreateEntry "Create dFolders object. List of all Folders/Groups for: " & sFileType, LogTypeVerbose
			set g_dFolders = CreateObject("Scripting.Dictionary")
			'TestAndFail not ( g_dFolders is nothing), 10106, "Create Scripting Object"
			g_dFolders.CompareMode = vbTextCompare
			
			sXPath = "/*/*[" + XPathFilterString( bEnabled, empty ) + " and (@guid != '" & HIDDEN_FOLDER_GUID & "')]"

			oLogging.CreateEntry "Ready to test xPath: " & sXPath , LogTypeVerbose
			for each oItem in oGroupControlFile.SelectNodes( sXPath )
			
				If not g_dFolders.Exists(oUtility.SelectSingleNodeString(oItem,"./Name")) then
					g_dFolders.Add oUtility.SelectSingleNodeString(oItem,"./Name"), oItem
				End if
				
			next 
			
			oLogging.CreateEntry "dFolders Dictionary Object Created, count = " & g_dFolders.count, LogTypeVerbose
			
		End if
		
		set dFolders = g_dFolders
	
	End function


	Private Function TestProfile( byval sPathToTest )
	
		Dim oItem
		Dim oDefinition
		Dim oSel
		Dim sPath
        Dim oXmlData
		
		If isempty(g_dSelections) then
		
			set g_dSelections = CreateObject("Scripting.Dictionary")
			'TestAndFail not ( g_dSelections is nothing), 10103, "Create Scripting Object"
			g_dSelections.CompareMode = vbTextCompare 

			set oDefinition = oUtility.CreateXMLDOMObject

			' If a "Custom" profile has been defined, use it first
			If sCustomSelectionProfile <> "" then
			
				oDefinition.LoadXML sCustomSelectionProfile
				for each oSel in oDefinition.SelectNodes("/*/*")
					' oLogging.CreateEntry vbTab & "Add Folder (" & (ucase(oSel.nodename) = "INCLUDE") & "): " & oSel.getAttribute("path"), LogTypeInfo
					g_dSelections.Add oSel.getAttribute("path"), ucase(oSel.nodename) = "INCLUDE"
				next
			Else
				set oXmlData = oUtility.LoadConfigFileEx( "SelectionProfiles.xml", false)
				oXmlData.setProperty "SelectionLanguage", "XPath"
				For each oItem in oXmlData.DocumentElement.SelectNodes("/*/*[translate(Name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')= '" + lcase(sSelectionProfile) + "']")
					oDefinition.LoadXML oUtility.SelectSingleNodeString(oItem,"Definition")
                    For each oSel in oDefinition.SelectNodes("/*/*")
						' oLogging.CreateEntry vbTab & "Add Folder (" & (ucase(oSel.nodename) = "INCLUDE") & "): " & oSel.getAttribute("path"), LogTypeInfo
						g_dSelections.Add oSel.getAttribute("path"), ucase(oSel.nodename) = "INCLUDE"
					next
				next
			End if

			oLogging.CreateEntry "Finished Parsing SelectionProfile '" & sSelectionProfile & "' Folder Matches = " & g_dSelections.Count, LogTypeVerbose
		
		End if
		
		TestProfile = ""
		Select case ucase(sFileType)
			case "OPERATINGSYSTEMS"
				sPathToTest =  "Operating Systems\" & sPathToTEst
			case "DRIVERS"
				sPathToTest =  "Out-of-Box Drivers\" & sPathToTEst
			case "TASKSEQUENCES"
				sPathToTest =  "Task Sequences\" & sPathToTEst
			case else
				sPathToTest =  sFileType & "\" & sPathToTEst
		End Select

		Do while len(sPathToTest) > 0 
		
			If g_dSelections.exists( sPathToTest ) then
				oLogging.CreateEntry vbTab & "Found profile match for [" & sSelectionProfile & "] = " & sPathToTest, LogTypeVerbose
				If g_dSelections.Item( sPathToTest ) = true then
					TestProfile = sPathToTest
				End if
				exit function
			End if

			sPathToTest = oFSO.GetParentFolderName( sPathToTest ) 
			
		Loop
		oLogging.CreateEntry "Finished Parsing SelectionProfile end of function  '" & sSelectionProfile & "' Folder Matches = " & g_dSelections.Count, LogTypeVerbose

	End function
	
	Private Function dEnabled   ' AS DictionaryObject
		Dim oItem
	
		If g_dEnabled is nothing then
		
			oLogging.CreateEntry "Create dEnabled object. List of all enabled items for: " & sFileType, LogTypeVerbose
			set g_dEnabled = CreateObject("Scripting.Dictionary")
			'TestAndFail not ( g_dEnabled is nothing), 10108, "Create Scripting Object"
			g_dEnabled.CompareMode = vbTextCompare

			If oEnvironment.Item(sEnabledElements) <> "" then
				If not g_dEnabled.Exists(oEnvironment.Item(sEnabledElements)) then
					g_dEnabled.Add oEnvironment.Item(sEnabledElements), "ChEcKeD"
				End if
			Else
				for each oItem in oEnvironment.ListItem(sEnabledElements)
					If not g_dEnabled.Exists(oItem) then
						g_dEnabled.Add oItem, "ChEcKeD"
					End if
				next
			End if
			
			' Special Case
			If ucase(sEnabledElements) = "APPLICATIONS" then

				for each oItem in oEnvironment.ListItem("MandatoryApplications")
				
					If not g_dEnabled.Exists(oItem) then
						g_dEnabled.Add oItem, "ChEcKeD disabled"
					Else
						g_dEnabled.Item(oItem) = "ChEcKeD disabled"
					End if
					
				next 
			
			End if
			
			oLogging.CreateEntry "dEnabled Dictionary Object Created, count = " & g_dEnabled.count, LogTypeVerbose
			
		End if
		
		set dEnabled = g_dEnabled
	
	End function

	Private Function dElementsToFolders  ' AS DictionaryObject
	
		Dim oItem
		Dim sGuid
		
		If g_dElementsToFolders is nothing then

			oLogging.CreateEntry "Create dElementsToFolders object. Relationship of Elements to Folders/Groups for: " & sFileType, LogTypeVerbose
			set g_dElementsToFolders = CreateObject("Scripting.Dictionary")
			'TestAndFail not ( g_dElementsToFolders is nothing), 10107, "Create Scripting Object"
			g_dElementsToFolders.CompareMode = vbTextCompare
			
			for each oItem in oGroupControlFile.SelectNodes("/*/*/*" )
			
				Select Case UCASE(oItem.NodeName)

					Case "NAME"               'Ignore ..
					Case "COMMENTS"
					Case "LASTMODIFIEDTIME"
					Case "LASTMODIFIEDBY"
					Case "CREATEDTIME"
					Case "CREATEDBY"
					Case Else
					
						sGuid = oItem.parentNode.getAttribute("guid")
						If not g_dElementsToFolders.exists( oItem.Text ) then
							g_dElementsToFolders.Add oItem.Text, sGuid
						Else
							g_dElementsToFolders.Item( oItem.Text ) = g_dElementsToFolders.Item( oItem.Text ) & vbTab & sGuid
						End if
						
				End select

			next 
			
			oLogging.CreateEntry "dElementsToFolders Dictionary Object Created, count = " & g_dElementsToFolders.count, LogTypeVerbose			

		End if
		
		set dElementsToFolders = g_dElementsToFolders
	
	End function
	

	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'
	' Stateless functions
	'
	
	Private Function LookupCheckedState ( oFolder, oItem ) 

		Dim sItemName
		Dim sItemGuid
		Dim sFolderName
		Dim sFolderGuid
		Dim sMatchType
		
		sItemName    = oUtility.SelectSingleNodeString(oItem,"./Name") 
		sItemGuid    = oItem.getAttribute("guid")
		sFolderName  = oUtility.SelectSingleNodeString(oFolder,"./Name") 
		sFolderGuid  = oFolder.getAttribute("guid")
		
		' Form of:  82af1067-6f90-4862-a690-fde433ca593b
		' Form of:  85abe1d8-c978-4f75-a313-9d18502ff78d\82af1067-6f90-4862-a690-fde433ca593b
		' Form of:  Redmond\Research and Development\82af1067-6f90-4862-a690-fde433ca593b
		' Form of:  85abe1d8-c978-4f75-a313-9d18502ff78d\Microsoft Office 2007 SP1
		' Form of:  Redmond\Research and Development\Microsoft Office 2007 SP1
		LookupCheckedState  = ""
		for each sMatchType in array ( sItemGuid, sFolderGuid & "\" & sItemGuid, sFolderName & "\" & sItemGuid, sFolderGuid & "\" & sItemName, sFolderName & "\" & sItemName )
			If dEnabled.Exists( sMatchType ) then
				LookupCheckedState = dEnabled.Item( sMatchType )
				exit for
			End if
		next
	
		oLogging.CreateEntry "LookupCheckedState: [" & sEnabledElements & "] with [" & sFolderName & "]\[" & sItemName & "] = " & LookupCheckedState, LogTypeVerbose

	End function 

	Public Function XPathFilterString( bEnabled, bHidden )  ' AS String
	
		Dim FilterString1, FilterString2
	
		If bEnabled = True then
			FilterString1 = "( @enable = 'True' or not(@enable) )"
		Elseif bEnabled = False then
			FilterString1 = "( @enable != 'True' )"
		End if

		If bHidden = True then
			FilterString2 = "( @hide = 'True' )"
		Elseif bHidden = False then
			FilterString2 = "( @hide != 'True' or not(@hide) )"
		End if
		
		If FilterString1 <> "" and FilterString2 <> "" then
			XPathFilterString = FilterString1 & " and " & FilterString2
		Else
			
			XPathFilterString = FilterString1 & FilterString2
		End if
	
	End function


	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	Private Function BuildHTML_Element ( oFolder, oItem  )  ' AS String

		Dim sGuid
		Dim sName
		Dim sComments
		Dim sIsChecked
		Dim sFolderGuid
		Dim sTSTemplate
		Dim bIsUpgradeTS
		
		If not oItem.SelectSingleNode("./TaskSequenceTemplate") is nothing then
			sTSTemplate = oItem.SelectSingleNode("./TaskSequenceTemplate").Text
		End if
		
		If len(sTSTemplate) > 10 and Right(Ucase(sTSTemplate),11) = "UPGRADE.XML" then 
			bIsUpgradeTS = 1
		Else 
			bIsUpgradeTS = 0
		End if
		
		If oEnvironment.Item("OSVersion") = "WinPE" and bIsUpgradeTS = 1 then
			oLogging.CreateEntry "Upgrade TS is not available in WinPE but only in full OS", LogTypeInfo
			BuildHTML_Element = ""
		Else
		
			sGuid = oItem.getAttribute("guid")
			sFolderGuid = oFolder.getAttribute("guid")
			sName = ""
			If not oItem.SelectSingleNode("./DisplayName") is nothing then
				sName = oItem.SelectSingleNode("./DisplayName").Text
			End if 
			If sName = "" then
				sName = EncodeXML(oUtility.SelectSingleNodeString(oItem,"./Name"))
			End if
			
			sComments = ""
			If not oItem.SelectSingleNode("./Comments") is nothing then
				sComments = EncodeXML(oItem.SelectSingleNode("./Comments").Text)
				If sComments <> "" then
					sComments = "<div>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" & sComments & "</div>"
				End if
			End if
			
			If sGuid = "DEFAULT" then
				sIsChecked = "ChEcKeD disabled"
			Else
				sIsChecked = LookupCheckedState ( oFolder, oItem )
			End if 
			
			oLogging.CreateEntry "BuildHTML_Element: " & sFolderGuid & "-" & sGuid & "   " & sName & " [" & sIsChecked & "]", LogTypeVerbose
			
			If sHTMLPropertyHook <> "" then
				sIsChecked = sIsChecked & sHTMLPropertyHook 
			End if

			BuildHTML_Element = "<div onmouseover=""javascript:this.className = 'DynamicListBoxRow-over';"" onmouseout=""javascript:this.className = 'DynamicListBoxRow';"" >"
			BuildHTML_Element = BuildHTML_Element & "<input name=" & sEnabledElements & " type=" & sButtonStyle & " id='" & sFolderGuid & "-" & sGuid & "' value='" & sGuid & "' " & sIsChecked & "/><img src='" & sItemIcon & "' />"
			BuildHTML_Element = BuildHTML_Element & "<label for='" & sFolderGuid & "-" & sGuid & "' class=TreeItem>" & sName & "</label>&nbsp;&nbsp;" & sComments & "</div>"

		End if		
		
	End function 


	Private Function BuildHTML_Folder ( oFolder, byval iLevel )  ' AS String

		Dim sGuid
		Dim sName
		Dim oItem
		Dim sComments
		
		sGuid = oFolder.getAttribute("guid")
		sName = EncodeXML(ofso.GetFileName(oUtility.SelectSingleNodeString(oFolder,"./Name")))
		sComments = ""
		If not oFolder.selectSingleNode("./Comments") is nothing then
			sComments = EncodeXML(oFolder.selectSingleNode("./Comments").text)
		End if
		
		oLogging.CreateEntry "BuildHTML_Folder: " & sGuid & "   " & sName, LogTypeVerbose
		

		' Construct Child Folders
		for each oItem in GetChildFolders ( oUtility.SelectSingleNodeString(oFolder,"Name") )
			If dFolders.Exists( oItem ) then
				BuildHTML_Folder = BuildHTML_Folder & BuildHTML_Folder ( dFolders.Item(oItem), iLevel + 1 )
			End if 
		next

		' Construct Child Elements
		for each oItem in FindItemsByFolder ( oFolder ).Items
			BuildHTML_Folder = BuildHTML_Folder & BuildHTML_Element ( oFolder, oItem )
		next
		
		
		BuildHTML_Folder = trim(BuildHTML_Folder)
		If BuildHTML_Folder = "" then
			' There are no Child Elements. Do not display this folder
			oLogging.CreateEntry "BuildHTML_Folder: Skip! " & sGuid & "   " & sName, LogTypeVerbose
			exit function 
		End if

		BuildHTML_Folder = BuildHTML_Folder & vbNewLine

		' Construct This Folder
		If sGuid <> ROOT_FOLDER_GUID then
		
			If iLevel < 2 or Instr(1,BuildHTML_Folder,"ChEcKeD",0) <> 0 then
				BuildHTML_Folder = "<div class=TreeDir id='" & sGuid & "-Window' >" & BuildHTML_Folder & "</div>"
			Else
				BuildHTML_Folder = "<div class=TreeDir id='" & sGuid & "-Window' style='display: none;' >" & BuildHTML_Folder & "</div>"
			End if
			BuildHTML_Folder = "<img src='FolderIcon.png' /><label class=TreeDirLabel for='" & sGuid & "-Icon'>" & sName & "</label>&nbsp;&nbsp;" & sComments & "</div>" & BuildHTML_Folder
			If iLevel < 2 or Instr(1,BuildHTML_Folder,"ChEcKeD",0) <> 0 then
				BuildHTML_Folder = "<input id='" & sGuid & "-Icon' type=image src='MinusIcon1.png' onclick=""javascript:HideUnHideFolder('" & sGuid & "-Window');""> " & BuildHTML_Folder
			Else
				BuildHTML_Folder = "<input id='" & sGuid & "-Icon' type=image src='PlusIcon1.png' onclick=""javascript:HideUnHideFolder('" & sGuid & "-Window');""> " & BuildHTML_Folder
			End if
			BuildHTML_Folder = "<div class=TreeDirLabel >" & BuildHTML_Folder
		
		End if

	End Function


	Private Function EncodeXML( sXMLString ) 
		Dim aString
		Dim i

		aString = split( sXMLString, "&", -1, vbTextCompare)
		for i = lbound(aString) to ubound(aString)
			astring(i)  = replace(replace(astring(i) ,">","&gt;",1,-1,vbTextCompare),"<","&lt;",1,-1,vbTextCompare)
		next
		EncodeXML = join(aSTring,"&amp;")

	End function

	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'
	' Class Initialization
	'
	
	Private Sub Class_Initialize
	
		ROOT_FOLDER_GUID = "{00000000-0000-0000-0000-000000000000}"
		HIDDEN_FOLDER_GUID = "{FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF}"

		sFileType = empty
		sSelectionProfile = "Everything"
		sCustomSelectionProfile = empty
		sGroupList = empty
		bEnabled = TRUE
		bHidden = FALSE
		bMustSucceed = TRUE

		sEnabledElements = empty
		sButtonStyle = empty
		sItemIcon = "ItemIcon1.png"
		sHTMLPropertyHook = ""

		set g_oGroupControlFile = Nothing
		set g_oControlFile = Nothing

		set g_GetChildFolders = nothing
		set g_dFolders = nothing
		set g_dElementsToFolders = nothing
		set g_dEnabled = nothing
		set g_FindAllItems = nothing
		set g_FindFilteredItems = nothing
		g_xPath = empty
		fnCustomFilter = empty

	End sub

End Class

