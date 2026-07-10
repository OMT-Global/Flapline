using System;
using System.IO;
using System.Text.Json;

namespace Flapline.Windows;

internal static class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Flapline",
        "settings.json"
    );

    public static FlaplineSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var settings = JsonSerializer.Deserialize<FlaplineSettings>(File.ReadAllText(SettingsPath), JsonOptions);
                if (settings is not null)
                {
                    settings.Normalize();
                    return settings;
                }
            }
        }
        catch (JsonException)
        {
            // A corrupt local preference file should not prevent the saver from starting.
        }
        catch (IOException)
        {
            // Fall back to defaults when the profile is temporarily unavailable.
        }

        return new FlaplineSettings();
    }

    public static void Save(FlaplineSettings settings)
    {
        settings.Normalize();
        var directory = Path.GetDirectoryName(SettingsPath)!;
        Directory.CreateDirectory(directory);

        var temporaryPath = SettingsPath + ".tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(settings, JsonOptions));
        File.Move(temporaryPath, SettingsPath, overwrite: true);
    }
}
