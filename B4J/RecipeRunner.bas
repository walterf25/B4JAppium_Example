B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10.45
@EndOfDesignText@
' Recipe schema v2 steps: {action, locatorType (id|accessibilityId|text|uiSelector|xpath), locator, ...}
' Schema v1 steps (waitForText/tapText/waitForId/tapId/typeId/tapUi) are normalized to v2 on the fly.
' Failure handling: a failed step aborts the recipe unless the step sets "continueOnFailure":true
' or the recipe root sets "onFailure":"continue". RecipeRunner never calls report.EndReport -
' the caller owns that, once, after every recipe in a session has run.
Sub Class_Globals
	Private fx As JFX
	Private driver As B4XAppium
	Private report As TestReport
	Private OutputDir As String
	Private DefaultWaitMs As Int = 15000
	Private PollIntervalMs As Int = 350
	Private TestedPackage As String
End Sub

Public Sub Initialize(DriverInstance As B4XAppium, ReportInstance As TestReport, OutputFolder As String, TestedAppPackage As String)
	driver = DriverInstance
	report = ReportInstance
	OutputDir = OutputFolder
	TestedPackage = TestedAppPackage

	If File.Exists(OutputDir, "") = False Then File.MakeDir(OutputDir, "")
	If File.Exists(OutputDir, "screenshots") = False Then File.MakeDir(OutputDir, "screenshots")
End Sub

