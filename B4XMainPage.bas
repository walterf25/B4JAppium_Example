B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=Project.zip

Sub Class_Globals
	Private Root As B4XView
	Private driver As B4XAppium
	Private report As TestReport
	Private runner As RecipeRunner
	Private appConfig As AppConfig
End Sub

Public Sub Initialize
'	B4XPages.GetManager.LogEvents = True
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("MainPage")

	Dim appId As String = ResolveAppId
	appConfig.Initialize
	appConfig.LoadFromFile(File.DirAssets, appId & ".json")

	Dim caps As DesiredCapabilities = appConfig.BuildCapabilities
	driver.Initialize(appConfig.PlatformKey, appConfig.AppiumHost, appConfig.AppiumPort, appConfig.BasePath, caps)

	report.Initialize(File.DirApp & "/" & appConfig.ReportName)
	runner.Initialize(driver, report, File.DirApp, appConfig.AppPackage)
End Sub

'Picks the app-under-test id: a launch arg wins, otherwise Files/active-app.json.
Private Sub ResolveAppId As String
	If Main.StartupArgs.Length > 0 And Main.StartupArgs(0) <> "" Then Return Main.StartupArgs(0)

	Dim jsonText As String = File.ReadString(File.DirAssets, "active-app.json")
	Dim p As JSONParser
	p.Initialize(jsonText)
	Dim Root1 As Map = p.NextObject
	Return Root1.GetDefault("appId", "ble-observer")
End Sub

'''You can see the list of page related events in the B4XPagesManager object. The event name Is B4XPage.

Private Sub Button1_Click
	Dim anyFailures As Boolean = False

	For Each recipeFile As String In appConfig.Recipes
		Dim jsonText As String = File.ReadString(File.DirAssets, recipeFile)
		Wait For (runner.RunRecipeFromJson(jsonText)) Complete (ok As Boolean)
		Log(recipeFile & " finished: " & ok)
		If ok = False Then
			anyFailures = True
			If appConfig.StopOnRecipeFailure Then Exit
		End If
	Next

	report.EndReport
	driver.quit
	Log("All recipes finished. Any failures: " & anyFailures)
End Sub
