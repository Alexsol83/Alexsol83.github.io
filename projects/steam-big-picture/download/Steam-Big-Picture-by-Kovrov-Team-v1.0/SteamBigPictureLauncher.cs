using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("Steam Big Picture by Kovrov Team")]
[assembly: AssemblyProduct("Steam Big Picture by Kovrov Team")]
[assembly: AssemblyCompany("Kovrov Team")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const string AppTitle = "Steam Big Picture by Kovrov Team — v1.0";

    [STAThread]
    private static void Main()
    {
        try { LaunchWizard(); }
        catch (Exception ex)
        {
            MessageBox.Show("Программа не смогла открыть мастер.\r\n\r\n" + ex.Message,
                AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void LaunchWizard()
    {
        string appDirectory = Path.GetDirectoryName(Application.ExecutablePath);
        string monitorTool = Path.Combine(appDirectory, "MultiMonitorTool.exe");
        string audioTool = Path.Combine(appDirectory, "SoundVolumeView.exe");
        if (!File.Exists(monitorTool) || !File.Exists(audioTool))
        {
            MessageBox.Show(
                "Рядом с программой должны находиться оригинальные файлы:\r\n\r\n" +
                "• MultiMonitorTool.exe\r\n• SoundVolumeView.exe\r\n\r\n" +
                "Скачайте их с сайта NirSoft и поместите в эту же папку.",
                AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
            @"WindowsPowerShell\v1.0\powershell.exe");
        if (!File.Exists(powershell))
        {
            MessageBox.Show("В Windows не найден Windows PowerShell 5.1.", AppTitle,
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        string logPath = Path.Combine(appDirectory, "launcher.log");
        File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") +
            " Launcher started. EXE directory: " + appDirectory + Environment.NewLine, Encoding.UTF8);
        string scriptPath = Path.Combine(appDirectory, "Configurator.runtime.ps1");
        using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream("Configurator.ps1"))
        {
            if (source == null)
            {
                MessageBox.Show("Встроенный мастер настройки не найден.", AppTitle,
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            using (StreamReader reader = new StreamReader(source, Encoding.UTF8, true))
                File.WriteAllText(scriptPath, reader.ReadToEnd(), new UTF8Encoding(true));
        }

        ProcessStartInfo start = new ProcessStartInfo();
        start.FileName = powershell;
        start.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " +
            Quote(scriptPath) + " -ToolsDirectory " + Quote(appDirectory);
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        start.WindowStyle = ProcessWindowStyle.Hidden;
        start.RedirectStandardError = true;
        start.RedirectStandardOutput = true;
        using (Process child = Process.Start(start))
        {
            if (child == null) throw new InvalidOperationException("Windows PowerShell не запустился.");
            StringBuilder output = new StringBuilder();
            StringBuilder errors = new StringBuilder();
            child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) output.AppendLine(e.Data); };
            child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) errors.AppendLine(e.Data); };
            child.BeginOutputReadLine();
            child.BeginErrorReadLine();
            bool endedEarly = child.WaitForExit(3500);
            if (endedEarly) child.WaitForExit();
            File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") +
                " PowerShell PID=" + child.Id + ", endedDuringStartup=" + endedEarly +
                (endedEarly ? ", exitCode=" + child.ExitCode : "") + Environment.NewLine +
                (String.IsNullOrWhiteSpace(output.ToString()) ? "" : output.ToString() + Environment.NewLine) +
                (String.IsNullOrWhiteSpace(errors.ToString()) ? "" : errors.ToString() + Environment.NewLine), Encoding.UTF8);
            if (endedEarly && child.ExitCode != 0)
                MessageBox.Show("Мастер завершился с ошибкой.\r\n\r\n" +
                    (String.IsNullOrWhiteSpace(errors.ToString()) ? output.ToString() : errors.ToString()) +
                    "\r\nПодробности: " + logPath, AppTitle,
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value + "\"";
    }
}
