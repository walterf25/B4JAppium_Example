B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10.45
@EndOfDesignText@
' Per-app-under-test configuration, loaded from Files/apps/<appId>.json.
' Deliberately platform-generic: PlatformName/AutomationName/ExtraCapabilities all come straight
' from the JSON, so adding an iOS app later is a new JSON file, not a code change.
Sub Class_Globals
	Public AppId As String
	Public DisplayName As String
	Public PlatformName As String
	Public PlatformKey As String
	Public AutomationName As String
	Public AppPath As String
	Public AppPackage As String
	Public DeviceName As String
	Public AppiumHost As String
	Public AppiumPort As Int
	Public BasePath As String
	Public ExtraCapabilities As Map
	Public Recipes As List
	Public ReportName As String
	Public StopOnRecipeFailure As Boolean
End Sub

Public Sub Initialize
	ExtraCapabilities.Initialize
	Recipes.Initialize
End Sub

'Load an app config, e.g. LoadFromFile(File.DirAssets & "/apps", "automotive-demo.json")
Public Sub LoadFromFile(Dir As String, FileName As String)
	Dim jsonText As String = File.ReadString(Dir, FileName)
	Dim p As JSONParser
	p.Initialize(jsonText)
	Dim root As Map = p.NextObject

	AppId = root.GetDefault("appId", "")
	DisplayName = root.GetDefault("displayName", AppId)
	PlatformName = root.GetDefault("platformName", "Android")
	PlatformKey = PlatformName.ToLowerCase
	AutomationName = root.GetDefault("automationName", "UiAutomator2")
	AppPath = root.GetDefault("appPath", "")
	AppPackage = root.GetDefault("appPackage", "")
	DeviceName = root.GetDefault("deviceName", "")
	AppiumHost = root.GetDefault("appiumHost", "http://127.0.0.1")
	AppiumPort = root.GetDefault("appiumPort", 4723)
	BasePath = root.GetDefault("basePath", "")
	ReportName = root.GetDefault("reportName", "test-report.html")
	StopOnRecipeFailure = root.GetDefault("stopOnRecipeFailure", True)

	Dim extraCaps As Map = root.GetDefault("extraCapabilities", Null)
	If extraCaps <> Null And extraCaps.IsInitialized Then
		ExtraCapabilities = extraCaps
	End If

	Dim recipeList As List = root.GetDefault("recipes", Null)
	If recipeList <> Null And recipeList.IsInitialized Then
		Recipes = recipeList
	End If
End Sub

'Builds the DesiredCapabilities the driver needs from the core fields + ExtraCapabilities.
Public Sub BuildCapabilities As DesiredCapabilities
	Dim caps As DesiredCapabilities
	caps.Initialize
	caps.setCapability("platformName", PlatformName)
	caps.setCapability("automationName", AutomationName)
	If DeviceName <> "" Then caps.setCapability("deviceName", DeviceName)
	If AppPath <> "" Then caps.setCapability("app", AppPath)

	For Each key As String In ExtraCapabilities.Keys
		caps.setCapability(key, ExtraCapabilities.Get(key))
	Next

	Return caps
End Sub
