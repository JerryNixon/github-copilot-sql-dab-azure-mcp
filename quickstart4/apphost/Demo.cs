// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Diagnostics;
using Spectre.Console;

static class Demo
{
    public static bool VerifySetup(string rootPath, out string? token)
    {
        token = null;

        if (!FileExists(Path.Combine(rootPath, "database.sql"), out var error))
        {
            ShowError($"{error} (SQL schema for Aspire to create the database)");
            return false;
        }

        var configJs = Path.Combine(rootPath, "web", "config.js");
        if (!FileExists(configJs, out error))
        {
            ShowError($"{error} (Entra ID settings for the web app)");
            return false;
        }

        var dabConfig = Path.Combine(rootPath, "api", "dab-config.json");
        if (!FileExists(dabConfig, out error))
        {
            ShowError($"{error} (Data API Builder configuration)");
            return false;
        }

        if (!IsConfigured(configJs, out error, "__CLIENT_ID__", "__TENANT_ID__"))
        {
            ShowError($"{error} (run azure/entra-setup.ps1 to configure)");
            return SetupAndRetry(rootPath, out token);
        }
        else if (!IsConfigured(dabConfig, out error, "__AUDIENCE__", "__ISSUER__"))
        {
            ShowError($"{error} (run azure/entra-setup.ps1 to configure)");
            return SetupAndRetry(rootPath, out token);
        }
        else
        {
            ShowTestUser(rootPath);
            token = ReadToken(rootPath);
            return true;
        }
    }

    private static bool SetupAndRetry(string rootPath, out string? token)
    {
        token = null;

        if (!IsInteractive())
        {
            return false;
        }

        if (!HasPrerequisites(out var error))
        {
            ShowError(error);
            return false;
        }

        if (!CompletesSetup(out error))
        {
            ShowError(error);
            return false;
        }

        if (!RunsAzLogin(rootPath, out error))
        {
            ShowError(error);
            return false;
        }

        if (!RunsEntraSetup(rootPath, out error))
        {
            ShowError(error);
            return false;
        }

        return VerifySetup(rootPath, out token);

        static bool IsInteractive()
        {
            return !Console.IsInputRedirected && Environment.UserInteractive;
        }
    }

    private static bool IsConfigured(string path, out string? error, params string[] markers)
    {
        if (!File.Exists(path))
        {
            error = $"{Path.GetFileName(path)} not found.";
            return false;
        }

        var content = File.ReadAllText(path);
        var found = markers.Where(content.Contains).ToArray();
        if (found.Length > 0)
        {
            error = $"{Path.GetFileName(path)} contains placeholders: {string.Join(", ", found)}";
            return false;
        }

        error = null;
        return true;
    }

    private static bool FileExists(string path, out string? error)
    {
        if (!File.Exists(path))
        {
            error = $"Missing file: {Path.GetFileName(path)}";
            return false;
        }

        error = null;
        return true;
    }

    private static bool HasPrerequisites(out string? error)
    {
        var prereqs = new (string Name, string Command, string Install)[]
        {
            ("Azure CLI",    "az",   "[link=https://aka.ms/installazurecli]https://aka.ms/installazurecli[/]"),
            ("DAB CLI",      "dab",  "[dim]dotnet tool install -g Microsoft.DataApiBuilder[/]"),
            ("PowerShell 7", "pwsh", "[link=https://aka.ms/powershell]https://aka.ms/powershell[/]"),
        };
        var status = prereqs.Select(p => (p.Name, p.Install, Found: CommandExists(p.Command))).ToList();
        var hasMissing = status.Any(s => !s.Found);

        var msg =
            "[yellow]Hey[/] — you haven't set up Entra ID yet.\n\n" +
            "You'll need an [white]app registration[/] and a [white]test user[/] in your\n" +
            "Azure AD tenant before the app can start. The setup script\n" +
            "automates all of this for you:\n\n" +
            "  [white]az login[/]\n" +
            "  [white]./azure/entra-setup.ps1[/]\n\n" +
            (hasMissing
                ? "[yellow]Before you run the script, install the missing prerequisites:[/]"
                : "[green]All prerequisites are installed:[/]") +
            "\n\n" +
            string.Join("\n", status.Select(s =>
                s.Found
                    ? $"  [green]✓[/] [white]{s.Name}[/]  →  {s.Install}"
                    : $"  [red]✗[/] [white]{s.Name}[/]  →  {s.Install}"));

        var panel = new Panel(msg)
        {
            Header = new PanelHeader("[red bold] SETUP REQUIRED [/]"),
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Red),
            Padding = new Padding(2, 1)
        };