'Run a recipe JSON file (schema 1 or 2)
Public Sub RunRecipeFromJson(JsonText As String) As ResumableSub
	Try
		Dim p As JSONParser
		p.Initialize(JsonText)
		Dim root As Map = p.NextObject

		Dim schema As Int = root.GetDefault("schema", 0)
		If schema <> 1 And schema <> 2 Then
			Fail("Unsupported recipe schema: " & schema)
			Return False
		End If

		Dim recipeName As String = root.GetDefault("name", "Unnamed Recipe")
		Dim onFailure As String = root.GetDefault("onFailure", "stop")
		If report.IsInitialized Then report.StartTest(recipeName)
		LogPass("Starting recipe: " & recipeName)

		'⚠️ IMPORTANT: Do NOT use "Steps"
		Dim stpList As List = root.Get("steps")
		If stpList.IsInitialized = False Or stpList.Size = 0 Then
			Fail("Recipe has no steps.")
			Return False
		End If

		Dim recipeHadFailures As Boolean = False

		For i = 0 To stpList.Size - 1
			Dim rawStep As Map = stpList.Get(i)
			Dim stp As Map = NormalizeStep(rawStep, schema)
			Dim action As String = stp.GetDefault("action", "")
			Dim stepOk As Boolean = True
			Dim errMsg As String = ""

			If action = "" Then
				stepOk = False
				errMsg = "Missing action"
			Else
				Dim stepLabel As String = stp.GetDefault("name", action)
				LogPass($"Step ${i}: ${stepLabel}"$)

				Select Case action
					Case "waitFor"
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						Dim timeoutSec As Int = stp.GetDefault("timeoutSec", DefaultWaitMs / 1000)
						Dim rs As ResumableSub = WaitForLocator(locatorType, locator, timeoutSec * 1000)
						wait for (rs) Complete(result As Boolean)
						If result = False Then
							stepOk = False
							errMsg = "Timed out waiting for " & locatorType & ": " & locator
						End If

					Case "tap"
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						stepOk = DoTap(locatorType, locator)
						If stepOk = False Then errMsg = "Element not found (" & locatorType & "): " & locator
						Sleep(300)

					Case "type"
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						Dim textValue As String = stp.GetDefault("text", "")
						stepOk = DoType(locatorType, locator, textValue)
						If stepOk = False Then errMsg = "Element not found (" & locatorType & "): " & locator
						Sleep(200)

					Case "assertVisible"
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						Dim timeoutSec As Int = stp.GetDefault("timeoutSec", 5)
						Dim rs As ResumableSub = WaitForLocator(locatorType, locator, timeoutSec * 1000)
						wait for (rs) Complete(result As Boolean)
						stepOk = result
						If stepOk Then
							LogPass("Assert visible passed: " & locator)
						Else
							errMsg = "Not visible (" & locatorType & "): " & locator
						End If

					Case "assertText"
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						Dim expectedText As String = stp.GetDefault("expectedText", "")
						stepOk = DoAssertText(locatorType, locator, expectedText)
						If stepOk = False Then errMsg = "Text mismatch at (" & locatorType & "): " & locator

					Case "screenshot"
						Dim n As String = stp.GetDefault("name", "step")
						TakeShot($"${i}_${Sanitize(n)}"$)

					Case "sleep"
						Dim ms As Int = stp.GetDefault("ms", 500)
						Sleep(ms)

					Case "back"
						driver.Back
						Sleep(400)

					Case "swipe"
						Dim direction As String = stp.GetDefault("direction", "up")
						Dim durationMs As Int = stp.GetDefault("durationMs", 300)
						If direction = "down" Then
							driver.SwipeDown(durationMs)
						Else
							driver.SwipeUp(durationMs)
						End If
						Sleep(300)

					Case "scrollToText"
						Dim value As String = stp.GetDefault("value", "")
						Dim maxSwipes As Int = stp.GetDefault("maxSwipes", 6)
						stepOk = driver.ScrollToText(value, maxSwipes)
						If stepOk = False Then errMsg = "Could not scroll to text: " & value

					Case "tapIfPresent"
						' Like "tap", but a missing element is not a failure - use this for menu items
						' that may be self-excluded because we're already on that screen.
						Dim locatorType As String = stp.GetDefault("locatorType", "text")
						Dim locator As String = stp.GetDefault("locator", "")
						If ElementExists(locatorType, locator) Then
							stepOk = DoTap(locatorType, locator)
							If stepOk = False Then errMsg = "tapIfPresent: element vanished before tap (" & locatorType & "): " & locator
						Else
							LogPass("tapIfPresent: not present, skipping (" & locatorType & "): " & locator)
							stepOk = True
						End If
						Sleep(300)

					Case "closeMenuIfOpen"
						' Pairs with tapIfPresent for the self-exclusion case: if the tap above was
						' skipped, the drawer is still open (a missing element is never tapped, so
						' nothing closed it) - tap the menu icon once to close it. If the tap above
						' succeeded, the drawer already closed via real navigation, so do nothing -
						' re-tapping the menu icon when it's already closed would wrongly reopen it.
						Dim markerText As String = stp.GetDefault("marker", "About")
						Dim menuLocatorType As String = stp.GetDefault("locatorType", "xpath")
						Dim menuLocator As String = stp.GetDefault("locator", "")
						If ElementExists("text", markerText) Then
							stepOk = DoTap(menuLocatorType, menuLocator)
							If stepOk Then
								LogPass("closeMenuIfOpen: menu was open, closed it.")
							Else
								errMsg = "closeMenuIfOpen: menu appeared open but tap failed"
							End If
						Else
							LogPass("closeMenuIfOpen: menu already closed, nothing to do.")
							stepOk = True
						End If
						Sleep(300)

					Case Else
						stepOk = False
						errMsg = "Unknown action: " & action
				End Select
			End If

			If stepOk = False Then
				recipeHadFailures = True
				LogStepFailure(i, action, errMsg)
				Dim stepContinueOnFailure As Boolean = stp.GetDefault("continueOnFailure", False)
				If stepContinueOnFailure = False And onFailure <> "continue" Then
					Return False
				End If
			End If
		Next

		If recipeHadFailures Then
			LogFail("Recipe completed with failures.")
		Else
			LogPass("Recipe completed successfully.")
		End If
		Return Not(recipeHadFailures)

	Catch
		Log(LastException)
		Fail("Recipe execution error: " & LastException.Message)
		Return False
	End Try
End Sub

'======================
' Schema v1 -> v2 normalization
'======================
Private Sub NormalizeStep(stp As Map, schema As Int) As Map
	If schema = 2 Then Return stp

	Dim action As String = stp.GetDefault("action", "")
	Dim normalized As Map
	normalized.Initialize
	normalized.Put("name", stp.GetDefault("name", action))
	normalized.Put("screen", stp.GetDefault("screen", ""))

	Select Case action
		Case "waitForText"
			normalized.Put("action", "waitFor")
			normalized.Put("locatorType", "text")
			normalized.Put("locator", stp.GetDefault("value", ""))
			normalized.Put("timeoutSec", stp.GetDefault("timeoutSec", DefaultWaitMs / 1000))

		Case "tapText"
			normalized.Put("action", "tap")
			normalized.Put("locatorType", "text")
			normalized.Put("locator", stp.GetDefault("value", ""))

		Case "waitForId"
			' Legacy recipes pass hint/visible text as "id", not a real resource-id - keep resolving as text.
			normalized.Put("action", "waitFor")
			normalized.Put("locatorType", "text")
			normalized.Put("locator", stp.GetDefault("id", ""))
			normalized.Put("timeoutSec", stp.GetDefault("timeoutSec", DefaultWaitMs / 1000))

		Case "tapId"
			normalized.Put("action", "tap")
			normalized.Put("locatorType", "text")
			normalized.Put("locator", stp.GetDefault("id", ""))

		Case "typeId"
			normalized.Put("action", "type")
			normalized.Put("locatorType", "text")
			normalized.Put("locator", stp.GetDefault("id", ""))
			normalized.Put("text", stp.GetDefault("text", ""))

		Case "tapUi"
			normalized.Put("action", "tap")
			normalized.Put("locatorType", "uiSelector")
			normalized.Put("locator", stp.GetDefault("ui", ""))

		Case Else
			'screenshot / sleep / back / anything unrecognized pass through unchanged
			Return stp
	End Select

	Return normalized
