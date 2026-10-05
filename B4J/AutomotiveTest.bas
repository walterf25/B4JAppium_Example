B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private driver As B4XAppium
	Private report As TestReport
	Private imagePath As String = File.DirApp
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(Apkpath As String)
	Dim caps As DesiredCapabilities
	caps.Initialize
	caps.setCapability("platformName", "Android")
	caps.setCapability("deviceName", "R5CTC1JMZCR")
	caps.setCapability("app", Apkpath)
	caps.setCapability("automationName", "UiAutomator2")
	caps.setCapability("autoGrantPermissions", True)
	driver.Initialize("android", "http://127.0.0.1", 4723, "", caps)
	
	report.Initialize(File.DirApp&"/test-report.html")
	report.StartTest("Login Test")
End Sub

Public Sub FillinCrecentials As ResumableSub
	Try
		Dim wel As WebElement
		wel = driver.findElementByxpath("Enter username")
		wel.SendKeys("walterf25")
		report.LogPass("Entered User Name")
	
		wel = driver.findElementByxpath("Enter 4-digit PIN")
		wel.SendKeys("0903")
		report.LogPass("Entered PIN Number")
	
		driver.takeScreenShot(imagePath&"/login-info.png")
	
		report.AddScreenshot(imagePath&"/login-info.png")
		Return True
	Catch
		Log(LastException)
		report.LogFail("failed to login")
		driver.takeScreenShot(imagePath&"/login-failed.png")
		report.LogFail("failed siging in")
		report.AddScreenshot(imagePath&"/login-failed.png")
		Return False
	End Try
End Sub

Public Sub Login As ResumableSub
	Try
		Dim wel As WebElement
		wel = driver.findElementByxpath("Log in")
		wel.Click
		Sleep(1000)
		report.LogPass("Successfully logged-in")
		driver.takeScreenShot(File.DirApp&"/logged-in.png")
		report.AddScreenshot(File.DirApp&"/logged-in.png")
		Return True
	Catch
		report.LogFail("did not find log in button")
		driver.takeScreenShot(File.DirApp&"/login-fail.png")
		report.LogFail("failed to login")
		report.AddScreenshot(File.DirApp&"/login-fail.png")
		Return False
	End Try
End Sub

Public Sub GotoTakeMyMeasurements As ResumableSub
	Try
		Dim wel As WebElement
		wel = driver.findElementByxpath("Take my measurements")
		wel.Click
		Sleep(1200)
		report.LogPass("navigated to Take my measurements screen")
		driver.takeScreenShot(imagePath&"/takemymeasurements.png")
		report.AddScreenshot(imagePath&"/takemymeasurements.png")
		Return True
	Catch
		driver.takeScreenShot(imagePath&"/takemymeasurements-failed.png")
		report.LogFail("failed to find take my measurements screen")
		report.AddScreenshot(imagePath&"/takemymeasurements-failed.png")
		Return False
	End Try
End Sub

Public Sub StartMyExperience As ResumableSub
	Try
		Dim wel As WebElement
		wel = driver.findElementByxpath("Start my experience")
		wel.Click
		Sleep(1200)
		report.LogPass("navigated to Start my experience screen")
		driver.takeScreenShot(imagePath&"/startmyexperience.png")
		report.AddScreenshot(imagePath&"/startmyexperience.png")
		Return True
	Catch
		driver.takeScreenShot(imagePath&"/startmyexperience-failed.png")
		report.LogFail("failed to find startmyexperience screen")
		report.AddScreenshot(imagePath&"/startmyexperience-failed.png")
		Return False
	End Try
End Sub

Public Sub SkipPlayTutorial As ResumableSub
	Try
		Dim wel As WebElement
		wel = driver.findElementByxpath("Skip")
		wel.Click
		Sleep(1200)
		report.LogPass("navigated to Start Take my picture screen")
		driver.takeScreenShot(imagePath&"/takemypicture.png")
		report.AddScreenshot(imagePath&"/takemypipcture.png")
		Return True
	Catch
		driver.takeScreenShot(imagePath&"/takemypicture-failed.png")
		report.LogFail("failed to find take my picture screen")
		report.AddScreenshot(imagePath&"/takemypicture-failed.png")
		Return False
	End Try
End Sub

Public Sub EndTest
	report.EndReport
	driver.quit
End Sub