        AnsiConsole.WriteLine();
        AnsiConsole.Write(panel);
        AnsiConsole.WriteLine();

        error = hasMissing
            ? "Missing: " + string.Join(", ", status.Where(s => !s.Found).Select(s => s.Name))
            : null;
        return !hasMissing;
    }

    private static bool CompletesSetup(out string? error)
    {
        AnsiConsole.Markup("  [green]Run setup now?[/] [dim](Y/n)[/] ");
        var key = Console.ReadKey(intercept: false);
        AnsiConsole.WriteLine();
        var accepted = key.Key is ConsoleKey.Enter or ConsoleKey.Y;
        error = accepted ? null : "Setup declined by user.";
        return accepted;
    }

    private static bool RunsAzLogin(string rootPath, out string? error)
    {
        if (IsLoggedIn())
        {
            AnsiConsole.Markup("\n  [green]✓[/] Already logged in to Azure CLI\n");
            error = null;
            return true;
        }

        AnsiConsole.Markup("\n  [yellow]Running:[/] az login\n");
        var success = TryRun("az", "login --output none", rootPath);
        error = success ? null : "az login failed. Sign in manually and try again.";
        return success;

        bool IsLoggedIn()
        {
            return TryRun("az", "account show --output none", rootPath);
        }
    }

    private static bool RunsEntraSetup(string rootPath, out string? error)
    {
        var scriptPath = Path.Combine(rootPath, "azure", "entra-setup.ps1");
        AnsiConsole.Markup("  [yellow]Running:[/] ./azure/entra-setup.ps1\n\n");
        var success = TryRun("pwsh", $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"", rootPath);
        error = success ? null : "Setup script failed. Check the output above.";
        return success;
    }

    private static void ShowError(string? message)
    {
        if (message != null)
        {
            AnsiConsole.Markup($"\n  [red]✗ {message}[/]\n");
        }
    }

    private static string? ReadToken(string rootPath)
    {
        var file = Path.Combine(rootPath, ".azure-env");
        if (!File.Exists(file))
        {
            return null;
        }

        return File.ReadAllLines(file)
            .Where(l => l.Contains('=') && !l.StartsWith('#'))
            .Select(l => (Key: l[..l.IndexOf('=')].Trim(), Value: l[(l.IndexOf('=') + 1)..].Trim()))
            .FirstOrDefault(l => l.Key == "token").Value;
    }

    private static void ShowTestUser(string rootPath)
    {
        var file = Path.Combine(rootPath, ".azure-env");
        if (!File.Exists(file))
        {
            return;
        }

        var lines = File.ReadAllLines(file)
            .Where(l => l.Contains('='))
            .ToDictionary(
                l => l[..l.IndexOf('=')].Trim(),
                l => l[(l.IndexOf('=') + 1)..].Trim());

        if (lines.TryGetValue("username", out var user) && lines.TryGetValue("password", out var pass))
        {
            var panel = new Panel(
                    $"[white]Username:[/]  [cyan]{user}[/]\n" +
                    $"[white]Password:[/]  [cyan]{pass}[/]")
            {
                Header = new PanelHeader("[green bold] TEST USER [/]"),
                Border = BoxBorder.Rounded,
                BorderStyle = new Style(Color.Green),
                Padding = new Padding(2, 1)
            };

            AnsiConsole.WriteLine();
            AnsiConsole.Write(panel);
        }
        else
        {
            var panel = new Panel(
                    "[yellow]Credentials missing from .azure-env[/]")
            {
                Header = new PanelHeader("[yellow bold] TEST USER [/]"),
                Border = BoxBorder.Rounded,
                BorderStyle = new Style(Color.Yellow),
                Padding = new Padding(2, 1)
            };

            AnsiConsole.WriteLine();
            AnsiConsole.Write(panel);
        }
    }

    private static bool CommandExists(string command)
    {
        try
        {
            var probe = OperatingSystem.IsWindows() ? "where" : "which";
            var p = Process.Start(new ProcessStartInfo(probe, command)
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            });
            if (p == null)
            {
                return false;
            }

            p.WaitForExit(5000);
            var found = p.ExitCode == 0;
            p.Dispose();
            return found;
        }
        catch { return false; }
    }

    private static bool TryRun(string fileName, string arguments, string workingDirectory)
    {
        var psi = OperatingSystem.IsWindows()
            ? new ProcessStartInfo("cmd", $"/c {fileName} {arguments}")
            : new ProcessStartInfo(fileName, arguments);
        psi.UseShellExecute = false;
        psi.WorkingDirectory = workingDirectory;
        using var process = Process.Start(psi)!;
        process.WaitForExit();
        return process.ExitCode == 0;
    }
}