End Sub

'======================
' Locator resolution
'======================
Private Sub ResolveElement(locatorType As String, locator As String) As WebElement
	If locator = "" Then Return Null
	Try
		Select Case locatorType
			Case "id"
				Return driver.tryFindElementById(locator)
			Case "text"
				Return driver.tryFindElementByText(locator)
			Case "accessibilityId"
				Return driver.tryFindElementByAccessibilityId(locator)
			Case "uiSelector"
				Return driver.tryFindElementByAndroidUIAutomator(locator)
			Case "xpath"
				Return driver.findElementByXPathRaw(locator)
			Case Else
				Return Null
		End Select
	Catch
		Return Null
	End Try
End Sub

Private Sub ElementExists(locatorType As String, locator As String) As Boolean
	Try
		Dim el As WebElement = ResolveElement(locatorType, locator)
		Return el.IsInitialized
	Catch
		Return False
	End Try
End Sub

Private Sub WaitForLocator(locatorType As String, locator As String, TimeoutMs As Int) As ResumableSub
	If locator = "" Then Return False
	Dim start As Long = DateTime.Now
	Do While DateTime.Now - start < TimeoutMs
		If ElementExists(locatorType, locator) Then Return True
		Sleep(PollIntervalMs)
	Loop
	Return False
End Sub

'======================
' Step actions
'======================
Private Sub DoTap(locatorType As String, locator As String) As Boolean
	Try
		Dim el As WebElement = ResolveElement(locatorType, locator)
		If el.IsInitialized = False Then Return False
		el.Click
		Return True
	Catch
		Return False
	End Try
End Sub

Private Sub DoType(locatorType As String, locator As String, TextValue As String) As Boolean
	Try
		Dim el As WebElement = ResolveElement(locatorType, locator)
		If el.IsInitialized = False Then Return False
		el.Clear
		el.SendKeys(TextValue)
		Return True
	Catch
		Return False
	End Try
End Sub

Private Sub DoAssertText(locatorType As String, locator As String, ExpectedText As String) As Boolean
	Try
		Dim el As WebElement = ResolveElement(locatorType, locator)
		If el.IsInitialized = False Then Return False
		Dim actual As String = el.Text
		Dim matched As Boolean = (actual = ExpectedText)
		If matched Then
			LogPass("Assert text passed: expected '" & ExpectedText & "' got '" & actual & "'")
		Else
			LogFail("Assert text failed: expected '" & ExpectedText & "' got '" & actual & "'")
		End If
		Return matched
	Catch
		Return False
	End Try
End Sub

'======================
' Logging / reporting helpers
'======================
Private Sub LogPass(msg As String)
	Log(msg)
	If report.IsInitialized Then report.LogPass(msg)
End Sub

Private Sub LogFail(msg As String)
	Log(msg)
	If report.IsInitialized Then report.LogFail(msg)
End Sub

Private Sub Fail(msg As String)
	LogFail(msg)
End Sub

Private Sub LogStepFailure(stepIndex As Int, action As String, msg As String)
	Fail($"Step ${stepIndex} (${action}) failed: ${msg}"$)
	Try
		TakeShot($"FAILED_step_${stepIndex}"$)
	Catch
	End Try
End Sub

Private Sub TakeShot(NameNoExt As String)
	Dim path As String = OutputDir & "/screenshots/" & NameNoExt & ".png"
	driver.takeScreenShot(path)
	LogPass("Screenshot: " & path)
	If report.IsInitialized Then report.AddScreenshot(path)
End Sub

Private Sub Sanitize(s As String) As String
	s = s.Replace("\", "_").Replace("/", "_").Replace(":", "_").Replace("*", "_").Replace("?", "_").Replace("""", "_").Replace("<", "_").Replace(">", "_").Replace("|", "_")
	Return s
End Sub
